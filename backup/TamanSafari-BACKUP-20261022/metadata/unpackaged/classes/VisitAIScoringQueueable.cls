/**
 * @description Sends completed visits to the n8n AI scorer (visit-ai-scoring design D3, D5, spec visit-ai-scoring
 *              "Request tracking"). One job handles up to 50 visits and chains the rest. All callouts for the batch are
 *              made first, because a callout cannot follow DML in the same transaction; then one update records the
 *              request id, status, attempt count and send time for every visit. The job may run as the rep who checked
 *              out or as the admin who owns the sweep, so it needs no object access of its own: the update goes
 *              through VisitLock.runAsSystem.
 *              A visit is sent when it is Completed and Pending or Sent. A 2xx answer means Sent. Any other answer
 *              counts as a failed attempt: back to Pending while attempts remain, otherwise Failed.
 */
public without sharing class VisitAIScoringQueueable implements Queueable, Database.AllowsCallouts {
  /** Visits per job. A transaction may make 100 callouts, and each has a short timeout, so 50 stays well inside. */
  public static final Integer BATCH_SIZE = 50;
  /** Webhook path under the N8N_Visit_Scoring Named Credential. */
  public static final String WEBHOOK_PATH = '/webhook/ts-visit-score';
  private static final Integer TIMEOUT_MS = 10000;

  private final List<Id> visitIds;

  /**
   * @param visitIds Visits to send. Visits beyond BATCH_SIZE are chained into a follow-up job.
   */
  public VisitAIScoringQueueable(List<Id> visitIds) {
    this.visitIds = visitIds;
  }

  /**
   * @description Sends one batch, records the outcome, and chains the remaining visits.
   * @param context Queueable context.
   */
  public void execute(QueueableContext context) {
    List<Id> batch = new List<Id>();
    List<Id> rest = new List<Id>();
    for (Id visitId : visitIds) {
      if (batch.size() < BATCH_SIZE) {
        batch.add(visitId);
      } else {
        rest.add(visitId);
      }
    }

    Integer maxAttempts = FieldSalesConfig.getAiMaxAttempts();
    // SYSTEM_MODE: the job may run as the rep who checked out, and reps have no field access to the AI fields.
    List<Visit_Form__c> visits = Database.query(
      'SELECT ' +
        VisitAIPayload.PAYLOAD_FIELDS +
        ', AI_Scoring_Status__c, AI_Attempt_Count__c FROM Visit_Form__c ' +
        'WHERE Id IN :batch AND Status__c = \'Completed\' AND AI_Scoring_Status__c IN (\'Pending\', \'Sent\')',
      AccessLevel.SYSTEM_MODE
    );

    // Callouts first. No DML may happen before the last callout.
    List<Visit_Form__c> changes = new List<Visit_Form__c>();
    for (Visit_Form__c visit : visits) {
      Integer used = visit.AI_Attempt_Count__c == null ? 0 : visit.AI_Attempt_Count__c.intValue();
      if (used >= maxAttempts) {
        changes.add(failed(visit.Id, used, 'No result after ' + used + ' attempts'));
        continue;
      }
      String requestId = VisitAIPayload.newRequestId();
      String error = send(VisitAIPayload.build(visit, requestId));
      if (error == null) {
        changes.add(
          new Visit_Form__c(
            Id = visit.Id,
            AI_Request_Id__c = requestId,
            AI_Scoring_Status__c = VisitRoutingService.AI_SENT,
            AI_Attempt_Count__c = used + 1,
            AI_Sent_At__c = System.now(),
            AI_Last_Error__c = null
          )
        );
      } else if (used + 1 >= maxAttempts) {
        changes.add(failed(visit.Id, used + 1, error));
      } else {
        changes.add(
          new Visit_Form__c(
            Id = visit.Id,
            AI_Scoring_Status__c = VisitRoutingService.AI_PENDING,
            AI_Attempt_Count__c = used + 1,
            AI_Last_Error__c = error.left(255)
          )
        );
      }
    }

    if (!changes.isEmpty()) {
      List<Database.SaveResult> results = VisitLock.runAsSystem(changes, false);
      for (Integer i = 0; i < results.size(); i++) {
        if (!results[i].isSuccess()) {
          System.debug(
            LoggingLevel.ERROR,
            'VisitAIScoringQueueable: update failed for ' + changes[i].Id + ': ' + results[i].getErrors()[0].getMessage()
          );
        }
      }
    }
    if (!rest.isEmpty()) {
      System.enqueueJob(new VisitAIScoringQueueable(rest));
    }
  }

  /**
   * @description Posts one payload to the n8n webhook through the Named Credential.
   * @param body JSON from VisitAIPayload.build.
   * @return Null on a 2xx answer, otherwise a short error text.
   */
  private static String send(String body) {
    HttpRequest request = new HttpRequest();
    request.setEndpoint('callout:N8N_Visit_Scoring' + WEBHOOK_PATH);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setTimeout(TIMEOUT_MS);
    request.setBody(body);
    try {
      HttpResponse response = new Http().send(request);
      if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
        return null;
      }
      return 'HTTP ' + response.getStatusCode() + ' from the evaluator';
    } catch (Exception e) {
      return e.getTypeName() + ': ' + e.getMessage();
    }
  }

  private static Visit_Form__c failed(Id visitId, Integer attempts, String error) {
    return new Visit_Form__c(
      Id = visitId,
      AI_Scoring_Status__c = VisitRoutingService.AI_FAILED,
      AI_Attempt_Count__c = attempts,
      AI_Last_Error__c = error.left(255)
    );
  }
}