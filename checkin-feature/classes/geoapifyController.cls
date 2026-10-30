//https://api.geoapify.com/v1/routing?waypoints=-6.200769449999999,106.79850424028051|-6.18769,106.82375407348503&mode=drive&apiKey=YOUR_API_KEY

public without sharing class geoapifyController {
  public class listRoute {
    @AuraEnabled
    public string lat { get; set; }
    @AuraEnabled
    public string lon { get; set; }
    @AuraEnabled
    public string mode { get; set; }
  }

  @AuraEnabled
  public static string getRoute(List<listRoute> waypoints, String mode) {
    try {
      List<String> waypointStrings = new List<String>();
      for (listRoute r : waypoints) {
        waypointStrings.add(r.lat + ',' + r.lon);
      }

      String baseUrl = 'https://api.geoapify.com/v1/routing?waypoints=';
      baseUrl += String.join(waypointStrings, '|');

      baseUrl +=
        '&mode=' +
        mode +
        '&apiKey=' +
        System.label.GeoLocation_API_Key;
      System.debug('baseUrl: ' + baseUrl);
      Http httpObject = new Http();
      HttpRequest request = new HttpRequest();
      request.setEndpoint(baseUrl);
      request.setMethod('GET');
      HttpResponse response = httpObject.send(request);
      String responseBody = response.getBody();

      System.debug('responseBody: ' + responseBody);
      return responseBody;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  public static string GeoapifyReverse(String latitude, String longitude) {
    try {
      String Address;
      String Street;

      String Geo_API_KEY = System.Label.GeoLocation_API_Key;
      String Geo_URL = System.Label.GeoLocation_URL;
      String Formatted_URL =
        Geo_URL +
        'lat=' +
        Latitude +
        '&lon=' +
        Longitude +
        '&apiKey=' +
        Geo_API_KEY;

      Http http = new Http();
      Httprequest req = new Httprequest();

      req.setEndpoint(Formatted_URL);
      req.setMethod('GET');

      HttpResponse res = http.send(req);
      Object response = JSON.deserializeUntyped(res.getBody());
      System.debug('Data Response' + response);

      Map<String, Object> DataJSON = (Map<String, Object>) response;
      String Serialize_features = JSON.serialize(DataJSON.get('features'));
      List<Object> DataJSON_features = (List<Object>) JSON.deserializeUntyped(
        Serialize_features
      );

      for (Object itemFeatures : DataJSON_features) {
        Map<String, Object> itemFeaturesJSON = (Map<String, Object>) itemFeatures;
        System.debug('Properties : ' + itemFeaturesJSON.get('properties'));

        Map<String, Object> DataJSON_Properties = (Map<String, Object>) itemFeaturesJSON.get(
          'properties'
        );
        System.debug('Properties : ' + DataJSON_Properties.get('formatted'));
        Address = String.valueOf(DataJSON_Properties.get('formatted'));
        Street = String.valueOf(DataJSON_Properties.get('address_line1'));
      }
      // return Street+', '+Address;
      return Address;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}