/**
 * @description Queueable Apex that executes Geoapify forward geocoding in the background
 *              when an Account or Lead address is inserted or updated.
 */
public with sharing class GeocodeAddressQueueable implements Queueable, Database.AllowsCallouts {
  private Set<Id> accountIds;
  private Set<Id> leadIds;

  public GeocodeAddressQueueable(Set<Id> accountIds, Set<Id> leadIds) {
    this.accountIds = accountIds != null ? accountIds : new Set<Id>();
    this.leadIds = leadIds != null ? leadIds : new Set<Id>();
  }

  public void execute(QueueableContext context) {
    TargetAddressGeocodeHandler.isExecutingGeocode = true;

    if (!accountIds.isEmpty()) {
      geocodeAccounts(accountIds);
    }
    if (!leadIds.isEmpty()) {
      geocodeLeads(leadIds);
    }
  }

  private void geocodeAccounts(Set<Id> accIds) {
    List<Account> accounts = [
      SELECT
        Id,
        BillingStreet,
        BillingCity,
        BillingState,
        BillingPostalCode,
        BillingCountry,
        BillingLatitude,
        BillingLongitude,
        Is_Location_Locked__c,
        Visit_Pin_Location__c
      FROM Account
      WHERE Id IN :accIds
      WITH SYSTEM_MODE
    ];

    List<Account> toUpdate = new List<Account>();
    for (Account acc : accounts) {
      if (acc.BillingLatitude != null && acc.BillingLongitude != null) {
        continue;
      }
      String addressText = VisitGeofenceService.formatAddress(
        acc.BillingStreet,
        acc.BillingCity,
        acc.BillingState,
        acc.BillingPostalCode,
        acc.BillingCountry
      );

      if (String.isNotBlank(addressText)) {
        GeoapifyService.GeocodeResult res = GeoapifyService.geocodeAddress(addressText);
        if (res != null && res.latitude != null && res.longitude != null) {
          toUpdate.add(new Account(
            Id = acc.Id,
            Visit_Pin_Location__Latitude__s = res.latitude,
            Visit_Pin_Location__Longitude__s = res.longitude,
            Location_Source__c = 'Located',
            Geocoded_Address__c = addressText.left(255)
          ));
        }
      }
    }

    if (!toUpdate.isEmpty()) {
      Database.update(toUpdate, false, AccessLevel.SYSTEM_MODE);
    }
  }

  private void geocodeLeads(Set<Id> ldIds) {
    List<Lead> leads = [
      SELECT
        Id,
        Street,
        City,
        State,
        PostalCode,
        Country,
        Latitude,
        Longitude,
        Is_Location_Locked__c,
        Visit_Pin_Location__c
      FROM Lead
      WHERE Id IN :ldIds
      WITH SYSTEM_MODE
    ];

    List<Lead> toUpdate = new List<Lead>();
    for (Lead ld : leads) {
      if (ld.Latitude != null && ld.Longitude != null) {
        continue;
      }
      String addressText = VisitGeofenceService.formatAddress(
        ld.Street,
        ld.City,
        ld.State,
        ld.PostalCode,
        ld.Country
      );

      if (String.isNotBlank(addressText)) {
        GeoapifyService.GeocodeResult res = GeoapifyService.geocodeAddress(addressText);
        if (res != null && res.latitude != null && res.longitude != null) {
          toUpdate.add(new Lead(
            Id = ld.Id,
            Visit_Pin_Location__Latitude__s = res.latitude,
            Visit_Pin_Location__Longitude__s = res.longitude,
            Location_Source__c = 'Located',
            Geocoded_Address__c = addressText.left(255)
          ));
        }
      }
    }

    if (!toUpdate.isEmpty()) {
      Database.update(toUpdate, false, AccessLevel.SYSTEM_MODE);
    }
  }
}