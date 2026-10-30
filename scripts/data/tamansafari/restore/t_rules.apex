Savepoint sp = Database.setSavepoint();
String log = '';
Id rt = [SELECT Id FROM RecordType WHERE SobjectType='Opportunity' AND DeveloperName='Taman_Safari'].Id;
Account a = [SELECT Id FROM Account WHERE Name != 'Sample Account for Entitlements' LIMIT 1];
Id pb = [SELECT Id FROM Pricebook2 WHERE Name='B2B Custom Pricebook'].Id;
Opportunity o1 = new Opportunity(Name='T1', AccountId=a.Id, StageName='Qualification', CloseDate=Date.today().addDays(30), RecordTypeId=rt, Pricebook2Id=pb, Preferred_Park_Location__c='Taman Safari Bogor');
insert o1;
// T1: stage Proposal tanpa produk harus ditolak
o1.StageName='Proposal/Quote';
Database.SaveResult r = Database.update(o1,false);
log += '\nT1 Proposal tanpa produk -> ' + (r.isSuccess()?'LOLOS (SALAH)':'DITOLAK OK: '+r.getErrors()[0].getMessage());
o1.StageName='Qualification';
// T2: termin 13 ditolak
o1.Payment_Terms__c=13; r=Database.update(o1,false);
log += '\nT2 Termin 13 -> ' + (r.isSuccess()?'LOLOS (SALAH)':'DITOLAK OK: '+r.getErrors()[0].getMessage());
// T3: produk
List<PricebookEntry> pes = [SELECT Id, Product2.Name, Product2.Park_Location__c, UnitPrice FROM PricebookEntry WHERE Pricebook2Id=:pb AND IsActive=true];
PricebookEntry bogor, bali, all;
for (PricebookEntry p: pes){ if(p.Product2.Park_Location__c=='Taman Safari Bogor') bogor=p; if(p.Product2.Park_Location__c=='Taman Safari Bali') bali=p; if(p.Product2.Park_Location__c=='All Locations') all=p; }
log += '\nProduk uji: bogor='+(bogor!=null)+' bali='+(bali!=null)+' all='+(all!=null);
Database.SaveResult r1 = Database.insert(new OpportunityLineItem(OpportunityId=o1.Id, PricebookEntryId=bogor.Id, Quantity=10, UnitPrice=bogor.UnitPrice),false);
log += '\nT3 Produk Bogor di deal Bogor -> ' + (r1.isSuccess()?'OK':'GAGAL: '+r1.getErrors()[0].getMessage());
if (bali!=null){ Database.SaveResult r2 = Database.insert(new OpportunityLineItem(OpportunityId=o1.Id, PricebookEntryId=bali.Id, Quantity=1, UnitPrice=bali.UnitPrice),false);
log += '\nT4 Produk Bali di deal Bogor -> ' + (r2.isSuccess()?'LOLOS (SALAH)':'DITOLAK OK: '+r2.getErrors()[0].getMessage()); }
if (all!=null){ Database.SaveResult r3 = Database.insert(new OpportunityLineItem(OpportunityId=o1.Id, PricebookEntryId=all.Id, Quantity=1, UnitPrice=all.UnitPrice),false);
log += '\nT5 Produk All Locations di deal Bogor -> ' + (r3.isSuccess()?'OK':'GAGAL: '+r3.getErrors()[0].getMessage()); }
// T6: set termin 3 -> jadwal otomatis
o1 = [SELECT Id, Amount FROM Opportunity WHERE Id=:o1.Id];
o1.Payment_Terms__c=3; update o1;
List<Payment__c> ps = [SELECT Term_Number__c, Amount__c, Due_Date__c, Status__c FROM Payment__c WHERE Opportunity__c=:o1.Id ORDER BY Term_Number__c];
Decimal sum=0; for (Payment__c p: ps) sum+=p.Amount__c;
log += '\nT6 Termin 3 -> '+ps.size()+' payment, total='+sum+' amount='+o1.Amount+' ('+(sum==o1.Amount?'OK':'TIDAK SAMA')+')';
// T7: ubah termin jadi 2 saat belum Paid -> jadwal dibuat ulang
o1.Payment_Terms__c=2; Database.SaveResult r7=Database.update(o1,false);
Integer c2=[SELECT COUNT() FROM Payment__c WHERE Opportunity__c=:o1.Id];
log += '\nT7 Ubah termin 3->2 -> '+(r7.isSuccess()?'sukses':'ditolak '+r7.getErrors()[0].getMessage())+', jumlah payment='+c2;
// T8: closed won tanpa PO / tanpa lunas
o1.StageName='Closed Won'; Database.SaveResult r8=Database.update(o1,false);
log += '\nT8 Closed Won tanpa PO & belum lunas -> '+(r8.isSuccess()?'LOLOS (SALAH)':'DITOLAK OK: '+r8.getErrors()[0].getMessage());
// T9: lunas + PO -> closed won ok
List<Payment__c> allp=[SELECT Id FROM Payment__c WHERE Opportunity__c=:o1.Id]; for(Payment__c p: allp) p.Status__c='Paid'; update allp;
o1.PO_Number__c='PO-TEST'; o1.StageName='Closed Won'; Database.SaveResult r9=Database.update(o1,false);
log += '\nT9 Lunas + PO -> Closed Won '+(r9.isSuccess()?'OK':'GAGAL: '+r9.getErrors()[0].getMessage());
// T10: Closed Lost tanpa alasan
Opportunity o2 = new Opportunity(Name='T10', AccountId=a.Id, StageName='Qualification', CloseDate=Date.today().addDays(5), RecordTypeId=rt);
insert o2; o2.StageName='Closed Lost'; Database.SaveResult r10=Database.update(o2,false);
log += '\nT10 Closed Lost tanpa alasan -> '+(r10.isSuccess()?'LOLOS (SALAH)':'DITOLAK OK: '+r10.getErrors()[0].getMessage());
Database.rollback(sp);
System.debug('HASIL_UJI'+log);
