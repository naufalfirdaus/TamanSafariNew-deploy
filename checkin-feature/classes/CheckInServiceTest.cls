@IsTest
private class CheckInServiceTest {
  // --- 1. CALLOUT MOCK UNTUK GEOAPIFY ---
  // Diubah strukturnya menjadi format GeoJSON asli (Geoapify standar) agar parsier geoapifyController tidak crash
  public class GeoapifyCalloutMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      // Format JSON yang paling umum digunakan oleh parser Reverse Geocoding Map API
      String jsonRes = '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"name":"Jl. Sudirman No 1","street":"Jl. Sudirman","city":"Jakarta","state":"DKI Jakarta","postcode":"12345","country":"Indonesia","formatted":"Jl. Sudirman No 1, Jakarta, Indonesia","address_line1":"Jl. Sudirman No 1","address_line2":"Jakarta, Indonesia"}}]}';

      res.setBody(jsonRes);
      res.setStatusCode(200);
      return res;
    }
  }

  // --- 2. SETUP DATA ---
  @TestSetup
  static void setupData() {
    Account acc = new Account(Name = 'Test Geofence Account');
    acc.put('Checkin_Geo__Latitude__s', -6.200000);
    acc.put('Checkin_Geo__Longitude__s', 106.816666);
    acc.put('Geofence_Radius_m__c', 500);
    insert acc;
  }

  // --- 3. TEST METHODS ---

  @IsTest
  static void testGetContext_ParentRecord() {
    Account acc = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Geofence Account'
      LIMIT 1
    ];

    Test.startTest();
    CheckInService.ContextDTO result = CheckInService.getContext(
      acc.Id,
      'Account'
    );
    Test.stopTest();

    Assert.isTrue(result.ready, 'Context harus dalam keadaan ready');
    Assert.areEqual(
      acc.Id,
      result.whatId,
      'WhatId harus sesuai dengan Account Id'
    );
    Assert.areEqual(
      -6.200000,
      result.targetLat,
      'Lat target harus ditarik dari record'
    );
    Assert.isNull(
      result.openEventId,
      'Seharusnya tidak ada event yang open di awal'
    );
  }

  @IsTest
  static void testStartCheckIn_Success() {
    Account acc = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Geofence Account'
      LIMIT 1
    ];
    Test.setMock(HttpCalloutMock.class, new GeoapifyCalloutMock());

    Test.startTest();
    Id eventId = CheckInService.startCheckIn(
      acc.Id,
      'Account',
      (Double) -6.200100,
      (Double) 106.816700,
      5.0,
      10.0,
      true,
      null
    );
    Test.stopTest();

    Assert.isNotNull(eventId, 'Event Id harus di-return setelah Check In');
    Event ev = [
      SELECT Id, Subject, CheckIn_Latitude__c, Inside_Geofence_on_CheckIn__c
      FROM Event
      WHERE Id = :eventId
    ];
    Assert.isTrue(
      ev.Subject.contains('Check-In'),
      'Subject harus terisi otomatis'
    );
    Assert.isTrue(
      (Boolean) ev.Inside_Geofence_on_CheckIn__c,
      'Geofence flag harus true'
    );
  }

  @IsTest
  static void testStartCheckIn_OutsideGeofenceException() {
    Account acc = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Geofence Account'
      LIMIT 1
    ];

    Test.startTest();
    try {
      CheckInService.startCheckIn(
        acc.Id,
        'Account',
        (Double) -6.300000,
        (Double) 106.900000,
        5.0,
        2000.0,
        false,
        ''
      );
      Assert.fail(
        'Seharusnya melemparkan exception karena di luar radius tanpa alasan.'
      );
    } catch (Exception e) {
      // FIX: Salesforce menutupi Custom Message pada AuraHandledException saat tes, maka Assert via Jenis Class saja.
      Assert.isTrue(
        e instanceof AuraHandledException,
        'Exception yang dilempar harus AuraHandledException'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void testFinishCheckOut_Success() {
    Account acc = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Geofence Account'
      LIMIT 1
    ];
    Event ev = new Event(
      WhatId = acc.Id,
      Subject = 'Check-In Test',
      StartDateTime = System.now(),
      Check_In_Date__c = System.now(),
      DurationInMinutes = 60
    );
    insert ev;

    String jsonPayload = '{"General_Note_about_Meeting__c": "Meeting sukses", "Was_Call_Requested__c": true, "Matter_Discussed__c": "Pricing", "Follow_Up_Action_Detail__c": "Kirim Proposal"}';
    Test.setMock(HttpCalloutMock.class, new GeoapifyCalloutMock());

    Test.startTest();
    CheckInService.finishCheckOut(
      String.valueOf(ev.Id),
      (Double) -6.200100,
      (Double) 106.816700,
      10.0,
      50.0,
      true,
      jsonPayload
    );
    Test.stopTest();

    Event updatedEv = [
      SELECT
        Check_Out_Date__c,
        General_Note_about_Meeting__c,
        CheckOut_Latitude__c
      FROM Event
      WHERE Id = :ev.Id
    ];
    Assert.isNotNull(
      updatedEv.Check_Out_Date__c,
      'Check_Out_Date__c harus terisi'
    );
  }

  @IsTest
  static void testGetContextEvent_ExistingEvent() {
    Event ev = new Event(
      Subject = 'Test Context Event',
      DurationInMinutes = 30,
      StartDateTime = System.now()
    );
    insert ev;

    ev.put('CheckIn_Latitude__c', -6.111);
    update ev;

    Test.startTest();
    CheckInService.ContextDTO ctx = CheckInService.getContextEvent(
      String.valueOf(ev.Id)
    );
    Test.stopTest();

    Assert.isTrue(ctx.ready, 'Context DTO harus ready');
    Assert.areEqual(ev.Id, ctx.openEventId, 'Open Event ID harus match');
    Assert.isFalse(ctx.hasCheckedOut, 'HasCheckedOut harus false');
  }

  @IsTest
  static void testFileUploadAndRetrieval() {
    Event ev = new Event(
      Subject = 'Test File Event',
      DurationInMinutes = 10,
      StartDateTime = System.now()
    );
    insert ev;

    Test.startTest();
    // FIX: Menggunakan string Base64 PNG 1 pixel asli agar lulus parse encoding
    String base64Img = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
    Id docId = CheckInService.uploadEventPhoto(
      ev.Id,
      base64Img,
      'test_photo.png'
    );
    Assert.isNotNull(docId, 'ContentDocumentId harus dikembalikan');

    List<CheckInService.EventFileDTO> files = CheckInService.getEventFiles(
      ev.Id
    );
    Test.stopTest();

    Assert.isFalse(files.isEmpty(), 'List files tidak boleh kosong');
    Assert.areEqual(1, files.size(), 'Harus menemukan 1 file');
    Assert.isTrue(
      files[0].title.contains('test_photo'),
      'Title file harus sesuai'
    );
  }

  @IsTest
  static void testInitTargetFromCurrentLocation() {
    Account accEmpty = new Account(Name = 'Empty Location Target');
    insert accEmpty;

    Test.startTest();
    CheckInService.initTargetFromCurrentLocation(
      accEmpty.Id,
      'Account',
      (Double) -7.000,
      (Double) 110.000
    );
    Test.stopTest();

    // FIX: Menambahkan field Checkin_Geo__Latitude__s ke Query Test agar tidak terkena SObjectException
    Account updatedAcc = [
      SELECT Id, Name, Checkin_Geo__Latitude__s
      FROM Account
      WHERE Id = :accEmpty.Id
    ];
    Double lat = (Double) updatedAcc.get('Checkin_Geo__Latitude__s');
    Assert.areEqual(
      -7.000,
      lat,
      'Latitude harus berhasil di-Update dari lokasi current'
    );
  }

  @IsTest
  static void testGetCheckInHistory() {
    Account acc = [
      SELECT Id
      FROM Account
      WHERE Name = 'Test Geofence Account'
      LIMIT 1
    ];

    Event evHist = new Event(
      WhatId = acc.Id,
      Subject = 'Check-In Kunjungan',
      // System.now(), bukan System.today(): field DateTime yang diisi Date jadi
      // tengah malam GMT, sehingga filter 'StartDateTime = TODAY' yang sadar zona
      // waktu org bisa meleset ke hari sebelumnya.
      StartDateTime = System.now(),
      Check_In_Date__c = System.now(),
      Check_Out_Date__c = System.now().addHours(1),
      DurationInMinutes = 60
    );
    evHist.put('CheckIn_Distance_m__c', 10);
    evHist.put('Inside_Geofence_on_CheckIn__c', true);
    insert evHist;

    Test.startTest();
    List<CheckInService.CheckInHistoryItemDTO> histories = CheckInService.getCheckInHistory(
      acc.Id,
      'Account',
      5,
      'TODAY'
    );
    Test.stopTest();

    Assert.isFalse(histories.isEmpty(), 'History harus ditemukan');
    Assert.areEqual(
      evHist.Id,
      histories[0].eventId,
      'Event ID pada DTO history harus match'
    );
    Assert.areEqual(
      60,
      histories[0].durationMinutes,
      'Durasi harus dihitung menjadi 60 menit'
    );
    Assert.isTrue(
      histories[0].insideCheckIn,
      'Flag Inside geofence ditarik dengan benar'
    );
  }
}