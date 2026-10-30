# Proyek referensi (untuk cek kewajaran estimasi)

Proposal yang sudah dikirim, dipakai agent solution sebagai pembanding setelah membuat
estimasi bottom-up. Ini **bukan** standar effort: kalau estimasi baru jauh berbeda dari
proyek yang mirip, sebutkan alasannya, jangan menyamakan angkanya begitu saja.

Tambahkan satu baris setiap kali proposal dikirim. Kolom Rp/minggu = harga jasa ÷ durasi
(1 bulan = 4,33 minggu), untuk membandingkan proyek dengan durasi berbeda.

Pola kasar dari data di bawah: proyek CRM inti satu produk sekitar Rp11–25 juta/minggu;
proyek yang memuat Marketing Cloud, portal, Tableau, integrasi ERP, atau proses cetak khusus
sekitar Rp23–55 juta/minggu.

| Klien | Industri | Produk & lisensi | Scope inti | Durasi | Harga jasa (sebelum PPN) | Rp/minggu | Catatan |
|---|---|---|---|---|---|---|---|
| SKHA | Jasa/konstruksi (MICE, corporate) | Sales Cloud EE 15 + Slack Business Plus 15 (USD, 2 tahun, TOP kuartalan) | Lead, Account, Contact, Opportunity, Quote; custom fields & list views; activity; duplicate & matching; advise reports; ≤5 automation; data import; check in/out; training | 5 minggu | Rp125.000.000 | Rp25,0 jt | Out: Einstein, integrasi pihak ketiga, custom quotation template |
| APM (juga AUG, isi sama) | Pendidikan (penerimaan siswa, multi-cabang) | Sales Cloud EE 30 + Account Engagement 1 + connector n8n (IDR) | Lead, Account, Contact; activity; validation & reminder; duplicate & matching; integrasi lead via n8n (TikTok, Meta, Google Ads); auto-assignment per cabang; Pardot form, landing page, email template; reports basic; training | 10 minggu | Rp175.000.000 | Rp17,5 jt | Skenario alternatif Power of Us |
| Movindo Gading Mas | Manufaktur/mesin (sales project, sparepart) | LKS Starterforce 11 user (IDR bulanan) | Account, Contact, Case + 10 custom object; ≤10 report & 2 dashboard; ≤15 automation; 12 Visualforce PDF; duplicate & matching; training | 14 minggu | Rp220.000.000 | ±Rp15,7 jt | Alternatif Sales Cloud EE 11. Out: ERP, Sales Service & Sparepart |
| Kafalah Indonesia | Nonprofit (program bantuan) | Service Cloud EE Power of Us 10, gratis (USD) | NPSP; Account & Contact; Funding Program; Funding Request; Requirement; duplicate & matching; advise reports; training | 8 minggu | Rp91.000.000 | ±Rp11,4 jt | Deck bahasa Indonesia |
| Prambanan Kencana — opsi lengkap | Manufaktur/distribusi | Service Cloud EE 23 + Platform Starter 224 + Sprout Social 11 + Marketing Cloud Growth 1 (IDR) | Account, Contact, Case, custom object; activity; duplicate & matching; project management module; Marketing Cloud; integrasi Microsoft Dynamics AX & Sprout Social; ≤10 automation; data import; check in/out; training | 4 bulan | Rp400.000.000 | ±Rp23,1 jt | Dua opsi dalam satu deck |
| Prambanan Kencana — opsi CRM | Manufaktur/distribusi | Service Cloud EE 12 + Platform Starter 224 (IDR) | Sama tanpa Marketing Cloud & Sprout Social; tetap integrasi Dynamics AX | 3 bulan | Rp300.000.000 | ±Rp23,1 jt | |
| Indospring | Manufaktur (komponen otomotif) | Sales Cloud EE 20 + Tableau Creator 2 + Viewer 20 + Premier Success (IDR, minimal 2 tahun) + bonus 10 login portal | Lead s.d. Order; activity; duplicate & matching; advise reports; Partner Portal (Experience Cloud); Tableau; automation; data import; training | 4 bulan | Rp400.000.000 | ±Rp23,1 jt | Out: integrasi pihak ketiga, Einstein |
| Taman Safari Indonesia | Pariwisata/rekreasi (sales corporate & event) | Sales Cloud EE 140 + Tableau Next Creator 2 + Viewer 140 (USD, 24 bulan) | Lead, Account, Contact, Opportunity, Quotation; proses Confirmation Letter, Group Event Order, Banquet Event Order (cetak); activity; Tableau; automation; data import; training | 3 bulan | Rp550.000.000 | ±Rp42,3 jt | Proses cetak khusus |
| MNC Media | Media | Sales Cloud EE 35 + Platform Starter 35 + Premier Success + Tableau Creator 2 + Viewer 35 (IDR, 2 tahun) | Lead s.d. Quotation; project management module; activity; check in/out; Tableau; ≤10 automation; data import; training | 4 bulan | Rp482.500.000 | ±Rp27,9 jt | Rincian per role: BA 15 md, Functional Consultant 35 md, Developer 30 md, PM 15 md (rate di deck lebih tinggi dari rate card saat ini) |
| i3L University — tanpa OCR | Pendidikan tinggi (admission) | Service Cloud EE 10 (diskon 100%) + Account Engagement Growth 1 + Digital Engagement 3 (USD) | Campaign, Lead, Account, Contact, Case; lead validation & assignment; Digital Engagement (WhatsApp); Account Engagement (≤5 email template, ≤2 landing page, ≤5 automation); advise reports; training | 12 minggu | Rp660.000.000 | Rp55,0 jt | Out: integrasi Sevima, pengadaan akun Mistral, redesain formulir |
| i3L University — dengan OCR | Pendidikan tinggi | Sama + OCR Mistral (25 × 1.000 halaman) | Sama + OCR Mistral via Apex callout, staging object, LWC upload & review queue | 4 bulan | Rp840.000.000 | ±Rp48,5 jt | Deck bahasa Indonesia/Inggris |
| Nusantara Funds | Nonprofit (pendanaan/donor) | Prosnap Document Automation 5.000 halaman + Server Automation (IDR); org Salesforce existing | Setup & data structuring (proposal, monitoring, report); custom fields; integrasi OCR via API; status tracking; ≤10 automation; mapping OCR; training | 8 minggu | Rp80.000.000 | Rp10,0 jt | Out: AI/OCR lanjutan, integrasi Accurate/WhatsApp, portal eksternal, document generation |
