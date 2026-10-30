/**
 * @description Visit lifecycle for the field visit LWC: check-in, resume, qualification draft saves and rep
 *              cancellation (field-visit-core design D2, D3, D6; specs field-visit-lifecycle and visit-qualification).
 *              Reads run WITH USER_MODE, so a rep only sees visits they can access. Server-computed fields are
 *              written in SYSTEM_MODE after ownership and state checks. Draft saves run in USER_MODE, so FLS limits
 *              them to the qualification fields.
 */
public with sharing class VisitLifecycleService {
  public static final String STATUS_IN_PROGRESS = 'In Progress';
  public static final String STATUS_CANCELLED = 'Cancelled';
  public static final String STATUS_COMPLETED = 'Completed';

  /** Reasons a rep can cancel with. Auto-Cancelled (Stale) is only set by StaleVisitCancelJob. */
  private static final Set<String> REP_CANCEL_REASONS = new Set<String>{
    'Client Not Available',
    'Wrong Target Selected',
    'Rescheduled'
  };

  /** Fields loaded for every visit DTO. Includes every draft field so resume can restore them. */
  public static final String VISIT_FIELDS =
    'Id, Name, OwnerId, Status__c, Target_Type__c, Account__c, Lead__c, ' +
    'Check_In_Time__c, Check_In_Accuracy_Meters__c, Check_In_Distance_Meters__c, ' +
    'Is_Outside_Geofence__c, Geofence_Exception_Reason__c, Is_Target_Rep_Pinned__c, Cancellation_Reason__c, ' +
    'Visit_Purpose__c, Contact__c, Opportunity__c, Pipeline_Action__c, Meeting_Summary__c, UU_PDP_Consent__c, ' +
    'Preferred_Park_Location__c, Event_Type__c, Interested_Packages__c, Estimated_Pax__c, ' +
    'Estimated_Budget_Per_Pax__c, Total_Estimated_Budget__c, Budget_Status__c, PIC_Department__c, ' +
    'Decision_Role__c, Final_Approver_Identified__c, Target_Event_Date__c, Preferred_Day_Type__c, ' +
    'Booking_Urgency__c, Check_In_Location__c, Photo_Document_Id__c, Image_SHA256_Hash__c, ' +
    'Is_Duplicate_Photo__c, Photo_Captured_At__c, Signature_Document_Id__c, Signed_By_Name__c, ' +
    'Signature_Captured_At__c, Signature_Distance_From_Check_In_Meters__c, Signature_Declined_Reason__c, ' +
    'Check_Out_Time__c, Visit_Duration_Minutes__c, Is_Short_Visit__c, Is_Check_Out_Location_Missing__c, ' +
    'Check_Out_Location__c, Check_Out_Distance_Meters__c, Check_Out_From_Check_In_Meters__c, Event_Id__c, ' +
    'Location_Score__c, Duration_Score__c, Proof_Score__c, Telemetry_Score__c, ' +
    'Check_In_Address__c, Check_Out_Address__c';

  /**
   * Whitelist of draft keys the client may write, mapped to Visit_Form__c fields. Any other key is ignored.
   * Every field here is editable by Field_Visit_Rep, so USER_MODE writes succeed for the owner.
   */
  private static final Map<String, String> DRAFT_FIELD_BY_KEY = new Map<String, String>{
    'visitPurpose' => 'Visit_Purpose__c',
    'contactId' => 'Contact__c',
    'opportunityId' => 'Opportunity__c',
    'pipelineAction' => 'Pipeline_Action__c',
    'meetingSummary' => 'Meeting_Summary__c',
    'uuPdpConsent' => 'UU_PDP_Consent__c',
    'preferredPark' => 'Preferred_Park_Location__c',
    'eventType' => 'Event_Type__c',
    'interestedPackages' => 'Interested_Packages__c',
    'estimatedPax' => 'Estimated_Pax__c',
    'budgetPerPax' => 'Estimated_Budget_Per_Pax__c',
    'totalBudget' => 'Total_Estimated_Budget__c',
    'budgetStatus' => 'Budget_Status__c',
    'picDepartment' => 'PIC_Department__c',
    'decisionRole' => 'Decision_Role__c',
    'finalApproverIdentified' => 'Final_Approver_Identified__c',
    'targetEventDate' => 'Target_Event_Date__c',
    'preferredDayType' => 'Preferred_Day_Type__c',
    'bookingUrgency' => 'Booking_Urgency__c'
  };

  private static final Map<String, String> PICKLIST_NORMALIZER = new Map<String, String>{
    'TSI Bogor' => 'Taman Safari Bogor',
    'TSI Prigen' => 'Taman Safari Prigen',
    'TSI Bali' => 'Taman Safari Bali',
    'Belum Ditentukan' => 'Multiple / Undecided',
    'Lainnya' => 'Other',
    'Tiket Masuk' => 'Tickets',
    'Venue Outdoor / Hall' => 'Venue',
    '< 500rb' => '< IDR 500k',
    '500rb - 1jt' => 'IDR 500k - 1M',
    '> 1jt' => '> IDR 1M',
    'Approved / Ada Anggaran' => 'Approved / Allocated',
    'Perlu Pengajuan' => 'In Planning / Pending',
    'Belum Ada Anggaran' => 'No Budget Yet',
    'HR / GA' => 'HR (Human Resources)',
    'Direksi / BOD' => 'Executive / Board',
    'Procurement / Purchasing' => 'Procurement',
    'Marketing / Comm' => 'GA (General Affairs)',
    'Influencer' => 'Influencer / Committee',
    'User' => 'Gatekeeper',
    'Weekday (Sen-Kam)' => 'Weekday (Mon-Thu)',
    'Weekend (Jum-Min)' => 'Weekend (Fri-Sun)',
    'Segera (< 1 Bulan)' => 'This Month',
    '1-3 Bulan' => 'This Quarter',
    '> 3 Bulan' => 'Next Quarter',
    'Fleksibel' => 'Next Year'
  };

  /**
   * @description Returns the caller's In Progress visit, if any. Used to resume a visit and to enforce one open visit per rep.
   * @return The open visit, or null.
   */
  public static Visit_Form__c getActiveVisit() {
    String inProgress = STATUS_IN_PROGRESS;
    Id ownerId = UserInfo.getUserId();
    List<Visit_Form__c> rows = Database.query(
      'SELECT ' +
        VISIT_FIELDS +
        ' FROM Visit_Form__c WHERE Status__c = :inProgress AND OwnerId = :ownerId WITH USER_MODE LIMIT 1'
    );
    return rows.isEmpty() ? null : rows[0];
  }

  /**
   * @description Creates an In Progress visit from a server-validated check-in. Distance, geofence status, times and
   *              the open-visit key are all computed here. Duplicate open visits are caught by the unique
   *              Open_Visit_Key__c, so a double tap or a second device cannot create two open visits.
   * @param targetId Account or Lead Id.
   * @param lat Rep latitude from the device.
   * @param lng Rep longitude from the device.
   * @param accuracyM GPS accuracy from the device, in metres. Stored as reported.
   * @param exceptionReason Required when the rep is outside the geofence and off-site check-in is allowed.
   * @return The new visit.
   * @throws AuraHandledException With the user-facing reason when a rule blocks the check-in.
   */
  public static Visit_Form__c checkIn(
    Id targetId,
    Double lat,
    Double lng,
    Double accuracyM,
    String exceptionReason
  ) {
    if (lat == null || lng == null || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
      throw new AuraHandledException(System.Label.Visit_Err_Location_Required);
    }
    if (getActiveVisit() != null) {
      throw new AuraHandledException(System.Label.Visit_Err_Open_Visit_Exists);
    }

    // Callouts must happen BEFORE any DML in the transaction to prevent System.CalloutException
    String checkInAddress = GeoapifyService.reverseGeocode(lat, lng);
    if (String.isNotBlank(checkInAddress) && checkInAddress.length() > 255) {
      checkInAddress = checkInAddress.left(255);
    }

    VisitGeofenceService.VisitTarget target = VisitGeofenceService.loadTarget(targetId);
    VisitGeofenceService.GeofenceResult geo = VisitGeofenceService.evaluate(target, lat, lng);

    if (!geo.inside) {
      if (!geo.allowOutsideCheckIn) {
        throw new AuraHandledException(
          String.format(
            System.Label.Visit_Err_Outside_Blocked,
            new List<String>{
              String.valueOf(geo.distanceM.setScale(0)),
              String.valueOf(geo.radiusM.setScale(0))
            }
          )
        );
      }
      if (String.isBlank(exceptionReason)) {
        throw new AuraHandledException(System.Label.Visit_Err_Exception_Reason_Required);
      }
      if (!VisitGeofenceService.EXCEPTION_REASONS.contains(exceptionReason)) {
        throw new AuraHandledException(System.Label.Visit_Err_Exception_Reason_Invalid);
      }
    }

    Visit_Form__c visit = new Visit_Form__c(
      Status__c = STATUS_IN_PROGRESS,
      Target_Type__c = target.targetType(),
      Account__c = target.accountId,
      Lead__c = target.leadId,
      Check_In_Time__c = System.now(),
      Check_In_Location__Latitude__s = lat,
      Check_In_Location__Longitude__s = lng,
      Check_In_Accuracy_Meters__c = (Decimal) accuracyM,
      Check_In_Distance_Meters__c = geo.distanceM,
      Check_In_Address__c = checkInAddress,
      Is_Outside_Geofence__c = !geo.inside,
      Geofence_Exception_Reason__c = geo.inside ? null : exceptionReason,
      Is_Target_Rep_Pinned__c = target.isRepPinned,
      Open_Visit_Key__c = String.valueOf(UserInfo.getUserId())
    );

    // SYSTEM_MODE: the rep has read-only FLS on the computed fields set above.
    List<Database.SaveResult> results = Database.insert(
      new List<Visit_Form__c>{ visit },
      false,
      AccessLevel.SYSTEM_MODE
    );
    Database.SaveResult result = results[0];
    if (!result.isSuccess()) {
      for (Database.Error err : result.getErrors()) {
        if (err.getStatusCode() == StatusCode.DUPLICATE_VALUE) {
          throw new AuraHandledException(System.Label.Visit_Err_Open_Visit_Exists);
        }
      }
      throw new AuraHandledException(result.getErrors()[0].getMessage());
    }
    return loadVisit(visit.Id);
  }

  /**
   * @description Saves qualification fields onto the rep's In Progress visit. Only whitelisted keys are written,
   *              and the write runs in USER_MODE, so FLS also applies.
   * @param visitId Visit to update. Must be owned by the caller and In Progress.
   * @param draftJson JSON object of draft values keyed by the whitelist names.
   * @return The visit after the save.
   * @throws AuraHandledException If the caller is not the owner, the visit is not In Progress, or a value is invalid.
   */
  public static Visit_Form__c saveDraft(Id visitId, String draftJson) {
    Visit_Form__c current = loadVisit(visitId);
    requireOwnedInProgress(current);
    if (String.isBlank(draftJson)) {
      return current;
    }

    Map<String, Object> draft;
    try {
      draft = (Map<String, Object>) JSON.deserializeUntyped(draftJson);
    } catch (Exception e) {
      throw new AuraHandledException(System.Label.Visit_Err_Draft_Invalid);
    }

    // Validation errors are AuraHandledExceptions with their own messages, so they are raised outside any catch-all.
    Visit_Form__c changes = new Visit_Form__c(Id = visitId);
    for (String key : draft.keySet()) {
      String field = DRAFT_FIELD_BY_KEY.get(key);
      if (field == null) {
        continue;
      }
      Object value = null;
      try {
        value = toFieldValue(field, draft.get(key));
      } catch (Exception e) {
        throw new AuraHandledException(System.Label.Visit_Err_Draft_Invalid);
      }
      String error = VisitQualificationService.valueError(field, value, current.Check_In_Time__c);
      if (error == null && field == 'Contact__c') {
        error = VisitQualificationService.contactError((Id) value, current);
      }
      if (error != null) {
        throw new AuraHandledException(error);
      }
      changes.put(field, value);
    }

    List<Database.SaveResult> results = Database.update(
      new List<Visit_Form__c>{ changes },
      false,
      AccessLevel.USER_MODE
    );
    if (!results[0].isSuccess()) {
      throw new AuraHandledException(results[0].getErrors()[0].getMessage());
    }
    return loadVisit(visitId);
  }

  /**
   * @description Cancels the caller's In Progress visit with a rep reason. The visit keeps its record. It gets no
   *              score and no activity. Clearing Open_Visit_Key__c frees the rep to check in again.
   * @param visitId Visit to cancel. Must be owned by the caller and In Progress.
   * @param reason One of the rep cancellation reasons.
   * @return The visit after cancellation.
   * @throws AuraHandledException If the caller is not the owner, the visit is not In Progress, or the reason is not allowed.
   */
  public static Visit_Form__c cancelVisit(Id visitId, String reason) {
    Visit_Form__c current = loadVisit(visitId);
    requireOwnedInProgress(current);
    if (!REP_CANCEL_REASONS.contains(reason)) {
      throw new AuraHandledException(System.Label.Visit_Err_Cancel_Reason_Invalid);
    }

    Visit_Form__c changes = new Visit_Form__c(
      Id = visitId,
      Status__c = STATUS_CANCELLED,
      Cancellation_Reason__c = reason,
      Open_Visit_Key__c = null
    );
    // SYSTEM_MODE: the rep has read-only FLS on Status__c and Open_Visit_Key__c.
    List<Database.SaveResult> results = Database.update(
      new List<Visit_Form__c>{ changes },
      false,
      AccessLevel.SYSTEM_MODE
    );
    if (!results[0].isSuccess()) {
      throw new AuraHandledException(results[0].getErrors()[0].getMessage());
    }
    return loadVisit(visitId);
  }

  /**
   * @description Completes a visit at check-out (design D5). The steps run in this order inside one savepoint: check the
   *              prerequisites, compute duration and distances, re-check the photo hash, run the pipeline action, log the
   *              Event, score the visit, and write the completed state. Any failure rolls back every write, so the
   *              visit stays In Progress with no side records.
   * @param visitId Visit to complete. Owned by the caller and In Progress.
   * @param lat Check-out latitude. Null when no location fix was obtained.
   * @param lng Check-out longitude. Null when no location fix was obtained.
   * @param accuracyM GPS accuracy from the device, in metres.
   * @param pipelineJson Optional JSON with opportunityStage, amount and closeDate for the Update Opportunity action.
   * @return The completed visit.
   * @throws AuraHandledException With the reason when a prerequisite or pipeline check fails, or a write is refused.
   */
  public static Visit_Form__c checkOut(Id visitId, Double lat, Double lng, Double accuracyM, String pipelineJson) {
    Visit_Form__c visit = loadOwnedInProgress(visitId);
    String prerequisiteError = VisitQualificationService.checkOutError(visit);
    if (prerequisiteError != null) {
      throw new AuraHandledException(prerequisiteError);
    }
    String pipelineError = VisitPipelineService.actionError(visit);
    if (pipelineError != null) {
      throw new AuraHandledException(pipelineError);
    }
    Map<String, Object> pipeline = parsePipeline(pipelineJson);

    // Distances come from the target before any conversion.
    // Evaluate BEFORE setting Savepoint to prevent System.CalloutException if target loads/geocodes.
    Decimal checkOutDistance = null;
    Decimal fromCheckIn = null;
    Boolean locationMissing = lat == null || lng == null;
    if (!locationMissing) {
      Id targetId = visit.Target_Type__c == VisitQualificationService.TARGET_LEAD ? visit.Lead__c : visit.Account__c;
      VisitGeofenceService.VisitTarget target = VisitGeofenceService.loadTarget(targetId);
      checkOutDistance = VisitGeofenceService.evaluate(target, lat, lng).distanceM;
      Location checkIn = visit.Check_In_Location__c;
      if (checkIn != null && checkIn.getLatitude() != null && checkIn.getLongitude() != null) {
        fromCheckIn = GeoUtil.haversine(checkIn.getLatitude(), checkIn.getLongitude(), lat, lng);
      }
    }

    Savepoint sp = Database.setSavepoint();
    try {
      return completeVisit(visit, lat, lng, accuracyM, pipeline, checkOutDistance, fromCheckIn);
    } catch (AuraHandledException e) {
      Database.rollback(sp);
      throw e;
    } catch (DmlException e) {
      Database.rollback(sp);
      throw new AuraHandledException(e.getDmlMessage(0));
    }
  }

  /** Steps 2 to 7 of design D5. Called only from checkOut, inside its savepoint. */
  private static Visit_Form__c completeVisit(
    Visit_Form__c visit,
    Double lat,
    Double lng,
    Double accuracyM,
    Map<String, Object> pipeline,
    Decimal checkOutDistance,
    Decimal fromCheckIn
  ) {
    Datetime checkOutTime = System.now();
    Boolean locationMissing = lat == null || lng == null;
    Integer duration = ((checkOutTime.getTime() - visit.Check_In_Time__c.getTime()) / 60000).intValue();

    Boolean isDuplicate = VisitProofStore.hashUsedByOtherVisit(visit.Image_SHA256_Hash__c, visit.Id);
    Boolean reachable = VisitQualificationService.hasReachableContact(visit);

    Id accountId = visit.Account__c;
    Id contactId = visit.Contact__c;
    Id opportunityId = visit.Opportunity__c;
    String targetType = visit.Target_Type__c;
    String action = visit.Pipeline_Action__c == null ? VisitPipelineService.ACTION_NONE : visit.Pipeline_Action__c;
    if (action == VisitPipelineService.ACTION_CONVERT_LEAD) {
      VisitPipelineService.ConvertResult converted = VisitPipelineService.convertLead(visit);
      accountId = converted.accountId;
      contactId = converted.contactId;
      opportunityId = converted.opportunityId;
      targetType = VisitQualificationService.TARGET_ACCOUNT;
      VisitPipelineService.qualifyConvertedOpportunity(opportunityId, visit, accountId);
    } else if (action == VisitPipelineService.ACTION_CREATE_OPPORTUNITY) {
      opportunityId = VisitPipelineService.createOpportunity(visit);
    } else if (action == VisitPipelineService.ACTION_UPDATE_OPPORTUNITY) {
      VisitPipelineService.updateOpportunity(visit, pipeline);
    }

    // Event: WhoId is the contact when there is one, otherwise the Lead. WhatId is the Opportunity, otherwise the Account.
    Id whoId = contactId != null ? contactId : visit.Lead__c;
    Id whatId = opportunityId != null ? opportunityId : accountId;
    Id eventId = VisitPipelineService.logEvent(visit, whoId, whatId, checkOutTime);

    VisitTelemetryScorer.VisitScoreInput input = new VisitTelemetryScorer.VisitScoreInput();
    input.geofenceRadiusM = FieldSalesConfig.getMaxGeofenceRadiusM();
    input.driveByDistanceM = FieldSalesConfig.getDriveByDistanceM();
    input.minDurationMinutes = FieldSalesConfig.getMinVisitDurationMinutes();
    input.durationMinutes = duration;
    input.purpose = visit.Visit_Purpose__c;
    input.checkInDistanceM = visit.Check_In_Distance_Meters__c;
    input.hasCheckInExceptionReason = visit.Geofence_Exception_Reason__c != null;
    input.checkOutDistanceM = checkOutDistance;
    input.checkOutFromCheckInM = fromCheckIn;
    input.isCheckOutLocationMissing = locationMissing;
    input.isRepPinnedAtCheckIn = visit.Is_Target_Rep_Pinned__c;
    input.hasProofPhoto = visit.Photo_Document_Id__c != null;
    input.isDuplicatePhoto = isDuplicate;
    input.hasClientSignature = visit.Signature_Document_Id__c != null;
    input.signatureDistanceFromCheckInM = visit.Signature_Distance_From_Check_In_Meters__c;
    input.isSignatureDeclined = visit.Signature_Declined_Reason__c != null;
    input.hasContactPhoneOrEmail = reachable;
    input.hasPdpConsent = visit.UU_PDP_Consent__c;
    VisitTelemetryScorer.VisitScoreResult score = VisitTelemetryScorer.score(input);

    String checkOutAddress = null;
    if (!locationMissing) {
      checkOutAddress = GeoapifyService.reverseGeocode(lat, lng);
      if (String.isNotBlank(checkOutAddress) && checkOutAddress.length() > 255) {
        checkOutAddress = checkOutAddress.left(255);
      }
    }

    // SYSTEM_MODE: the rep has read-only FLS on the status, the scores and the links set here.
    VisitProofStore.updateVisit(
      new Visit_Form__c(
        Id = visit.Id,
        Status__c = STATUS_COMPLETED,
        Check_Out_Time__c = checkOutTime,
        Visit_Duration_Minutes__c = duration,
        Is_Short_Visit__c = duration < input.minDurationMinutes,
        Check_Out_Location__Latitude__s = lat,
        Check_Out_Location__Longitude__s = lng,
        Check_Out_Accuracy_Meters__c = (Decimal) accuracyM,
        Check_Out_Distance_Meters__c = checkOutDistance,
        Check_Out_From_Check_In_Meters__c = fromCheckIn,
        Check_Out_Address__c = checkOutAddress,
        Is_Check_Out_Location_Missing__c = locationMissing,
        Is_Duplicate_Photo__c = isDuplicate,
        Target_Type__c = targetType,
        Account__c = accountId,
        Contact__c = contactId,
        Opportunity__c = opportunityId,
        Event_Id__c = String.valueOf(eventId),
        Open_Visit_Key__c = null,
        Location_Score__c = score.locationScore,
        Duration_Score__c = score.durationScore,
        Proof_Score__c = score.proofScore,
        Telemetry_Score__c = score.telemetryScore
      )
    );
    return loadVisit(visit.Id);
  }

  private static Map<String, Object> parsePipeline(String pipelineJson) {
    if (String.isBlank(pipelineJson)) {
      return new Map<String, Object>();
    }
    try {
      return (Map<String, Object>) JSON.deserializeUntyped(pipelineJson);
    } catch (Exception e) {
      throw new AuraHandledException(System.Label.Visit_Err_Draft_Invalid);
    }
  }

  /**
   * @description Maps a visit's whitelisted draft fields to the client's keys. interestedPackages becomes a list.
   * @param visit Visit loaded with VISIT_FIELDS.
   * @return Draft values keyed by the whitelist names.
   */
  public static Map<String, Object> draftOf(Visit_Form__c visit) {
    Map<String, Object> draft = new Map<String, Object>();
    for (String key : DRAFT_FIELD_BY_KEY.keySet()) {
      Object value = visit.get(DRAFT_FIELD_BY_KEY.get(key));
      if (key == 'interestedPackages' && value != null) {
        List<String> packages = new List<String>();
        for (String item : String.valueOf(value).split(';')) {
          packages.add(item);
        }
        value = packages;
      }
      draft.put(key, value);
    }
    return draft;
  }

  /**
   * @description Loads a visit the caller owns and that is In Progress. Proof services call this before any write.
   * @param visitId Visit Id.
   * @return The visit.
   * @throws AuraHandledException If the visit is not visible, not owned by the caller, or no longer In Progress.
   */
  public static Visit_Form__c loadOwnedInProgress(Id visitId) {
    Visit_Form__c visit = loadVisit(visitId);
    requireOwnedInProgress(visit);
    return visit;
  }

  /**
   * @description Reloads a visit WITH USER_MODE after a write, so the DTO reflects the saved state.
   * @param visitId Visit Id.
   * @return The visit.
   */
  public static Visit_Form__c reload(Id visitId) {
    return loadVisit(visitId);
  }

  /** Loads one visit WITH USER_MODE. A visit the caller cannot see is reported as not found. */
  private static Visit_Form__c loadVisit(Id visitId) {
    List<Visit_Form__c> rows = Database.query(
      'SELECT ' + VISIT_FIELDS + ' FROM Visit_Form__c WHERE Id = :visitId WITH USER_MODE LIMIT 1'
    );
    if (rows.isEmpty()) {
      throw new AuraHandledException(System.Label.Visit_Err_Visit_Not_Found);
    }
    return rows[0];
  }

  /** Throws unless the caller owns the visit and it is In Progress. */
  private static void requireOwnedInProgress(Visit_Form__c visit) {
    if (visit.OwnerId != UserInfo.getUserId()) {
      throw new AuraHandledException(System.Label.Visit_Err_Not_Owner);
    }
    if (visit.Status__c != STATUS_IN_PROGRESS) {
      throw new AuraHandledException(System.Label.Visit_Err_Not_In_Progress);
    }
  }

  /** Converts a client draft value to the type of its target field. Blank text becomes null. */
  private static Object toFieldValue(String field, Object raw) {
    if (raw == null) {
      return null;
    }
    if (raw instanceof List<Object>) {
      List<String> items = new List<String>();
      for (Object item : (List<Object>) raw) {
        String s = String.valueOf(item).trim();
        if (PICKLIST_NORMALIZER.containsKey(s)) {
          s = PICKLIST_NORMALIZER.get(s);
        }
        items.add(s);
      }
      return items.isEmpty() ? null : String.join(items, ';');
    }

    String text = String.valueOf(raw).trim();
    if (String.isBlank(text)) {
      return null;
    }
    if (PICKLIST_NORMALIZER.containsKey(text)) {
      text = PICKLIST_NORMALIZER.get(text);
    }
    if (field == 'Estimated_Pax__c' || field == 'Total_Estimated_Budget__c') {
      return Decimal.valueOf(text);
    }
    if (field == 'UU_PDP_Consent__c' || field == 'Final_Approver_Identified__c') {
      return Boolean.valueOf(text);
    }
    if (field == 'Target_Event_Date__c') {
      return Date.valueOf(text);
    }
    if (field == 'Contact__c' || field == 'Opportunity__c') {
      return Id.valueOf(text);
    }
    return text;
  }
}