// Seed Activities (Field Visits & Tasks) for Taman Safari Indonesia
// Links realistic Visits (Event) and Follow-up Tasks (Task) to corporate Accounts and Opportunities.

List<Opportunity> opps = [
    SELECT Id, Name, AccountId, OwnerId, Preferred_Park_Location__c, StageName, Amount 
    FROM Opportunity 
    WHERE RecordType.DeveloperName = 'Taman_Safari'
    ORDER BY CreatedDate ASC
];

Map<Id, Contact> contactsByAccount = new Map<Id, Contact>();
for (Contact c : [SELECT Id, Name, AccountId FROM Contact WHERE AccountId != null]) {
    contactsByAccount.put(c.AccountId, c);
}

Map<Id, Account> accountsMap = new Map<Id, Account>([
    SELECT Id, Name, BillingCity, BillingStreet FROM Account
]);

List<Event> visitEvents = new List<Event>();
List<Task> activityTasks = new List<Task>();

Date today = Date.today();

// 1. Generate Visit Events (16 Field Visits across Opportunities)
for (Integer i = 0; i < opps.size() && i < 16; i++) {
    Opportunity opp = opps[i];
    Account acc = accountsMap.get(opp.AccountId);
    Contact cnt = contactsByAccount.get(opp.AccountId);
    
    Id contactId = (cnt != null) ? cnt.Id : null;
    String accName = (acc != null) ? acc.Name : 'Klien Korporat';
    String cityName = (acc != null && acc.BillingCity != null) ? acc.BillingCity : 'Jakarta';
    String loc = (opp.Preferred_Park_Location__c != null) ? opp.Preferred_Park_Location__c : 'Taman Safari Bogor';
    
    // Visit Date: between 3 to 14 days ago for completed, or future for upcoming
    Integer dayOffset = (i < 12) ? -(12 - i) : (i - 11);
    DateTime visitStart = DateTime.newInstance(today.addDays(dayOffset), Time.newInstance(9 + Math.mod(i, 5), 0, 0, 0));
    DateTime visitEnd = visitStart.addHours(1).addMinutes(30);
    
    Event v = new Event();
    v.WhatId = opp.Id;
    v.WhoId = contactId;
    v.OwnerId = opp.OwnerId;
    v.StartDateTime = visitStart;
    v.EndDateTime = visitEnd;
    
    if (i < 12) {
        // Completed field visit with geofence & qualification
        v.Subject = 'Field Visit Canvassing: ' + accName + ' (' + loc + ')';
        v.Inside_Geofence_on_CheckIn__c = true;
        v.Inside_Geofence_on_CheckOut__c = true;
        v.CheckIn_Distance_m__c = 35 + (i * 3);
        v.CheckIn_Accuracy_m__c = 10;
        v.CheckOut_Distance_m__c = 40 + (i * 2);
        v.CheckOut_Accuracy_m__c = 12;
        v.Check_In_Date__c = visitStart;
        v.Check_Out_Date__c = visitEnd;
        v.Check_In_Address_Line__c = 'Gedung Grha ' + accName + ', ' + cityName + ', Indonesia';
        v.Check_Out_Address_Line__c = 'Gedung Grha ' + accName + ', ' + cityName + ', Indonesia';
        v.General_Note_about_Meeting__c = 'Pertemuan tatap muka membahas proposal paket kegiatan di ' + loc + '. Klien sangat antusias dengan program edukasi satwa dan safari journey.';
        v.Metter_Discussed__c = 'Rundown acara, paket F&B buffet makan siang, koordinasi bus, fasilitas safari trek.';
        v.Need__c = 'Gathering tahunan perusahaan untuk mempererat sinergi karyawan.';
        v.Budget__c = (opp.Amount != null) ? opp.Amount : 100000000;
        v.Authority__c = (Math.mod(i, 2) == 0) ? 'Committee/Multiple Stakeholders' : 'Single Decision Maker';
        v.Timeline__c = (Math.mod(i, 2) == 0) ? 'This Quarter' : 'This Month';
        v.Follow_Up_Action_Detail__c = 'Kirim draft kontrak revisi, finalisasi menu makan siang, dan invoice termin Down Payment.';
    } else {
        // Upcoming visit
        v.Subject = 'Scheduled Field Visit: Final Koordinasi ' + accName;
        v.Inside_Geofence_on_CheckIn__c = false;
        v.General_Note_about_Meeting__c = 'Agenda pertemuan persiapan final dan penandatanganan konfirmasi kedatangan.';
        v.Authority__c = 'Committee/Multiple Stakeholders';
        v.Timeline__c = 'This Quarter';
    }
    
    visitEvents.add(v);
}

// 2. Generate Follow-up Tasks (18 Tasks across Opportunities & Accounts)
String[] taskSubjects = new String[]{
    'Kirim Proposal Penawaran Paket & Rundown Acara Lengkap',
    'Follow Up Konfirmasi Pembayaran Down Payment (DP) Termin 1',
    'Koordinasi Alokasi Unit Bus Pariwisata & Akses Jalur Khusus',
    'Kirim Draft Surat Perjanjian Kerjasama (PKS) Gathering',
    'Telepon Konfirmasi PIC Jumlah Peserta Final & Menu Makanan Khusus',
    'Pengiriman Dokumen Invoice Pelunasan H-7 Pelaksanaan Kegiatan',
    'Review Permohonan Diskon Korporat Khusus dengan Sales Manager',
    'Follow Up Penerbitan Purchase Order (PO) Resmi dari Procurement',
    'Penyusunan Rundown Acara Detail & Briefing Fasilitator Outbound',
    'Kirim E-Voucher Tiket Barcode & Akses Gate Masuk ke PIC Klien',
    'Kirim Kuesioner Evaluasi Kepuasan Klien Pasca Kunjungan',
    'Follow Up Validasi Tanggal Kunjungan Study Tour Sekolah'
};

for (Integer i = 0; i < opps.size() && i < 18; i++) {
    Opportunity opp = opps[i];
    Contact cnt = contactsByAccount.get(opp.AccountId);
    
    Task t = new Task();
    t.WhatId = opp.Id;
    t.WhoId = (cnt != null) ? cnt.Id : null;
    t.OwnerId = opp.OwnerId;
    t.Subject = taskSubjects[Math.mod(i, taskSubjects.size())] + ' - ' + opp.Name;
    
    Integer dayOffset = Math.mod(i, 7) - 3;
    t.ActivityDate = today.addDays(dayOffset);
    
    if (dayOffset < 0) {
        t.Status = 'Completed';
        t.Priority = (Math.mod(i, 2) == 0) ? 'High' : 'Normal';
    } else if (dayOffset == 0) {
        t.Status = 'In Progress';
        t.Priority = 'High';
    } else {
        t.Status = 'Not Started';
        t.Priority = (Math.mod(i, 2) == 0) ? 'High' : 'Normal';
    }
    
    t.Description = 'Tindak lanjut operasional penjualan B2B Taman Safari untuk deal ' + opp.Name + '. PIC bertanggung jawab memastikan seluruh persyaratan administratif dan operasional terpenuhi.';
    activityTasks.add(t);
}

insert visitEvents;
insert activityTasks;

System.debug('SUCCESS: Created ' + visitEvents.size() + ' Visit Events and ' + activityTasks.size() + ' Tasks.');
