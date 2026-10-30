/**
 * @description Alerts a rep's manager that a visit was flagged for investigation (visit-ai-scoring design D9, spec
 *              "Manager alert for flagged visits"). Each visit gets a high-priority Task assigned to the manager, a bell
 *              notification (Field_Visit_Flagged) and an email, all linking the visit. A failure in one channel is
 *              logged and does not stop the others. A rep without a manager is skipped, and the visit stays flagged.
 *              The trigger queues this job once per visit, when Manager_Alerted_At__c is first set, so it never
 *              sends a second alert. Texts are Custom Labels in Bahasa Indonesia.
 *              The job runs as the rep, who has no field access to the flag reasons and audit summary, so its queries
 *              say WITH SYSTEM_MODE.
 */
public without sharing class VisitManagerAlertQueueable implements Queueable {
  public static final String NOTIFICATION_TYPE_NAME = 'Field_Visit_Flagged';

  private final List<Id> visitIds;

  /**
   * @param visitIds Visits that were just flagged for the first time.
   */
  public VisitManagerAlertQueueable(List<Id> visitIds) {
    this.visitIds = visitIds;
  }

  /**
   * @description Sends the three alert channels for each visit.
   * @param context Queueable context.
   */
  public void execute(QueueableContext context) {
    List<Visit_Form__c> visits = [
      SELECT
        Id,
        OwnerId,
        Account__r.Name,
        Lead__r.Name,
        Fraud_Flag_Reasons__c,
        AI_Audit_Summary__c
      FROM Visit_Form__c
      WHERE Id IN :visitIds
      WITH SYSTEM_MODE
    ];
    Set<Id> ownerIds = new Set<Id>();
    for (Visit_Form__c visit : visits) {
      ownerIds.add(visit.OwnerId);
    }
    Map<Id, User> owners = new Map<Id, User>(
      [
        SELECT Id, Name, ManagerId, Manager.Name, Manager.Email, Manager.IsActive
        FROM User
        WHERE Id IN :ownerIds
        WITH SYSTEM_MODE
      ]
    );

    for (Visit_Form__c visit : visits) {
      User rep = owners.get(visit.OwnerId);
      if (rep == null || rep.ManagerId == null || rep.Manager.IsActive != true) {
        System.debug(LoggingLevel.WARN, 'VisitManagerAlertQueueable: no active manager for visit ' + visit.Id);
        continue;
      }
      List<String> text = texts(visit, rep);
      createTask(visit, rep, text);
      sendBell(visit, rep, text);
      sendEmail(visit, rep, text);
    }
  }

  /** Builds the shared text pieces: [subject, task body, bell title, bell body, email subject, email body]. */
  private static List<String> texts(Visit_Form__c visit, User rep) {
    String target = visit.Account__r != null ? visit.Account__r.Name : (visit.Lead__r != null ? visit.Lead__r.Name : '-');
    String reasons = String.isBlank(visit.Fraud_Flag_Reasons__c)
      ? System.Label.Visit_Alert_Reasons_None
      : visit.Fraud_Flag_Reasons__c.replace(';', ', ');
    String audit = String.isBlank(visit.AI_Audit_Summary__c) ? System.Label.Visit_Alert_Audit_Pending : visit.AI_Audit_Summary__c;
    String link = URL.getOrgDomainUrl().toExternalForm() + '/' + visit.Id;
    List<String> repAndTarget = new List<String>{ rep.Name, target };
    return new List<String>{
      String.format(System.Label.Visit_Alert_Task_Subject, repAndTarget),
      String.format(System.Label.Visit_Alert_Task_Body, new List<String>{ rep.Name, target, reasons, audit }),
      System.Label.Visit_Alert_Notif_Title,
      String.format(System.Label.Visit_Alert_Notif_Body, repAndTarget),
      String.format(System.Label.Visit_Alert_Email_Subject, repAndTarget),
      String.format(
        System.Label.Visit_Alert_Email_Body,
        new List<String>{ rep.Manager.Name, rep.Name, target, reasons, audit, link }
      )
    };
  }

  private static void createTask(Visit_Form__c visit, User rep, List<String> text) {
    try {
      insert new Task(
        OwnerId = rep.ManagerId,
        WhatId = visit.Id,
        Subject = text[0].left(255),
        Description = text[1],
        Priority = 'High',
        Status = 'Not Started',
        ActivityDate = System.today()
      );
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'VisitManagerAlertQueueable: task failed for ' + visit.Id + ': ' + e.getMessage());
    }
  }

  private static void sendBell(Visit_Form__c visit, User rep, List<String> text) {
    try {
      CustomNotificationType type = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = :NOTIFICATION_TYPE_NAME
        LIMIT 1
      ];
      Messaging.CustomNotification notification = new Messaging.CustomNotification();
      notification.setNotificationTypeId(type.Id);
      notification.setTargetId(visit.Id);
      notification.setTitle(text[2]);
      notification.setBody(text[3]);
      notification.send(new Set<String>{ String.valueOf(rep.ManagerId) });
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'VisitManagerAlertQueueable: bell failed for ' + visit.Id + ': ' + e.getMessage());
    }
  }

  private static void sendEmail(Visit_Form__c visit, User rep, List<String> text) {
    try {
      if (String.isBlank(rep.Manager.Email)) {
        return;
      }
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setToAddresses(new List<String>{ rep.Manager.Email });
      email.setSubject(text[4]);
      email.setPlainTextBody(text[5]);
      email.setSaveAsActivity(false);
      Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'VisitManagerAlertQueueable: email failed for ' + visit.Id + ': ' + e.getMessage());
    }
  }
}