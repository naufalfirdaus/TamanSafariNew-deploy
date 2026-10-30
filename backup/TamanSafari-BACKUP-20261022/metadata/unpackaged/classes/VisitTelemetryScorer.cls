/**
 * @description Pure, deterministic telemetry scorer for a completed field visit (0-50).
 *              Location (0-20), duration (0-15) and physical proof (0-15) are computed from the
 *              input object only. It does no SOQL, no DML and reads no clock, so the same input
 *              always gives the same score. Cancelled visits must not be scored; the caller enforces that.
 *              Scoring rules: openspec/changes/field-visit-core/specs/visit-telemetry-score/spec.md
 */
public with sharing class VisitTelemetryScorer {
  /** Purpose value that shortens the duration threshold for full duration points. */
  private static final String PURPOSE_FINAL_CONFIRMATION = 'Final Confirmation / Contracting';
  /** Duration at which the full 15 duration points are awarded (except final confirmation). */
  private static final Integer FULL_DURATION_MINUTES = 15;
  /** Maximum location score while the target's location was rep-pinned at check-in. */
  private static final Integer REP_PINNED_LOCATION_CAP = 12;

  /**
   * @description Everything the scorer needs. The caller gathers these from the visit and its related records.
   */
  public class VisitScoreInput {
    /** Geofence radius R in metres, from FieldSalesConfig. */
    public Decimal geofenceRadiusM;
    /** Drive-by distance D in metres, from FieldSalesConfig. */
    public Decimal driveByDistanceM;
    /** Minimum visit duration M in minutes, from FieldSalesConfig. */
    public Integer minDurationMinutes;

    /** Whole minutes between server check-in and server check-out. */
    public Integer durationMinutes;
    /** Visit purpose picklist value. */
    public String purpose;

    /** Server-computed distance from the check-in reading to the target, in metres. */
    public Decimal checkInDistanceM;
    /** True when the rep gave a reason for checking in outside the geofence. */
    public Boolean hasCheckInExceptionReason;
    /** Server-computed distance from the check-out reading to the target, in metres. Null when missing. */
    public Decimal checkOutDistanceM;
    /** Server-computed distance from the check-out reading to the check-in reading, in metres. Null when missing. */
    public Decimal checkOutFromCheckInM;
    /** True when no check-out location fix was obtained (Is_Check_Out_Location_Missing__c). */
    public Boolean isCheckOutLocationMissing;
    /** True when the target's location source was Rep Pinned at check-in (snapshot). */
    public Boolean isRepPinnedAtCheckIn;

    /** True when the visit has a proof photo. */
    public Boolean hasProofPhoto;
    /** True when the proof photo hash matches another visit's photo. */
    public Boolean isDuplicatePhoto;
    /** True when a client signature is stored. */
    public Boolean hasClientSignature;
    /** Server-computed distance from the signature capture to the check-in reading, in metres. */
    public Decimal signatureDistanceFromCheckInM;
    /** True when the client declined to sign and a declined reason is recorded. */
    public Boolean isSignatureDeclined;
    /** True when the Contact (or the Lead) has a phone number or an email. */
    public Boolean hasContactPhoneOrEmail;
    /** True when the client gave PDP consent. */
    public Boolean hasPdpConsent;
  }

  /**
   * @description Scoring output. telemetryScore is always the sum of the three components.
   */
  public class VisitScoreResult {
    /** Location score, 0-20. */
    public Integer locationScore;
    /** Duration score, 0-15. */
    public Integer durationScore;
    /** Physical-proof score, 0-15. */
    public Integer proofScore;
    /** Telemetry score, 0-50. */
    public Integer telemetryScore;
  }

  /**
   * @description Computes the three component scores and their total for one completed visit.
   * @param input Raw and server-computed facts about the visit. Required fields must not be null
   *              except the distances noted as nullable on VisitScoreInput.
   * @return VisitScoreResult with each component and the telemetry total.
   */
  public static VisitScoreResult score(VisitScoreInput input) {
    VisitScoreResult result = new VisitScoreResult();
    result.locationScore = locationScore(input);
    result.durationScore = durationScore(input);
    result.proofScore = proofScore(input);
    result.telemetryScore =
      result.locationScore +
      result.durationScore +
      result.proofScore;
    return result;
  }

  /**
   * @description Location score: 20 on-site throughout; 12 for an off-site meeting (with a reason, up to the
   *              drive-by distance) where check-out stayed within R of the check-in point; 10 for a visit that
   *              wandered between R and D; 5 otherwise, including a missing check-out location.
   *              A rep-pinned target at check-in caps the score at 12.
   */
  private static Integer locationScore(VisitScoreInput input) {
    Decimal radius = input.geofenceRadiusM;
    Decimal driveBy = input.driveByDistanceM;
    Boolean checkOutMissing =
      isTrue(input.isCheckOutLocationMissing) ||
      input.checkOutDistanceM == null ||
      input.checkOutFromCheckInM == null;

    Integer score;
    if (checkOutMissing) {
      score = 5;
    } else if (
      input.checkInDistanceM <= radius &&
      input.checkOutDistanceM <= radius
    ) {
      score = 20;
    } else if (
      input.checkInDistanceM > radius &&
      input.checkInDistanceM <= driveBy &&
      isTrue(input.hasCheckInExceptionReason) &&
      input.checkOutFromCheckInM <= radius
    ) {
      score = 12;
    } else if (
      input.checkInDistanceM <= radius &&
      input.checkOutDistanceM > radius &&
      input.checkOutDistanceM <= driveBy
    ) {
      score = 10;
    } else {
      score = 5;
    }

    if (isTrue(input.isRepPinnedAtCheckIn)) {
      score = Math.min(score, REP_PINNED_LOCATION_CAP);
    }
    return score;
  }

  /**
   * @description Duration score: 0 under the minimum duration; 15 for 15 minutes or more, or for any
   *              duration at or above the minimum in a final-confirmation visit; 10 otherwise.
   */
  private static Integer durationScore(VisitScoreInput input) {
    if (input.durationMinutes < input.minDurationMinutes) {
      return 0;
    }
    if (
      input.durationMinutes >= FULL_DURATION_MINUTES ||
      input.purpose == PURPOSE_FINAL_CONFIRMATION
    ) {
      return 15;
    }
    return 10;
  }

  /**
   * @description Physical-proof score: 6 for a unique proof photo; 5 for a signature within R of the check-in
   *              location, or 2 for a declined reason; 4 when the contact is reachable and consent is given.
   *              A duplicate photo makes the whole score 0.
   */
  private static Integer proofScore(VisitScoreInput input) {
    if (isTrue(input.isDuplicatePhoto)) {
      return 0;
    }

    Integer score = 0;
    if (isTrue(input.hasProofPhoto)) {
      score += 6;
    }
    if (
      isTrue(input.hasClientSignature) &&
      input.signatureDistanceFromCheckInM != null &&
      input.signatureDistanceFromCheckInM <= input.geofenceRadiusM
    ) {
      score += 5;
    } else if (isTrue(input.isSignatureDeclined)) {
      score += 2;
    }
    if (
      isTrue(input.hasContactPhoneOrEmail) &&
      isTrue(input.hasPdpConsent)
    ) {
      score += 4;
    }
    return score;
  }

  /** Treats a null Boolean as false, so an unset flag never throws. */
  private static Boolean isTrue(Boolean flag) {
    return flag == true;
  }
}