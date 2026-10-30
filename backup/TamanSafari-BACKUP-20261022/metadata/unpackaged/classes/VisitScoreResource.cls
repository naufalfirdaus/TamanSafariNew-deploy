/**
 * @description REST endpoint n8n calls with the AI result: POST /services/apexrest/visit-score/v1
 *              (visit-ai-scoring design D7, spec "Result write-back acceptance" and "Result validation").
 *              It accepts a result only for a visit that is Sent, with the current request id. It clamps the scores,
 *              answers a repeat of an accepted result with success, and writes inside VisitLock.runAsSystem.
 *              The class runs without sharing and the caller is an integration identity that has only this class
 *              (permission set Field_Visit_AI_Integration), so n8n cannot edit visits any other way. That identity has
 *              no field access on Visit_Form__c, and a query only sees fields the running user can see unless it runs in
 *              system mode, so the visit query says WITH SYSTEM_MODE explicitly.
 *              Responses: 200 accepted or duplicate; 400 bad input; 404 unknown visit; 409 not Sent or stale id.
 */
@RestResource(urlMapping='/visit-score/v1')
global without sharing class VisitScoreResource {
  private static final Integer MAX_CONSISTENCY = 20;
  private static final Integer MAX_SUMMARY = 30;
  private static final Integer MAX_AUDIT_LENGTH = 5000;
  private static final Integer MAX_MODEL_LENGTH = 80;
  private static final Integer MAX_ERROR_LENGTH = 255;

  /** Parsed and validated request. Internal. */
  private class ScoreRequest {
    Id visitId;
    String requestId;
    Boolean isFailure;
    Integer consistency;
    Integer summary;
    String auditSummary;
    Boolean injection;
    String model;
    String error;
  }

  /** Thrown for any input problem. Carries the message returned with the 400. */
  private class BadRequestException extends Exception {
  }

  /**
   * @description Applies one AI result to its visit.
   */
  @HttpPost
  global static void receive() {
    RestResponse response = RestContext.response;
    response.addHeader('Content-Type', 'application/json');

    ScoreRequest request;
    try {
      request = parse(RestContext.request.requestBody);
    } catch (BadRequestException e) {
      reply(response, 400, 'error', e.getMessage());
      return;
    }

    List<Visit_Form__c> rows = [
      SELECT
        Id,
        AI_Scoring_Status__c,
        AI_Request_Id__c,
        AI_Attempt_Count__c,
        AI_Consistency_Score__c,
        AI_Summary_Score__c
      FROM Visit_Form__c
      WHERE Id = :request.visitId
      WITH SYSTEM_MODE
      LIMIT 1
      FOR UPDATE
    ];
    if (rows.isEmpty()) {
      reply(response, 404, 'error', 'Visit not found');
      return;
    }
    Visit_Form__c visit = rows[0];
    Boolean idMatches = visit.AI_Request_Id__c == request.requestId;

    // A redelivery of the accepted result is a success that changes nothing.
    if (
      idMatches &&
      visit.AI_Scoring_Status__c == VisitRoutingService.AI_SCORED &&
      !request.isFailure &&
      visit.AI_Consistency_Score__c == request.consistency &&
      visit.AI_Summary_Score__c == request.summary
    ) {
      reply(response, 200, 'result', 'duplicate');
      return;
    }
    // Not Sent, or the id belongs to an earlier attempt (or has not been committed yet; n8n retries a 409).
    if (visit.AI_Scoring_Status__c != VisitRoutingService.AI_SENT || !idMatches) {
      reply(response, 409, 'error', 'Visit is not waiting for this request');
      return;
    }

    Visit_Form__c changes = request.isFailure ? failureChanges(visit, request) : scoredChanges(visit, request);
    Database.SaveResult result = VisitLock.runAsSystem(new List<Visit_Form__c>{ changes }, false)[0];
    if (!result.isSuccess()) {
      reply(response, 500, 'error', result.getErrors()[0].getMessage());
      return;
    }
    reply(response, 200, 'result', 'accepted');
  }

  /** Reads and validates the body. Scores must be numbers; out-of-range values are clamped and rounded. */
  private static ScoreRequest parse(Blob body) {
    Map<String, Object> parsed;
    try {
      parsed = (Map<String, Object>) JSON.deserializeUntyped(body == null ? '' : body.toString());
    } catch (Exception e) {
      throw new BadRequestException('Body is not a JSON object');
    }
    ScoreRequest request = new ScoreRequest();
    try {
      request.visitId = Id.valueOf(String.valueOf(parsed.get('visitId')));
    } catch (Exception e) {
      throw new BadRequestException('visitId is missing or invalid');
    }
    if (request.visitId.getSObjectType() != Visit_Form__c.SObjectType) {
      throw new BadRequestException('visitId is not a visit');
    }
    request.requestId = parsed.get('requestId') instanceof String ? (String) parsed.get('requestId') : null;
    if (String.isBlank(request.requestId)) {
      throw new BadRequestException('requestId is missing');
    }

    String status = parsed.get('status') instanceof String ? ((String) parsed.get('status')).toLowerCase() : null;
    if (status == 'failed') {
      request.isFailure = true;
      Object error = parsed.get('error');
      request.error = error == null ? 'Evaluator reported a failure' : String.valueOf(error).left(MAX_ERROR_LENGTH);
      return request;
    }
    if (status != 'scored') {
      throw new BadRequestException('status must be scored or failed');
    }
    request.isFailure = false;
    request.consistency = clamp(parsed.get('consistencyScore'), MAX_CONSISTENCY, 'consistencyScore');
    request.summary = clamp(parsed.get('summaryScore'), MAX_SUMMARY, 'summaryScore');
    request.injection = parsed.get('injectionSuspected') == true;
    // An injection attempt always scores 0 for the summary, whatever the evaluator returned (spec "Summary text is treated as data").
    if (request.injection) {
      request.summary = 0;
    }
    Object audit = parsed.get('auditSummary');
    request.auditSummary = audit == null ? '' : String.valueOf(audit).left(MAX_AUDIT_LENGTH);
    Object model = parsed.get('model');
    request.model = model == null ? null : String.valueOf(model).left(MAX_MODEL_LENGTH);
    return request;
  }

  /** Rounds a JSON number and clamps it to 0..max. Anything that is not a number is a 400. */
  private static Integer clamp(Object raw, Integer max, String name) {
    if (!(raw instanceof Integer || raw instanceof Long || raw instanceof Decimal || raw instanceof Double)) {
      throw new BadRequestException(name + ' must be a number');
    }
    Decimal value = Decimal.valueOf(String.valueOf(raw)).setScale(0, RoundingMode.HALF_UP);
    return Math.min(Math.max(value.intValue(), 0), max);
  }

  private static Visit_Form__c scoredChanges(Visit_Form__c visit, ScoreRequest request) {
    return new Visit_Form__c(
      Id = visit.Id,
      AI_Consistency_Score__c = request.consistency,
      AI_Summary_Score__c = request.summary,
      AI_Audit_Summary__c = request.auditSummary,
      AI_Injection_Suspected__c = request.injection,
      AI_Model__c = request.model,
      AI_Scored_At__c = System.now(),
      AI_Last_Error__c = null,
      AI_Scoring_Status__c = VisitRoutingService.AI_SCORED
    );
  }

  /** A reported failure was already counted when the attempt was sent, so it only decides Pending or Failed. */
  private static Visit_Form__c failureChanges(Visit_Form__c visit, ScoreRequest request) {
    Integer used = visit.AI_Attempt_Count__c == null ? 0 : visit.AI_Attempt_Count__c.intValue();
    Boolean attemptsLeft = used < FieldSalesConfig.getAiMaxAttempts();
    return new Visit_Form__c(
      Id = visit.Id,
      AI_Last_Error__c = request.error,
      AI_Scoring_Status__c = attemptsLeft ? VisitRoutingService.AI_PENDING : VisitRoutingService.AI_FAILED
    );
  }

  private static void reply(RestResponse response, Integer statusCode, String key, String value) {
    response.statusCode = statusCode;
    response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ key => value }));
  }
}