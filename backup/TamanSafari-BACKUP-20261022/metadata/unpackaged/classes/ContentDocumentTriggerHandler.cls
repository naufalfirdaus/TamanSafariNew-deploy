/**
 * @description Blocks deleting a file linked to a Completed or Cancelled field visit, unless the user holds the
 *              Bypass_Visit_Lock custom permission (field-visit-core D4 and D8, spec visit-proof "Proof visible to
 *              managers"). It runs without sharing, so the lock covers every visit, including ones the deleting
 *              user cannot see. Replacing a photo on an In Progress visit is still allowed.
 */
public without sharing class ContentDocumentTriggerHandler {
  /**
   * @description Adds an error to each deleted file that is linked to a locked visit.
   * @param deletedById Files about to be deleted, keyed by Id.
   */
  public static void beforeDelete(Map<Id, ContentDocument> deletedById) {
    if (deletedById == null || deletedById.isEmpty()) {
      return;
    }
    if (FeatureManagement.checkPermission('Bypass_Visit_Lock')) {
      return;
    }

    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId, LinkedEntityId
      FROM ContentDocumentLink
      WHERE ContentDocumentId IN :deletedById.keySet()
    ];

    Set<Id> visitIds = new Set<Id>();
    for (ContentDocumentLink link : links) {
      if (link.LinkedEntityId.getSObjectType() == Visit_Form__c.SObjectType) {
        visitIds.add(link.LinkedEntityId);
      }
    }
    if (visitIds.isEmpty()) {
      return;
    }

    Set<Id> lockedVisitIds = new Map<Id, Visit_Form__c>([
      SELECT Id
      FROM Visit_Form__c
      WHERE Id IN :visitIds AND Status__c IN ('Completed', 'Cancelled')
    ]).keySet();

    for (ContentDocumentLink link : links) {
      if (lockedVisitIds.contains(link.LinkedEntityId) && deletedById.containsKey(link.ContentDocumentId)) {
        deletedById.get(link.ContentDocumentId).addError(System.Label.Visit_Err_Proof_Delete_Locked);
      }
    }
  }
}