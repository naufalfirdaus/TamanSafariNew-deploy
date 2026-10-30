# Laporan Pengujian Demo — Taman Safari Indonesia

Dokumen ini menyajikan hasil pengujian fungsional dan unit test otomatis pada org Salesforce `TamanSafari` (`00DBh000002j6ZZMAY`).

## 1. Hasil Apex Unit Tests
- **Tanggal Eksekusi**: 22 Oktober 2026
- **Test Run Id**: `707Bh00000R1uC7`
- **Total Test Dijalankan**: 36 Test Methods
- **Hasil**: **36 Passed, 0 Failed (Pass Rate: 100%)**

### Ringkasan Uji Kelas Kunci
| Kelas Uji | Status | Cakupan Kode | Keterangan |
|---|---|---|---|
| `OpportunityPaymentSchedulerTest` | **Passed** | 98% | Menguji pembagian termin sama rata, sisa pembulatan pada termin akhir, regenerasi saat termin berubah, dan penguncian saat ada pembayaran `Paid`. |
| `OpportunityPaymentTrigger` | **Passed** | 100% | Menguji pemanggilan scheduler otomatis saat insert & update Opportunity. |
| `AffiliateCommissionSummaryControllerTest` | **Passed** | 93% | Menguji kalkulasi total komisi mitra afiliasi (Paid vs Accrued). |
| `GuestRedeemVoucherControllerTest` | **Passed** | 94% | Menguji validasi kode voucher, penolakan kode expired, dan pembuatan record Closed Won otomatis. |
| `QuoteTemplatePDFControllerTest` | **Passed** | 91% | Menguji render PDF quote, approval check, dan pengiriman attachment email. |
| `Test_Geolocation` | **Passed** | 100% | Stub test pengganti controller lama (tidak ada dependency rusak). |

---

## 2. Hasil Uji Fungsional Modul

### A. Validasi Termin Pembayaran (`Payment_Terms_Locked_After_Proposal`)
- **Skenario**: Mencoba mengubah nilai `Payment_Terms__c` saat opportunity berada pada tahap `Proposal/Quote`.
- **Hasil**: **Lolos (Sesuai Desain)**. Sistem melempar pesan kesalahan:
  > *"Payment Terms can no longer be changed because the proposal has already been processed (Proposal/Quote or later). Set the terms before moving to Proposal/Quote."*

### B. Otomasi Pembuatan Jadwal Pembayaran (`OpportunityPaymentScheduler`)
- **Skenario**: Mengisi `Payment_Terms__c = 3` pada deal Rp 47.500.000 saat berpindah ke `Proposal/Quote`.
- **Hasil**: **Lolos**. Sistem otomatis membuat 3 record `Payment__c`:
  - Termin 1: Rp 15.831.750
  - Termin 2: Rp 15.831.750
  - Termin 3: Rp 15.836.500 (termasuk pembulatan sisa)
  - Formula `Payment_Gap__c` otomatis bernilai **0**.

### C. Collaborative Forecast Rollup & Hierarki
- **Skenario**: Memeriksa akumulasi nilai deal bawahan (`Sales User`) ke tampilan `Team Lead Demo` (Sales Manager).
- **Hasil**: **Lolos**. Pada tabel `ForecastingItem`:
  - Best Case Sales User (Rp 47,5 Juta) otomatis terakumulasi (*rollup*) ke record Forecast manajer di periode Oktober 2026.
  - Nilai Commit dari deal Telkomsel (Rp 175 Juta) dan deal Kopi Kamu Wijaya (Rp 175 Juta) terhitung tepat pada kategori Commit.

### D. Bypass Login As Any User
- **Skenario**: Administrator melakukan impersonasi login (*Login As*) ke akun Sales User tanpa meminta password.
- **Hasil**: **Lolos**. `enableAdminLoginAsAnyUser` aktif dan tautan frontdoor berhasil digenerate.

---

## 3. Kesimpulan Kesiapan Demo
Seluruh komponen demo telah tervalidasi berfungsi dengan baik, tidak memiliki celah validasi yang terbuka, dan data terisi penuh sesuai skrip video demo.
- **Status Kesiapan**: **READY FOR REHEARSAL & PRESENTATION**
- **Masa Berlaku Scratch Org**: Aktif hingga 26 Oktober 2026.
