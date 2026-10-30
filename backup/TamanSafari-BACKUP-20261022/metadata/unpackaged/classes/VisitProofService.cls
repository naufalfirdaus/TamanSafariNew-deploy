/**
 * @description Proof capture for an In Progress visit: the live photo and the client signature (field-visit-core
 *              design D8, spec visit-proof). The server hashes the stored bytes, stamps the capture time, records the
 *              device location, computes the signature distance from check-in, and flags duplicate photos. Only the
 *              visit owner can write proof, and only while the visit is In Progress. File storage runs in
 *              VisitProofStore, in system mode.
 */
public with sharing class VisitProofService {
  /** Largest image accepted after base64 decoding. The client sends a 1280 px JPEG at quality 0.7 (design D3). */
  public static final Integer MAX_IMAGE_BYTES = 1000000;
  /** Reasons a rep can record when the client does not sign (spec visit-proof, signature declined path). */
  public static final Set<String> DECLINE_REASONS = new Set<String>{
    'Client Declined to Sign',
    'Signer Not Available',
    'Other'
  };

  private static final String JPEG_BASE64_PREFIX = '/9j/';
  private static final String PNG_BASE64_PREFIX = 'iVBORw0KGgo';
  private static final String PROOF_PHOTO = 'Photo';
  private static final String PROOF_SIGNATURE = 'Signature';

  /**
   * @description Stores the live proof photo and replaces any earlier photo on the visit. The new photo is flagged
   *              as a duplicate when another visit already has the same hash.
   * @param visitId Visit Id. Must be owned by the caller and In Progress.
   * @param base64Jpeg JPEG bytes, optionally as a data URL.
   * @param lat Device latitude at capture.
   * @param lng Device longitude at capture.
   * @return The visit after the upload.
   * @throws AuraHandledException If the visit is locked, the image is invalid or too large, or the location is missing.
   */
  public static Visit_Form__c uploadPhoto(Id visitId, String base64Jpeg, Double lat, Double lng) {
    Visit_Form__c visit = VisitLifecycleService.loadOwnedInProgress(visitId);
    Blob image = decodeImage(base64Jpeg, JPEG_BASE64_PREFIX, System.Label.Visit_Err_Photo_Invalid);
    requireLocation(lat, lng);

    String hash = sha256Hex(image);
    Boolean isDuplicate = VisitProofStore.hashUsedByOtherVisit(hash, visit.Id);
    Id previousDocument = documentId(visit.Photo_Document_Id__c);

    Id newDocument = VisitProofStore.createProofFile(
      'Visit photo',
      'visit-photo.jpg',
      image,
      PROOF_PHOTO,
      lat,
      lng,
      hash
    );
    VisitProofStore.linkToVisit(newDocument, visit.Id);
    VisitProofStore.deleteFile(previousDocument);

    VisitProofStore.updateVisit(
      new Visit_Form__c(
        Id = visit.Id,
        Photo_Document_Id__c = String.valueOf(newDocument),
        Image_SHA256_Hash__c = hash,
        Is_Duplicate_Photo__c = isDuplicate,
        Photo_Captured_At__c = System.now(),
        Photo_Location__Latitude__s = lat,
        Photo_Location__Longitude__s = lng
      )
    );
    return VisitLifecycleService.reload(visit.Id);
  }

  /**
   * @description Stores the client's signature and records the signer, the time, the device location and the distance
   *              from check-in. A new signature replaces an earlier one and clears any declined reason.
   * @param visitId Visit Id. Must be owned by the caller and In Progress.
   * @param base64Png PNG bytes, optionally as a data URL. Empty means the pad was not signed.
   * @param signerName Name of the person who signed.
   * @param lat Device latitude at signing.
   * @param lng Device longitude at signing.
   * @return The visit after the upload.
   * @throws AuraHandledException If the visit is locked, the signature is blank or invalid, or the name or location is missing.
   */
  public static Visit_Form__c uploadSignature(
    Id visitId,
    String base64Png,
    String signerName,
    Double lat,
    Double lng
  ) {
    Visit_Form__c visit = VisitLifecycleService.loadOwnedInProgress(visitId);
    if (String.isBlank(base64Png)) {
      throw new AuraHandledException(System.Label.Visit_Err_Signature_Blank);
    }
    if (String.isBlank(signerName)) {
      throw new AuraHandledException(System.Label.Visit_Err_Signer_Name_Required);
    }
    Blob signature = decodeImage(base64Png, PNG_BASE64_PREFIX, System.Label.Visit_Err_Signature_Invalid);
    requireLocation(lat, lng);

    String hash = sha256Hex(signature);
    Decimal distance = distanceFromCheckIn(visit, lat, lng);
    Id previousDocument = documentId(visit.Signature_Document_Id__c);

    Id newDocument = VisitProofStore.createProofFile(
      'Client signature',
      'client-signature.png',
      signature,
      PROOF_SIGNATURE,
      lat,
      lng,
      hash
    );
    VisitProofStore.linkToVisit(newDocument, visit.Id);
    VisitProofStore.deleteFile(previousDocument);

    VisitProofStore.updateVisit(
      new Visit_Form__c(
        Id = visit.Id,
        Signature_Document_Id__c = String.valueOf(newDocument),
        Signed_By_Name__c = signerName.trim().left(255),
        Signature_Captured_At__c = System.now(),
        Signature_Location__Latitude__s = lat,
        Signature_Location__Longitude__s = lng,
        Signature_Distance_From_Check_In_Meters__c = distance,
        Signature_Declined_Reason__c = null
      )
    );
    return VisitLifecycleService.reload(visit.Id);
  }

  /**
   * @description Records that the client did not sign. Removes any signature already on the visit, so a visit never
   *              holds both a signature and a declined reason.
   * @param visitId Visit Id. Must be owned by the caller and In Progress.
   * @param reason One of DECLINE_REASONS.
   * @return The visit after the decline is recorded.
   * @throws AuraHandledException If the visit is locked or the reason is not allowed.
   */
  public static Visit_Form__c declineSignature(Id visitId, String reason) {
    Visit_Form__c visit = VisitLifecycleService.loadOwnedInProgress(visitId);
    if (!DECLINE_REASONS.contains(reason)) {
      throw new AuraHandledException(System.Label.Visit_Err_Decline_Reason_Invalid);
    }

    VisitProofStore.deleteFile(documentId(visit.Signature_Document_Id__c));
    VisitProofStore.updateVisit(
      new Visit_Form__c(
        Id = visit.Id,
        Signature_Document_Id__c = null,
        Signed_By_Name__c = null,
        Signature_Captured_At__c = null,
        Signature_Location__Latitude__s = null,
        Signature_Location__Longitude__s = null,
        Signature_Distance_From_Check_In_Meters__c = null,
        Signature_Declined_Reason__c = reason
      )
    );
    return VisitLifecycleService.reload(visit.Id);
  }

  /**
   * @description Decodes a base64 image and checks its type from the base64 prefix. JPEG and PNG have fixed
   *              leading bytes, so the check runs before decoding. Images over MAX_IMAGE_BYTES are rejected.
   * @param payload Base64 text, optionally prefixed with a data URL.
   * @param expectedPrefix Base64 prefix of the expected image type.
   * @param invalidMessage Message for a blank or wrong-type payload.
   * @return The decoded bytes.
   */
  private static Blob decodeImage(String payload, String expectedPrefix, String invalidMessage) {
    if (String.isBlank(payload)) {
      throw new AuraHandledException(invalidMessage);
    }
    String data = payload.trim();
    if (data.startsWith('data:')) {
      data = data.substringAfter('base64,');
    }
    if (!data.startsWith(expectedPrefix)) {
      throw new AuraHandledException(invalidMessage);
    }
    Blob image = EncodingUtil.base64Decode(data);
    if (image.size() > MAX_IMAGE_BYTES) {
      throw new AuraHandledException(System.Label.Visit_Err_Image_Too_Large);
    }
    return image;
  }

  /** SHA-256 of the stored bytes as 64 lowercase hex characters. Computed on the server, never on the client. */
  private static String sha256Hex(Blob data) {
    return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', data));
  }

  private static void requireLocation(Double lat, Double lng) {
    if (lat == null || lng == null || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
      throw new AuraHandledException(System.Label.Visit_Err_Location_Required);
    }
  }

  /**
   * @description Distance from the visit's check-in location to the signing location, in metres.
   * @return The distance, or null when the check-in location is not stored.
   */
  private static Decimal distanceFromCheckIn(Visit_Form__c visit, Double lat, Double lng) {
    Location checkIn = visit.Check_In_Location__c;
    if (checkIn == null || checkIn.getLatitude() == null || checkIn.getLongitude() == null) {
      return null;
    }
    return GeoUtil.haversine(checkIn.getLatitude(), checkIn.getLongitude(), lat, lng);
  }

  private static Id documentId(String value) {
    return String.isBlank(value) ? null : Id.valueOf(value);
  }
}