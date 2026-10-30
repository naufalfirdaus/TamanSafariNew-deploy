/**
 * @description Centralized trigger handler for Account and Lead to automatically
 *              enqueue geocoding when an address is created or updated.
 */
public with sharing class TargetAddressGeocodeHandler {
  public static Boolean isExecutingGeocode = false;

  public static void handleAccountAfterInsert(List<Account> newAccounts) {
    if (isExecutingGeocode) return;
    Set<Id> accountIdsToGeocode = new Set<Id>();
    for (Account acc : newAccounts) {
      if (hasAddress(acc.BillingStreet, acc.BillingCity, acc.BillingPostalCode)) {
        accountIdsToGeocode.add(acc.Id);
      }
    }
    enqueueIfNotEmpty(accountIdsToGeocode, new Set<Id>());
  }

  public static void handleAccountAfterUpdate(List<Account> newAccounts, Map<Id, Account> oldMap) {
    if (isExecutingGeocode) return;
    Set<Id> accountIdsToGeocode = new Set<Id>();
    for (Account acc : newAccounts) {
      Account old = oldMap.get(acc.Id);
      Boolean addressChanged =
        acc.BillingStreet != old.BillingStreet ||
        acc.BillingCity != old.BillingCity ||
        acc.BillingState != old.BillingState ||
        acc.BillingPostalCode != old.BillingPostalCode ||
        acc.BillingCountry != old.BillingCountry;

      if (addressChanged && hasAddress(acc.BillingStreet, acc.BillingCity, acc.BillingPostalCode)) {
        Boolean isLocked = acc.Is_Location_Locked__c == true;
        Boolean hasPin = acc.Visit_Pin_Location__c != null;
        if (!isLocked || !hasPin) {
          accountIdsToGeocode.add(acc.Id);
        }
      }
    }
    enqueueIfNotEmpty(accountIdsToGeocode, new Set<Id>());
  }

  public static void handleLeadAfterInsert(List<Lead> newLeads) {
    if (isExecutingGeocode) return;
    Set<Id> leadIdsToGeocode = new Set<Id>();
    for (Lead ld : newLeads) {
      if (hasAddress(ld.Street, ld.City, ld.PostalCode)) {
        leadIdsToGeocode.add(ld.Id);
      }
    }
    enqueueIfNotEmpty(new Set<Id>(), leadIdsToGeocode);
  }

  public static void handleLeadAfterUpdate(List<Lead> newLeads, Map<Id, Lead> oldMap) {
    if (isExecutingGeocode) return;
    Set<Id> leadIdsToGeocode = new Set<Id>();
    for (Lead ld : newLeads) {
      Lead old = oldMap.get(ld.Id);
      Boolean addressChanged =
        ld.Street != old.Street ||
        ld.City != old.City ||
        ld.State != old.State ||
        ld.PostalCode != old.PostalCode ||
        ld.Country != old.Country;

      if (addressChanged && hasAddress(ld.Street, ld.City, ld.PostalCode)) {
        Boolean isLocked = ld.Is_Location_Locked__c == true;
        Boolean hasPin = ld.Visit_Pin_Location__c != null;
        if (!isLocked || !hasPin) {
          leadIdsToGeocode.add(ld.Id);
        }
      }
    }
    enqueueIfNotEmpty(new Set<Id>(), leadIdsToGeocode);
  }

  private static Boolean hasAddress(String street, String city, String postalCode) {
    return String.isNotBlank(street) || String.isNotBlank(city) || String.isNotBlank(postalCode);
  }

  private static void enqueueIfNotEmpty(Set<Id> accountIds, Set<Id> leadIds) {
    if (accountIds.isEmpty() && leadIds.isEmpty()) return;
    if (System.isQueueable() || System.isBatch() || System.isFuture()) {
      if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) return;
    }
    System.enqueueJob(new GeocodeAddressQueueable(accountIds, leadIds));
  }
}