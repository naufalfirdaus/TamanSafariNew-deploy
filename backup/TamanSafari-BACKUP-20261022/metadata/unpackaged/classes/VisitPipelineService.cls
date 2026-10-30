/**
 * @description Bridges a completed field visit into Salesforce activity and pipeline records (field-visit-core design D1 and D5,
 *              spec visit-pipeline-bridge): Lead conversion, new or updated Opportunities, and the Event logged at check-out.
 *              Writes run with the rep's record access (AccessLevel.USER_MODE), so an action the rep could not do by
 *              hand fails with a clear message. Lead conversion uses the platform's own conversion, which also runs as the rep.
 */
public with sharing class VisitPipelineService {
  public static final String ACTION_NONE = 'None';
  public static final String ACTION_CONVERT_LEAD = 'Convert Lead';
  public static final String ACTION_CREATE_OPPORTUNITY = 'Create Opportunity';
  public static final String ACTION_UPDATE_OPPORTUNITY = 'Update Opportunity';

  private static final List<String> MONTHS = new List<String>{
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  };

  /** @description Records created or linked by a Lead conversion. */
  public class ConvertResult {
    public Id accountId;
    public Id contactId;
    public Id opportunityId;
  }

  /**
   * @description Checks that the visit's pipeline action can run on this visit. It reads only the visit and writes nothing.
   * @param visit Visit loaded with VISIT_FIELDS.
   * @return The error message, or null when the action is allowed or no action is selected.
   */
  public static String actionError(Visit_Form__c visit) {
    String action = visit.Pipeline_Action__c == null ? ACTION_NONE : visit.Pipeline_Action__c;
    if (action == ACTION_CONVERT_LEAD) {
      Boolean isUnconvertedLead =
        visit.Target_Type__c == VisitQualificationService.TARGET_LEAD &&
        visit.Lead__c != null &&
        visit.Account__c == null;
      return isUnconvertedLead ? null : System.Label.Visit_Err_Pipeline_Convert_Needs_Lead;
    }
    if (action == ACTION_CREATE_OPPORTUNITY) {
      if (visit.Target_Type__c != VisitQualificationService.TARGET_ACCOUNT || visit.Account__c == null) {
        return System.Label.Visit_Err_Pipeline_Create_Needs_Account;
      }
      if (visit.Opportunity__c != null) {
        return System.Label.Visit_Err_Pipeline_Already_Linked;
      }
      return visit.Target_Event_Date__c == null ? System.Label.Visit_Err_Event_Date_Required : null;
    }
    if (action == ACTION_UPDATE_OPPORTUNITY) {
      return visit.Opportunity__c == null ? System.Label.Visit_Err_Pipeline_Update_Needs_Opp : null;
    }
    return null;
  }

  /**
   * @description Converts the visit's Lead into an Account, a Contact and an Opportunity. A duplicate-rule or validation
   *              failure is raised as an error, and the caller rolls the whole check-out back.
   * @param visit Visit whose Lead__c is converted.
   * @return The Ids of the new Account, Contact and Opportunity.
   * @throws AuraHandledException With the platform's message when the conversion fails.
   */
  public static ConvertResult convertLead(Visit_Form__c visit) {
    // Converted statuses in sort order. The first one the platform accepts is used. In this org "Closed - Converted"
    // is refused for the Lead record type and "Converted" is accepted, so a fixed choice would fail here.
    List<LeadStatus> convertedStatuses = [
      SELECT MasterLabel
      FROM LeadStatus
      WHERE IsConverted = true
      ORDER BY SortOrder
    ];
    for (LeadStatus status : convertedStatuses) {
      Database.LeadConvert conversion = new Database.LeadConvert();
      conversion.setLeadId(visit.Lead__c);
      conversion.setConvertedStatus(status.MasterLabel);
      conversion.setDoNotCreateOpportunity(false);
      Database.LeadConvertResult result = Database.convertLead(conversion, false);
      if (result.isSuccess()) {
        ConvertResult out = new ConvertResult();
        out.accountId = result.getAccountId();
        out.contactId = result.getContactId();
        out.opportunityId = result.getOpportunityId();
        return out;
      }
      // Skip only statuses the org does not allow. Any other failure, such as a duplicate-rule block, is reported as is.
      Database.Error err = result.getErrors()[0];
      if (err.getStatusCode() != StatusCode.INVALID_STATUS) {
        throw new AuraHandledException(err.getMessage());
      }
    }
    throw new AuraHandledException(System.Label.Visit_Err_Lead_Status_Missing);
  }

  /**
   * @description Sets the visit's qualification on the Opportunity created by a Lead conversion: name, stage, amount,
   *              close date, and the BANT and package fields.
   * @param opportunityId Converted Opportunity.
   * @param visit Visit with the qualification values.
   * @param accountId Converted Account, used for the name.
   */
  public static void qualifyConvertedOpportunity(Id opportunityId, Visit_Form__c visit, Id accountId) {
    Account account = [SELECT Name FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1];
    Opportunity opp = new Opportunity(
      Id = opportunityId,
      Name = opportunityName(
        account.Name,
        visit.Event_Type__c,
        visit.Preferred_Park_Location__c,
        visit.Target_Event_Date__c
      ),
      StageName = VisitQualificationService.STAGE_QUALIFICATION,
      Amount = visit.Total_Estimated_Budget__c,
      Interested_Packages__c = visit.Interested_Packages__c,
      Estimated_Pax__c = visit.Estimated_Pax__c,
      Preferred_Park_Location__c = visit.Preferred_Park_Location__c,
      Event_Type__c = visit.Event_Type__c
    );
    if (visit.Target_Event_Date__c != null) {
      opp.CloseDate = visit.Target_Event_Date__c;
    }
    updateUserMode(new List<SObject>{ opp });
  }

  /**
   * @description Creates an Opportunity on the visit's Account at stage Qualification, with the visit's amount, close date
   *              and package values, and adds the visit's Contact as a primary contact role.
   * @param visit Visit loaded with VISIT_FIELDS. Must have a target event date and a contact.
   * @return The new Opportunity Id.
   */
  public static Id createOpportunity(Visit_Form__c visit) {
    Account account = [SELECT Name FROM Account WHERE Id = :visit.Account__c WITH USER_MODE LIMIT 1];
    Opportunity opp = new Opportunity(
      Name = opportunityName(
        account.Name,
        visit.Event_Type__c,
        visit.Preferred_Park_Location__c,
        visit.Target_Event_Date__c
      ),
      AccountId = visit.Account__c,
      StageName = VisitQualificationService.STAGE_QUALIFICATION,
      CloseDate = visit.Target_Event_Date__c,
      Amount = visit.Total_Estimated_Budget__c,
      Interested_Packages__c = visit.Interested_Packages__c,
      Estimated_Pax__c = visit.Estimated_Pax__c,
      Preferred_Park_Location__c = visit.Preferred_Park_Location__c,
      Event_Type__c = visit.Event_Type__c
    );
    insertUserMode(new List<SObject>{ opp });

    OpportunityContactRole role = new OpportunityContactRole(
      OpportunityId = opp.Id,
      ContactId = visit.Contact__c,
      IsPrimary = true
    );
    insertUserMode(new List<SObject>{ role });
    return opp.Id;
  }

  /**
   * @description Updates the linked Opportunity's stage, amount and close date from the check-out pipeline payload.
   *              A field missing from the payload is left unchanged.
   * @param visit Visit with Opportunity__c set.
   * @param pipeline Parsed payload with optional opportunityStage, amount and closeDate.
   * @throws AuraHandledException If the amount is negative or a save fails.
   */
  public static void updateOpportunity(Visit_Form__c visit, Map<String, Object> pipeline) {
    Opportunity opp = new Opportunity(Id = visit.Opportunity__c);
    if (pipeline.get('opportunityStage') != null) {
      opp.StageName = String.valueOf(pipeline.get('opportunityStage'));
    }
    if (pipeline.get('amount') != null) {
      Decimal amount = Decimal.valueOf(String.valueOf(pipeline.get('amount')));
      String error = VisitQualificationService.valueError('Total_Estimated_Budget__c', amount, null);
      if (error != null) {
        throw new AuraHandledException(error);
      }
      opp.Amount = amount;
    }
    if (pipeline.get('closeDate') != null) {
      opp.CloseDate = Date.valueOf(String.valueOf(pipeline.get('closeDate')));
    }
    updateUserMode(new List<SObject>{ opp });
  }

  /**
   * @description Logs the visit as an Event owned by the rep. Start is the server check-in time, end is the check-out
   *              time, subject is "Field Visit: <purpose>", and description is the meeting summary.
   * @param visit Visit with check-in time, purpose and summary.
   * @param whoId Contact or Lead the visit was with.
   * @param whatId Opportunity when there is one, otherwise the Account.
   * @param checkOutTime Server check-out time.
   * @return The new Event Id.
   */
  public static Id logEvent(Visit_Form__c visit, Id whoId, Id whatId, Datetime checkOutTime) {
    Event activity = new Event(
      Subject = 'Field Visit: ' + visit.Visit_Purpose__c,
      Description = visit.Meeting_Summary__c,
      StartDateTime = visit.Check_In_Time__c,
      EndDateTime = checkOutTime,
      WhoId = whoId,
      WhatId = whatId
    );
    insertUserMode(new List<SObject>{ activity });
    return activity.Id;
  }

  /**
   * @description Builds the Opportunity name "<Account> - <Event Type> - <Park> - <MMM yyyy of target event date>".
   *              Months use fixed English abbreviations, so the name does not depend on the user's locale. The result is
   *              cut to the 120-character name limit.
   * @return The Opportunity name.
   */
  public static String opportunityName(String accountName, String eventType, String park, Date targetEventDate) {
    String eventPart = String.isBlank(eventType) ? 'Event' : eventType;
    String parkPart = String.isBlank(park) ? 'Undecided' : park;
    String datePart = targetEventDate == null
      ? ''
      : ' - ' + MONTHS[targetEventDate.month() - 1] + ' ' + String.valueOf(targetEventDate.year());
    return (accountName + ' - ' + eventPart + ' - ' + parkPart + datePart).left(120);
  }

  private static void insertUserMode(List<SObject> records) {
    List<Database.SaveResult> results = Database.insert(records, false, AccessLevel.USER_MODE);
    if (!results[0].isSuccess()) {
      throw new AuraHandledException(results[0].getErrors()[0].getMessage());
    }
  }

  private static void updateUserMode(List<SObject> records) {
    List<Database.SaveResult> results = Database.update(records, false, AccessLevel.USER_MODE);
    if (!results[0].isSuccess()) {
      throw new AuraHandledException(results[0].getErrors()[0].getMessage());
    }
  }
}