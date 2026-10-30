/**
 * @description Admin retry of failed AI scoring, called by the headless quick action retryAiScoring
 *              (visit-ai-scoring design D12, spec "Admin retry of failed scoring"). Only users with the
 *              Bypass_Visit_Lock custom permission (admins) may retry, and only a visit that is Failed.
 */
public with sharing class VisitAIScoringController {
  /**
   * @description Resets the attempt count, sets the visit back to Pending and sends it again.
   * @param visitId Visit whose scoring Failed.
   * @throws AuraHandledException If the caller is not an admin, the visit is not visible, or it is not Failed.
   */
  @AuraEnabled
  public static void retry(Id visitId) {
    if (!FeatureManagement.checkPermission('Bypass_Visit_Lock')) {
      throw new AuraHandledException(System.Label.Visit_Err_Retry_Admin_Only);
    }
    List<Visit_Form__c> rows = [
      SELECT Id, AI_Scoring_Status__c
      FROM Visit_Form__c
      WHERE Id = :visitId
      WITH USER_MODE
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw new AuraHandledException(System.Label.Visit_Err_Visit_Not_Found);
    }
    if (rows[0].AI_Scoring_Status__c != VisitRoutingService.AI_FAILED) {
      throw new AuraHandledException(System.Label.Visit_Err_Retry_Not_Failed);
    }

    List<Database.SaveResult> results = VisitLock.runAsSystem(
      new List<Visit_Form__c>{
        new Visit_Form__c(
          Id = visitId,
          AI_Scoring_Status__c = VisitRoutingService.AI_PENDING,
          AI_Attempt_Count__c = 0,
          AI_Last_Error__c = null
        )
      },
      false
    );
    if (!results[0].isSuccess()) {
      throw new AuraHandledException(results[0].getErrors()[0].getMessage());
    }
    System.enqueueJob(new VisitAIScoringQueueable(new List<Id>{ visitId }));
  }
}