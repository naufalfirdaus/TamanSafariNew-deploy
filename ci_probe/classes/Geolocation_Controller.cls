public class Geolocation_Controller {
    
    @AuraEnabled
    public static string GeoapifyReverse(String latitude, String longitude){
        try {
            String Address;
            String Street;
            
            String Geo_API_KEY = System.Label.GeoLocation_API_Key;
            String Geo_URL = System.Label.GeoLocation_URL;
            String Formatted_URL = Geo_URL+'lat='+Latitude+'&lon='+Longitude+'&apiKey='+Geo_API_KEY;

            Http http = new Http();
            Httprequest req = new Httprequest();

            req.setEndpoint(Formatted_URL);
            req.setMethod('GET');

            HttpResponse res = http.send(req);
            Object response = JSON.deserializeUntyped(res.getBody());
            System.debug('Data Response'+response);

            Map<String,Object> DataJSON =  (Map<String,Object>) response;
            String Serialize_features = JSON.serialize(DataJSON.get('features'));
            List<Object> DataJSON_features = (List<Object>) JSON.deserializeUntyped(Serialize_features);

            
            for(Object itemFeatures : DataJSON_features){
                Map<String,Object> itemFeaturesJSON = (Map<String,Object>) itemFeatures;
                System.debug('Properties : ' + itemFeaturesJSON.get('properties'));

                Map<String,Object> DataJSON_Properties = (Map<String,Object>) itemFeaturesJSON.get('properties');
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


    @AuraEnabled
    public static string CreateEventCheckIn(String latitude, String longitude, String RecordID, String Address, String ObjectName){
        try {
            String value_Datetime = String.ValueOf(Datetime.now()).replace('T','');
            Datetime datetime_format = Datetime.valueOf(value_Datetime);
            Datetime datetime_subject = Datetime.valueOf(value_Datetime)+(0.04167 * 7);
            
            List<Contact> obj_contact = [SELECT Id, AccountId FROM Contact WHERE Id =:RecordId];
            Set<Id> set_WhatID = new Set<Id>();
            Set<Id> set_WhoID = new Set<Id>();
            String str_whatid;
            String str_whoid;

            if(ObjectName == 'Contact'){
                for(Contact listcontact : obj_contact){
                    set_WhatID.add(listcontact.AccountId);
                    set_WhoID.add(listcontact.Id);
                }
                str_whatid = String.valueOf(set_WhatID).replace('{','').replace('}','');
                str_whoid = String.valueOf(set_WhoID).replace('{','').replace('}','');
            }else if(ObjectName == 'Lead'){

                str_whoid = RecordID;

            }else {

                str_whatid = RecordID;
            }
            
            
            RecordType eventRecordType = [Select Id FROM RecordType Where sObjectType = 'Event' And Name = 'Geolocation'];

            Event createEvent = new Event(
                Subject = 'CheckIn Location at '+datetime_subject,
                WhatId = str_whatid,
                WhoId = str_whoid,
                Check_In_Latitude__c = Decimal.valueOf(latitude), 
                Check_In_Longitude__c = Decimal.valueOf(longitude),
                StartDateTime = datetime_format,
                EndDateTime = datetime_format,
                RecordTypeId = eventRecordType.Id,
                Check_In_Address_Line__c = Address,
                Check_In_Date__c = datetime_format
            );

            Insert createEvent;
            return createEvent.Id;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string CreateEventCheckOut(String latitude, String longitude, String EventID, String Address){
        try {
            String value_Datetime = String.ValueOf(Datetime.now()).replace('T','');
            Datetime datetime_format = Datetime.valueOf(value_Datetime);

            List<Event> UpdateEvent = [SELECT Id, Check_Out_Address_Line__c, Check_Out_Latitude__c, Check_Out_Longitude__c, Check_Out_Date__c, 
            EndDateTime From Event WHERE Id=:EventID];

            
            for (Event obj_event : UpdateEvent) {
                obj_event.Check_Out_Address_Line__c = Address;
                obj_event.Check_Out_Date__c = datetime_format;
                obj_event.EndDateTime = datetime_format;
                obj_event.Check_Out_Latitude__c = Decimal.valueOf(latitude);
                obj_event.Check_Out_Longitude__c = Decimal.valueOf(longitude);
            }
            Update UpdateEvent;
            return EventID;

            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static string ValidateCheckOut(String EventID){
        try {

            Event cekEvent = [SELECT Id, Check_Out_Address_Line__c, Check_Out_Latitude__c, Check_Out_Longitude__c, Check_Out_Date__c
            From Event WHERE Id=:EventID];
            
            if(cekEvent.Check_Out_Address_Line__c== null){
                return 'Update';
            }else{
                return 'Dont Update';
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
}