public with sharing class CheckInService {
  public class ContextDTO {
    @AuraEnabled
    public String parentName;
    @AuraEnabled
    public Double targetLat;
    @AuraEnabled
    public Double targetLng;
    @AuraEnabled
    public Decimal radiusM;
    @AuraEnabled
    public Id whoId;
    @AuraEnabled
    public Id whatId;
    @AuraEnabled
    public Boolean ready;
    @AuraEnabled
    public Boolean hasCheckedOut;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Id openEventId;
  }

  public class CheckInHistoryItemDTO {
    @AuraEnabled
    public Id eventId;
    @AuraEnabled
    public String subject;
    @AuraEnabled
    public Datetime checkInAt;
    @AuraEnabled
    public Datetime checkOutAt;
    @AuraEnabled
    public Integer durationMinutes;

    @AuraEnabled
    public Decimal checkInDistanceM;
    @AuraEnabled
    public Decimal checkOutDistanceM;
    @AuraEnabled
    public Boolean insideCheckIn;
    @AuraEnabled
    public Boolean insideCheckOut;

    @AuraEnabled
    public Decimal checkInLat;
    @AuraEnabled
    public Decimal checkInLng;
    @AuraEnabled
    public Decimal checkOutLat;
    @AuraEnabled
    public Decimal checkOutLng;

    @AuraEnabled
    public Boolean hasPhoto;

    // helper display
    @AuraEnabled
    public String checkInDistanceMDisplay;
    @AuraEnabled
    public String checkOutDistanceMDisplay;
  }

  @AuraEnabled(cacheable=true)
  public static ContextDTO getContext(String recordId, String objectApiName) {
    ContextDTO dto = new ContextDTO();
    string addFields = '';

    if (objectApiName != 'Event')
      addFields = ',Name,Checkin_Geo__Latitude__s,Checkin_Geo__Longitude__s,Geofence_Radius_m__c';

    String queryObject =
      'SELECT Id' +
      addFields +
      ' FROM ' +
      objectApiName +
      ' WHERE Id =\'' +
      String.escapeSingleQuotes(recordId) +
      '\' LIMIT 1';

    dto.ready = false;
    SObject parentRec = Database.query(queryObject.trim())[0];

    if (objectApiName != 'Event')
      dto.parentName = (String) parentRec.get('Name');

    // Ambil geo & radius dari custom fields
    // NB: pastikan field ada di ketiga objek
    List<String> fields = new List<String>{
      'Checkin_Geo__Latitude__s',
      'Checkin_Geo__Longitude__s',
      'Geofence_Radius_m__c'
    };
    Map<String, Object> vals = new Map<String, Object>();
    for (String f : fields) {
      if (
        !parentRec.getSObjectType().getDescribe().fields.getMap().containsKey(f)
      )
        continue;
      vals.put(f, parentRec.get(f));
    }

    Double lat = (Double) vals.get('Checkin_Geo__Latitude__s');
    Double lng = (Double) vals.get('Checkin_Geo__Longitude__s');
    Decimal radiusM = (Decimal) vals.get('Geofence_Radius_m__c');

    // if (lat == null || lng == null || radiusM == null) {
    //   dto.message = 'Geofence di record ini belum lengkap (lat/lng/radius).';
    //   return dto;
    // }

    dto.targetLat = lat;
    dto.targetLng = lng;
    dto.radiusM = radiusM;

    // Tentukan Who/What
    if (objectApiName == 'Lead') {
      dto.whoId = recordId;
    } else if (
      objectApiName == 'Account' ||
      objectApiName == 'Opportunity' ||
      objectApiName == 'Project__c'
    ) {
      dto.whatId = recordId;
    } else {
      dto.message = 'Objek belum didukung.';
      return dto;
    }

    // Cari open Event (Start terisi & End null) milik user sekarang untuk parent ini (hari ini)
    String evSoql =
      'SELECT Id FROM Event ' +
      'WHERE CheckOut_Longitude__c = Null AND OwnerId = \'' +
      UserInfo.getUserId() +
      '\' ' +
      (dto.whoId != null
        ? 'AND WhoId = \'' + dto.whoId + '\' '
        : 'AND WhatId = \'' + dto.whatId + '\' ') +
      'ORDER BY CreatedDate DESC LIMIT 1';
    List<Event> opens = Database.query(evSoql);
    dto.openEventId = (opens.isEmpty() ? null : opens[0].Id);

    dto.ready = true;
    dto.message = 'OK';
    return dto;
  }

  @AuraEnabled(cacheable=true)
  public static ContextDTO getContextEvent(String recordId) {
    try {
      ContextDTO dto = new ContextDTO();
      Event ev = [
        SELECT
          Id,
          StartDateTime,
          EndDateTime,
          WhoId,
          WhatId,
          CheckIn_Latitude__c,
          CheckIn_Longitude__c,
          CheckIn_Distance_m__c,
          CheckIn_Accuracy_m__c,
          Check_Out_Date__c,
          Subject
        FROM Event
        WHERE Id = :recordId
        LIMIT 1
      ];

      dto.openEventId = ev.Id;
      dto.parentName = ev.Subject;
      dto.radiusM = (Decimal) 250;
      dto.targetLat = (Decimal) ev.CheckIn_Latitude__c;
      dto.targetLng = (Decimal) ev.CheckIn_Longitude__c;
      dto.ready = true;
      dto.message = 'OK';
      dto.whatId = ev.WhatId;
      dto.whoId = ev.WhoId;
      dto.hasCheckedOut = false;

      if (ev.Check_Out_Date__c != null) {
        dto.message = 'Already Check-Out';
        dto.hasCheckedOut = true;
      }
      System.debug('dto: ' + dto);
      return dto;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static Id startCheckIn(
    Id recordId,
    String objectApiName,
    Double lat,
    Double lng,
    Decimal accuracyM,
    Decimal distanceM,
    Boolean inside,
    String overrideReason
  ) {
    // FLS/CRUD checks
    if (!Schema.sObjectType.Event.isCreateable()) {
      throw new AuraHandledException('Anda tidak punya izin membuat Event.');
    }

    ContextDTO ctx = getContext(recordId, objectApiName);
    if (!ctx.ready)
      throw new AuraHandledException(ctx.message);

    // Rule: 1 open event per parent per user
    if (ctx.openEventId != null)
      return ctx.openEventId;

    // Optional strict geofence
    Boolean allow =
      inside || (overrideReason != null && overrideReason.trim().length() > 0);
    if (!allow)
      throw new AuraHandledException(
        'Di luar geofence. Isi alasan override untuk lanjut.'
      );

    Event ev = new Event();
    ev.Subject = 'Check-In ' + System.now();
    ev.IsAllDayEvent = false;
    ev.StartDateTime = System.now();
    ev.Check_In_Date__c = System.now();
    ev.DurationInMinutes = 1;
    ev.RecordTypeId = getRecordTypeByName('Geolocation');
    if (ctx.whoId != null)
      ev.WhoId = ctx.whoId;
    if (ctx.whatId != null)
      ev.WhatId = ctx.whatId;
    ev.OwnerId = UserInfo.getUserId();

    String addressLine = geoapifyController.GeoapifyReverse(
      String.valueOf(lat),
      String.valueOf(lng)
    );

    // Custom fields
    ev.put('CheckIn_Latitude__c', lat);
    ev.put('CheckIn_Longitude__c', lng);
    ev.put('CheckIn_Accuracy_m__c', accuracyM);
    ev.put('CheckIn_Distance_m__c', distanceM);
    ev.put('Inside_Geofence_on_CheckIn__c', inside);
    ev.put('Check_In_Address_Line__c', addressLine);
    if (overrideReason != null)
      ev.put('Override_Reason__c', overrideReason);

    insert ev;
    return ev.Id;
  }

  @AuraEnabled
  public static Id finishCheckOut(
    String eventId,
    Double lat,
    Double lng,
    Decimal accuracyM,
    Decimal distanceM,
    Boolean inside,
    String eventDetails
  ) {
    if (!Schema.sObjectType.Event.isUpdateable()) {
      throw new AuraHandledException('Anda tidak punya izin update Event.');
    }
    Object jsonObj = (Object) JSON.deserializeUntyped(eventDetails);
    Map<String, Object> data = (Map<String, Object>) jsonObj;

    Event ev = [SELECT Id, EndDateTime FROM Event WHERE Id = :eventId LIMIT 1];

    ev.EndDateTime = System.now();
    ev.Check_Out_Date__c = System.now();
    ev.Check_Out_Address_Line__c = geoapifyController.GeoapifyReverse(
      String.valueOf(lat),
      String.valueOf(lng)
    );
    ev.put('CheckOut_Latitude__c', lat);
    ev.put('CheckOut_Longitude__c', lng);
    ev.put('CheckOut_Accuracy_m__c', accuracyM);
    ev.put('CheckOut_Distance_m__c', distanceM);
    ev.put('Inside_Geofence_on_CheckOut__c', inside);
    // ev.put(
    //   'General_Note_about_Meeting__c',
    //   (String) data.get('General_Note_about_Meeting__c')
    // );
    // ev.put('Was_The_Call_Requested__c', data.get('Was_Call_Requested__c'));
    // ev.put('Metter_Discussed__c', (String) data.get('Matter_Discussed__c'));
    // ev.put(
    //   'Follow_Up_Action_Detail__c',
    //   (String) data.get('Follow_Up_Action_Detail__c')
    // );
    update ev;
    return ev.Id;
  }

  private static String getRecordTypeByName(String Name) {
    RecordType rt = [
      SELECT Id
      FROM RecordType
      WHERE DeveloperName = :Name
      LIMIT 1
    ];
    return rt.Id;
  }
  @AuraEnabled
  public static Id uploadEventPhoto(
    Id eventId,
    String dataUrl,
    String fileName
  ) {
    if (eventId == null)
      throw new AuraHandledException('Event Id kosong.');
    if (String.isBlank(dataUrl))
      throw new AuraHandledException('Gambar kosong.');
    if (!Schema.sObjectType.ContentVersion.isCreateable()) {
      throw new AuraHandledException('Anda tidak punya izin upload file.');
    }

    String base64Data;
    String mimeType = 'image/jpeg';
    if (dataUrl.contains('base64,')) {
      Integer p0 = dataUrl.indexOf(':');
      Integer p1 = dataUrl.indexOf(';');
      if (p0 > -1 && p1 > -1 && p1 > p0)
        mimeType = dataUrl.substring(p0 + 1, p1);
      base64Data = dataUrl.substring(dataUrl.indexOf('base64,') + 7);
    } else {
      base64Data = dataUrl;
    }

    Blob body = EncodingUtil.base64Decode(base64Data);

    ContentVersion cv = new ContentVersion();
    cv.Title = String.isBlank(fileName)
      ? 'CheckIn_Photo_' + String.valueOf(DateTime.now().getTime())
      : fileName;
    cv.PathOnClient = cv.Title.endsWithIgnoreCase('.jpg') ||
      cv.Title.endsWithIgnoreCase('.jpeg') ||
      cv.Title.endsWithIgnoreCase('.png')
      ? cv.Title
      : (cv.Title + '.jpg');
    cv.VersionData = body;
    cv.FirstPublishLocationId = eventId;
    insert cv;

    cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
    return cv.ContentDocumentId;
  }

  public class EventFileDTO {
    @AuraEnabled
    public Id contentDocumentId;
    @AuraEnabled
    public Id contentVersionId;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String thumbUrl; // rendition thumbnail
    @AuraEnabled
    public String previewUrl; // file preview page
  }

  @AuraEnabled(cacheable=true)
  public static List<EventFileDTO> getEventFiles(Id eventId) {
    if (eventId == null)
      return new List<EventFileDTO>();
    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId, LinkedEntityId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :eventId
    ];
    if (links.isEmpty())
      return new List<EventFileDTO>();

    Set<Id> docIds = new Set<Id>();
    for (ContentDocumentLink cdl : links)
      docIds.add(cdl.ContentDocumentId);

    Map<Id, ContentVersion> latest = new Map<Id, ContentVersion>();
    for (ContentVersion v : [
      SELECT Id, ContentDocumentId, Title, FileType, VersionNumber
      FROM ContentVersion
      WHERE IsLatest = TRUE AND ContentDocumentId IN :docIds
    ]) {
      latest.put(v.ContentDocumentId, v);
    }

    String base = URL.getOrgDomainUrl().toExternalForm();
    List<EventFileDTO> out = new List<EventFileDTO>();
    for (Id docId : docIds) {
      ContentVersion v = latest.get(docId);
      if (v == null)
        continue;
      EventFileDTO dto = new EventFileDTO();
      dto.contentDocumentId = docId;
      dto.contentVersionId = v.Id;
      dto.title = v.Title;
      // THUMB rendition (fallback aman)
      dto.thumbUrl =
        base +
        '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' +
        v.Id;
      // Preview page
      dto.previewUrl =
        base +
        '/lightning/r/ContentDocument/' +
        String.valueOf(docId) +
        '/view';
      out.add(dto);
    }
    return out;
  }
  @AuraEnabled
  public static void initTargetFromCurrentLocation(
    Id recordId,
    String objectApiName,
    Double lat,
    Double lng
  ) {
    if (recordId == null) {
      throw new AuraHandledException('recordId is required');
    }
    if (String.isBlank(objectApiName)) {
      throw new AuraHandledException('objectApiName is required');
    }
    if (lat == null || lng == null) {
      throw new AuraHandledException('Latitude/Longitude is required');
    }
    if (objectApiName == 'Event') {
      throw new AuraHandledException('Init target tidak didukung untuk Event.');
    }

    Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
    if (sType == null) {
      throw new AuraHandledException('Objek tidak valid.');
    }

    Map<String, Schema.SObjectField> fmap = sType.getDescribe().fields.getMap();
    if (
      !fmap.containsKey('Checkin_Geo__Latitude__s') ||
      !fmap.containsKey('Checkin_Geo__Longitude__s')
    ) {
      throw new AuraHandledException(
        'Field geolocation target tidak tersedia di objek ini.'
      );
    }

    String soql =
      'SELECT Id, Checkin_Geo__Latitude__s, Checkin_Geo__Longitude__s ' +
      'FROM ' +
      objectApiName +
      ' WHERE Id = \'' +
      String.escapeSingleQuotes((String) recordId) +
      '\'' +
      ' LIMIT 1';

    SObject rec = Database.query(soql);

    Double existingLat = (Double) rec.get('Checkin_Geo__Latitude__s');
    Double existingLng = (Double) rec.get('Checkin_Geo__Longitude__s');

    // hanya set kalau memang belum ada
    // if (existingLat == null || existingLng == null) {
    rec.put('Checkin_Geo__Latitude__s', lat);
    rec.put('Checkin_Geo__Longitude__s', lng);
    update rec;
    // }
  }

  @AuraEnabled(cacheable=true)
  public static List<CheckInHistoryItemDTO> getCheckInHistory(
    Id recordId,
    String objectApiName,
    Integer rowLimit,
    String periodFilter
  ) {
    if (recordId == null) {
      throw new AuraHandledException('recordId is required');
    }
    if (String.isBlank(objectApiName)) {
      throw new AuraHandledException('objectApiName is required');
    }

    Integer lim = (rowLimit == null ||
      rowLimit <= 0)
      ? 6
      : Math.min(rowLimit, 20);

    Id whoId;
    Id whatId;

    if (objectApiName == 'Lead') {
      whoId = recordId;
    } else if (
      objectApiName == 'Account' ||
      objectApiName == 'Opportunity' ||
      objectApiName == 'Project__c'
    ) {
      whatId = recordId;
    } else if (objectApiName == 'Event') {
      Event evRef = [
        SELECT Id, WhoId, WhatId
        FROM Event
        WHERE Id = :recordId
        LIMIT 1
      ];
      whoId = evRef.WhoId;
      whatId = evRef.WhatId;
    } else {
      throw new AuraHandledException(
        'Objek belum didukung untuk history check-in.'
      );
    }

    // If no relation target can be derived, return empty safely.
    if (whoId == null && whatId == null) {
      return new List<CheckInHistoryItemDTO>();
    }

    String normalizedPeriod = String.isBlank(periodFilter)
      ? 'TODAY'
      : periodFilter.trim().toUpperCase();

    String periodClause = '';
    if (normalizedPeriod == 'TODAY') {
      periodClause = ' AND StartDateTime = TODAY ';
    } else if (normalizedPeriod == 'THIS_WEEK') {
      periodClause = ' AND StartDateTime = THIS_WEEK ';
    } else {
      normalizedPeriod = 'ALL';
    }

    // Optional: filter geolocation events only (recommended)
    // If your org uses a different record type name, adjust it.
    String geoFilter = ' AND Subject LIKE \'Check-In%\' ';

    String soql =
      'SELECT Id, Subject, Check_In_Date__c, Check_Out_Date__c, CreatedDate, StartDateTime, EndDateTime,  ' +
      'CheckIn_Distance_m__c, CheckOut_Distance_m__c, ' +
      'Inside_Geofence_on_CheckIn__c, Inside_Geofence_on_CheckOut__c, ' +
      'CheckIn_Latitude__c, CheckIn_Longitude__c, ' +
      'CheckOut_Latitude__c, CheckOut_Longitude__c ' +
      'FROM Event WHERE ' +
      (whoId != null
        ? 'WhoId = \'' + String.escapeSingleQuotes((String) whoId) + '\' '
        : 'WhatId = \'' + String.escapeSingleQuotes((String) whatId) + '\' ') +
      geoFilter +
      periodClause +
      'ORDER BY Check_In_Date__c DESC, CreatedDate DESC LIMIT ' +
      lim;

    List<Event> rows = Database.query(soql);
    if (rows.isEmpty()) {
      return new List<CheckInHistoryItemDTO>();
    }

    Set<Id> eventIds = new Set<Id>();
    for (Event e : rows) {
      eventIds.add(e.Id);
    }

    // Photo indicator (simple + efficient enough for <=20 rows)
    Set<Id> eventIdsWithPhotos = new Set<Id>();
    for (ContentDocumentLink cdl : [
      SELECT LinkedEntityId
      FROM ContentDocumentLink
      WHERE LinkedEntityId IN :eventIds
    ]) {
      eventIdsWithPhotos.add(cdl.LinkedEntityId);
    }

    List<CheckInHistoryItemDTO> out = new List<CheckInHistoryItemDTO>();

    for (Event e : rows) {
      CheckInHistoryItemDTO dto = new CheckInHistoryItemDTO();
      dto.eventId = e.Id;
      dto.subject = e.Subject;
      dto.checkInAt = e.Check_In_Date__c;
      dto.checkOutAt = e.Check_Out_Date__c;

      if (e.StartDateTime != null && e.EndDateTime != null) {
        Long ms = e.EndDateTime.getTime() - e.StartDateTime.getTime();
        if (ms >= 0) {
          dto.durationMinutes = Integer.valueOf(Math.floor(ms / 60000));
        }
      }

      dto.checkInDistanceM = (Decimal) e.get('CheckIn_Distance_m__c');
      dto.checkOutDistanceM = (Decimal) e.get('CheckOut_Distance_m__c');
      dto.insideCheckIn = (Boolean) e.get('Inside_Geofence_on_CheckIn__c');
      dto.insideCheckOut = (Boolean) e.get('Inside_Geofence_on_CheckOut__c');

      dto.checkInLat = (Decimal) e.get('CheckIn_Latitude__c');
      dto.checkInLng = (Decimal) e.get('CheckIn_Longitude__c');
      dto.checkOutLat = (Decimal) e.get('CheckOut_Latitude__c');
      dto.checkOutLng = (Decimal) e.get('CheckOut_Longitude__c');

      dto.hasPhoto = eventIdsWithPhotos.contains(e.Id);

      dto.checkInDistanceMDisplay = dto.checkInDistanceM == null
        ? null
        : String.valueOf(dto.checkInDistanceM.setScale(0));
      dto.checkOutDistanceMDisplay = dto.checkOutDistanceM == null
        ? null
        : String.valueOf(dto.checkOutDistanceM.setScale(0));

      out.add(dto);
    }

    return out;
  }
}