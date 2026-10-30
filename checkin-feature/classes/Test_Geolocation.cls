@isTest
public class Test_Geolocation {

   /**
    * Record type Account dicari berdasarkan yang benar-benar tersedia bagi user
    * yang menjalankan test. Sebelumnya Id-nya di-hardcode dari org asal, sehingga
    * test selalu gagal begitu dijalankan di org lain (INVALID_CROSS_REFERENCE_KEY).
    */
   private static Id akunRecordTypeId() {
      List<RecordType> rt = [
         SELECT Id FROM RecordType
         WHERE SobjectType = 'Account' AND IsActive = true AND IsPersonType = false
         ORDER BY DeveloperName LIMIT 1
      ];
      return rt.isEmpty() ? null : rt[0].Id;
   }
   @IsTest
   static void testGeolocationController(){

    Profile p = [select id from profile where name ='System Administrator'];
    User user = new User(Alias = 'newUser', Email='newuser@testorg.com',
         EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
         LocaleSidKey='en_US', ProfileId = p.Id,
         TimeZoneSidKey='America/Los_Angeles', UserName='new-acek@testorg.com');
    //Insert user;

    Account account = new Account(
        Name = 'testAccount',
        RecordTypeId = akunRecordTypeId()
    );
    Insert account;

    Test.startTest();
    System.runAs(user){
        try {

            String ResultHttp = Geolocation_Controller.GeoapifyReverse('-6.1978323', '106.8058839');
            System.debug('ResultHttp: ' + ResultHttp);

            // Object response = JSON.deserializeUntyped(res.getBody());
            // System.debug('Data Response'+response);

            // Map<String,Object> DataJSON =  (Map<String,Object>) response;
            // String Serialize_features = JSON.serialize(DataJSON.get('features'));
            // List<Object> DataJSON_features = (List<Object>) JSON.deserializeUntyped(Serialize_features);

            
            // for(Object itemFeatures : DataJSON_features){
            //     Map<String,Object> itemFeaturesJSON = (Map<String,Object>) itemFeatures;
            //     System.debug('Properties : ' + itemFeaturesJSON.get('properties'));

            //     Map<String,Object> DataJSON_Properties = (Map<String,Object>) itemFeaturesJSON.get('properties');
            //     System.debug('Properties : ' + DataJSON_Properties.get('formatted'));
            //     Address = String.valueOf(DataJSON_Properties.get('formatted'));
            //     Street = String.valueOf(DataJSON_Properties.get('address_line1'));

            // }

        } catch (Exception e) {
            
        }
    }
    Test.stopTest();
    
   }

   @IsTest
   static void Test_CheckIn(){
        Profile p = [select id from profile where name ='System Administrator'];
        User user = new User(Alias = 'newUser', Email='newuser@testorg.com',
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='new-acek@testorg.com');
        //Insert user;

        Account account = new Account(
            Name = 'testAccount',
            RecordTypeId = akunRecordTypeId()
        );
        Insert account;

        Contact contact = new Contact(
            FirstName = 'testContact',
            LastName = 'testContact',
            AccountId = account.Id
        );
        Insert contact;
    Test.startTest();
    System.runAs(user){
        
        String ResultCheckIn = Geolocation_Controller.CreateEventCheckIn('-6.1978323', '106.8058839', contact.Id, 'Address', 'Contact');
        System.debug('ResultCheckIn'+ResultCheckIn);

    }
    Test.stopTest();
    
   }

   @IsTest
   static void testCheckOut(){
        Profile p = [select id from profile where name ='System Administrator'];
        User user = new User(Alias = 'newUser', Email='newuser@testorg.com',
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='new-acek@testorg.com');
        //Insert user;

        Account account = new Account(
            Name = 'testAccount',
            RecordTypeId = akunRecordTypeId()
        );
        Insert account;

        String value_Datetime = String.ValueOf(Datetime.now()).replace('T','');
        Datetime datetime_format = Datetime.valueOf(value_Datetime);
        RecordType eventRecordType = [Select Id FROM RecordType Where sObjectType = 'Event' And Name = 'Geolocation'];

        Event event = new Event(
            Subject = 'testEvent',
            WhoId = user.id,
            WhatId = account.Id,
            StartDateTime = datetime_format,
            EndDateTime = datetime_format,
            RecordTypeId = eventRecordType.Id
        );
        Insert event;
    Test.startTest();
    System.runAs(user){

        String ResultCheckOut = Geolocation_Controller.CreateEventCheckOut('-6.1978323', '106.8058839', event.id, 'Adress');
        System.debug('ResultCheckOut'+ResultCheckOut);

    }
    Test.stopTest();
    
   }

   @IsTest
   static void testValidasi(){
        Profile p = [select id from profile where name ='System Administrator'];
        User user = new User(Alias = 'newUser', Email='newuser@testorg.com',
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='new-acek@testorg.com');
        //Insert user;

        Account account = new Account(
            Name = 'testAccount',
            RecordTypeId = akunRecordTypeId()
        );
        Insert account;

        String value_Datetime = String.ValueOf(Datetime.now()).replace('T','');
        Datetime datetime_format = Datetime.valueOf(value_Datetime);
        RecordType eventRecordType = [Select Id FROM RecordType Where sObjectType = 'Event' And Name = 'Geolocation'];

        Event event = new Event(
            Subject = 'testEvent',
            WhoId = user.id,
            WhatId = account.Id,
            StartDateTime = datetime_format,
            EndDateTime = datetime_format,
            RecordTypeId = eventRecordType.Id
        );
        Insert event;
    Test.startTest();
    System.runAs(user){

        String ResultValidasi = Geolocation_Controller.ValidateCheckOut(event.id);
        System.debug('ResultValidasi'+ResultValidasi);

    }
    Test.stopTest();
    
   }

}