/**
 * @description AuraEnabled entry point for the field visit LWC (field-visit-core design D2 and D3). It is deliberately
 *              thin: it maps results to DTOs and passes user-facing errors through. The rules live in
 *              VisitGeofenceService and VisitLifecycleService. The client sends raw readings only. Distance,
 *              geofence status, times and scores are computed on the server.
 */
public with sharing class VisitController {
  /** @description Target summary shown before check-in. canPin is true only for targets with no coordinates. */
  public class TargetContextDTO {
    @AuraEnabled
    public Id targetId;
    @AuraEnabled
    public String targetType;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String address;
    @AuraEnabled
    public Double latitude;
    @AuraEnabled
    public Double longitude;
    @AuraEnabled
    public Boolean hasCoordinates;
    @AuraEnabled
    public Boolean canPin;
    @AuraEnabled
    public String locationSource;
    @AuraEnabled
    public Decimal radiusM;
    @AuraEnabled
    public Boolean allowOutsideCheckIn;
    @AuraEnabled
    public Integer minDurationMinutes;
    @AuraEnabled
    public Boolean isLocationLocked;
  }

  /** @description Server geofence result for the UI preview. Check-in evaluates it again from the raw reading. */
  public class GeofencePreviewDTO {
    @AuraEnabled
    public Boolean hasCoordinates;
    @AuraEnabled
    public Decimal distanceM;
    @AuraEnabled
    public Boolean inside;
    @AuraEnabled
    public Decimal radiusM;
    @AuraEnabled
    public Boolean allowOutsideCheckIn;
  }

  /** @description Visit state for resume, the telemetry bar and the qualification form. serverNow lets the client correct its timer. */
  public class VisitDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String targetType;
    @AuraEnabled
    public Id accountId;
    @AuraEnabled
    public Id leadId;
    @AuraEnabled
    public Datetime checkInTime;
    @AuraEnabled
    public Datetime serverNow;
    @AuraEnabled
    public Decimal accuracyM;
    @AuraEnabled
    public Decimal distanceM;
    @AuraEnabled
    public Boolean isOutsideGeofence;
    @AuraEnabled
    public String exceptionReason;
    @AuraEnabled
    public Boolean isTargetRepPinned;
    @AuraEnabled
    public String cancellationReason;
    @AuraEnabled
    public Map<String, Object> draft;
    @AuraEnabled
    public Boolean hasPhoto;
    @AuraEnabled
    public String photoDocumentId;
    @AuraEnabled
    public String imageSha256Hash;
    @AuraEnabled
    public Boolean isDuplicatePhoto;
    @AuraEnabled
    public Datetime photoCapturedAt;
    @AuraEnabled
    public Boolean hasSignature;
    @AuraEnabled
    public String signedByName;
    @AuraEnabled
    public Datetime signatureCapturedAt;
    @AuraEnabled
    public Decimal signatureDistanceM;
    @AuraEnabled
    public String signatureDeclinedReason;
    @AuraEnabled
    public Datetime checkOutTime;
    @AuraEnabled
    public Integer durationMinutes;
    @AuraEnabled
    public Boolean isShortVisit;
    @AuraEnabled
    public Boolean isCheckOutLocationMissing;
    @AuraEnabled
    public Decimal checkOutDistanceM;
    @AuraEnabled
    public Decimal checkOutFromCheckInM;
    @AuraEnabled
    public String checkInAddress;
    @AuraEnabled
    public String checkOutAddress;
    @AuraEnabled
    public Id opportunityId;
    @AuraEnabled
    public String eventId;
    @AuraEnabled
    public Integer locationScore;
    @AuraEnabled
    public Integer durationScore;
    @AuraEnabled
    public Integer proofScore;
    @AuraEnabled
    public Integer telemetryScore;
  }

  /** @description Contact option for the picker. */
  public class ContactOptionDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String mobilePhone;
    @AuraEnabled
    public String email;
  }

  /** @description Open opportunity option for the follow-up picker. */
  public class OpportunityOptionDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String stageName;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public Date closeDate;
  }

  /** @description Prefill for the qualification form when a follow-up opportunity is chosen. */
  public class OpportunityPrefillDTO {
    @AuraEnabled
    public Id priorVisitId;
    @AuraEnabled
    public Map<String, Object> draft;
  }

  /**
   * @description Returns the caller's In Progress visit so the LWC can resume it.
   * @return The visit, or null when the rep has no open visit.
   */
  @AuraEnabled
  public static VisitDTO getActiveVisit() {
    Visit_Form__c visit = VisitLifecycleService.getActiveVisit();
    return visit == null ? null : toDto(visit);
  }

  /**
   * @description Returns the target summary: name, coordinate status, pin eligibility and the governance settings.
   * @param targetId Account or Lead Id.
   * @return Target context.
   */
  @AuraEnabled
  public static TargetContextDTO getTargetContext(Id targetId) {
    return toTargetContext(VisitGeofenceService.loadTarget(targetId));
  }

  /**
   * @description Previews the server's geofence result for the rep's current reading. It is for display only.
   *              checkIn evaluates the reading again.
   * @param targetId Account or Lead Id.
   * @param lat Rep latitude from the device.
   * @param lng Rep longitude from the device.
   * @return Geofence preview.
   */
  @AuraEnabled
  public static GeofencePreviewDTO previewGeofence(Id targetId, Double lat, Double lng) {
    VisitGeofenceService.VisitTarget target = VisitGeofenceService.loadTarget(targetId);
    GeofencePreviewDTO dto = new GeofencePreviewDTO();
    dto.hasCoordinates = target.hasCoordinates();
    dto.radiusM = FieldSalesConfig.getMaxGeofenceRadiusM();
    dto.allowOutsideCheckIn = FieldSalesConfig.isAllowOutsideGeofenceCheckIn();
    if (dto.hasCoordinates) {
      VisitGeofenceService.GeofenceResult geo = VisitGeofenceService.evaluate(target, lat, lng);
      dto.distanceM = geo.distanceM;
      dto.inside = geo.inside;
    }
    return dto;
  }

  /**
   * @description Pins the rep's location on a target that has no coordinates, then returns the updated target context.
   * @param targetId Account or Lead Id.
   * @param lat Rep latitude from the device.
   * @param lng Rep longitude from the device.
   * @return Updated target context.
   */
  @AuraEnabled
  public static TargetContextDTO pinTargetLocation(Id targetId, Double lat, Double lng) {
    VisitGeofenceService.pinTarget(VisitGeofenceService.loadTarget(targetId), lat, lng);
    return toTargetContext(VisitGeofenceService.loadTarget(targetId));
  }

  /**
   * @description Updates the location lock state on a target (Account or Lead).
   *              If unlocked (isLocked == false), changes in the address will automatically
   *              re-geocode and update coordinates.
   * @param targetId Account or Lead Id.
   * @param isLocked True to lock location, false to unlock.
   * @return Updated target context.
   */
  @AuraEnabled
  public static TargetContextDTO updateLocationLock(Id targetId, Boolean isLocked) {
    return toTargetContext(VisitGeofenceService.updateLocationLock(targetId, isLocked));
  }

  /**
   * @description Checks the rep in to a target. Creates the visit with server time, server distance and the server
   *              geofence decision.
   * @param targetId Account or Lead Id.
   * @param lat Rep latitude from the device.
   * @param lng Rep longitude from the device.
   * @param accuracyM GPS accuracy from the device, in metres.
   * @param exceptionReason Required when the rep is outside the geofence and off-site check-in is allowed.
   * @return The new visit.
   */
  @AuraEnabled
  public static VisitDTO checkIn(
    Id targetId,
    Double lat,
    Double lng,
    Double accuracyM,
    String exceptionReason
  ) {
    return toDto(VisitLifecycleService.checkIn(targetId, lat, lng, accuracyM, exceptionReason));
  }

  /**
   * @description Saves the rep's qualification draft on an In Progress visit. Only whitelisted keys are written.
   * @param visitId Visit Id.
   * @param draftJson JSON object of draft values.
   * @return The visit after the save.
   */
  @AuraEnabled
  public static VisitDTO saveVisitDraft(Id visitId, String draftJson) {
    return toDto(VisitLifecycleService.saveDraft(visitId, draftJson));
  }

  /**
   * @description Cancels the rep's In Progress visit with a reason. The rep can check in again afterwards.
   * @param visitId Visit Id.
   * @param reason Rep cancellation reason.
   * @return The cancelled visit.
   */
  @AuraEnabled
  public static VisitDTO cancelVisit(Id visitId, String reason) {
    return toDto(VisitLifecycleService.cancelVisit(visitId, reason));
  }

  /**
   * @description Stores the live proof photo, replacing any earlier one. Returns the hash and the duplicate flag.
   * @param visitId Visit Id.
   * @param base64Jpeg JPEG captured from the live camera.
   * @param lat Device latitude at capture.
   * @param lng Device longitude at capture.
   * @return The updated visit.
   */
  @AuraEnabled
  public static VisitDTO uploadVisitPhoto(Id visitId, String base64Jpeg, Double lat, Double lng) {
    return toDto(VisitProofService.uploadPhoto(visitId, base64Jpeg, lat, lng));
  }

  /**
   * @description Stores the client's signature with the signer name, time, location and distance from check-in.
   * @param visitId Visit Id.
   * @param base64Png Signature pad image.
   * @param signerName Name of the person who signed.
   * @param lat Device latitude at signing.
   * @param lng Device longitude at signing.
   * @return The updated visit.
   */
  @AuraEnabled
  public static VisitDTO uploadClientSignature(
    Id visitId,
    String base64Png,
    String signerName,
    Double lat,
    Double lng
  ) {
    return toDto(VisitProofService.uploadSignature(visitId, base64Png, signerName, lat, lng));
  }

  /**
   * @description Records that the client did not sign, with a reason. Removes any signature already on the visit.
   * @param visitId Visit Id.
   * @param reason Declined reason.
   * @return The updated visit.
   */
  @AuraEnabled
  public static VisitDTO declineClientSignature(Id visitId, String reason) {
    return toDto(VisitProofService.declineSignature(visitId, reason));
  }

  /**
   * @description Completes the visit at check-out. The server checks the prerequisites, computes duration and distances, runs
   *              the pipeline action, logs the Event, and scores the visit. Nothing is saved if any step fails.
   * @param visitId Visit Id.
   * @param lat Check-out latitude. Null when no location fix was obtained.
   * @param lng Check-out longitude. Null when no location fix was obtained.
   * @param accuracyM GPS accuracy from the device, in metres.
   * @param pipelineJson Optional JSON for the Update Opportunity action: opportunityStage, amount, closeDate.
   * @return The completed visit, with its scores.
   */
  @AuraEnabled
  public static VisitDTO completeVisitCheckOut(
    Id visitId,
    Double lat,
    Double lng,
    Double accuracyM,
    String pipelineJson
  ) {
    return toDto(VisitLifecycleService.checkOut(visitId, lat, lng, accuracyM, pipelineJson));
  }

  /**
   * @description Lists the Contacts of an Account for the contact picker.
   * @param accountId Account Id.
   * @return Contact options.
   */
  @AuraEnabled
  public static List<ContactOptionDTO> getAccountContacts(Id accountId) {
    List<ContactOptionDTO> out = new List<ContactOptionDTO>();
    for (Contact contact : VisitQualificationService.getAccountContacts(accountId)) {
      ContactOptionDTO dto = new ContactOptionDTO();
      dto.id = contact.Id;
      dto.name = contact.Name;
      dto.title = contact.Title;
      dto.mobilePhone = contact.MobilePhone;
      dto.email = contact.Email;
      out.add(dto);
    }
    return out;
  }

  /**
   * @description Creates a Contact under an Account the caller owns. Name and mobile number are required.
   * @param accountId Account Id.
   * @param contactJson JSON with name, mobile, email, department and role.
   * @return The new Contact Id.
   */
  @AuraEnabled
  public static Id quickCreateContact(Id accountId, String contactJson) {
    return VisitQualificationService.quickCreateContact(accountId, contactJson);
  }

  /**
   * @description Lists the open opportunities of an Account for the follow-up picker.
   * @param accountId Account Id.
   * @return Open opportunity options.
   */
  @AuraEnabled
  public static List<OpportunityOptionDTO> getOpenOpportunities(Id accountId) {
    List<OpportunityOptionDTO> out = new List<OpportunityOptionDTO>();
    for (Opportunity opp : VisitQualificationService.getOpenOpportunities(accountId)) {
      OpportunityOptionDTO dto = new OpportunityOptionDTO();
      dto.id = opp.Id;
      dto.name = opp.Name;
      dto.stageName = opp.StageName;
      dto.amount = opp.Amount;
      dto.closeDate = opp.CloseDate;
      out.add(dto);
    }
    return out;
  }

  /**
   * @description Returns the qualification values to prefill when a follow-up opportunity is chosen.
   * @param opportunityId Opportunity Id.
   * @return Prior visit Id (if any) and the draft values.
   */
  @AuraEnabled
  public static OpportunityPrefillDTO getOpportunityPrefill(Id opportunityId) {
    VisitQualificationService.OpportunityPrefill prefill = VisitQualificationService.getOpportunityPrefill(opportunityId);
    OpportunityPrefillDTO dto = new OpportunityPrefillDTO();
    dto.priorVisitId = prefill.priorVisitId;
    dto.draft = prefill.draft;
    return dto;
  }

  /**
   * @description Reverse-geocodes live GPS coordinates into a readable address for real-time preview.
   * @param lat Latitude.
   * @param lng Longitude.
   * @return Formatted address.
   */
  @AuraEnabled
  public static String reverseGeocodeLive(Double lat, Double lng) {
    return GeoapifyService.reverseGeocode(lat, lng);
  }

  private static TargetContextDTO toTargetContext(VisitGeofenceService.VisitTarget target) {
    TargetContextDTO dto = new TargetContextDTO();
    dto.targetId = target.targetId;
    dto.targetType = target.targetType();
    dto.name = target.name;
    dto.address = target.address;
    dto.hasCoordinates = target.hasCoordinates();
    if (dto.hasCoordinates) {
      dto.latitude = target.coordinates[0].latitude;
      dto.longitude = target.coordinates[0].longitude;
    }
    dto.canPin = !dto.hasCoordinates;
    dto.locationSource = target.locationSource;
    dto.isLocationLocked = target.isLocationLocked != null ? target.isLocationLocked : true;
    dto.radiusM = FieldSalesConfig.getMaxGeofenceRadiusM();
    dto.allowOutsideCheckIn = FieldSalesConfig.isAllowOutsideGeofenceCheckIn();
    dto.minDurationMinutes = FieldSalesConfig.getMinVisitDurationMinutes();
    return dto;
  }

  private static VisitDTO toDto(Visit_Form__c visit) {
    VisitDTO dto = new VisitDTO();
    dto.id = visit.Id;
    dto.name = visit.Name;
    dto.status = visit.Status__c;
    dto.targetType = visit.Target_Type__c;
    dto.accountId = visit.Account__c;
    dto.leadId = visit.Lead__c;
    dto.checkInTime = visit.Check_In_Time__c;
    dto.serverNow = System.now();
    dto.accuracyM = visit.Check_In_Accuracy_Meters__c;
    dto.distanceM = visit.Check_In_Distance_Meters__c;
    dto.isOutsideGeofence = visit.Is_Outside_Geofence__c;
    dto.exceptionReason = visit.Geofence_Exception_Reason__c;
    dto.isTargetRepPinned = visit.Is_Target_Rep_Pinned__c;
    dto.cancellationReason = visit.Cancellation_Reason__c;
    dto.draft = VisitLifecycleService.draftOf(visit);
    dto.hasPhoto = visit.Photo_Document_Id__c != null;
    dto.photoDocumentId = visit.Photo_Document_Id__c;
    dto.imageSha256Hash = visit.Image_SHA256_Hash__c;
    dto.isDuplicatePhoto = visit.Is_Duplicate_Photo__c;
    dto.photoCapturedAt = visit.Photo_Captured_At__c;
    dto.hasSignature = visit.Signature_Document_Id__c != null;
    dto.signedByName = visit.Signed_By_Name__c;
    dto.signatureCapturedAt = visit.Signature_Captured_At__c;
    dto.signatureDistanceM = visit.Signature_Distance_From_Check_In_Meters__c;
    dto.signatureDeclinedReason = visit.Signature_Declined_Reason__c;
    dto.checkOutTime = visit.Check_Out_Time__c;
    dto.durationMinutes = visit.Visit_Duration_Minutes__c == null ? null : visit.Visit_Duration_Minutes__c.intValue();
    dto.isShortVisit = visit.Is_Short_Visit__c;
    dto.isCheckOutLocationMissing = visit.Is_Check_Out_Location_Missing__c;
    dto.checkOutDistanceM = visit.Check_Out_Distance_Meters__c;
    dto.checkOutFromCheckInM = visit.Check_Out_From_Check_In_Meters__c;
    dto.checkInAddress = visit.Check_In_Address__c;
    dto.checkOutAddress = visit.Check_Out_Address__c;
    dto.opportunityId = visit.Opportunity__c;
    dto.eventId = visit.Event_Id__c;
    dto.locationScore = visit.Location_Score__c == null ? null : visit.Location_Score__c.intValue();
    dto.durationScore = visit.Duration_Score__c == null ? null : visit.Duration_Score__c.intValue();
    dto.proofScore = visit.Proof_Score__c == null ? null : visit.Proof_Score__c.intValue();
    dto.telemetryScore = visit.Telemetry_Score__c == null ? null : visit.Telemetry_Score__c.intValue();
    return dto;
  }
}