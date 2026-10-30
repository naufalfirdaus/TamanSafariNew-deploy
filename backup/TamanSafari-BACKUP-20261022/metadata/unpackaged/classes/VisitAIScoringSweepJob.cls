/**
 * @description Recurring safety net for AI scoring (visit-ai-scoring design D11, spec "Automatic retries"). Every run
 *              finds Completed visits that are still Pending after a grace period, or have been Sent for longer than the
 *              callback timeout. Visits with attempts left are handed to VisitAIScoringQueueable; visits that have used
 *              every attempt become Failed with no tier. It runs without sharing as the admin who scheduled it, so it
 *              sees every rep's visits. Scheduling is done by scripts/apex/post-deploy.apex (four times an hour).
 */
public without sharing class VisitAIScoringSweepJob implements Schedulable {
  /** Minutes a visit may stay Pending before the sweep picks it up. The check-out trigger normally sends at once. */
  public static final Integer PENDING_GRACE_MINUTES = 5;
  /** Visits handled per run. Anything beyond is picked up by the next run. */
  public static final Integer RUN_LIMIT = 200;

  /**
   * @description Schedulable entry point.
   * @param context Scheduling context.
   */
  public void execute(SchedulableContext context) {
    run();
  }

  /**
   * @description One sweep. Public so it can be run from anonymous Apex.
   * @return Number of visits re-sent or failed in this run.
   */
  public static Integer run() {
    Datetime pendingCutoff = System.now().addMinutes(-PENDING_GRACE_MINUTES);
    Datetime sentCutoff = System.now().addMinutes(-FieldSalesConfig.getAiCallbackTimeoutMinutes());
    Integer maxAttempts = FieldSalesConfig.getAiMaxAttempts();

    List<Visit_Form__c> due = [
      SELECT Id, AI_Scoring_Status__c, AI_Attempt_Count__c
      FROM Visit_Form__c
      WHERE
        Status__c = :VisitLifecycleService.STATUS_COMPLETED
        AND (
          (AI_Scoring_Status__c = :VisitRoutingService.AI_PENDING AND LastModifiedDate < :pendingCutoff)
          OR (AI_Scoring_Status__c = :VisitRoutingService.AI_SENT AND AI_Sent_At__c < :sentCutoff)
        )
      WITH SYSTEM_MODE
      ORDER BY LastModifiedDate
      LIMIT :RUN_LIMIT
    ];

    List<Id> toSend = new List<Id>();
    List<Visit_Form__c> exhausted = new List<Visit_Form__c>();
    for (Visit_Form__c visit : due) {
      Integer used = visit.AI_Attempt_Count__c == null ? 0 : visit.AI_Attempt_Count__c.intValue();
      if (used >= maxAttempts) {
        exhausted.add(
          new Visit_Form__c(
            Id = visit.Id,
            AI_Scoring_Status__c = VisitRoutingService.AI_FAILED,
            AI_Last_Error__c = 'No result after ' + used + ' attempts'
          )
        );
      } else {
        toSend.add(visit.Id);
      }
    }
    if (!exhausted.isEmpty()) {
      VisitLock.runAsSystem(exhausted, false);
    }
    if (!toSend.isEmpty()) {
      System.enqueueJob(new VisitAIScoringQueueable(toSend));
    }
    return toSend.size() + exhausted.size();
  }
}