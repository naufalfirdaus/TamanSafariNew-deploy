/**
 * @description System-mode storage for visit proof (field-visit-core design D4 and D8). Reps have no permission-set
 *              access to the ContentVersion proof fields, and the lookup for duplicate photos must see other reps'
 *              visits. So these operations run without sharing. The callers in VisitProofService check ownership and
 *              state first, and this class does no validation of its own.
 */
public without sharing class VisitProofStore {
  /**
   * @description Stores a proof file with its server-computed metadata.
   * @param title Title shown on the file.
   * @param fileName Name on the client, with an extension.
   * @param data File bytes.
   * @param proofType Photo or Signature.
   * @param lat Capture latitude from the device.
   * @param lng Capture longitude from the device.
   * @param sha256Hex SHA-256 of the stored bytes, as 64 hex characters.
   * @return ContentDocumentId of the new file.
   */
  public static Id createProofFile(
    String title,
    String fileName,
    Blob data,
    String proofType,
    Double lat,
    Double lng,
    String sha256Hex
  ) {
    ContentVersion version = new ContentVersion(
      Title = title,
      PathOnClient = fileName,
      VersionData = data,
      Proof_Type__c = proofType,
      Captured_At__c = System.now(),
      Captured_Location__Latitude__s = lat,
      Captured_Location__Longitude__s = lng,
      Image_SHA256_Hash__c = sha256Hex
    );
    insert version;
    return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id LIMIT 1].ContentDocumentId;
  }

  /**
   * @description Links a proof file to a visit. ShareType V and AllUsers mean the file follows the visit's sharing.
   * @param documentId File to link.
   * @param visitId Visit to link it to.
   */
  public static void linkToVisit(Id documentId, Id visitId) {
    insert new ContentDocumentLink(
      ContentDocumentId = documentId,
      LinkedEntityId = visitId,
      ShareType = 'V',
      Visibility = 'AllUsers'
    );
  }

  /**
   * @description Deletes a replaced or declined proof file. The ContentDocument trigger still applies, so this only
   *              succeeds while the visit is In Progress or the user has Bypass_Visit_Lock.
   * @param documentId File to delete. Null is ignored.
   * @throws AuraHandledException With the trigger's message when the deletion is blocked.
   */
  public static void deleteFile(Id documentId) {
    if (documentId == null) {
      return;
    }
    List<ContentDocument> documents = [SELECT Id FROM ContentDocument WHERE Id = :documentId];
    if (documents.isEmpty()) {
      return;
    }
    try {
      delete documents;
    } catch (DmlException e) {
      throw new AuraHandledException(e.getDmlMessage(0));
    }
  }

  /**
   * @description Checks whether another visit already carries this photo hash. Returns only the Boolean, so the
   *              lookup reveals nothing about other reps' visits.
   * @param sha256Hex Hash of the new photo.
   * @param visitId Visit being checked. Excluded from the search.
   * @return True when a different visit has the same photo hash.
   */
  public static Boolean hashUsedByOtherVisit(String sha256Hex, Id visitId) {
    return !([SELECT Id FROM Visit_Form__c WHERE Image_SHA256_Hash__c = :sha256Hex AND Id != :visitId LIMIT 1]).isEmpty();
  }

  /**
   * @description Writes visit proof fields in system mode. Reps have read-only FLS on them.
   * @param changes Visit with the Id and the fields to write.
   * @throws AuraHandledException With the first save error.
   */
  public static void updateVisit(Visit_Form__c changes) {
    List<Database.SaveResult> results = Database.update(
      new List<Visit_Form__c>{ changes },
      false,
      AccessLevel.SYSTEM_MODE
    );
    if (!results[0].isSuccess()) {
      throw new AuraHandledException(results[0].getErrors()[0].getMessage());
    }
  }
}