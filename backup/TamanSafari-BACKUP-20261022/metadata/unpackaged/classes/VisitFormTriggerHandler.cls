/**
 * @description Trigger logic for Visit_Form__c (visit-ai-scoring design D2, D3).
 *              Before update: (1) the completed-visit lock, which replaces the old Lock_Completed_Visits validation
 *              rule; (2) on In Progress to Completed, the AI scoring status becomes Pending and the check-out fraud
 *              flags are applied; (3) when AI scoring reaches Scored, the tier and investigation status are set.
 *              After update: queues AI scoring and the one-time manager alert. Both are asynchronous, so check-out
 *              never waits for, or fails because of, n8n or OpenAI.
 */
public without sharing class VisitFormTriggerHandler {
  /** Fields a reviewer (manager) may change on a locked visit. API names in lower case. */
  private static final Set<String> REVIEWER_FIELDS = new Set<String>{
    'investigation_status__c',
    'investigation_notes__c'
  };

  /** Audit and system fields that change on every save and say nothing about the user's edit. */
  private static final Set<String> IGNORED_FIELDS = new Set<String>{
    'id',
    'isdeleted',
    'createddate',
    'createdbyid',
    'lastmodifieddate',
    'lastmodifiedbyid',
    'systemmodstamp',
    'lastactivitydate',
    'lastvieweddate',
    'lastreferenceddate'
  };

  /** Describe of the editable data fields, loaded once per transaction. */
  private static List<Schema.SObjectField> comparableFields;

  /**
   * @description Runs the lock, the check-out routing and the scored-result routing for each updated visit.
   * @param updated New versions of the visits.
   * @param oldById Old versions, keyed by Id.
   */
  public static void beforeUpdate(List<Visit_Form__c> updated, Map<Id, Visit_Form__c> oldById) {
    Boolean canBypass = FeatureManagement.checkPermission('Bypass_Visit_Lock');
    Boolean canReview = FeatureManagement.checkPermission('Review_Visit_Investigation');

    for (Visit_Form__c visit : updated) {
      Visit_Form__c old = oldById.get(visit.Id);

      String lockError = lockViolation(old, visit, VisitLock.systemWrite, canBypass, canReview);
      if (lockError != null) {
        visit.addError(lockError);
        continue;
      }

      if (old.Status__c != VisitLifecycleService.STATUS_COMPLETED && visit.Status__c == VisitLifecycleService.STATUS_COMPLETED) {
        visit.AI_Scoring_Status__c = VisitRoutingService.AI_PENDING;
        visit.AI_Attempt_Count__c = 0;
        VisitRoutingService.applyCheckOutFlags(visit);
      }

      if (old.AI_Scoring_Status__c != VisitRoutingService.AI_SCORED && visit.AI_Scoring_Status__c == VisitRoutingService.AI_SCORED) {
        VisitRoutingService.applyScoredResult(visit);
      }
    }
  }

  /**
   * @description Queues AI scoring for visits that just became Completed, and the manager alert for visits that were
   *              just flagged for the first time (Manager_Alerted_At__c went from blank to set).
   * @param updated New versions of the visits.
   * @param oldById Old versions, keyed by Id.
   */
  public static void afterUpdate(List<Visit_Form__c> updated, Map<Id, Visit_Form__c> oldById) {
    List<Id> toScore = new List<Id>();
    List<Id> toAlert = new List<Id>();
    for (Visit_Form__c visit : updated) {
      Visit_Form__c old = oldById.get(visit.Id);
      if (old.Status__c != VisitLifecycleService.STATUS_COMPLETED && visit.Status__c == VisitLifecycleService.STATUS_COMPLETED) {
        toScore.add(visit.Id);
      }
      if (old.Manager_Alerted_At__c == null && visit.Manager_Alerted_At__c != null) {
        toAlert.add(visit.Id);
      }
    }
    // A job already running as a Queueable may only enqueue one child, so skip rather than throw. The sweep job
    // picks up any visit that stays Pending, and a skipped alert is logged.
    if (!toScore.isEmpty() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
      System.enqueueJob(new VisitAIScoringQueueable(toScore));
    }
    if (!toAlert.isEmpty()) {
      if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
        System.enqueueJob(new VisitManagerAlertQueueable(toAlert));
      } else {
        System.debug(LoggingLevel.ERROR, 'VisitFormTrigger: manager alert not queued for ' + toAlert);
      }
    }
  }

  /**
   * @description Decides whether an update to a visit breaks the completed-visit lock (design D2). Pure: it reads only
   *              its arguments, so every case can be checked without DML.
   *              Not locked unless the old status is Completed or Cancelled. A locked visit may be changed by system
   *              processes, by users with Bypass_Visit_Lock, and by reviewers only for the investigation fields with a
   *              decision status.
   * @param oldVisit The visit before the update.
   * @param newVisit The visit after the update.
   * @param systemWrite True when VisitLock.runAsSystem is performing the write.
   * @param canBypass True when the user has the Bypass_Visit_Lock custom permission.
   * @param canReview True when the user has the Review_Visit_Investigation custom permission.
   * @return The error message to show, or null when the update is allowed.
   */
  public static String lockViolation(
    Visit_Form__c oldVisit,
    Visit_Form__c newVisit,
    Boolean systemWrite,
    Boolean canBypass,
    Boolean canReview
  ) {
    Boolean locked =
      oldVisit.Status__c == VisitLifecycleService.STATUS_COMPLETED ||
      oldVisit.Status__c == VisitLifecycleService.STATUS_CANCELLED;
    if (!locked || systemWrite || canBypass) {
      return null;
    }
    if (!canReview) {
      return System.Label.Visit_Err_Locked;
    }
    for (String field : changedFields(oldVisit, newVisit)) {
      if (!REVIEWER_FIELDS.contains(field)) {
        return System.Label.Visit_Err_Locked;
      }
    }
    String decision = newVisit.Investigation_Status__c;
    if (decision != VisitRoutingService.INVESTIGATION_EXCUSED && decision != VisitRoutingService.INVESTIGATION_REJECTED) {
      return System.Label.Visit_Err_Investigation_Status;
    }
    return null;
  }

  /**
   * @description Lists the data fields whose value differs between two versions of a visit. Formula fields and the
   *              audit fields are skipped. A geolocation is compared by latitude and longitude.
   * @param oldVisit The visit before the update.
   * @param newVisit The visit after the update.
   * @return Lower-case API names of the changed fields.
   */
  public static List<String> changedFields(Visit_Form__c oldVisit, Visit_Form__c newVisit) {
    List<String> changed = new List<String>();
    for (Schema.SObjectField token : fields()) {
      Schema.DescribeFieldResult describe = token.getDescribe();
      String name = describe.getName();
      if (describe.getType() == Schema.DisplayType.LOCATION) {
        String base = name.removeEnd('__c');
        if (
          oldVisit.get(base + '__Latitude__s') != newVisit.get(base + '__Latitude__s') ||
          oldVisit.get(base + '__Longitude__s') != newVisit.get(base + '__Longitude__s')
        ) {
          changed.add(name.toLowerCase());
        }
      } else if (oldVisit.get(name) != newVisit.get(name)) {
        changed.add(name.toLowerCase());
      }
    }
    return changed;
  }

  /** Fields worth comparing: not formulas, not audit fields. */
  private static List<Schema.SObjectField> fields() {
    if (comparableFields == null) {
      comparableFields = new List<Schema.SObjectField>();
      for (Schema.SObjectField token : Schema.SObjectType.Visit_Form__c.fields.getMap().values()) {
        Schema.DescribeFieldResult describe = token.getDescribe();
        if (!describe.isCalculated() && !IGNORED_FIELDS.contains(describe.getName().toLowerCase())) {
          comparableFields.add(token);
        }
      }
    }
    return comparableFields;
  }
}