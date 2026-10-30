/**
 * @description Reads the org-level field visit governance settings from the Field_Sales_Config__mdt
 *              record named Default. The record is queried once per transaction. When the record is
 *              missing, or a value is blank, the documented default is used, so a missing setting never
 *              blocks a rep from checking in or out. Admins change the settings in Setup; no code change is needed.
 */
public without sharing class FieldSalesConfig {
  /** Default maximum geofence radius in metres. */
  public static final Decimal DEFAULT_MAX_GEOFENCE_RADIUS_M = 300;
  /** Default: off-site check-in is allowed, with an exception reason and a soft score penalty. */
  public static final Boolean DEFAULT_ALLOW_OUTSIDE_GEOFENCE_CHECKIN = true;
  /** Default minimum visit duration in minutes. */
  public static final Integer DEFAULT_MIN_VISIT_DURATION_MINUTES = 10;
  /** Default drive-by distance in metres. */
  public static final Decimal DEFAULT_DRIVE_BY_DISTANCE_M = 1000;
  /** Default stale-visit cutoff in hours. */
  public static final Integer DEFAULT_STALE_VISIT_HOURS = 12;
  /** Default AI alert score threshold: totals below it are flagged for investigation (visit-ai-scoring). */
  public static final Integer DEFAULT_AI_ALERT_SCORE_THRESHOLD = 55;
  /** Default verified threshold: totals at or above it, with no fraud flag, are Verified (visit-ai-scoring). */
  public static final Integer DEFAULT_VERIFIED_SCORE_THRESHOLD = 75;
  /** Default minutes to wait for the AI callback before a Sent visit is re-sent (visit-ai-scoring). */
  public static final Integer DEFAULT_AI_CALLBACK_TIMEOUT_MINUTES = 30;
  /** Default number of AI send attempts before a visit becomes Failed (visit-ai-scoring). */
  public static final Integer DEFAULT_AI_MAX_ATTEMPTS = 3;

  private static final String CONFIG_DEVELOPER_NAME = 'Default';

  private static Field_Sales_Config__mdt cachedConfig;
  private static Boolean isLoaded = false;

  /**
   * @description Maximum geofence radius in metres.
   * @return Configured radius, or DEFAULT_MAX_GEOFENCE_RADIUS_M when missing or blank.
   */
  public static Decimal getMaxGeofenceRadiusM() {
    Field_Sales_Config__mdt cfg = getRecord();
    return (cfg == null || cfg.Max_Geofence_Radius_Meters__c == null)
      ? DEFAULT_MAX_GEOFENCE_RADIUS_M
      : cfg.Max_Geofence_Radius_Meters__c;
  }

  /**
   * @description Whether a rep may check in outside the geofence (with an exception reason).
   * @return Configured flag, or DEFAULT_ALLOW_OUTSIDE_GEOFENCE_CHECKIN when missing or blank.
   */
  public static Boolean isAllowOutsideGeofenceCheckIn() {
    Field_Sales_Config__mdt cfg = getRecord();
    return (cfg == null || cfg.Allow_Outside_Geofence_CheckIn__c == null)
      ? DEFAULT_ALLOW_OUTSIDE_GEOFENCE_CHECKIN
      : cfg.Allow_Outside_Geofence_CheckIn__c;
  }

  /**
   * @description Minimum visit duration in minutes. Visits shorter than this are flagged as short.
   * @return Configured minutes, or DEFAULT_MIN_VISIT_DURATION_MINUTES when missing or blank.
   */
  public static Integer getMinVisitDurationMinutes() {
    Field_Sales_Config__mdt cfg = getRecord();
    return (cfg == null || cfg.Min_Visit_Duration_Minutes__c == null)
      ? DEFAULT_MIN_VISIT_DURATION_MINUTES
      : cfg.Min_Visit_Duration_Minutes__c.intValue();
  }

  /**
   * @description Drive-by distance in metres. Beyond it, a check-out counts as a drive-by.
   * @return Configured distance, or DEFAULT_DRIVE_BY_DISTANCE_M when missing or blank.
   */
  public static Decimal getDriveByDistanceM() {
    Field_Sales_Config__mdt cfg = getRecord();
    return (cfg == null || cfg.Drive_By_Distance_Meters__c == null)
      ? DEFAULT_DRIVE_BY_DISTANCE_M
      : cfg.Drive_By_Distance_Meters__c;
  }

  /**
   * @description Hours an In Progress visit may stay open before the nightly job cancels it.
   * @return Configured hours, or DEFAULT_STALE_VISIT_HOURS when missing or blank.
   */
  public static Integer getStaleVisitHours() {
    Field_Sales_Config__mdt cfg = getRecord();
    return (cfg == null || cfg.Stale_Visit_Hours__c == null)
      ? DEFAULT_STALE_VISIT_HOURS
      : cfg.Stale_Visit_Hours__c.intValue();
  }

  /**
   * @description AI alert score threshold. A scored visit totalling less than this is Flagged for Investigation.
   * @return Configured threshold, or DEFAULT_AI_ALERT_SCORE_THRESHOLD when missing or blank.
   */
  public static Integer getAiAlertScoreThreshold() {
    Field_Sales_Config__mdt cfg = getRecord();
    return (cfg == null || cfg.AI_Alert_Score_Threshold__c == null)
      ? DEFAULT_AI_ALERT_SCORE_THRESHOLD
      : cfg.AI_Alert_Score_Threshold__c.intValue();
  }

  /**
   * @description Verified threshold. A scored visit totalling at least this, with no fraud flag, is Verified.
   * @return Configured threshold, or DEFAULT_VERIFIED_SCORE_THRESHOLD when missing or blank.
   */
  public static Integer getVerifiedScoreThreshold() {
    Field_Sales_Config__mdt cfg = getRecord();
    return (cfg == null || cfg.Verified_Score_Threshold__c == null)
      ? DEFAULT_VERIFIED_SCORE_THRESHOLD
      : cfg.Verified_Score_Threshold__c.intValue();
  }

  /**
   * @description Minutes a visit may stay Sent before the sweep job re-sends it.
   * @return Configured minutes, or DEFAULT_AI_CALLBACK_TIMEOUT_MINUTES when missing or blank.
   */
  public static Integer getAiCallbackTimeoutMinutes() {
    Field_Sales_Config__mdt cfg = getRecord();
    return (cfg == null || cfg.AI_Callback_Timeout_Minutes__c == null)
      ? DEFAULT_AI_CALLBACK_TIMEOUT_MINUTES
      : cfg.AI_Callback_Timeout_Minutes__c.intValue();
  }

  /**
   * @description Maximum AI send attempts per visit. After the last failed attempt the visit becomes Failed.
   * @return Configured attempts, or DEFAULT_AI_MAX_ATTEMPTS when missing or blank.
   */
  public static Integer getAiMaxAttempts() {
    Field_Sales_Config__mdt cfg = getRecord();
    return (cfg == null || cfg.AI_Max_Attempts__c == null)
      ? DEFAULT_AI_MAX_ATTEMPTS
      : cfg.AI_Max_Attempts__c.intValue();
  }

  /**
   * @description Loads the Default configuration record once per transaction.
   * @return The record, or null when it does not exist.
   */
  private static Field_Sales_Config__mdt getRecord() {
    if (!isLoaded) {
      List<Field_Sales_Config__mdt> rows = [
        SELECT
          Max_Geofence_Radius_Meters__c,
          Allow_Outside_Geofence_CheckIn__c,
          Min_Visit_Duration_Minutes__c,
          Drive_By_Distance_Meters__c,
          Stale_Visit_Hours__c,
          AI_Alert_Score_Threshold__c,
          Verified_Score_Threshold__c,
          AI_Callback_Timeout_Minutes__c,
          AI_Max_Attempts__c
        FROM Field_Sales_Config__mdt
        WHERE DeveloperName = :CONFIG_DEVELOPER_NAME
        LIMIT 1
      ];
      cachedConfig = rows.isEmpty() ? null : rows[0];
      isLoaded = true;
    }
    return cachedConfig;
  }
}