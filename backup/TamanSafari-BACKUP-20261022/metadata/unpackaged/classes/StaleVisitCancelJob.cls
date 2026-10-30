/**
 * @description Nightly job that cancels In Progress visits older than the stale-visit cutoff and notifies the owning
 *              rep (field-visit-core design D9, spec field-visit-lifecycle "Stale visit auto-cancellation").
 *              It runs without sharing on purpose: it must see every rep's open visits. It only touches visits that
 *              are In Progress and past the cutoff. The cutoff comes from Field_Sales_Config__mdt.
 *              Scheduling is done by the post-deploy script (task 8.3), not here.
 */
public without sharing class StaleVisitCancelJob implements Database.Batchable<SObject>, Schedulable {
  public static final String CANCEL_REASON = 'Auto-Cancelled (Stale)';
  public static final String NOTIFICATION_TYPE_NAME = 'Field_Visit_Auto_Cancelled';
  private static final Integer BATCH_SIZE = 200;

  /**
   * @description Selects In Progress visits whose server check-in is older than the stale cutoff.
   * @param bc Batch context.
   * @return Query locator over the stale visits.
   */
  public Database.QueryLocator start(Database.BatchableContext bc) {
    String inProgress = VisitLifecycleService.STATUS_IN_PROGRESS;
    DateTime cutoff = System.now().addHours(-FieldSalesConfig.getStaleVisitHours());
    return Database.getQueryLocator(
      [
        SELECT Id, OwnerId, Status__c
        FROM Visit_Form__c
        WHERE Status__c = :inProgress AND Check_In_Time__c < :cutoff
      ]
    );
  }

  /**
   * @description Cancels one chunk of stale visits, then notifies each owner.
   * @param bc Batch context.
   * @param scope Stale visits in this chunk.
   */
  public void execute(Database.BatchableContext bc, List<Visit_Form__c> scope) {
    List<Visit_Form__c> cancelled = cancelVisits(scope);
    notifyOwners(cancelled);
  }

  public void finish(Database.BatchableContext bc) {
  }

  /**
   * @description Schedulable entry point. Runs the batch with a chunk size of 200.
   * @param sc Scheduling context.
   */
  public void execute(SchedulableContext sc) {
    Database.executeBatch(new StaleVisitCancelJob(), BATCH_SIZE);
  }

  /**
   * @description Sets the visits to Cancelled with the stale reason and clears the open-visit key, so the owner can check in again.
   *              Public so the cancel step can be run without sending notifications.
   * @param visits In Progress visits to cancel.
   * @return The visits that were cancelled.
   */
  public static List<Visit_Form__c> cancelVisits(List<Visit_Form__c> visits) {
    for (Visit_Form__c visit : visits) {
      visit.Status__c = VisitLifecycleService.STATUS_CANCELLED;
      visit.Cancellation_Reason__c = CANCEL_REASON;
      visit.Open_Visit_Key__c = null;
    }
    if (!visits.isEmpty()) {
      // Through VisitLock so this write passes the completed-visit lock regardless of who runs the job.
      VisitLock.runAsSystem(visits, true);
    }
    return visits;
  }

  /**
   * @description Sends the Field_Visit_Auto_Cancelled custom notification to each visit owner. A notification
   *              failure is logged and does not undo the cancellations.
   * @param cancelled Visits that were just cancelled.
   */
  private static void notifyOwners(List<Visit_Form__c> cancelled) {
    if (cancelled.isEmpty()) {
      return;
    }
    try {
      CustomNotificationType notificationType = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = :NOTIFICATION_TYPE_NAME
        LIMIT 1
      ];
      for (Visit_Form__c visit : cancelled) {
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setNotificationTypeId(notificationType.Id);
        notification.setTargetId(visit.Id);
        notification.setTitle(System.Label.Visit_Notif_Auto_Cancel_Title);
        notification.setBody(System.Label.Visit_Notif_Auto_Cancel_Body);
        notification.send(new Set<String>{ String.valueOf(visit.OwnerId) });
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'StaleVisitCancelJob: owner notification failed: ' + e.getMessage());
    }
  }
}