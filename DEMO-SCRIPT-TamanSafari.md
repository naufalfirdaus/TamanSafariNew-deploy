# Skrip Video Demonstrasi — Taman Safari Indonesia

Skrip pengambilan video untuk demo Salesforce **Taman Safari Indonesia**, dua persona: **Sales** internal dan **Partner** afiliasi.

- **Org**: `TamanSafariNew` — `https://pt1787027311648.my.salesforce.com`
- **Portal Partner**: `https://pt1787027311648.my.site.com/tamansafari`
- **Total durasi target**: ±14 menit (Sales 8 menit, Partner 5 menit, penutup 1 menit)

Setiap adegan berisi **Aksi layar** (yang dilakukan) dan **Narasi** (yang diucapkan). Narasi ditulis untuk dibacakan langsung.

---

## Persiapan Sebelum Rekam

| # | Item | Keterangan |
|---|---|---|
| 1 | Dua browser terpisah | Chrome biasa untuk Sales, Incognito untuk Partner — supaya tidak perlu logout |
| 2 | Login Sales | `demo.me@sdo.com`, buka **App Launcher → Taman Safari** |
| 3 | Login Partner | `ahmad.nfirdaus+zainal@langitkreasi.com` / `Slipi2026` |
| 4 | Izin lokasi browser | Wajib **Allow** — adegan check-in butuh GPS |
| 5 | Zoom browser 100% | Supaya teks terbaca di video |
| 6 | Bersihkan Event uji | Hapus Event `Check-In ...` sisa percobaan agar timeline bersih |
| 7 | Sembunyikan bookmark bar | Layar lebih rapi |

> **Penting soal nominal.** Commission Statement memuat angka sangat besar (tiket.com Rp197 miliar, @explorebatang Rp90 miliar) — terbawa dari org sumber. Untuk video yang ditonton pihak eksternal, sebaiknya diskalakan dulu ke angka wajar, atau hindari menyorot kolom itu.

---

# BAGIAN 1 — PERSONA SALES (±8 menit)

## Adegan 1.1 — Pembuka (30 detik)

**Aksi layar:** App Launcher terbuka, klik app **Taman Safari**. Berhenti di halaman Home.

**Narasi:**
> "Taman Safari Indonesia menjual lewat dua jalur: tim sales internal yang menggarap korporat, sekolah, dan instansi pemerintah; serta jaringan mitra afiliasi yang menjual tiket lewat kanal mereka sendiri. Keduanya berjalan di atas satu platform Salesforce. Saya mulai dari sisi sales."

## Adegan 1.2 — Pipeline (45 detik)

**Aksi layar:** Tab **Opportunities** → list view record type Taman Safari. Scroll pelan.

**Narasi:**
> "Ini pipeline Taman Safari — 17 opportunity yang tersebar di enam stage."

| Stage | Jumlah | Sorot |
|---|---|---|
| Qualification | 5 | |
| Discovery | 2 | |
| Proposal/Quote | 1 | |
| Negotiation | 3 | **Nusantara EO - MICE Batang, Rp34.500.000** |
| Closed Won | 3 | Interdesign - Team Building Prigen, Rp26.800.000 |
| Closed Lost | 3 | |

> "Semua segmen ada di satu tempat — dari study tour sekolah sampai MICE korporat bernilai puluhan juta."

## Adegan 1.3 — Lead dan Path (40 detik)

**Aksi layar:** Tab **Leads** → buka **Interdesign, PT** (Ahmad Naufal Firdaus - Test TS). Sorot Path di bagian atas.

**Narasi:**
> "Setiap lead punya layout dan Path khusus Taman Safari. Path ini memandu sales soal langkah berikutnya, dan statusnya terlihat sekilas."

## Adegan 1.4 — Check-in kunjungan **(adegan utama, 2 menit)**

Ini bagian paling penting untuk divideokan. Rekam dua skenario berurutan.

### 1.4a — Check-in ditolak karena di luar radius (50 detik)

**Aksi layar:** Buka Lead **Maju Jaya, PT** (`00QjV000000SrEHUA0`). Sorot panel **Geo Check-In** di sidebar kanan — badge merah **OUTSIDE**, jarak ratusan kilometer. Klik tombol **Check-In**.

**Narasi:**
> "Sebelum berkunjung, setiap lead punya titik lokasi dan radius geofence — di sini 300 meter. Lead Maju Jaya berlokasi di Gresik, sementara saya di Jakarta. Saat saya tekan Check-In..."

**Aksi layar:** Error muncul seketika, kolom "Alasan override" tampil. **Tidak ada modal foto maupun tanda tangan.**

**Narasi:**
> "...sistem langsung menolak dan menyebutkan jaraknya. Perhatikan, saya tidak diminta foto atau tanda tangan sama sekali — validasi jarak dijalankan lebih dulu, jadi sales tidak membuang waktu mengisi apa pun kalau memang belum sampai lokasi. Kalau ada alasan sah, misalnya pertemuan dipindah, tinggal isi kolom override dan lanjut. Alasannya tersimpan sebagai jejak audit."

### 1.4b — Check-in berhasil (70 detik)

**Aksi layar:** Buka Lead **Garutmerdeka.inc** (`00QjV000000SrEIUA0`). Badge hijau **INSIDE**. Klik **Check-In**.

**Narasi:**
> "Sekarang lead yang titik lokasinya memang di posisi saya. Statusnya INSIDE."

**Aksi layar:** Modal **foto** muncul → ambil foto → **Confirm**. Modal **tanda tangan** muncul → bubuhkan tanda tangan → **Confirm**.

**Narasi:**
> "Karena posisi valid, barulah sistem meminta bukti kunjungan: foto lokasi, lalu tanda tangan pihak yang ditemui."

**Aksi layar:** Panel berubah — tombol jadi **Already Checked-In**, muncul tag **Open Event Active**.

**Narasi:**
> "Check-in tercatat. Salesforce otomatis membuat record Event berisi koordinat, jarak ke target, akurasi GPS, dan status geofence — semuanya terekam tanpa input manual."

## Adegan 1.5 — Check-out dan hasil kunjungan (60 detik)

**Aksi layar:** Klik tombol **Open Event** di panel. Halaman Event terbuka. Buka tab **Details**, scroll ke section **Check-In**.

**Narasi:**
> "Dari panel tadi saya buka record Event-nya. Di section Check-In terlihat lengkap: waktu, koordinat, jarak dari target, akurasi, dan status di dalam geofence."

**Aksi layar:** Sorot panel **Check-Out** di sidebar kanan. Klik **Check-Out**.

**Narasi:**
> "Saat kunjungan selesai, sales melakukan check-out dari halaman yang sama. Sistem merekam ulang lokasi dan waktu, sehingga durasi kunjungan terhitung otomatis."

**Aksi layar:** Scroll ke section **Check-Out** dan **Hasil Kunjungan**. Isi catatan meeting dan tindak lanjut.

**Narasi:**
> "Terakhir, sales mencatat hasil pertemuan — apa yang dibahas dan tindak lanjutnya. Satu kunjungan lapangan terdokumentasi utuh: lokasi terverifikasi, bukti foto, tanda tangan, dan notulen."

## Adegan 1.6 — Anatomi deal (50 detik)

**Aksi layar:** Buka Opportunity **Nusantara EO - MICE Batang**. Sorot berurutan: Path → Products → Activity timeline.

**Narasi:**
> "Kembali ke deal. Opportunity MICE Batang senilai Rp34,5 juta ini berisi dua produk dari Taman Safari Pricebook — Paket Full Journey 2 hari 1 malam sebanyak 10 unit, dan Sesi Team Building 10 unit. Di timeline aktivitas terlihat task kunjungan lapangan yang sudah selesai. Seluruh konteks deal ada di satu halaman."

## Adegan 1.7 — Katalog produk (30 detik)

**Aksi layar:** Buka **Taman Safari Pricebook**.

**Narasi:**
> "Katalognya mencakup sepuluh produk lintas kategori — tiket masuk empat lokasi safari, akomodasi resort, transport, konsumsi, sesi team building, sampai paket bundling."

| Produk | Harga |
|---|---|
| Tiket Masuk Taman Safari Bali | Rp400.000 |
| Tiket Masuk Taman Safari Bogor | Rp200.000 |
| Tiket Masuk Taman Safari Prigen | Rp180.000 |
| Tiket Masuk Beach Safari Batang | Rp150.000 |
| Akomodasi Resort - Standard Room | Rp500.000 |
| Sesi Team Building | Rp2.500.000 |
| Transport Bus Antar Jemput | Rp1.500.000 |
| Paket Makan Siang Group | Rp75.000 |
| Paket Corporate Gathering 1 Hari | Rp350.000 |
| Paket Full Journey 2H1M | Rp950.000 |

## Adegan 1.8 — Guardrail aturan bisnis (40 detik)

**Aksi layar:** Buka **Interdesign - Corporate Gathering Q3** (Negotiation). Ubah stage ke **Closed Won** tanpa mengisi Nomor PO → **Save**. Error muncul.

**Narasi:**
> "Aturan bisnis ditegakkan platform. Opportunity tidak bisa ditutup sebagai Closed Won tanpa nomor PO."

> "Ada tiga guardrail serupa: wajib nomor PO sebelum Closed Won, wajib alasan kekalahan sebelum Closed Lost, dan wajib ada produk sebelum masuk tahap quotation. Data pipeline jadi bisa dipercaya tanpa bergantung pada disiplin masing-masing orang."

**Aksi layar:** Batalkan perubahan (jangan simpan).

## Adegan 1.9 — Quotation, approval, dan PDF (70 detik)

**Aksi layar:** Dari opportunity yang sama, buka **Quotation Interdesign - Corporate Gathering** (status Approved).

**Narasi:**
> "Quotation dengan diskon di atas 20 persen wajib melewati persetujuan. Quotation ini sudah disetujui, dan jejak approval-nya tercatat."

**Aksi layar:** Klik tombol **Preview and Send Quotation**.

**Narasi:**
> "Sekali klik, sistem me-render quotation jadi PDF ber-branding Taman Safari, menyimpannya sebagai file yang tertaut ke record, mengirimkannya ke email klien sebagai lampiran, dan mencatat pengiriman itu di Activity Timeline. Empat langkah manual selesai dalam satu aksi."

## Adegan 1.10 — Termin Pembayaran Otomatis (60 detik)

**Aksi layar:** Buka Opportunity **Telkomsel - Annual Outing Taman Safari Bogor** (Rp175.000.000). Sorot kolom **Payment Terms** (3 termin) dan section **Payments**.

**Narasi:**
> "Untuk transaksi B2B bernilai ratusan juta, pembayaran jarang dilakukan sekaligus. Di sini kita tentukan 3 termin. Begitu termin diisi, Salesforce otomatis membuat jadwal cicilan yang terbagi rata lengkap dengan tanggal jatuh tempo setiap 30 hari. Perhatikan pula bahwa setelah proposal disetujui, termin pembayaran dikunci otomatis oleh sistem agar kesepakatan finansial tidak bisa diubah sepihak tanpa otorisasi."

## Adegan 1.11 — Sales Forecast & Pencapaian Target (60 detik)

**Aksi layar:** Buka tab **Forecasts** di aplikasi Taman Safari. Tampilkan tampilan hierarki manajer dan breakdown target tim.

**Narasi:**
> "Pertanyaan penting manajemen: apakah target bulan ini akan tercapai? Di tab Forecasts, manajemen bisa melihat posisi pipa penjualan secara real-time. Target Sales Rep Rp500 juta dan target Manager Rp1 miliar terbagi dalam kategori Commit, Best Case, dan Pipeline. Angka dari rep langsung terakumulasi ke level manajer tanpa rekapitulasi spreadsheet manual. Manajemen tahu persis angka pasti yang sudah di tangan dan potensi closing di akhir bulan."

## Adegan 1.12 — Knowledge Base Sales Playbook (30 detik)

**Aksi layar:** Buka tab **Knowledge** atau panel Knowledge di sidebar, sorot artikel **SOP & Panduan Praktis: Canvassing Sales B2B Corporate**.

**Narasi:**
> "Dan untuk menjaga konsistensi tim sales di lapangan, SOP canvassing dan panduan penawaran tersimpan rapi di Knowledge Base internal yang bisa diakses langsung dari sistem."

---

# BAGIAN 2 — PERSONA PARTNER (±5 menit)

Pindah ke jendela Incognito.

## Adegan 2.1 — Login portal (30 detik)

**Aksi layar:** Buka `https://pt1787027311648.my.site.com/tamansafari`, login sebagai Zainal.

**Narasi:**
> "Sekarang sisi mitra. Zainal Abidin adalah pemilik Cipta Travel, agen perjalanan yang menjual tiket Taman Safari lewat toko offline, OTA, dan kampanye promo. Dia punya portal sendiri."

## Adegan 2.2 — Ringkasan komisi (40 detik)

**Aksi layar:** Halaman **Kode Afiliasi dan Komisi Saya**. Sorot banner ringkasan di atas.

**Narasi:**
> "Begitu masuk, Zainal langsung melihat posisi komisinya — berapa yang sudah dibayar dan berapa yang masih berjalan. Yang penting: dia hanya melihat data miliknya sendiri. Isolasi data ini ditangani sharing model Salesforce, bukan filter yang ditulis manual di kode."

## Adegan 2.3 — Kode afiliasi per kanal (50 detik)

**Aksi layar:** Scroll ke daftar kode afiliasi.

**Narasi:**
> "Cipta Travel punya lima kode aktif, satu untuk tiap kanal penjualan."

| Kode | Kanal |
|---|---|
| `CIPTABALI01` | Offline Store |
| `CIPTAOTA01` | OTA |
| `CIPTAPROMO` | Campaign |
| `CIPT80054` | TikTok |
| `TEST7912` | TikTok |

> "Dengan kode terpisah per kanal, Taman Safari maupun mitranya bisa mengukur kanal mana yang benar-benar menghasilkan."

## Adegan 2.4 — Minta kode baru (40 detik)

**Aksi layar:** Jalankan flow **Request New Affiliate Code**. Isi kanal dan periode. Submit.

**Narasi:**
> "Kalau butuh kode baru untuk kampanye, mitra tidak perlu menghubungi admin Taman Safari. Dia isi kanal dan masa berlaku, kode terbit saat itu juga."

## Adegan 2.5 — Redemption dan komisi (60 detik)

**Aksi layar:** Buka daftar **Redemption**.

**Narasi:**
> "Setiap tiket yang terjual lewat kode ini tercatat sebagai redemption, lengkap dengan nomor booking, kategori produk, jumlah, dan komisi 10 persen yang dihitung otomatis."

| Booking Ref | Kategori | Qty | Status |
|---|---|---|---|
| BK-2026-2001 | Bundled Package | 12 | Statemented |
| BK-2026-2050 | Ticket & Voucher | 31 | Statemented |
| BK-2026-2090 | Ticket & Voucher | 4 | Accrued |
| BO-92321-2026 | Ticket & Voucher | 5 | Accrued |

> "Statusnya bergerak dari Accrued — komisi terkumpul, ke Statemented — sudah masuk tagihan periode. Mitra tahu persis mana yang masih berjalan dan mana yang sudah ditagihkan."

## Adegan 2.6 — Siklus pembayaran komisi (50 detik)

**Aksi layar:** Buka daftar **Commission Statement**. *(Hindari menyorot kolom nominal bila belum diskalakan.)*

**Narasi:**
> "Komisi ditagihkan per periode. Cipta Travel punya dua statement: periode Juni–Juli sudah berstatus Paid, periode Juli–Agustus sedang Eligible untuk diklaim."

> "Siklus lengkapnya melewati enam status — Draft, Issued, Eligible, Claimed, Approved, hingga Paid. Seluruh prosesnya transparan bagi kedua pihak."

## Adegan 2.7 — Redeem oleh tamu (50 detik)

**Aksi layar:** Buka halaman **Guest Redeem Voucher** (tanpa login). Masukkan `DENPASAROLD` → tampil error. Lalu masukkan `CIPTAPROMO` → valid, isi data booking, submit.

**Narasi:**
> "Terakhir, tamu yang datang membawa kode bisa redeem sendiri tanpa punya akun. Kode kedaluwarsa langsung ditolak. Kode yang valid diteruskan, dan di balik layar Salesforce otomatis membuat opportunity retail beserta record redemption — komisi mitra tetap tercatat."

---

# BAGIAN 3 — PENUTUP (±1 menit)

**Aksi layar:** Kembali ke jendela Sales. Buka Opportunity **Redeem - CIPTAPROMO - 2026-08-11** (Closed Won, Rp1.000.000) pada Account *Retail Customer - Voucher Redemption*.

**Narasi:**
> "Dan inilah yang menghubungkan keduanya. Opportunity ini terbentuk otomatis dari redemption yang tadi dilakukan lewat kode Cipta Travel. Aksi mitra di portal langsung muncul sebagai revenue di pipeline Taman Safari."

> "Satu platform, dua persona, satu sumber kebenaran — dari kunjungan lapangan yang terverifikasi lokasi, sampai komisi mitra yang terhitung otomatis."

| Untuk Taman Safari | Untuk Mitra |
|---|---|
| Pipeline seluruh segmen dalam satu tampilan | Portal mandiri 24 jam |
| Kunjungan sales terverifikasi lokasi | Kode afiliasi terbit tanpa menunggu admin |
| Aturan bisnis ditegakkan otomatis | Komisi terhitung transparan |
| Revenue afiliasi masuk pipeline otomatis | Status pembayaran jelas per periode |

---

## Lampiran — Data & Tautan Cepat

### Lead untuk adegan check-in

| Company | Skenario | Record Id |
|---|---|---|
| **Garutmerdeka.inc** | INSIDE — check-in berhasil | `00QjV000000SrEIUA0` |
| **Maju Jaya, PT** | OUTSIDE — uji override | `00QjV000000SrEHUA0` |
| Interdesign, PT | Jakarta Barat | `00QjV000000SqlFUAS` |
| Code Development Indonesia, PT | Bandung | `00QjV000000SqlGUAS` |

Radius geofence semuanya 300 meter. Kalau lokasi rekaman berpindah, gunakan tombol **Set Target Here** pada lead yang akan dipakai adegan berhasil.

### Isi data demo

| Object | Jumlah |
|---|---|
| Lead Taman Safari | 4 |
| Opportunity Taman Safari | 17 |
| OpportunityLineItem | 22 |
| Task | 10 |
| Affiliate Code | 13 |
| Redemption | 13 |
| Commission Statement | 7 |

### Perhatian saat adegan penutup

Ada **tiga** opportunity bernama `Redeem - CIPTAPROMO - 2026-08-11`. Yang dipakai untuk penutup adalah yang berstatus **Closed Won senilai Rp1.000.000** — dua lainnya berstatus Qualification senilai Rp400.000 dan bukan hasil redemption yang diceritakan.

Buka langsung lewat tautan ini agar tidak salah pilih:
`https://pt1787027311648.my.salesforce.com/lightning/r/Opportunity/006jV000000ApxYQAS/view`

### Catatan teknis

- **Halaman Event.** Panel Check-Out hanya muncul bila Event dibuka dari dalam **app Taman Safari** — penugasan halamannya diatur di level app untuk record type `Geolocation`.
- **Reverse geocoding.** Nama alamat check-in diambil dari API Geoapify memakai kunci bawaan. Bila kuotanya habis, kolom alamat bisa kosong — koordinat dan validasi geofence tetap berjalan normal.
- **Mata uang.** IDR aktif dengan kurs 1 dan tanpa desimal, jadi nominal tampil sebagai Rupiah.
