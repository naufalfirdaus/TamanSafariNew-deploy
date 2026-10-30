/**
 * @description Integration service for Geoapify API (Geocoding & Reverse Geocoding).
 *              Converts postal/street address to coordinates (Forward Geocoding)
 *              and coordinates to human-readable address (Reverse Geocoding).
 */
public with sharing class GeoapifyService {
  @TestVisible
  private static final String API_KEY = '41a37272ac3c4c0b83b23eeb588262f2';
  private static final String GEOCODE_SEARCH_URL = 'https://api.geoapify.com/v1/geocode/search';
  private static final String GEOCODE_REVERSE_URL = 'https://api.geoapify.com/v1/geocode/reverse';

  public class GeocodeResult {
    public Double latitude;
    public Double longitude;
    public String formattedAddress;
  }

  /**
   * @description Converts an address string into latitude & longitude coordinates.
   * @param addressText Formatted address or street address.
   * @return GeocodeResult containing latitude, longitude, and formatted address, or null if unresolved.
   */
  public static GeocodeResult geocodeAddress(String addressText) {
    if (String.isBlank(addressText)) {
      return null;
    }

    try {
      String endpoint = GEOCODE_SEARCH_URL +
        '?text=' + EncodingUtil.urlEncode(addressText, 'UTF-8') +
        '&format=json&limit=1&apiKey=' + API_KEY;

      HttpRequest req = new HttpRequest();
      req.setEndpoint(endpoint);
      req.setMethod('GET');
      req.setTimeout(25000);

      Http http = new Http();
      HttpResponse res = http.send(req);

      if (res.getStatusCode() == 200) {
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> results = (List<Object>) root.get('results');
        if (results != null && !results.isEmpty()) {
          Map<String, Object> first = (Map<String, Object>) results[0];
          GeocodeResult result = new GeocodeResult();
          if (first.get('lat') != null) {
            result.latitude = ((Decimal) first.get('lat')).doubleValue();
          }
          if (first.get('lon') != null) {
            result.longitude = ((Decimal) first.get('lon')).doubleValue();
          }
          result.formattedAddress = (String) first.get('formatted');
          return result;
        }
      } else {
        System.debug(LoggingLevel.WARN, 'Geoapify geocodeAddress failed with status ' + res.getStatusCode() + ': ' + res.getBody());
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'Geoapify geocodeAddress exception: ' + e.getMessage());
    }
    return null;
  }

  public static String reverseGeocode(Decimal lat, Decimal lon) {
    if (lat == null || lon == null) {
      return null;
    }
    return reverseGeocode(lat.doubleValue(), lon.doubleValue());
  }

  /**
   * @description Converts GPS coordinates (latitude, longitude) into a human-readable address.
   * @param lat Latitude.
   * @param lon Longitude.
   * @return Formatted address string, or null if unresolved.
   */
  public static String reverseGeocode(Double lat, Double lon) {
    if (lat == null || lon == null) {
      return null;
    }

    try {
      String endpoint = GEOCODE_REVERSE_URL +
        '?lat=' + lat +
        '&lon=' + lon +
        '&format=json&apiKey=' + API_KEY;

      HttpRequest req = new HttpRequest();
      req.setEndpoint(endpoint);
      req.setMethod('GET');
      req.setTimeout(25000);

      Http http = new Http();
      HttpResponse res = http.send(req);

      if (res.getStatusCode() == 200) {
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> results = (List<Object>) root.get('results');
        if (results != null && !results.isEmpty()) {
          Map<String, Object> first = (Map<String, Object>) results[0];
          return (String) first.get('formatted');
        }
      } else {
        System.debug(LoggingLevel.WARN, 'Geoapify reverseGeocode failed with status ' + res.getStatusCode() + ': ' + res.getBody());
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'Geoapify reverseGeocode exception: ' + e.getMessage());
    }
    return null;
  }
}