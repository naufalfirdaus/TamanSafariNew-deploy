# Taman Safari Scratch Org Backup - 2026-10-22 (Full Backup with Activities)

## Overview
- **Backup Date:** 2026-10-22
- **Source Scratch Org:** `TamanSafari`
- **Org ID:** `00DBh000002j6ZZMAY`
- **Admin Username:** `teamlead1792180335630@tamansafaridemo.com`
- **Sales User:** `testsales@tsi.com`
- **Partner User:** `ahmad.nfirdaus+zainal@langitkreasi.com`
- **Expiration Date:** 2026-10-26
- **Test Integrity:** 36/36 Apex Test Methods Passing (100% Pass Rate).

---

## 1. Data Inventory (`data/`)

| Object | File Mentah & Bersih | Records | Keterangan |
| :--- | :--- | :--- | :--- |
| `Opportunity` | `Opportunity.json` / `.clean.json` | 25 records | Pipeline senilai Rp 3.129.500.000 (3,12 Miliar) di 4 lokasi taman |
| `Payment__c` | `Payment__c.json` / `.clean.json` | 57 records | Termin pembayaran bertahap (Down Payment, Termin Progresif, Pelunasan) |
| `Event` | `Event.json` / `.clean.json` | 29 records | Aktivitas kunjungan lapangan (Field Visits Canvassing) dengan GPS Geofencing & kualifikasi BANT |
| `Task` | `Task.json` / `.clean.json` | 23 records | Tugas operasional & follow-up penagihan/logistik sepanjang pipeline |
| `Account` | `Account.json` / `.clean.json` | 20 records | Akun B2B korporat (BUMN, International School, MNC, Swasta) |
| `Contact` | `Contact.json` / `.clean.json` | 19 records | PIC & Decision Maker tiap korporasi |
| `Product2` | `Product2.json` / `.clean.json` | 15 records | Katalog tiket & paket wisata ber-tag `Park_Location__c` |
| `PricebookEntry` | `PricebookEntry.json` / `.clean.json` | 45 records | Active pricebook entries untuk Standard & B2B Custom Pricebook |
| `OpportunityLineItem` | `OpportunityLineItem.json` / `.clean.json` | 45 records | Line items produk untuk 25 deal |
| `ForecastingQuota` | `ForecastingQuota.json` / `.clean.json` | 6 records | Quota Q4 2026 untuk Sales User (Rp 500 Jt/bln) & Manager (Rp 1 M/bln) |
| `Lead` | `Lead.json` / `.clean.json` | 8 records | Inbound leads B2B gathering & study tour |
| `Knowledge__kav` | `Knowledge__kav.json` / `.clean.json` | 1 record | SOP B2B Canvassing & Field Sales Playbook |
| `UserRole` | `UserRole.json` / `.clean.json` | 2 records | Role hierarchy: Sales Manager -> Sales Rep |

---

## 2. Metadata Inventory (`metadata/unpackaged/`)

Formulir metadata lengkap yang diexport via Salesforce Metadata API v60.0 (`package.xml`):

### A. Portal Experience Cloud (Mitra Afiliasi)
- **`experiences/Taman_Safari1`**: ExperienceBundle lengkap (views, routes, themes, branding set, config, termasuk halaman khusus `kodeAfiliasiDanKomisiSaya` dan `viewVouchers`).
- **`networks/Taman Safari.network`**: Konfigurasi membership partner, login, dan registrasi mandiri.
- **`sites/Taman_Safari.site`**: Definisi URL path `/tamansafari`.

### B. Lightning Web Components (19 LWC)
- `affiliateCommissionSummary`: Widget komisi mitra (Paid vs Accrued, 10%).
- `guestRedeemVoucher`: Form validasi & redeem voucher tiket tamu.
- `fieldVisitExperience`: Core container aplikasi canvassing sales B2B.
- `visitTelemetryBar`: Bar metrik GPS accuracy, visit duration timer, dan geofence status.
- `visitGeofenceModal`: Modal penolakan jika posisi sales di luar 300 meter.
- `photoCaptureModal`: Bukti foto kamera kunjungan lapangan.
- `signaturePadModal`: Canvas tanda tangan digital PIC klien.
- `visitAuditMap`: Peta rute & posisi check-in Leaflet/Geoapify.
- Komponen pendukung: `visitActiveInfo`, `visitTargetCard`, `visitQualificationForm`, `visitCompletionSummary`, `visitCheckoutPanel`, `visitContactCreateModal`, `visitCancelModal`, `visitShortDurationModal`, `visitStickyBottomBar`, `retryAiScoring`, `fieldVisitUtils`.

### C. Apex Classes (57 Kelas) & Triggers (6 Trigger)
- **Financial & Payment**: `OpportunityPaymentScheduler`, `OpportunityPaymentSchedulerTest`, `OpportunityPaymentTrigger`.
- **Portal & Quotes**: `AffiliateCommissionSummaryController`, `GuestRedeemVoucherController`, `QuoteTemplatePDFController`.
- **Field Visit & Geolocation**: `VisitPipelineService`, `VisitLifecycleService`, `VisitGeofenceService`, `VisitProofService`, `VisitAIScoringSweepJob`, `VisitTelemetryScorer`, `GeoapifyService`, `geoapifyController`, `Test_Geolocation`.
- **Triggers**: `OpportunityPaymentTrigger`, `AccountTrigger`, `LeadTrigger`, `VisitFormTrigger`, `ContentDocumentTrigger`.

### D. Validation Rules (7 Aturan Kunci)
1. `Opportunity.Payment_Required_Before_Closed_Won`
2. `Opportunity.Payment_Terms_Locked_After_Proposal`
3. `Opportunity.Payment_Terms_Rules`
4. `OpportunityLineItem.Product_Must_Match_Park_Location`
5. `Opportunity.Wajib_PO_Sebelum_Closed_Won`
6. `Opportunity.Wajib_produk_sebelum_quotation`
7. `Opportunity.Wajib_Loss_Reason_Sebelum_Closed_Lost`

### E. Flows (3 Flows)
1. `Request_New_Affiliate_Code.flow`
2. `Redeem_Affiliate_Voucher.flow`
3. `sfdc_default_ReportExport_Protection_Flow.flow`

---

## 3. Peta Halaman di `ai-memory` (27 Halaman)

| Kategori | Path di `ai-memory` |
| :--- | :--- |
| **Aktivitas & Kunjungan** | `backup/tamansafari-data/events_and_visits.md`, `backup/tamansafari-data/tasks_and_activities.md`, `concepts/tamansafari-sales-activities-and-canvassing.md` |
| **Portal Experience Cloud** | `backup/tamansafari-metadata/portal_experience_cloud.md` |
| **Lightning Web Components** | `backup/tamansafari-metadata/lightning_web_components.md` |
| **Apex Classes & Triggers** | `backup/tamansafari-metadata/apex_classes_and_triggers.md` |
| **Validation Rules & Flows** | `backup/tamansafari-metadata/validation_rules_and_automations.md` |
| **Data Mentah Utama** | `backup/tamansafari-data/opportunities.md`, `payments.md`, `accounts.md`, `contacts.md`, `products.md`, `pricebook_entries.md`, `opportunity_line_items.md`, `forecasting_quotas.md`, `leads.md`, `knowledge_and_roles.md` |
| **Arsitektur & Rehidrasi** | `concepts/tamansafari-system-architecture.md`, `concepts/tamansafari-data-pipeline.md`, `_rules/tamansafari-business-rules.md`, `decisions/tamansafari-payment-scheduler-design.md`, `decisions/tamansafari-scratch-org-restore-procedure.md`, `notes/tamansafari-demo-execution-playbook.md` |

---

## 4. Cara Restore / Rehidrasi ke Org Baru

Jika scratch org kedaluwarsa setelah 26 Oktober 2026:

1. **Buat Scratch Org baru:**
   ```bash
   sf org create scratch -f config/project-scratch-def.json -a TamanSafariNew -d 30
   ```

2. **Deploy Full Metadata (Portal, Apex, LWC, VR, dsb):**
   ```bash
   sf project deploy start -d backup/TamanSafari-BACKUP-20261022/metadata/unpackaged -o TamanSafariNew
   ```

3. **Assign Permission Sets:**
   ```bash
   sf org assign permset -n Opportunity_Payment_Access -o TamanSafariNew
   sf org assign permset -n Forecast_Access -o TamanSafariNew
   sf org assign permset -n Knowledge_Article_Author -o TamanSafariNew
   ```

4. **Jalankan Seeder Data Utama:**
   ```bash
   sf apex run -f scripts/data/tamansafari/seed_tamansafari_demo.apex -o TamanSafariNew
   ```

5. **Jalankan Seeder Aktivitas (Visits & Tasks):**
   ```bash
   sf apex run -f scripts/data/tamansafari/seed_tamansafari_activities.apex -o TamanSafariNew
   ```

6. **Verifikasi Test Suite:**
   ```bash
   sf apex run test -l RunLocalTests -c -r human -o TamanSafariNew
   ```
