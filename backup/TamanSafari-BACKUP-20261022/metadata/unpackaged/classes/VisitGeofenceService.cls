/**
 * @description Resolves a visit target's coordinates, pins unlocated targets, and evaluates the geofence on the
 *              server (field-visit-core design D2 and D7, spec visit-geofence). The distance is the smallest
 *              Haversine distance to any resolved coordinate, so the rep only has to be near one of the
 *              target's locations. The client never computes distance.
 */
public with sharing class VisitGeofenceService {
  /** Target type stored on Visit_Form__c for an Account target. */
  public static final String TARGET_TYPE_ACCOUNT = 'Account_Contact';
  /** Target type stored on Visit_Form__c for a Lead target. */
  public static final String TARGET_TYPE_LEAD = 'Lead';
  /** Location source written when a rep pins an unlocated target. */
  public static final String LOCATION_SOURCE_REP_PINNED = 'Rep Pinned';
  /** Exception reasons a rep may give for checking in outside the geofence. */
  public static final Set<String> EXCEPTION_REASONS = new Set<String>{
    'Weak GPS / Indoor Tower',
    'Met at External Cafe/Restaurant',
    'Different Branch/Building'
  };

  /** @description One resolved coordinate of a target. */
  public class VisitGeoPoint {
    public Double latitude;
    public Double longitude;
  }

  /** @description An Account or Lead target with every coordinate source resolved. */
  public class VisitTarget {
    public Id targetId;
    public Id accountId;
    public Id leadId;
    public Boolean isAccount;
    public String name;
    public String address;
    /** Location_Source__c on the target. Null when the target has no pin. */
    public String locationSource;
    /** Snapshot for Is_Target_Rep_Pinned__c: the target's location came from a rep pin. */
    public Boolean isRepPinned;
    public List<VisitGeoPoint> coordinates = new List<VisitGeoPoint>();
    public Boolean isLocationLocked = true;
    public String geocodedAddress;

    /** @return True when at least one coordinate source resolved. */
    public Boolean hasCoordinates() {
      return !coordinates.isEmpty();
    }

    /** @return Target type as stored on Visit_Form__c. */
    public String targetType() {
      return isAccount ? TARGET_TYPE_ACCOUNT : TARGET_TYPE_LEAD;
    }
  }

  /** @description Server-computed geofence result. Check-in and the preview both use it. */
  public class GeofenceResult {
    /** Smallest distance from the rep's reading to any target coordinate, in metres. */
    public Decimal distanceM;
    /** True when distanceM is within the configured radius. */
    public Boolean inside;
    public Decimal radiusM;
    public Boolean allowOutsideCheckIn;
  }

  /**
   * @description Loads a target and every coordinate source it has: Account billing and shipping geocodes or the
   *              Lead geocode, plus any rep pin. The query runs WITH USER_MODE, so a target the user cannot read
   *              looks the same as a missing one.
   * @param targetId Account or Lead Id.
   * @return The resolved target.
   * @throws AuraHandledException If the Id is blank, is not an Account or Lead, or the record is not visible to the user.
   */
  public static VisitTarget loadTarget(Id targetId) {
    if (targetId == null) {
      throw new AuraHandledException(System.Label.Visit_Err_Target_Not_Found);
    }

    VisitTarget target = new VisitTarget();
    target.targetId = targetId;
    Schema.SObjectType objectType = targetId.getSObjectType();
    Boolean hasStandardGeocode = false;

    if (objectType == Account.SObjectType) {
      List<Account> rows = [
        SELECT
          Id,
          Name,
          BillingStreet,
          BillingCity,
          BillingState,
          BillingPostalCode,
          BillingCountry,
          BillingLatitude,
          BillingLongitude,
          ShippingLatitude,
          ShippingLongitude,
          Visit_Pin_Location__c,
          Location_Source__c,
          Is_Location_Locked__c,
          Geocoded_Address__c
        FROM Account
        WHERE Id = :targetId
        WITH USER_MODE
        LIMIT 1
      ];
      if (rows.isEmpty()) {
        throw new AuraHandledException(System.Label.Visit_Err_Target_Not_Found);
      }
      Account record = rows[0];
      hasStandardGeocode = record.BillingLatitude != null && record.BillingLongitude != null;
      target.isAccount = true;
      target.accountId = record.Id;
      target.name = record.Name;
      target.locationSource = record.Location_Source__c;
      target.isLocationLocked = record.Is_Location_Locked__c != null ? record.Is_Location_Locked__c : true;
      target.geocodedAddress = record.Geocoded_Address__c;
      target.address = formatAddress(
        record.BillingStreet,
        record.BillingCity,
        record.BillingState,
        record.BillingPostalCode,
        record.BillingCountry
      );
      addCoordinate(target, record.BillingLatitude, record.BillingLongitude);
      addCoordinate(target, record.ShippingLatitude, record.ShippingLongitude);
      addPin(target, record.Visit_Pin_Location__c);
    } else if (objectType == Lead.SObjectType) {
      List<Lead> rows = [
        SELECT
          Id,
          Name,
          Street,
          City,
          State,
          PostalCode,
          Country,
          Latitude,
          Longitude,
          Visit_Pin_Location__c,
          Location_Source__c,
          Is_Location_Locked__c,
          Geocoded_Address__c
        FROM Lead
        WHERE Id = :targetId
        WITH USER_MODE
        LIMIT 1
      ];
      if (rows.isEmpty()) {
        throw new AuraHandledException(System.Label.Visit_Err_Target_Not_Found);
      }
      Lead record = rows[0];
      target.isAccount = false;
      target.leadId = record.Id;
      target.name = record.Name;
      target.locationSource = record.Location_Source__c;
      target.isLocationLocked = record.Is_Location_Locked__c != null ? record.Is_Location_Locked__c : true;
      target.geocodedAddress = record.Geocoded_Address__c;
      target.address = formatAddress(
        record.Street,
        record.City,
        record.State,
        record.PostalCode,
        record.Country
      );
      hasStandardGeocode = record.Latitude != null && record.Longitude != null;
      addCoordinate(target, record.Latitude, record.Longitude);
      addPin(target, record.Visit_Pin_Location__c);
    } else {
      throw new AuraHandledException(System.Label.Visit_Err_Target_Not_Found);
    }

    Boolean needsInitialGeocode = !hasStandardGeocode && !target.hasCoordinates() && String.isNotBlank(target.address);
    Boolean addressChangedWhileUnlocked = !hasStandardGeocode && !target.isLocationLocked && String.isNotBlank(target.address) && (target.address != target.geocodedAddress);

    if (needsInitialGeocode || addressChangedWhileUnlocked) {
      GeoapifyService.GeocodeResult geoResult = GeoapifyService.geocodeAddress(target.address);
      if (geoResult != null && geoResult.latitude != null && geoResult.longitude != null) {
        target.coordinates.clear();
        addCoordinate(target, geoResult.latitude, geoResult.longitude);
        target.locationSource = 'Located';
        target.isRepPinned = false;
        target.geocodedAddress = target.address;

        if (target.isAccount) {
          Database.SaveResult sr = Database.update(
            new Account(
              Id = target.accountId,
              Visit_Pin_Location__Latitude__s = geoResult.latitude,
              Visit_Pin_Location__Longitude__s = geoResult.longitude,
              Location_Source__c = 'Located',
              Geocoded_Address__c = target.address.left(255)
            ),
            false
          );
          if (!sr.isSuccess()) {
            System.debug(LoggingLevel.WARN, 'Failed to update Account geocode: ' + sr.getErrors());
          }
        } else {
          Database.SaveResult sr = Database.update(
            new Lead(
              Id = target.leadId,
              Visit_Pin_Location__Latitude__s = geoResult.latitude,
              Visit_Pin_Location__Longitude__s = geoResult.longitude,
              Location_Source__c = 'Located',
              Geocoded_Address__c = target.address.left(255)
            ),
            false
          );
          if (!sr.isSuccess()) {
            System.debug(LoggingLevel.WARN, 'Failed to update Lead geocode: ' + sr.getErrors());
          }
        }
      }
    }

    target.isRepPinned = target.locationSource == LOCATION_SOURCE_REP_PINNED;
    return target;
  }

  /**
   * @description Updates the location lock state on a target (Account or Lead).
   *              If unlocked (isLocked == false) and the target has an address,
   *              it immediately re-geocodes via Geoapify and updates the coordinates.
   * @param targetId Account or Lead Id.
   * @param isLocked True to lock location, false to unlock.
   * @return Updated VisitTarget.
   */
  public static VisitTarget updateLocationLock(Id targetId, Boolean isLocked) {
    if (targetId == null) {
      throw new AuraHandledException(System.Label.Visit_Err_Target_Not_Found);
    }

    Schema.SObjectType objectType = targetId.getSobjectType();
    String address = null;
    String geocodedAddress = null;
    Boolean hasStandardGeocode = false;

    if (objectType == Account.SObjectType) {
      List<Account> rows = [
        SELECT
          BillingStreet,
          BillingCity,
          BillingState,
          BillingPostalCode,
          BillingCountry,
          BillingLatitude,
          BillingLongitude,
          Geocoded_Address__c
        FROM Account
        WHERE Id = :targetId
        WITH USER_MODE
        LIMIT 1
      ];
      if (!rows.isEmpty()) {
        Account a = rows[0];
        hasStandardGeocode = a.BillingLatitude != null && a.BillingLongitude != null;
        geocodedAddress = a.Geocoded_Address__c;
        address = formatAddress(a.BillingStreet, a.BillingCity, a.BillingState, a.BillingPostalCode, a.BillingCountry);
      }
    } else if (objectType == Lead.SObjectType) {
      List<Lead> rows = [
        SELECT
          Street,
          City,
          State,
          PostalCode,
          Country,
          Latitude,
          Longitude,
          Geocoded_Address__c
        FROM Lead
        WHERE Id = :targetId
        WITH USER_MODE
        LIMIT 1
      ];
      if (!rows.isEmpty()) {
        Lead l = rows[0];
        hasStandardGeocode = l.Latitude != null && l.Longitude != null;
        geocodedAddress = l.Geocoded_Address__c;
        address = formatAddress(l.Street, l.City, l.State, l.PostalCode, l.Country);
      }
    }

    // Callout MUST be performed BEFORE any DML to prevent CalloutException (uncommitted work pending)
    Boolean needsGeocode = !isLocked && !hasStandardGeocode && String.isNotBlank(address);
    GeoapifyService.GeocodeResult geoResult = null;
    if (needsGeocode) {
      geoResult = GeoapifyService.geocodeAddress(address);
    }

    // Perform DML after Callout - keep Is_Location_Locked__c = true so default is always locked
    if (objectType == Account.SObjectType) {
      Account accToUpdate = new Account(Id = targetId, Is_Location_Locked__c = true);
      if (geoResult != null && geoResult.latitude != null && geoResult.longitude != null) {
        accToUpdate.Visit_Pin_Location__Latitude__s = geoResult.latitude;
        accToUpdate.Visit_Pin_Location__Longitude__s = geoResult.longitude;
        accToUpdate.Location_Source__c = 'Located';
        accToUpdate.Geocoded_Address__c = address.left(255);
      }
      Database.update(accToUpdate, false);
    } else if (objectType == Lead.SObjectType) {
      Lead leadToUpdate = new Lead(Id = targetId, Is_Location_Locked__c = true);
      if (geoResult != null && geoResult.latitude != null && geoResult.longitude != null) {
        leadToUpdate.Visit_Pin_Location__Latitude__s = geoResult.latitude;
        leadToUpdate.Visit_Pin_Location__Longitude__s = geoResult.longitude;
        leadToUpdate.Location_Source__c = 'Located';
        leadToUpdate.Geocoded_Address__c = address.left(255);
      }
      Database.update(leadToUpdate, false);
    }

    VisitTarget target = loadTarget(targetId);
    target.isLocationLocked = isLocked;
    return target;
  }

  public static String formatAddress(String street, String city, String state, String postalCode, String country) {
    List<String> parts = new List<String>();
    if (String.isNotBlank(street)) parts.add(street.trim());
    if (String.isNotBlank(city)) parts.add(city.trim());
    if (String.isNotBlank(state)) parts.add(state.trim());
    if (String.isNotBlank(postalCode)) parts.add(postalCode.trim());
    if (String.isNotBlank(country)) parts.add(country.trim());
    return String.join(parts, ', ');
  }

  /**
   * @description Evaluates the rep's raw reading against the target's coordinates. The distance is the minimum
   *              over all resolved coordinates. The result is inside when the distance is within the configured radius.
   * @param target Target from loadTarget. Must have coordinates.
   * @param lat Rep latitude from the device.
   * @param lng Rep longitude from the device.
   * @return Server-computed geofence result.
   * @throws AuraHandledException If the target has no coordinates or the reading is missing.
   */
  public static GeofenceResult evaluate(VisitTarget target, Double lat, Double lng) {
    if (!target.hasCoordinates()) {
      throw new AuraHandledException(System.Label.Visit_Err_Target_No_Location);
    }

    Decimal nearest = null;
    for (VisitGeoPoint point : target.coordinates) {
      Decimal distance = GeoUtil.haversine(lat, lng, point.latitude, point.longitude);
      if (distance != null && (nearest == null || distance < nearest)) {
        nearest = distance;
      }
    }
    if (nearest == null) {
      throw new AuraHandledException(System.Label.Visit_Err_Location_Required);
    }

    GeofenceResult result = new GeofenceResult();
    result.distanceM = nearest;
    result.radiusM = FieldSalesConfig.getMaxGeofenceRadiusM();
    result.allowOutsideCheckIn = FieldSalesConfig.isAllowOutsideGeofenceCheckIn();
    result.inside = nearest <= result.radiusM;
    return result;
  }

  /**
   * @description Pins the rep's current location on a target that has no coordinates yet. A located target,
   *              including one already pinned, cannot be pinned again. Managers move pins from the record page.
   *              Reps have read-only FLS on the pin fields, so the write runs in SYSTEM_MODE after loadTarget has
   *              confirmed the user can read the record.
   * @param target Target from loadTarget.
   * @param lat Rep latitude from the device.
   * @param lng Rep longitude from the device.
   * @throws AuraHandledException If the target is already located, the reading is missing, or the update fails.
   */
  public static void pinTarget(VisitTarget target, Double lat, Double lng) {
    if (target.hasCoordinates()) {
      throw new AuraHandledException(System.Label.Visit_Err_Target_Already_Located);
    }
    if (lat == null || lng == null) {
      throw new AuraHandledException(System.Label.Visit_Err_Location_Required);
    }

    // Geolocation compound fields are written through their latitude and longitude components.
    SObject record;
    if (target.isAccount) {
      record = new Account(
        Id = target.accountId,
        Visit_Pin_Location__Latitude__s = lat,
        Visit_Pin_Location__Longitude__s = lng,
        Location_Source__c = LOCATION_SOURCE_REP_PINNED,
        Geocoded_Address__c = target.address != null ? target.address.left(255) : null
      );
    } else {
      record = new Lead(
        Id = target.leadId,
        Visit_Pin_Location__Latitude__s = lat,
        Visit_Pin_Location__Longitude__s = lng,
        Location_Source__c = LOCATION_SOURCE_REP_PINNED,
        Geocoded_Address__c = target.address != null ? target.address.left(255) : null
      );
    }

    List<Database.SaveResult> results = Database.update(
      new List<SObject>{ record },
      false,
      AccessLevel.SYSTEM_MODE
    );
    if (!results[0].isSuccess()) {
      throw new AuraHandledException(results[0].getErrors()[0].getMessage());
    }
  }

  /** Adds a coordinate when both parts are present. Standard geocodes and Location components are Decimal. */
  private static void addCoordinate(VisitTarget target, Decimal latitude, Decimal longitude) {
    if (latitude == null || longitude == null) {
      return;
    }
    VisitGeoPoint point = new VisitGeoPoint();
    point.latitude = latitude.doubleValue();
    point.longitude = longitude.doubleValue();
    target.coordinates.add(point);
  }

  /** Adds the rep pin, if one is set. */
  private static void addPin(VisitTarget target, Location pin) {
    if (pin != null) {
      addCoordinate(target, pin.getLatitude(), pin.getLongitude());
    }
  }
}