/**
 * @description Qualification rules for field visits (field-visit-core tasks 6.1 and 6.2, spec visit-qualification):
 *              contact selection and quick create, open-opportunity lookup with prefill, value validation, and the
 *              check-out prerequisites. Validation methods return a user-facing message or null instead of throwing,
 *              so the rules can be checked without raising an AuraHandledException.
 */
public with sharing class VisitQualificationService {
  /** Opportunity stage used for opportunities created or converted by a field visit. */
  public static final String STAGE_QUALIFICATION = 'Qualification';
  /** Visit target type for an Account visit (design D1). */
  public static final String TARGET_ACCOUNT = 'Account_Contact';
  /** Visit target type for a Lead visit. */
  public static final String TARGET_LEAD = 'Lead';

  /** Draft keys copied from the prior visit when an opportunity is prefilled (visit-qualification prefill). */
  private static final Set<String> PREFILL_KEYS = new Set<String>{
    'estimatedPax',
    'interestedPackages',
    'preferredPark',
    'eventType',
    'budgetPerPax',
    'totalBudget',
    'budgetStatus',
    'picDepartment',
    'decisionRole',
    'finalApproverIdentified',
    'targetEventDate',
    'preferredDayType',
    'bookingUrgency'
  };

  /** @description Result of an opportunity prefill: the prior visit used, if any, and the draft values to show. */
  public class OpportunityPrefill {
    public Id priorVisitId;
    public Map<String, Object> draft = new Map<String, Object>();
  }

  /**
   * @description Lists the Contacts of an Account for the contact picker.
   * @param accountId Account Id.
   * @return Contacts visible to the caller.
   */
  public static List<Contact> getAccountContacts(Id accountId) {
    return [
      SELECT Id, Name, Title, MobilePhone, Email
      FROM Contact
      WHERE AccountId = :accountId
      WITH USER_MODE
      ORDER BY Name
      LIMIT 200
    ];
  }

  /**
   * @description Creates a Contact under an Account from the quick-create form. The caller must own the Account.
   *              Name and mobile number are required.
   * @param accountId Account Id.
   * @param contactJson JSON object with name, mobile, email, department and role.
   * @return The new Contact Id.
   * @throws AuraHandledException If the Account is not owned by the caller, required fields are missing, or the insert fails.
   */
  public static Id quickCreateContact(Id accountId, String contactJson) {
    List<Account> accounts = [SELECT Id, OwnerId FROM Account WHERE Id = :accountId WITH USER_MODE LIMIT 1];
    if (accounts.isEmpty()) {
      throw new AuraHandledException(System.Label.Visit_Err_Target_Not_Found);
    }
    if (accounts[0].OwnerId != UserInfo.getUserId()) {
      throw new AuraHandledException(System.Label.Visit_Err_Account_Not_Owner);
    }

    Map<String, Object> data;
    try {
      data = (Map<String, Object>) JSON.deserializeUntyped(contactJson);
    } catch (Exception e) {
      throw new AuraHandledException(System.Label.Visit_Err_Draft_Invalid);
    }
    String name = text(data.get('name'));
    String mobile = text(data.get('mobile'));
    if (name == null || mobile == null) {
      throw new AuraHandledException(System.Label.Visit_Err_Contact_Required);
    }

    Contact contact = new Contact(
      AccountId = accountId,
      LastName = name.left(80),
      MobilePhone = mobile,
      Email = text(data.get('email')),
      Department = text(data.get('department')),
      Title = text(data.get('role'))
    );
    List<Database.SaveResult> results = Database.insert(new List<Contact>{ contact }, false, AccessLevel.USER_MODE);
    if (!results[0].isSuccess()) {
      throw new AuraHandledException(results[0].getErrors()[0].getMessage());
    }
    return contact.Id;
  }

  /**
   * @description Lists the open opportunities of an Account for the follow-up picker.
   * @param accountId Account Id.
   * @return Open opportunities visible to the caller.
   */
  public static List<Opportunity> getOpenOpportunities(Id accountId) {
    return [
      SELECT Id, Name, StageName, Amount, CloseDate
      FROM Opportunity
      WHERE AccountId = :accountId AND IsClosed = false
      WITH USER_MODE
      ORDER BY CloseDate
      LIMIT 100
    ];
  }

  /**
   * @description Prefills the qualification form for a follow-up opportunity. The most recent completed visit on the
   *              opportunity supplies the BANT values. Where it has no value, or there is no such visit, the
   *              opportunity's amount and close date fill total budget and target event date.
   * @param opportunityId Opportunity Id.
   * @return Prior visit Id (if any) and the draft values to show.
   */
  public static OpportunityPrefill getOpportunityPrefill(Id opportunityId) {
    Opportunity opp = [SELECT Id, Amount, CloseDate FROM Opportunity WHERE Id = :opportunityId WITH USER_MODE LIMIT 1];
    String completed = 'Completed';
    List<Visit_Form__c> priorVisits = Database.query(
      'SELECT ' +
        VisitLifecycleService.VISIT_FIELDS +
        ' FROM Visit_Form__c WHERE Opportunity__c = :opportunityId AND Status__c = :completed' +
        ' WITH USER_MODE ORDER BY Check_Out_Time__c DESC LIMIT 1'
    );

    OpportunityPrefill prefill = new OpportunityPrefill();
    if (!priorVisits.isEmpty()) {
      prefill.priorVisitId = priorVisits[0].Id;
      Map<String, Object> prior = VisitLifecycleService.draftOf(priorVisits[0]);
      for (String key : PREFILL_KEYS) {
        if (prior.get(key) != null) {
          prefill.draft.put(key, prior.get(key));
        }
      }
    }
    if (!prefill.draft.containsKey('totalBudget') && opp.Amount != null) {
      prefill.draft.put('totalBudget', opp.Amount);
    }
    if (!prefill.draft.containsKey('targetEventDate') && opp.CloseDate != null) {
      prefill.draft.put('targetEventDate', opp.CloseDate);
    }
    return prefill;
  }

  /**
   * @description Validates one qualification value. Pax must be a positive whole number, the budget must not be
   *              negative, and the event date must not be before the check-in date. Other fields are not checked here.
   * @param field Visit_Form__c field API name.
   * @param value Converted value, or null (not checked).
   * @param checkInTime Visit check-in time, used for the event-date rule.
   * @return The error message, or null when the value is acceptable.
   */
  public static String valueError(String field, Object value, Datetime checkInTime) {
    if (value == null) {
      return null;
    }
    if (field == 'Estimated_Pax__c') {
      Decimal pax = (Decimal) value;
      Boolean whole = pax.setScale(0, System.RoundingMode.DOWN) == pax;
      return (pax <= 0 || !whole) ? System.Label.Visit_Err_Pax_Invalid : null;
    }
    if (field == 'Total_Estimated_Budget__c') {
      return ((Decimal) value) < 0 ? System.Label.Visit_Err_Budget_Invalid : null;
    }
    if (field == 'Target_Event_Date__c' && checkInTime != null) {
      Date eventDate = (Date) value;
      Date checkInDate = Date.valueOf(checkInTime.format('yyyy-MM-dd', UserInfo.getTimeZone().getID()));
      return eventDate < checkInDate ? System.Label.Visit_Err_Event_Date_Invalid : null;
    }
    return null;
  }

  /**
   * @description Checks that a contact belongs to the visit's Account. The check runs on save, so a rep cannot link
   *              a contact from another Account.
   * @param contactId Contact being linked.
   * @param visit The visit being saved.
   * @return The error message, or null when the contact is acceptable.
   */
  public static String contactError(Id contactId, Visit_Form__c visit) {
    if (contactId == null) {
      return null;
    }
    if (visit.Target_Type__c != TARGET_ACCOUNT || visit.Account__c == null) {
      return System.Label.Visit_Err_Contact_Other_Account;
    }
    List<Contact> rows = [SELECT Id, AccountId FROM Contact WHERE Id = :contactId WITH USER_MODE LIMIT 1];
    if (rows.isEmpty() || rows[0].AccountId != visit.Account__c) {
      return System.Label.Visit_Err_Contact_Other_Account;
    }
    return null;
  }

  /**
   * @description Lists the check-out prerequisites the visit is missing (spec field-visit-lifecycle "Check-out
   *              prerequisites"), then re-checks the stored values. A missing item is named in the message.
   * @param visit Visit loaded with VISIT_FIELDS.
   * @return The error message, or null when check-out may proceed.
   */
  public static String checkOutError(Visit_Form__c visit) {
    List<String> missing = new List<String>();
    if (String.isBlank(visit.Visit_Purpose__c)) {
      missing.add(System.Label.Visit_Item_Purpose);
    }
    if (visit.Target_Type__c == TARGET_ACCOUNT && visit.Contact__c == null) {
      missing.add(System.Label.Visit_Item_Contact);
    }
    if (visit.Photo_Document_Id__c == null) {
      missing.add(System.Label.Visit_Item_Photo);
    }
    if (String.isBlank(visit.Meeting_Summary__c)) {
      missing.add(System.Label.Visit_Item_Summary);
    }
    if (visit.Signature_Document_Id__c == null && visit.Signature_Declined_Reason__c == null) {
      missing.add(System.Label.Visit_Item_Signature);
    }
    if (!missing.isEmpty()) {
      return String.format(System.Label.Visit_Err_Checkout_Missing, new List<String>{ String.join(missing, ', ') });
    }

    String error = valueError('Estimated_Pax__c', visit.Estimated_Pax__c, visit.Check_In_Time__c);
    if (error == null) {
      error = valueError('Total_Estimated_Budget__c', visit.Total_Estimated_Budget__c, visit.Check_In_Time__c);
    }
    if (error == null) {
      error = valueError('Target_Event_Date__c', visit.Target_Event_Date__c, visit.Check_In_Time__c);
    }
    return error;
  }

  /**
   * @description Whether the visit's person met can be reached by phone or email. Reads the Lead for a Lead visit,
   *              or the selected Contact for an Account visit. Call it before any Lead conversion.
   * @param visit Visit loaded with VISIT_FIELDS.
   * @return True when a phone number or email is on record.
   */
  public static Boolean hasReachableContact(Visit_Form__c visit) {
    if (visit.Target_Type__c == TARGET_LEAD) {
      List<Lead> leads = [SELECT Phone, MobilePhone, Email FROM Lead WHERE Id = :visit.Lead__c WITH USER_MODE LIMIT 1];
      return !leads.isEmpty() && hasAnyContact(leads[0].Phone, leads[0].MobilePhone, leads[0].Email);
    }
    if (visit.Contact__c == null) {
      return false;
    }
    List<Contact> contacts = [
      SELECT Phone, MobilePhone, Email
      FROM Contact
      WHERE Id = :visit.Contact__c
      WITH USER_MODE
      LIMIT 1
    ];
    return !contacts.isEmpty() && hasAnyContact(contacts[0].Phone, contacts[0].MobilePhone, contacts[0].Email);
  }

  private static Boolean hasAnyContact(String phone, String mobile, String email) {
    return !String.isBlank(phone) || !String.isBlank(mobile) || !String.isBlank(email);
  }

  /** Trimmed text, or null when blank. */
  private static String text(Object value) {
    if (value == null) {
      return null;
    }
    String result = String.valueOf(value).trim();
    return String.isBlank(result) ? null : result;
  }
}