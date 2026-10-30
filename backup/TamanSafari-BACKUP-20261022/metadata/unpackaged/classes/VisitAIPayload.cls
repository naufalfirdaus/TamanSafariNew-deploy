/**
 * @description Builds the JSON that leaves Salesforce for the AI evaluator (visit-ai-scoring design D6, spec
 *              "Evaluation payload excludes personal data"). The payload is assembled from an explicit allowlist of
 *              keys. It is never produced by serializing the record, so a personal-data field added to Visit_Form__c
 *              later cannot leak by accident. The visit's Account, Lead and Contact are not read at all: no name,
 *              phone, email, coordinate, photo or signature is available to this class.
 */
public with sharing class VisitAIPayload {
  /** Visit fields the allowlist reads. Used by every query that feeds build(). */
  public static final String PAYLOAD_FIELDS =
    'Id, Target_Type__c, Visit_Purpose__c, Preferred_Park_Location__c, Event_Type__c, Interested_Packages__c, ' +
    'Estimated_Pax__c, Estimated_Budget_Per_Pax__c, Total_Estimated_Budget__c, Budget_Status__c, ' +
    'PIC_Department__c, Decision_Role__c, Final_Approver_Identified__c, Target_Event_Date__c, ' +
    'Preferred_Day_Type__c, Booking_Urgency__c, Meeting_Summary__c';

  /**
   * @description Builds the request body for one visit.
   * @param visit Visit queried with PAYLOAD_FIELDS.
   * @param requestId Single-use id of this send attempt.
   * @return JSON text with the keys of design D6 and nothing else.
   */
  public static String build(Visit_Form__c visit, String requestId) {
    List<String> packages = new List<String>();
    if (String.isNotBlank(visit.Interested_Packages__c)) {
      packages.addAll(visit.Interested_Packages__c.split(';'));
    }
    Map<String, Object> body = new Map<String, Object>{
      'visitId' => visit.Id,
      'requestId' => requestId,
      'targetType' => visit.Target_Type__c,
      'visitPurpose' => visit.Visit_Purpose__c,
      'preferredPark' => visit.Preferred_Park_Location__c,
      'eventType' => visit.Event_Type__c,
      'interestedPackages' => packages,
      'estimatedPax' => visit.Estimated_Pax__c,
      'budgetPerPax' => visit.Estimated_Budget_Per_Pax__c,
      'totalEstimatedBudgetIdr' => visit.Total_Estimated_Budget__c,
      'budgetStatus' => visit.Budget_Status__c,
      'picDepartment' => visit.PIC_Department__c,
      'decisionRole' => visit.Decision_Role__c,
      'finalApproverIdentified' => visit.Final_Approver_Identified__c,
      'targetEventDate' => visit.Target_Event_Date__c == null ? null : String.valueOf(visit.Target_Event_Date__c),
      'preferredDayType' => visit.Preferred_Day_Type__c,
      'bookingUrgency' => visit.Booking_Urgency__c,
      'meetingSummary' => visit.Meeting_Summary__c
    };
    return JSON.serialize(body);
  }

  /**
   * @description Generates a new request id: 32 hex characters from a 128-bit random key, so it is unguessable
   *              and cannot be reused across attempts.
   * @return The request id.
   */
  public static String newRequestId() {
    return EncodingUtil.convertToHex(Crypto.generateAesKey(128));
  }
}