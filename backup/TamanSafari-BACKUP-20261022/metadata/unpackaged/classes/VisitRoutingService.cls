/**
 * @description Verification routing for completed visits (visit-ai-scoring design D8, spec visit-verification-routing).
 *              It turns check-out fraud flags, the AI result and the thresholds into a verification tier, an
 *              investigation status and a one-time manager alert mark. The decision methods (checkOutFlags, tier,
 *              mergeFlags) are pure. The apply methods only change the visit passed in, so they are called from the
 *              before-update trigger and need no DML.
 */
public with sharing class VisitRoutingService {
  public static final String TIER_VERIFIED = 'Verified';
  public static final String TIER_COACHING = 'Coaching Needed';
  public static final String TIER_FLAGGED = 'Flagged for Investigation';

  public static final String FLAG_DUPLICATE_PHOTO = 'Duplicate photo';
  public static final String FLAG_OFFSITE_SHORT = 'Off-site check-in with short visit';
  public static final String FLAG_AI_MANIPULATION = 'Suspected AI manipulation';

  public static final String INVESTIGATION_NOT_REQUIRED = 'Not Required';
  public static final String INVESTIGATION_PENDING = 'Pending Manager Review';
  public static final String INVESTIGATION_EXCUSED = 'Excused / Valid';
  public static final String INVESTIGATION_REJECTED = 'Rejected / Fake Visit';

  public static final String AI_PENDING = 'Pending';
  public static final String AI_SENT = 'Sent';
  public static final String AI_SCORED = 'Scored';
  public static final String AI_FAILED = 'Failed';

  /**
   * @description Fraud flags that can be decided at check-out, without AI: a duplicate photo, and an off-site
   *              check-in combined with a short visit.
   * @param visit Visit with Is_Duplicate_Photo__c, Is_Outside_Geofence__c and Is_Short_Visit__c set.
   * @return The flag reasons, in a stable order. Empty when none apply.
   */
  public static List<String> checkOutFlags(Visit_Form__c visit) {
    List<String> flags = new List<String>();
    if (visit.Is_Duplicate_Photo__c == true) {
      flags.add(FLAG_DUPLICATE_PHOTO);
    }
    if (visit.Is_Outside_Geofence__c == true && visit.Is_Short_Visit__c == true) {
      flags.add(FLAG_OFFSITE_SHORT);
    }
    return flags;
  }

  /**
   * @description Verification tier for a scored visit. Any fraud flag, or a total below the alert threshold, is Flagged;
   *              otherwise a total at or above the verified threshold is Verified; anything else is Coaching Needed.
   * @param total Telemetry + AI consistency + AI summary.
   * @param flags Fraud flag reasons already known for the visit.
   * @param alertThreshold Totals below this are flagged (default 55).
   * @param verifiedThreshold Totals at or above this are Verified (default 75).
   * @return The tier picklist value.
   */
  public static String tier(Decimal total, List<String> flags, Integer alertThreshold, Integer verifiedThreshold) {
    if ((flags != null && !flags.isEmpty()) || total < alertThreshold) {
      return TIER_FLAGGED;
    }
    return total >= verifiedThreshold ? TIER_VERIFIED : TIER_COACHING;
  }

  /**
   * @description Merges flag reasons from the multi-select field with new ones, without duplicates.
   * @param existing Current value of Fraud_Flag_Reasons__c (semicolon separated), or null.
   * @param added Reasons to add.
   * @return The merged list, existing reasons first.
   */
  public static List<String> mergeFlags(String existing, List<String> added) {
    List<String> merged = new List<String>();
    if (String.isNotBlank(existing)) {
      merged.addAll(existing.split(';'));
    }
    for (String flag : added) {
      if (!merged.contains(flag)) {
        merged.add(flag);
      }
    }
    return merged;
  }

  /**
   * @description Applies the check-out fraud flags to a visit that has just been completed. A match sets the tier to
   *              Flagged, investigation to Pending Manager Review, records the reasons and marks the visit for its
   *              one manager alert. No match leaves the visit untouched, so the tier waits for the AI result.
   * @param visit The completed visit, modified in place. Call from a before-update trigger.
   * @return True when the visit was flagged and has not been alerted before, so the caller must queue the alert.
   */
  public static Boolean applyCheckOutFlags(Visit_Form__c visit) {
    List<String> flags = checkOutFlags(visit);
    if (flags.isEmpty()) {
      return false;
    }
    visit.Fraud_Flag_Reasons__c = String.join(mergeFlags(visit.Fraud_Flag_Reasons__c, flags), ';');
    return markFlagged(visit);
  }

  /**
   * @description Applies the AI result to a visit that has just reached Scored: total, tier, the prompt-injection
   *              flag and the investigation status. A flag set at check-out stays and keeps the tier Flagged.
   * @param visit The scored visit, modified in place. Call from a before-update trigger.
   * @return True when the visit is flagged and has not been alerted before, so the caller must queue the alert.
   */
  public static Boolean applyScoredResult(Visit_Form__c visit) {
    List<String> added = new List<String>();
    if (visit.AI_Injection_Suspected__c == true) {
      added.add(FLAG_AI_MANIPULATION);
    }
    List<String> flags = mergeFlags(visit.Fraud_Flag_Reasons__c, added);
    if (!flags.isEmpty()) {
      visit.Fraud_Flag_Reasons__c = String.join(flags, ';');
    }
    Decimal total =
      zeroIfNull(visit.Telemetry_Score__c) +
      zeroIfNull(visit.AI_Consistency_Score__c) +
      zeroIfNull(visit.AI_Summary_Score__c);
    String verdict = tier(
      total,
      flags,
      FieldSalesConfig.getAiAlertScoreThreshold(),
      FieldSalesConfig.getVerifiedScoreThreshold()
    );
    if (verdict == TIER_FLAGGED) {
      return markFlagged(visit);
    }
    visit.Visit_Verification_Tier__c = verdict;
    if (String.isBlank(visit.Investigation_Status__c)) {
      visit.Investigation_Status__c = INVESTIGATION_NOT_REQUIRED;
    }
    return false;
  }

  /** Sets the Flagged tier and investigation status, and stamps the alert time once. Returns true on the first alert. */
  private static Boolean markFlagged(Visit_Form__c visit) {
    visit.Visit_Verification_Tier__c = TIER_FLAGGED;
    // A manager's decision on a flagged visit is final, so only a blank or Not Required status is reopened.
    if (String.isBlank(visit.Investigation_Status__c) || visit.Investigation_Status__c == INVESTIGATION_NOT_REQUIRED) {
      visit.Investigation_Status__c = INVESTIGATION_PENDING;
    }
    if (visit.Manager_Alerted_At__c == null) {
      visit.Manager_Alerted_At__c = System.now();
      return true;
    }
    return false;
  }

  private static Decimal zeroIfNull(Decimal value) {
    return value == null ? 0 : value;
  }
}