# Rencana Demo Salesforce — Taman Safari Indonesia

Dokumen ini mendefinisikan rencana skenario demonstrasi solusi Salesforce untuk Taman Safari Indonesia, mencakup dua persona utama: **Internal Sales Team** dan **Partner Afiliasi**.

## 1. Informasi Lingkungan Demo
- **Klien**: Taman Safari Indonesia
- **Org Demo**: Scratch Org `TamanSafari` (`00DBh000002j6ZZMAY`), masa berlaku s/d 26 Oktober 2026
- **Aplikasi**: `Taman Safari` (Lightning App)
- **Portal Mitra**: Experience Cloud Site (`/tamansafari`)

## 2. Persona & Kredensial
| Persona | User / Role | Tujuan Demonstrasi |
|---|---|---|
| **Sales Manager** | `teamlead1792180335630@tamansafaridemo.com` | Monitoring pipeline, persetujuan diskon, supervisi kunjungan sales, evaluasi target forecast tim. |
| **Sales Representative** | `testsales@tsi.com` | Eksekusi canvassing lapangan, geo check-in/out, penyusunan penawaran, penjadwalan termin pembayaran. |
| **Mitra Afiliasi** | `ahmad.nfirdaus+zainal@langitkreasi.com` | Mengakses portal partner, monitoring komisi mandiri, request kode promo baru. |

## 3. Alur Skenario Demo

### Bagian 1: Persona Sales Internal (±8 Menit)
1. **Pipeline & Peluang Penjualan**: Tinjauan 5 Opportunity dari berbagai segmen bisnis (Study tour sekolah, MICE korporat).
2. **Validasi Lokasi Taman**: Bukti sistem menolak pemilihan tiket lokasi taman lain pada opportunity preferred location tertentu.
3. **Geo Check-In Lapangan (Adegan Utama)**:
   - Skenario A: Check-in ditolak seketika karena posisi berada di luar radius geofence (>300 meter).
   - Skenario B: Check-in berhasil pada lokasi yang valid, mewajibkan bukti foto dan tanda tangan digital.
4. **Quotation & Approval Flow**: Penawaran dengan diskon >20% melewati approval, generasi PDF otomatis, dan pengiriman email.
5. **Termin Pembayaran Bertahap (`Payment__c`)**: Penjadwalan termin pembayaran otomatis (cicilan merata, interval 30 hari) dan penguncian termin setelah tahap Proposal/Quote.
6. **Collaborative Forecasts**: Visualisasi target vs realisasi (Commit, Best Case, Pipeline) dengan rollup otomatis dari Rep ke Manager.
7. **Knowledge Base Playbook**: Akses langsung ke SOP canvassing B2B dari sistem.

### Bagian 2: Persona Mitra Afiliasi (±5 Menit)
1. **Login Portal Mitra**: Pengalaman akses mandiri tanpa lisensi internal penuh.
2. **Ringkasan Komisi**: Visualisasi total komisi yang sudah dibayar (*Paid*) dan yang sedang berjalan (*Accrued*).
3. **Manajemen Kode Afiliasi Multi-Kanal**: Penggunaan kode unik per kanal penjualan (Offline, OTA, TikTok).
4. **Penerbitan Kode Otomatis**: Self-service flow permintaan kode baru untuk kampanye mendatang.
5. **Redemption & Transparansi Perhitungan**: Detail transaksi per nomor booking dan komisi otomatis 10%.
