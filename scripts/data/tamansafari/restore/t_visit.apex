Double la=-6.6296, lo=106.8219, la2=-6.6297, lo2=106.8220, acc1=12, acc2=10;
Savepoint sp = Database.setSavepoint();
String log='';
Contact c = [SELECT Id, AccountId FROM Contact WHERE AccountId != null AND Account.Name != 'Sample Account for Entitlements' LIMIT 1];
Id acc = c.AccountId;
try {
  VisitController.TargetContextDTO t0 = VisitController.getTargetContext(acc);
  log += '\nA1 konteks target: koordinat='+t0.hasCoordinates+' canPin='+t0.canPin+' radius='+t0.radiusM+' minDurasi='+t0.minDurationMinutes+' allowOutside='+t0.allowOutsideCheckIn;
  if (t0.hasCoordinates != true) { VisitController.TargetContextDTO t1 = VisitController.pinTargetLocation(acc, la, lo); log += '\nA2 pin lokasi -> koordinat='+t1.hasCoordinates+' sumber='+t1.locationSource; }
  VisitController.GeofencePreviewDTO g = VisitController.previewGeofence(acc, la2, lo2);
  log += '\nA3 preview geofence: inside='+g.inside+' jarak='+g.distanceM;
  VisitController.VisitDTO v = VisitController.checkIn(acc, la2, lo2, acc1, null);
  log += '\nA4 check-in -> '+v.name+' status='+v.status+' outside='+v.isOutsideGeofence+' jarak='+v.distanceM;
  v = VisitController.saveVisitDraft(v.id, JSON.serialize(new Map<String,Object>{'visitPurpose'=>'Initial Canvassing / Discovery','contactId'=>c.Id,'meetingSummary'=>'Diskusi gathering 120 peserta, minat paket Bogor.','uuPdpConsent'=>true,'pipelineAction'=>'None','estimatedPax'=>120}));
  log += '\nA5 draft tersimpan';
  v = VisitController.uploadVisitPhoto(v.id, '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==', la2, lo2);
  log += '\nA6 foto: hasPhoto='+v.hasPhoto+' duplikat='+v.isDuplicatePhoto;
  v = VisitController.uploadClientSignature(v.id, 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'Budi Santoso', la2, lo2);
  log += '\nA7 tanda tangan: hasSignature='+v.hasSignature+' oleh='+v.signedByName;
  v = VisitController.completeVisitCheckOut(v.id, la2, lo2, acc2, null);
  log += '\nA8 check-out -> status='+v.status+' durasi='+v.durationMinutes+' short='+v.isShortVisit;
  Visit_Form__c f = [SELECT Status__c, Location_Score__c, Duration_Score__c, Proof_Score__c, Telemetry_Score__c, Total_Visit_Score__c, AI_Scoring_Status__c, Event_Id__c, Open_Visit_Key__c, Is_Short_Visit__c FROM Visit_Form__c WHERE Id=:v.id];
  log += '\nA9 hasil: skor L/D/P/T='+f.Location_Score__c+'/'+f.Duration_Score__c+'/'+f.Proof_Score__c+'/'+f.Telemetry_Score__c+' total='+f.Total_Visit_Score__c+' AI='+f.AI_Scoring_Status__c+' eventId='+f.Event_Id__c+' openKey='+f.Open_Visit_Key__c;
  log += '\nA10 Event dibuat: '+[SELECT COUNT() FROM Event WHERE Id=:f.Event_Id__c];
  VisitAuditController.AuditMapDTO a = VisitAuditController.getVisitAuditData(v.id);
  log += '\nA11 data peta audit: marker='+(a.markers==null?0:a.markers.size());
} catch (Exception e) { log += '\nGAGAL: '+e.getTypeName()+' '+e.getMessage()+' @ '+e.getStackTraceString(); }
Database.rollback(sp);
System.debug('HASIL_VISIT'+log);
