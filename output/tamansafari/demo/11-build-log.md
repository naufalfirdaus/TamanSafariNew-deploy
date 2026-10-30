# Catatan Build Metadata — Taman Safari Indonesia

Dokumen ini mencatat seluruh komponen metadata yang dibangun dan dideploy ke org `TamanSafari` (`00DBh000002j6ZZMAY`).

## 1. Custom Objects & Fields
- **`Payment__c`**:
  - Master-Detail ke `Opportunity` (`Opportunity__c`)
  - `Term_Number__c` (Number 2,0)
  - `Amount__c` (Currency 16,2)
  - `Due_Date__c` (Date)
  - `Status__c` (Picklist: Pending, Paid, Overdue, Cancelled)
- **`Opportunity` Fields**:
  - `Payment_Terms__c` (Number 2,0) — Jumlah termin (1–12)
  - `Total_Payment_Scheduled__c` (Roll-up Summary SUM `Payment__c.Amount__c`)
  - `Total_Paid__c` (Roll-up Summary SUM `Payment__c.Amount__c` WHERE `Status__c = 'Paid'`)
  - `Outstanding_Balance__c` (Formula Currency: `Amount - Total_Paid__c`)
  - `Payment_Gap__c` (Formula Currency: `Amount - Total_Payment_Scheduled__c`)
  - `Preferred_Park_Location__c` (Picklist: Taman Safari Bogor, Prigen, Bali, Beach Safari Batang, All Locations)
- **`Product2` Fields**:
  - `Park_Location__c` (Picklist: Taman Safari Bogor, Prigen, Bali, Beach Safari Batang, All Locations)

## 2. Validation Rules
- **`Opportunity.Payment_Terms_Locked_After_Proposal`**:
  Mengunci field `Payment_Terms__c` agar tidak dapat diubah setelah opportunity mencapai tahap `Proposal/Quote` atau lebih lanjut.
- **`Opportunity.Payment_Terms_Rules`**:
  Memvalidasi termin harus antara 1–12 dan dilarang diubah jika sudah ada pembayaran berstatus `Paid`.
- **`Opportunity.Payment_Required_Before_Closed_Won`**:
  Mewajibkan `Total_Paid__c >= Amount` sebelum deal dinyatakan `Closed Won` (jika `Payment_Terms__c > 0`).
- **`OpportunityLineItem.Product_Must_Match_Park_Location`**:
  Mencegah produk dari lokasi taman yang berbeda dipilih dalam satu opportunity kecuali produk bertipe "All Locations".

## 3. Apex Classes & Triggers
- **`OpportunityPaymentScheduler.cls`**:
  Service class untuk menghitung dan membuat record `Payment__c` secara merata berdasarkan jumlah termin dengan sisa pembulatan pada termin terakhir. Interval jatuh tempo default per 30 hari.
- **`OpportunityPaymentSchedulerTest.cls`**:
  Unit test suite (4 skenario uji, 98% code coverage).
- **`OpportunityPaymentTrigger.trigger`**:
  Trigger pada `Opportunity` (After Insert, After Update) yang memicu `OpportunityPaymentScheduler` saat `Payment_Terms__c` atau `Amount` berubah.
- **`Test_Geolocation.cls`**:
  Stub test pengganti class lama yang sudah dimigrasi ke `VisitPipelineService`.

## 4. Collaborative Forecasts & Hierarchy
- **Forecasting Type**: `OpportunityRevenue` (Active).
- **User Roles**:
  - `Taman Safari Sales Manager` (`00EBh000003mt25MAA`) — `ForecastUserId` = `005Bh000006MpN0IAK` (`Team Lead Demo`).
  - `Taman Safari Sales Rep` (`00EBh000003mt26MAA`) — Parent: `Taman Safari Sales Manager`.
- **Application Navigation**:
  - Tab `Forecasting3` (Forecasts) ditambahkan ke aplikasi `Taman_Safari`.

## 5. Security & Permission Sets
- **`enableAdminLoginAsAnyUser`**: Diaktifkan (`true`) pada `SecuritySettings`.
- **Permission Sets**:
  - `Opportunity_Payment_Access`: Hak akses Read/Create/Edit pada `Payment__c` dan field-field pembayaran di `Opportunity`.
  - `Forecast_Access`: Hak akses melihat dan mengelola Forecasts.
  - `Knowledge_Article_Author` & `Knowledge_Article_Reader`.
