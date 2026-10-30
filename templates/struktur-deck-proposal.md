# Struktur deck proposal Langit Kreasi (Canva)

Disarikan dari 11 proposal yang sudah dikirim: SKHA, APM/AUG, Movindo Gading Mas, Kafalah
Indonesia, Prambanan Kencana, Indospring, MNC Media, i3L University, Nusantara Funds, dan
Taman Safari Indonesia. Dipakai agent writer untuk menyusun
`output/<klien>/04-slide-outline.md`, yang kemudian disalin presales ke template Canva.

## Pengaturan per project
Dibaca dari bagian "Project ini" di `CLAUDE.md` project (diisi `presales-init`):
- **Bahasa deck**: `en` (default) atau `id` (Kafalah, i3L). Pada deck `id`, narasi berbahasa
  Indonesia, tetapi judul Scope of Work, Project Timeline, dan Commercial Detail tetap
  berbahasa Inggris.
- **Template deck**:
  - `label` (default): label bagian vertikal di sisi kiri.
  - `nomor` (APM, MNC): slide pembatas bernomor, yaitu 1 About Company, 2 Salesforce Solution,
    3 Project Timeline, 4 Commercial, 5 Customer Story.
- **Mata uang lisensi**: `USD` (SKHA, Kafalah, Taman Safari, i3L) atau `IDR` (APM, Movindo,
  Prambanan, Indospring, MNC). Untuk IDR, kurs wajib disebutkan di asumsi `03-pricing.md`.

Jenis slide:
- **[TETAP]**: isi sudah ada di template Canva; outline cukup menulis judulnya.
- **[PUSTAKA]**: slide generik yang dipakai ulang; tulis judulnya, sesuaikan bila perlu.
- **[KLIEN]**: ditulis ulang untuk setiap klien.
- **[OPSIONAL]**: hanya bila relevan.

---

## Urutan slide

| # | Bagian | Judul (en / id) | Jenis | Isi |
|---|---|---|---|---|
| 1 | Cover | Salesforce Solution Proposal — "Exclusive For: <logo klien>" + nomor quotation | KLIEN | Nomor: `QTN-<no>/LKS/<bulan romawi>/<tahun>` (mis. QTN-480/LKS/IV/2026); biarkan `QTN-___` bila belum ada. Paket LKS: "LKS Starterforce* Solution Proposal — Powered by Salesforce Platform" |
| 2 | Company | About Us / Tentang Langit Kreasi Solusindo | TETAP | |
| 3 | Company | Who We Are, Vision, Mission | TETAP | |
| 4 | Company | Our Services / Layanan Kami | TETAP | |
| 5 | Company | Our Portfolio / Portofolio Kami | TETAP | |
| 6 | Company | Salesforce certified team / Why LKS? | TETAP | |
| 7 | Objective | Objective / Tujuan Implementasi | KLIEN | 4–5 hasil bisnis |
| 8 | Solution | Pengenalan produk (mis. "Salesforce CRM for Customer Service – The World's #1 Intelligent CRM Platform", "Customer 360") | PUSTAKA/OPSIONAL | Untuk klien yang baru mengenal Salesforce |
| 9 | Solution | High Level Architecture | OPSIONAL | Bila ada beberapa produk, portal, atau integrasi |
| 10 | Solution | Journey (mis. "Sales Project Team Journey") | OPSIONAL | Alur persona → langkah → modul |
| 11..n | Solution | Satu slide per modul/proses | KLIEN | Judul + paragraf + screenshot |
| | Solution | Proses unik klien (mis. "Taman Safari Unique Process") | OPSIONAL | Proses khusus + catatan batasan |
| | Solution | Activity Is Important | PUSTAKA | Bila ada activity tracking |
| | Solution | Monitor Company Performance Anytime / Dashboard / Tableau | PUSTAKA/KLIEN | |
| | Solution | Comparison of Licenses | OPSIONAL | Dua opsi lisensi |
| | Commercial | Divider: "Commercial Proposal – <opsi>" | KLIEN | Satu divider per opsi |
| | Scope | Scope of Work | KLIEN | In Scope / Out of Scope (per opsi) |
| | Timeline | Project Timeline / Implementation Plan | KLIEN | Per opsi |
| | Commercial | Commercial Detail – License (Annual) | KLIEN | Per opsi |
| | Commercial | Commercial Detail – <item non-Salesforce> (mis. Server Automation) | OPSIONAL | |
| | Commercial | Commercial Detail – Premier Success (Optional) | OPSIONAL | Atau satu baris di tabel lisensi |
| | Commercial | Commercial TOP Detail | OPSIONAL | Kontrak multi-tahun |
| | Commercial | Commercial Detail – Implementation (One Time) | KLIEN | Per opsi |
| | Story | Customer Story (2–3) | TETAP | Pilih yang paling mirip industri klien |
| akhir | Closing | Thank you | TETAP | Kontak |
| lampiran | Commercial | Best Practice Offering (Optional) | OPSIONAL | Skenario alternatif setelah Thank you (Movindo) |

### Proposal dengan beberapa opsi
Bila ada lebih dari satu opsi (mis. Prambanan: "Sales Cloud & Marketing Cloud" vs "CRM only";
i3L: "Commercial without Mistral OCR" vs "Commercial with Mistral OCR"), setiap opsi punya
blok sendiri dengan urutan: divider opsi → Scope of Work → Project Timeline → License →
Implementation. Isi setiap blok hanya untuk opsi itu: timeline opsi tanpa Marketing Cloud tidak
boleh memuat pekerjaan Marketing Cloud. Skenario harga saja (Power of Us, upgrade edisi) cukup
satu slide lisensi tambahan, tanpa blok penuh.

### Contoh urutan slide solusi
- **SKHA** (Sales Cloud): Lead → Account → Contact → Opportunity → Quote → Project → Check in/out
  (mobile & web) → Activity Is Important → Monitor Company Performance.
- **APM** (pendidikan): Multi-Channel Lead Capture (n8n) → Marketing Performance Dashboard
  (Pardot) → Prospect Detail & Activity → Landing Page Form → Contact → Prospective Student
  Management & Enrollment → Activity Is Important → Operational Performance Dashboard.
- **Prambanan** (Service Cloud + Marketing): pengenalan produk → Customer 360 → Campaign → Lead →
  Account → Contact → Opportunity → Quotation → Project Management → Project Summary → Activity →
  Dashboard → Marketing Cloud Journey Builder → Email Builder → Data Management Platform → Sprout Social.
- **Indospring** (Sales Cloud + portal mitra + Tableau): High Level Architecture → Lead → Account →
  Contact → Opportunity → Quotation → Order → Sales Activity → Executive Dashboard → Partner
  Portal → Tableau Analytics.
- **Taman Safari**: Lead → Account → Contact → Opportunity → Quotation → Sales Activity →
  Executive Dashboard → Tableau Analytics → Taman Safari Unique Process.
- **i3L** (pendidikan tinggi): Lead → Opportunity → Activity Tracking → Marketing Cloud Account
  Engagement → AI Agent + WhatsApp → Monitor Admission Performance.
- **Nusantara Funds** (nonprofit): Lead → Donor Journey → Donor Management → OCR Document → Dashboard.
- **Kafalah** (nonprofit, NPSP): Account & Contact → Funding Program → Funding Request →
  Requirement → Dashboard.

Urutkan mengikuti alur proses klien (dari data masuk sampai laporan manajemen), bukan daftar
fitur produk. Jangan membuat slide solusi atau journey untuk proses yang Out of Scope.

---

## Format slide per jenis

### Objective / Tujuan Implementasi
4–5 poin. Setiap poin: judul hasil bisnis (3–8 kata) + 1–2 kalimat dengan istilah dan angka
klien bila ada. Contoh: **"Paper Form Digitization"** — Mistral OCR converts ±25,000 paper forms
per year from visits to 250 schools into digital data, with a manual verification path for
unreadable handwriting.

### Solusi per modul
- Judul modul dengan istilah klien; boleh ditambah subjudul satu kalimat manfaat
  (mis. "Automate first-touch engagement and route qualified student inquiries faster").
- Satu paragraf: ±50 kata (en) atau ±70–90 kata (id).
- Catatan screenshot: layar mana dari org demo dan data apa yang terlihat.

### Proses unik klien (opsional)
Jelaskan proses khusus (mis. Confirmation Letter, Group Event Order, Banquet Event Order) dan
tambahkan catatan batasan bila menyangkut cetak dokumen: tata letak cetak tidak bisa sama persis
dengan dokumen asli; template cetak harus final, ukuran gambar ditentukan, tabel disesuaikan.

### Scope of Work
- **In Scope**: butir pekerjaan. Butir yang bisa melebar diberi batas jumlah, mis.
  "Process Automation – Workflows, etc. Up to 10 Automation", "Up to 5 email templates, up to
  2 landing pages", "Reports and dashboards (up to 10 reports & 2 dashboards)", "Custom
  Visualforce PDF (12)", "Data Importing/Loading (template provided)". Jangan menulis butir
  tanpa batas seperti "Process Automation – Workflows, etc." saja.
- Paket dengan batas object (LKS Starterforce): pisahkan Standard Object dan Custom Object dan
  sebutkan jumlahnya.
- **Out of Scope**, termasuk:
  - fitur yang tidak dikerjakan (Einstein/Agentforce, integrasi pihak ketiga termasuk ERP,
    document generation, portal/mobile app eksternal, analytics lanjutan);
  - batas tambahan: "Additional modules, objects, or custom development beyond the agreed scope",
    "Additional WhatsApp numbers, channels, or complex routing beyond agreed limits";
  - tanggung jawab klien: pengadaan akun API pihak ketiga, pemasangan DNS/DKIM oleh tim IT klien,
    data migrasi yang sudah bersih di template yang disediakan.
- Satu bahasa per slide.

### Project Timeline / Implementation Plan
Satuan minggu (proyek ≤ 3 bulan) atau bulan (proyek lebih panjang), dan satuan yang sama dipakai
di kolom Duration slide Implementation. Blok fase:
- **Design**: Kickoff, in-depth discovery sessions, collect & confirm requirements, define plan,
  develop/review/approve blueprint.
- **Build**: satu blok per produk/alur kerja (mis. "Configure Sales Cloud", "Configure Marketing
  Cloud Account Engagement", "Integration to Microsoft Dynamics AX", "Partner Community Portal",
  "Tableau Dashboard Analytics", "Import"). Nama produk di judul blok harus sama dengan lisensi.
- **UAT & Training**, **Wrap-up** (go-live, fine tuning, dokumentasi).
Catatan ketergantungan bila ada, mis. "This can only be implemented if your system supports API
integration."

### Commercial Detail – License
Pilih format sesuai mata uang:

**USD, dengan diskon** (SKHA, Kafalah, Taman Safari, i3L)
| Product Subscription | Qty | Monthly Cost/User (List Price) | Discount | Net Price (After Discount) | Monthly Total | Annual Sales Price |
|---|---|---|---|---|---|---|

**IDR, dengan harga price list dan harga diskon** (Indospring, MNC)
| Product Subscription | Qty | Month | Monthly Cost/User (Price List) | Monthly Cost/User (Discounted) | Monthly Total | Annual Sales Price |
|---|---|---|---|---|---|---|

**IDR, satu harga** (APM, Movindo, Prambanan)
| No | Product Specification | Period (Month) | Qty/User | Price (Rp, per user per month) | Total Investment per Year (Rp) |
|---|---|---|---|---|---|

Aturan:
- Harga di slide adalah **harga jual ke klien**. List price harus sama dengan price list
  Salesforce (dikonversi dengan kurs yang disebutkan bila IDR). Label kolom harus sesuai isinya.
- Kontrak multi-tahun: kolom total diberi label sesuai periodenya ("Total Investment (24 Months)"),
  bukan "Per Year".
- Monthly Total = Qty × Net Price; Annual = Monthly Total × 12. Paket yang dihitung per tahun
  (mis. OCR per 1.000 halaman) diberi satuan jelas.
- Item non-Salesforce (Sprout Social, OCR, connector n8n, server) boleh di tabel yang sama atau
  slide sendiri, dengan satuan yang jelas (per user, per halaman, per bulan).
- Premier Success boleh sebagai baris di tabel lisensi.
- Bonus ditulis sebagai catatan, mis. "Free 10 Partner Community logins". Jenis lisensinya
  harus sesuai penggunanya (portal mitra memakai Partner Community, bukan Customer Community).
- Di bawah tabel: Total, PPN 11%, Grand Total.

Notes bila relevan:
- Kelayakan program: "The above pricing applies only to organizations eligible for Salesforce's
  Nonprofit Program (Power of Us). The client must provide documentation confirming nonprofit status."
- Batas paket: "LKS Starterforce currently utilizing 10 custom objects. Any additional business
  process that requires a new custom object is not possible. Upgrade to Salesforce Enterprise
  Edition is mandatory."
- "Implementation costs are not included."

Term of Condition (lisensi):
- Price 100% in advance, atau "Price paid monthly"
- Price excludes VAT 11% (PPN dihitung terpisah di tabel)
- Billing Frequency: <Annual / Quarterly / Monthly>; Contract period: <12 / 24> months
- Changes in quantities associated with this offer will impact overall pricing
- (USD) For invoices issued in Indonesian Rupiah, the final invoiced amount will be adjusted based
  on the prevailing USD/IDR exchange rate on the invoice issuance date
- Offer Valid Through: <tanggal> and should be signed before validity date

### Commercial TOP Detail (opsional)
| Payment | Payment Date | <Produk 1 (Qty)> | <Produk 2 (Qty)> | Total / Quarter USD | Total / Quarter IDR |
|---|---|---|---|---|---|
Baris per kuartal per tahun, subtotal per tahun, TOTAL CONTRACT (N YEARS); kurs ditulis.

### Commercial Detail – Implementation (One Time)
Dua format:

**Lump sum per layanan** (default)
| No | Service Description | Details | Duration (Week/Month) | Price (Rp) |
|---|---|---|---|---|
Details = butir In Scope.

**Per role** (MNC), bila klien meminta rincian
| No | Service Description (role) | Person | Quantity (Work Days) | Price per Day (Rp) | Total Price (Rp) |
|---|---|---|---|---|---|
Nama role dan rate dari rate card.

Di bawah tabel: PPN 11% dan Grand Total, semua angka dengan awalan "Rp".

Notes bila ada proses yang ditunda: "The Scope of Work outlined in this proposal does not include
<...>. The costs and implementation efforts for <...> will be evaluated separately based on the
complexity of the systems, business processes, and requirements to be implemented."

Term of Condition (implementasi):
- 50% down payment after PO received
- 50% after acceptance
- Price excludes VAT 11% (PPN dihitung terpisah di tabel)
- Offer Valid Through: <tanggal> and should be signed before validity date (sama di semua slide)
- This offer price is valid upon receipt of the solution concept, business processes, and
  information regarding any external systems to be integrated.

---

## Hal yang sering salah di deck (dicek reviewer)
Ditemukan di deck referensi:
- **PPN**: teks "Price Included VAT 11%" padahal PPN ditambahkan di tabel (semua deck).
- **Label vs isi**:
  - "Total Investment Per Year (US$)" berisi Rupiah (APM) atau berisi total 2 tahun (MNC);
  - "List Price" untuk harga setelah diskon;
  - angka tanpa "Rp" di tabel ber-header Rp (Kafalah, Nusantara).
- **Hitungan**:
  - Monthly Total ≠ Qty × Net Price (i3L: OCR 25 × $6.67 ditulis $6.67);
  - nomor baris berulang (MNC: 3, 3, 3).
- **Harga**:
  - list price tidak sesuai price list (Taman Safari: Tableau Next Creator $90, di price list $150);
  - net price di bawah harga beli partner tanpa catatan special pricing approval (Taman Safari:
    Sales Cloud EE $50,15, sedangkan harga beli terendah 100–199 user $68,96).
- **Konsistensi produk**:
  - divider atau blok timeline menyebut produk lain dari lisensi ("Sales Cloud & Marketing Cloud"
    dengan lisensi Service Cloud, Prambanan; "Configure Sales Cloud" dan "Marketing Cloud Next"
    padahal lisensinya Service Cloud dan Account Engagement, i3L; "Experience Cloud" di proyek
    Sales Cloud, SKHA).
- **Konsistensi scope**:
  - butir di Implementation tidak ada di Scope (Indospring: check-in/out);
  - timeline opsi memuat pekerjaan opsi lain (Prambanan opsi CRM memuat Marketing & CS system);
  - Out of Scope mengecualikan sesuatu yang tidak ada di In Scope (Kafalah: payment gateway);
  - slide solusi untuk proses Out of Scope (Movindo: Sparepart Journey);
  - butir tanpa batas jumlah ("Process Automation – Workflows, etc.").
- **Tanggal**: "Offer Valid Through" rusak ("May 20th June, 2026") atau berbeda antar slide
  (Indospring, Taman Safari, Movindo), atau sudah lewat.
- **Lisensi portal**: portal mitra dengan "Customer Portal Login" (Indospring); cek jenis lisensinya.
- **Billing**: billing frequency di slide lisensi berbeda dengan jadwal TOP (SKHA).
- **Bahasa**: campur bahasa dalam satu slide ("minimum kontrak 2 years", "Setup user, role, dan
  profile", "Integrasi Apex callout ke Mistral").
- **Salah ketik**: "Enterprice", "Entreprise", "Eintstein", "Standart", "Costumize", "DIscount",
  "Slaesforce", "Quanity", "Tableu", "engagemetn", "Groupt", "Banguet", "eull", "speficied",
  "hierarcy", "Potofolio", "let'do", "SAP & DKIM" (SPF & DKIM).
- **Sisa template**: nama perusahaan atau klien lain dari template sebelumnya.
