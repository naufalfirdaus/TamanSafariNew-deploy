# Fitur Check-In / Check-Out Berbasis Geofence

Ditarik dari sandbox **`sandboxdevlksnopal`** (`langitkreasisolusindo--devlks`, Org Id `00DMR000000hmfh2AA`) pada 24 Agustus 2026.
Status: **tersimpan lokal, belum di-deploy ke org manapun.**

## Cara kerja

Lead menyimpan titik lokasi tujuan (`Checkin_Geo__c`) dan radius toleransi (`Geofence_Radius_m__c`). Saat sales melakukan check-in, sistem merekam koordinat perangkat ke record **Event**, menghitung jarak ke titik target, lalu menandai apakah posisi berada di dalam geofence. Proses yang sama berlaku saat check-out, ditambah pencatatan hasil pertemuan.

```
Lead (target + radius)  ──►  Event (bukti check-in & check-out)
   Checkin_Geo__c              koordinat, jarak, akurasi,
   Geofence_Radius_m__c        status geofence, catatan meeting
```

## Isi paket — 36 komponen

### Field Lead (2)
| Field | Tipe | Fungsi |
|---|---|---|
| `Checkin_Geo__c` | Geolocation | Titik lokasi tujuan kunjungan |
| `Geofence_Radius_m__c` | Number | Radius toleransi dalam meter |

### Field Activity (24) — berlaku untuk Event & Task
Metadata custom field yang dibagi Event dan Task didefinisikan pada object **`Activity`**, bukan `Event`.

**Koordinat & waktu**
`CheckIn_Latitude__c` · `CheckIn_Longitude__c` · `CheckOut_Latitude__c` · `CheckOut_Longitude__c` · `Check_In_Latitude__c` · `Check_In_Longitude__c` · `Check_Out_Latitude__c` · `Check_Out_Longitude__c` · `Check_In_Date__c` · `Check_Out_Date__c` · `Update_Check_Out_Date__c`

**Validasi geofence**
`CheckIn_Distance_m__c` · `CheckOut_Distance_m__c` · `CheckIn_Accuracy_m__c` · `CheckOut_Accuracy_m__c` · `Inside_Geofence_on_CheckIn__c` · `Inside_Geofence_on_CheckOut__c` · `Override_Reason__c`

**Alamat & hasil pertemuan**
`Check_In_Address_Line__c` · `Check_Out_Address_Line__c` · `General_Note_about_Meeting__c` · `Metter_Discussed__c` · `Follow_Up_Action_Detail__c` · `Was_The_Call_Requested__c`

> `Metter_Discussed__c` memang salah eja di org sumber. Dipertahankan apa adanya karena Apex merujuk nama itu.

### Apex (4)
| Class | Baris | Peran |
|---|---|---|
| `CheckInService` | 615 | Logika inti check-in/check-out, hitung jarak, validasi geofence |
| `Geolocation_Controller` | 145 | Utilitas geolokasi |
| `CheckInServiceTest` | — | Test class |
| `Test_Geolocation` | — | Test class |

### LWC (6)
| Komponen | Peran |
|---|---|
| `geoCheckinPanel` | Panel check-in di record page |
| `geoCheckoutPanel` | Panel check-out |
| `geoCheckinHistory` | Riwayat kunjungan |
| `salesforceCheckinMaps` | Peta lokasi check-in |
| `salesforceCheckoutMaps` | Peta lokasi check-out |
| `checkOutLocation` | Pemilih lokasi check-out |

## Pemeriksaan dependensi

✅ **Tidak ada dependensi managed package.** Nol referensi ke `ShinobiForce` maupun `B25` — kedua package itu memang punya fitur check-in serupa di sandbox sumber, tapi komponen ini tidak memakainya. Jadi paket ini bisa dideploy ke org yang tidak memasang package tersebut.

✅ **Seluruh field yang dirujuk Apex sudah ikut** (26 field vs 25 rujukan aktif).

⚠️ **Tiga rujukan yang sengaja tidak diikutkan** — sudah diverifikasi aman:

| Rujukan | Alasan aman |
|---|---|
| `Matter_Discussed__c` | Hanya key di string JSON pada test; baris `put()`-nya dikomentari di controller |
| `Was_Call_Requested__c` | Sama seperti di atas |
| `Project__c` | Hanya perbandingan string `objectApiName == 'Project__c'` — object opsional. Kalau tidak ada di org tujuan, cabang itu tidak pernah aktif |

## Yang belum diikutkan

Modul **Visit Plan** sengaja tidak diambil (di luar cakupan check-in/check-out):
`Visit_Plan__c` · `VisitPlanController` · `VisitApprovalController` · `VisitPlanPDFController` · `visitPlanManager` · `visitPlanDetail` · `visitApprovalPage` · FlexiPage `Visit_Plan_Manager` & `Visit_Plan_Record_Page`

## Langkah kalau nanti mau di-deploy

1. **Validasi dulu** (check-only, tidak mengubah org):
   ```
   sf project deploy validate -x manifest/package-checkin.xml -o <ORG> -l RunLocalTests -w 45
   ```
2. Pastikan org tujuan punya **Geolocation field** dan LWC diizinkan mengakses lokasi perangkat (butuh HTTPS).
3. Field baru **tidak otomatis dapat field-level security** — siapkan permission set untuk Lead dan Activity, lalu assign ke profil yang butuh.
4. Tempatkan LWC `geoCheckinPanel` / `geoCheckoutPanel` ke Lightning record page Lead lewat Lightning App Builder.
5. Isi `Checkin_Geo__c` dan `Geofence_Radius_m__c` pada Lead yang akan dipakai uji coba.

Manifest: `manifest/package-checkin.xml`
