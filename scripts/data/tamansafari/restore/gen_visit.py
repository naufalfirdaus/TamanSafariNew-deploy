"""Generator metadata rekonstruksi modul Field Visit (Visit_Form__c, Field_Sales_Config__mdt, label, notif type).
Skema diturunkan dari penggunaan di kode Apex/LWC backup 22 Okt 2026, bukan dari ekspor aslinya."""
import os, shutil
from xml.sax.saxutils import escape

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'stage3')
for d in ('objects','customMetadata','notificationtypes','labels'):
    shutil.rmtree(os.path.join(OUT, d), ignore_errors=True)
NS = 'xmlns="http://soap.sforce.com/2006/04/metadata"'
HDR = '<?xml version="1.0" encoding="UTF-8"?>\n'


def w(path, text):
    p = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w', encoding='utf-8').write(text)


def vs(values, default=None, restricted=False, sort=False):
    x = '    <valueSet>\n        <restricted>%s</restricted>\n        <valueSetDefinition>\n            <sorted>%s</sorted>\n' % (
        'true' if restricted else 'false', 'true' if sort else 'false')
    for v in values:
        x += '            <value>\n                <fullName>%s</fullName>\n                <default>%s</default>\n                <label>%s</label>\n            </value>\n' % (
            escape(v), 'true' if v == default else 'false', escape(v))
    return x + '        </valueSetDefinition>\n    </valueSet>\n'


def field(name, label, typ, extra='', desc=None):
    d = '    <description>%s</description>\n' % escape(desc) if desc else ''
    return '%s<CustomField %s>\n    <fullName>%s</fullName>\n%s    <label>%s</label>\n    <externalId>false</externalId>\n    <trackTrending>false</trackTrending>\n    <type>%s</type>\n%s</CustomField>\n' % (
        HDR, NS, name, d, escape(label), typ, extra)


def put(obj, name, label, typ, extra=''):
    w('objects/%s/fields/%s.field-meta.xml' % (obj, name), field(name, label, typ, extra))


def L(n):  # Text length
    return '    <length>%d</length>\n    <required>false</required>\n    <unique>false</unique>\n' % n


def num(p, s):
    return '    <precision>%d</precision>\n    <scale>%d</scale>\n    <required>false</required>\n' % (p, s)


def lookup(target, rel, plural):
    return ('    <referenceTo>%s</referenceTo>\n    <relationshipLabel>%s</relationshipLabel>\n    <relationshipName>%s</relationshipName>\n'
            '    <deleteConstraint>SetNull</deleteConstraint>\n    <required>false</required>\n') % (target, plural, rel)


V = 'Visit_Form__c'
# ---- objek ----
w('objects/%s/%s.object-meta.xml' % (V, V), HDR + '''<CustomObject %s>
    <actionOverrides><actionName>Accept</actionName><type>Default</type></actionOverrides>
    <allowInChatterGroups>false</allowInChatterGroups>
    <compactLayoutAssignment>SYSTEM</compactLayoutAssignment>
    <deploymentStatus>Deployed</deploymentStatus>
    <description>Kunjungan lapangan sales (check-in/out, bukti foto &amp; tanda tangan, skor, audit AI). Skema direkonstruksi dari kode.</description>
    <enableActivities>true</enableActivities>
    <enableBulkApi>true</enableBulkApi>
    <enableFeeds>false</enableFeeds>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <enableSearch>true</enableSearch>
    <enableSharing>true</enableSharing>
    <enableStreamingApi>true</enableStreamingApi>
    <label>Visit Form</label>
    <nameField>
        <displayFormat>VF-{0000000}</displayFormat>
        <label>Visit Number</label>
        <trackHistory>false</trackHistory>
        <type>AutoNumber</type>
    </nameField>
    <pluralLabel>Visit Forms</pluralLabel>
    <searchLayouts></searchLayouts>
    <sharingModel>Private</sharingModel>
    <visibility>Public</visibility>
</CustomObject>
''' % NS)

PARKS = ['Taman Safari Bogor', 'Taman Safari Prigen', 'Taman Safari Bali', 'Beach Safari Batang', 'Solo Safari', 'Multiple / Undecided']
put(V, 'Status__c', 'Status', 'Picklist', vs(['In Progress', 'Completed', 'Cancelled'], 'In Progress'))
put(V, 'Target_Type__c', 'Target Type', 'Picklist', vs(['Account_Contact', 'Lead']))
put(V, 'Account__c', 'Account', 'Lookup', lookup('Account', 'Visit_Forms', 'Visit Forms'))
put(V, 'Contact__c', 'Contact', 'Lookup', lookup('Contact', 'Visit_Forms', 'Visit Forms'))
put(V, 'Lead__c', 'Lead', 'Lookup', lookup('Lead', 'Visit_Forms', 'Visit Forms'))
put(V, 'Opportunity__c', 'Opportunity', 'Lookup', lookup('Opportunity', 'Visit_Forms', 'Visit Forms'))
put(V, 'Open_Visit_Key__c', 'Open Visit Key', 'Text', '    <length>18</length>\n    <required>false</required>\n    <unique>true</unique>\n    <caseSensitive>false</caseSensitive>\n')
put(V, 'Check_In_Time__c', 'Check-In Time', 'DateTime', '    <required>false</required>\n')
put(V, 'Check_Out_Time__c', 'Check-Out Time', 'DateTime', '    <required>false</required>\n')
put(V, 'Check_In_Location__c', 'Check-In Location', 'Location', '    <displayLocationInDecimal>true</displayLocationInDecimal>\n    <scale>6</scale>\n    <required>false</required>\n')
put(V, 'Check_Out_Location__c', 'Check-Out Location', 'Location', '    <displayLocationInDecimal>true</displayLocationInDecimal>\n    <scale>6</scale>\n    <required>false</required>\n')
for n, lab in [('Check_In_Accuracy_Meters__c', 'Check-In Accuracy (m)'), ('Check_In_Distance_Meters__c', 'Check-In Distance (m)'),
               ('Check_Out_Accuracy_Meters__c', 'Check-Out Accuracy (m)'), ('Check_Out_Distance_Meters__c', 'Check-Out Distance (m)'),
               ('Check_Out_From_Check_In_Meters__c', 'Check-Out From Check-In (m)'), ('Signature_Distance_From_Check_In_Meters__c', 'Signature Distance From Check-In (m)')]:
    put(V, n, lab, 'Number', num(18, 2))
put(V, 'Visit_Duration_Minutes__c', 'Visit Duration (min)', 'Number', num(10, 2))
put(V, 'Check_In_Address__c', 'Check-In Address', 'Text', L(255))
put(V, 'Check_Out_Address__c', 'Check-Out Address', 'Text', L(255))
for n, lab in [('Is_Outside_Geofence__c', 'Outside Geofence'), ('Is_Target_Rep_Pinned__c', 'Target Rep Pinned'), ('Is_Short_Visit__c', 'Short Visit'),
               ('Is_Check_Out_Location_Missing__c', 'Check-Out Location Missing'), ('Is_Duplicate_Photo__c', 'Duplicate Photo'),
               ('UU_PDP_Consent__c', 'UU PDP Consent'), ('Final_Approver_Identified__c', 'Final Approver Identified'), ('AI_Injection_Suspected__c', 'AI Injection Suspected')]:
    put(V, n, lab, 'Checkbox', '    <defaultValue>false</defaultValue>\n')
put(V, 'Geofence_Exception_Reason__c', 'Geofence Exception Reason', 'Picklist', vs(['Weak GPS / Indoor Tower', 'Met at External Cafe/Restaurant', 'Different Branch/Building']))
put(V, 'Cancellation_Reason__c', 'Cancellation Reason', 'Picklist', vs(['Client Not Available', 'Wrong Target Selected', 'Rescheduled', 'Auto-Cancelled (Stale)']))
put(V, 'Visit_Purpose__c', 'Visit Purpose', 'Picklist', vs(['Initial Canvassing / Discovery', 'Follow-Up / Proposal Review', 'Final Confirmation / Contracting']))
put(V, 'Pipeline_Action__c', 'Pipeline Action', 'Picklist', vs(['None', 'Convert Lead', 'Create Opportunity', 'Update Opportunity'], 'None'))
put(V, 'Meeting_Summary__c', 'Meeting Summary', 'LongTextArea', '    <length>32768</length>\n    <visibleLines>6</visibleLines>\n')
put(V, 'Preferred_Park_Location__c', 'Preferred Park Location', 'Picklist', vs(PARKS))
put(V, 'Event_Type__c', 'Event Type', 'Picklist', vs(['Team Building', 'Family Gathering', 'Corporate Meeting', 'Other']))
put(V, 'Interested_Packages__c', 'Interested Packages', 'MultiselectPicklist', vs(['Tickets', 'Hotel', 'Catering', 'Venue', 'Other']) + '    <visibleLines>5</visibleLines>\n')
put(V, 'Estimated_Pax__c', 'Estimated Pax', 'Number', num(6, 0))
put(V, 'Estimated_Budget_Per_Pax__c', 'Estimated Budget Per Pax', 'Picklist', vs(['< IDR 500k', 'IDR 500k - 1M', '> IDR 1M']))
put(V, 'Total_Estimated_Budget__c', 'Total Estimated Budget', 'Currency', num(18, 0))
put(V, 'Budget_Status__c', 'Budget Status', 'Picklist', vs(['Approved / Allocated', 'In Planning / Pending', 'No Budget Yet']))
put(V, 'PIC_Department__c', 'PIC Department', 'Picklist', vs(['HR (Human Resources)', 'Procurement', 'GA (General Affairs)', 'Executive / Board', 'Other']))
put(V, 'Decision_Role__c', 'Decision Role', 'Picklist', vs(['Decision Maker', 'Influencer / Committee', 'Gatekeeper', 'Other']))
put(V, 'Target_Event_Date__c', 'Target Event Date', 'Date', '    <required>false</required>\n')
put(V, 'Preferred_Day_Type__c', 'Preferred Day Type', 'Picklist', vs(['Weekday (Mon-Thu)', 'Weekend (Fri-Sun)', 'No Preference']))
put(V, 'Booking_Urgency__c', 'Booking Urgency', 'Picklist', vs(['This Month', 'This Quarter', 'Next Quarter', 'Next Year']))
put(V, 'Photo_Document_Id__c', 'Photo Document Id', 'Text', L(18))
put(V, 'Image_SHA256_Hash__c', 'Image SHA-256 Hash', 'Text', L(64))
put(V, 'Photo_Captured_At__c', 'Photo Captured At', 'DateTime', '    <required>false</required>\n')
put(V, 'Signature_Document_Id__c', 'Signature Document Id', 'Text', L(18))
put(V, 'Signed_By_Name__c', 'Signed By Name', 'Text', L(255))
put(V, 'Signature_Captured_At__c', 'Signature Captured At', 'DateTime', '    <required>false</required>\n')
put(V, 'Signature_Declined_Reason__c', 'Signature Declined Reason', 'Picklist', vs(['Client Declined to Sign', 'Signer Not Available', 'Other']))
put(V, 'Event_Id__c', 'Event Id', 'Text', L(18))
for n, lab in [('Location_Score__c', 'Location Score'), ('Duration_Score__c', 'Duration Score'), ('Proof_Score__c', 'Proof Score'),
               ('Telemetry_Score__c', 'Telemetry Score'), ('AI_Consistency_Score__c', 'AI Consistency Score'), ('AI_Summary_Score__c', 'AI Summary Score')]:
    put(V, n, lab, 'Number', num(3, 0))
put(V, 'Total_Visit_Score__c', 'Total Visit Score', 'Number',
    '    <formula>BLANKVALUE(Location_Score__c, 0) + BLANKVALUE(Duration_Score__c, 0) + BLANKVALUE(Proof_Score__c, 0) + BLANKVALUE(Telemetry_Score__c, 0) + BLANKVALUE(AI_Consistency_Score__c, 0) + BLANKVALUE(AI_Summary_Score__c, 0)</formula>\n    <formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs>\n    <precision>18</precision>\n    <scale>0</scale>\n')
put(V, 'Visit_Verification_Tier__c', 'Verification Tier', 'Picklist', vs(['Verified', 'Coaching Needed', 'Flagged for Investigation']))
put(V, 'Fraud_Flag_Reasons__c', 'Fraud Flag Reasons', 'MultiselectPicklist',
    vs(['Duplicate photo', 'Off-site check-in with short visit', 'Suspected AI manipulation']) + '    <visibleLines>3</visibleLines>\n')
put(V, 'Investigation_Status__c', 'Investigation Status', 'Picklist', vs(['Not Required', 'Pending Manager Review', 'Excused / Valid', 'Rejected / Fake Visit'], 'Not Required'))
put(V, 'Investigation_Notes__c', 'Investigation Notes', 'LongTextArea', '    <length>5000</length>\n    <visibleLines>4</visibleLines>\n')
put(V, 'Manager_Alerted_At__c', 'Manager Alerted At', 'DateTime', '    <required>false</required>\n')
put(V, 'AI_Scoring_Status__c', 'AI Scoring Status', 'Picklist', vs(['Pending', 'Sent', 'Scored', 'Failed']))
put(V, 'AI_Attempt_Count__c', 'AI Attempt Count', 'Number', num(3, 0))
put(V, 'AI_Request_Id__c', 'AI Request Id', 'Text', L(80))
put(V, 'AI_Model__c', 'AI Model', 'Text', L(80))
put(V, 'AI_Last_Error__c', 'AI Last Error', 'Text', L(255))
put(V, 'AI_Audit_Summary__c', 'AI Audit Summary', 'LongTextArea', '    <length>5000</length>\n    <visibleLines>5</visibleLines>\n')
put(V, 'AI_Sent_At__c', 'AI Sent At', 'DateTime', '    <required>false</required>\n')
put(V, 'AI_Scored_At__c', 'AI Scored At', 'DateTime', '    <required>false</required>\n')

LOC = '    <displayLocationInDecimal>true</displayLocationInDecimal>\n    <scale>6</scale>\n    <required>false</required>\n'
put(V, 'Photo_Location__c', 'Photo Location', 'Location', LOC)
put(V, 'Signature_Location__c', 'Signature Location', 'Location', LOC)
CV = 'ContentVersion'
put(CV, 'Proof_Type__c', 'Proof Type', 'Text', L(30))
put(CV, 'Captured_At__c', 'Captured At', 'DateTime', '    <required>false</required>\n')
put(CV, 'Captured_Location__c', 'Captured Location', 'Location', LOC)
put(CV, 'Image_SHA256_Hash__c', 'Image SHA-256 Hash', 'Text', L(64))

# ---- Field_Sales_Config__mdt ----
M = 'Field_Sales_Config__mdt'
w('objects/%s/%s.object-meta.xml' % (M, M), HDR + '<CustomObject %s>\n    <description>Governance Field Visit. Satu record bernama Default.</description>\n    <label>Field Sales Config</label>\n    <pluralLabel>Field Sales Configs</pluralLabel>\n    <visibility>Public</visibility>\n</CustomObject>\n' % NS)
cfg = [('Max_Geofence_Radius_Meters__c', 'Max Geofence Radius (m)', 300), ('Min_Visit_Duration_Minutes__c', 'Min Visit Duration (min)', 10),
       ('Drive_By_Distance_Meters__c', 'Drive-By Distance (m)', 1000), ('Stale_Visit_Hours__c', 'Stale Visit (hours)', 12),
       ('AI_Alert_Score_Threshold__c', 'AI Alert Score Threshold', 55), ('Verified_Score_Threshold__c', 'Verified Score Threshold', 75),
       ('AI_Callback_Timeout_Minutes__c', 'AI Callback Timeout (min)', 30), ('AI_Max_Attempts__c', 'AI Max Attempts', 3)]
for n, lab, _ in cfg:
    put(M, n, lab, 'Number', '    <fieldManageability>DeveloperControlled</fieldManageability>\n' + num(18, 0).replace('<precision>18</precision>', '<precision>18</precision>'))
put(M, 'Allow_Outside_Geofence_CheckIn__c', 'Allow Outside Geofence Check-In', 'Checkbox', '    <defaultValue>true</defaultValue>\n    <fieldManageability>DeveloperControlled</fieldManageability>\n')
rec = HDR + '<CustomMetadata %s xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">\n    <label>Default</label>\n    <protected>false</protected>\n' % NS
for n, _, v in cfg:
    rec += '    <values>\n        <field>%s</field>\n        <value xsi:type="xsd:double">%d</value>\n    </values>\n' % (n, v)
rec += '    <values>\n        <field>Allow_Outside_Geofence_CheckIn__c</field>\n        <value xsi:type="xsd:boolean">true</value>\n    </values>\n</CustomMetadata>\n'
w('customMetadata/Field_Sales_Config.Default.md-meta.xml', rec)

# ---- notification types ----
for n, lab, d in [('Field_Visit_Flagged', 'Field Visit Flagged', 'Notifikasi ke manajer saat kunjungan lapangan ditandai untuk investigasi.'),
                  ('Field_Visit_Auto_Cancelled', 'Field Visit Auto-Cancelled', 'Notifikasi ke sales saat kunjungan yang menggantung dibatalkan otomatis.')]:
    w('notificationtypes/%s.notiftype-meta.xml' % n, HDR + '<CustomNotificationType %s>\n    <customNotifTypeName>%s</customNotifTypeName>\n    <masterLabel>%s</masterLabel>\n    <description>%s</description>\n    <desktop>true</desktop>\n    <mobile>true</mobile>\n</CustomNotificationType>\n' % (NS, n, lab, d))

# ---- custom labels (Bahasa Indonesia, sesuai UI asli: "mnt", dd/MM/yyyy) ----
LAB = {
 'FV_Action_Cancel_Visit': 'Batalkan Kunjungan', 'FV_Action_Pin_Location': 'Pin Lokasi', 'FV_Action_Update_Address': 'Perbarui Alamat',
 'FV_App_Title': 'Kunjungan Lapangan',
 'FV_AuditMap_Accuracy': 'Akurasi', 'FV_AuditMap_Address': 'Alamat', 'FV_AuditMap_AiSummaryTitle': 'Ringkasan Audit AI',
 'FV_AuditMap_CardTitle': 'Peta Audit Kunjungan', 'FV_AuditMap_CheckIn': 'Check-In', 'FV_AuditMap_CheckOut': 'Check-Out',
 'FV_AuditMap_Distance': 'Jarak dari target', 'FV_AuditMap_Duration': 'Durasi', 'FV_AuditMap_ErrorTitle': 'Peta tidak dapat dimuat',
 'FV_AuditMap_FraudReasons': 'Alasan Penandaan', 'FV_AuditMap_InvestigationNotes': 'Catatan Investigasi',
 'FV_AuditMap_InvestigationStatus': 'Status Investigasi', 'FV_AuditMap_Loading': 'Memuat peta...',
 'FV_AuditMap_LocationSource': 'Sumber lokasi', 'FV_AuditMap_NoAiSummary': 'Ringkasan AI belum tersedia.',
 'FV_AuditMap_NoFraudReasons': 'Tidak ada penandaan.', 'FV_AuditMap_NoInvestigationNotes': 'Belum ada catatan.',
 'FV_AuditMap_NoLocations': 'Belum ada koordinat untuk ditampilkan.', 'FV_AuditMap_Photo': 'Foto Bukti', 'FV_AuditMap_Signature': 'Tanda Tangan',
 'FV_AuditMap_Signer': 'Penandatangan', 'FV_AuditMap_Target': 'Target', 'FV_AuditMap_TelemetryScore': 'Skor Telemetri',
 'FV_AuditMap_Tier_Coaching': 'Perlu Pembinaan', 'FV_AuditMap_Tier_Flagged': 'Ditandai untuk Investigasi', 'FV_AuditMap_Tier_Verified': 'Terverifikasi',
 'FV_AuditMap_Time': 'Waktu', 'FV_AuditMap_TotalScore': 'Skor Total', 'FV_AuditMap_VerificationTitle': 'Verifikasi Kunjungan',
 'FV_BANT_Budget_Label': 'Anggaran', 'FV_BANT_Date_Label': 'Tanggal Acara', 'FV_BANT_EventType_Label': 'Jenis Acara',
 'FV_BANT_Packages_Label': 'Paket yang Diminati', 'FV_BANT_Park_Label': 'Lokasi Taman', 'FV_BANT_Pax_Label': 'Jumlah Peserta',
 'FV_BANT_Summary_Label': 'Ringkasan Pertemuan',
 'FV_Badge_AiInjection': 'Indikasi manipulasi AI', 'FV_Badge_DuplicatePhoto': 'Foto duplikat', 'FV_Badge_MissingCheckOut': 'Lokasi check-out tidak tersedia',
 'FV_Badge_OutsideGeofence': 'Di luar geofence', 'FV_Badge_ShortVisit': 'Kunjungan singkat',
 'FV_Btn_Back': 'Kembali', 'FV_Btn_Cancel': 'Batal', 'FV_Btn_CheckIn': 'Check-In', 'FV_Btn_Checkout': 'Check-Out',
 'FV_Btn_Confirm_CheckIn': 'Konfirmasi Check-In', 'FV_Btn_Confirm_Early_Exit': 'Ya, Akhiri Sekarang', 'FV_Btn_Decline_Sign': 'Klien Tidak Bisa Tanda Tangan',
 'FV_Btn_New_Visit': 'Kunjungan Baru', 'FV_Btn_Next': 'Lanjut', 'FV_Btn_Quick_Create_Contact': 'Buat Kontak Baru', 'FV_Btn_Retake_Photo': 'Ambil Ulang',
 'FV_Btn_Save': 'Simpan', 'FV_Btn_Sign': 'Simpan Tanda Tangan', 'FV_Btn_Stay': 'Lanjutkan Kunjungan', 'FV_Btn_Take_Photo': 'Ambil Foto',
 'FV_Camera_Error': 'Kamera tidak dapat diakses. Izinkan akses kamera lalu coba lagi.',
 'FV_Cancel_Body': 'Pilih alasan pembatalan kunjungan ini.', 'FV_Cancel_Reason_NoShow': 'Klien Tidak Ada di Tempat',
 'FV_Cancel_Reason_Rescheduled': 'Dijadwalkan Ulang', 'FV_Cancel_Reason_WrongTarget': 'Salah Memilih Target', 'FV_Cancel_Title': 'Batalkan Kunjungan',
 'FV_Checklist_Contact': 'Kontak (PIC)', 'FV_Checklist_Photo': 'Foto bukti', 'FV_Checklist_Purpose': 'Tujuan kunjungan',
 'FV_Checklist_Signature': 'Tanda tangan klien', 'FV_Checklist_Summary': 'Ringkasan pertemuan', 'FV_Checklist_Title': 'Kelengkapan sebelum check-out',
 'FV_Complete_Duration': 'Durasi kunjungan: {0} mnt', 'FV_Complete_Title': 'Kunjungan Selesai',
 'FV_Consent_PDP': 'Klien menyetujui pengolahan data pribadi sesuai UU PDP.', 'FV_Contact_Picker_Label': 'Kontak (PIC)',
 'FV_Draft_Failed': 'Draf gagal disimpan', 'FV_Draft_Saved': 'Draf tersimpan', 'FV_Draft_Saving': 'Menyimpan draf...',
 'FV_GPS_Accuracy': 'Akurasi GPS ±{0} m', 'FV_GPS_Acquiring': 'Mencari sinyal GPS...',
 'FV_Geofence_Blocking_Body': 'Anda berada {0} m dari target (batas {1} m). Check-in di luar area tidak diizinkan.',
 'FV_Geofence_Blocking_Title': 'Di Luar Area Kunjungan',
 'FV_Geofence_Warning_Body': 'Anda berada {0} m dari target (batas {1} m). Pilih alasan untuk melanjutkan check-in.',
 'FV_Geofence_Warning_Title': 'Anda Berada di Luar Area Target',
 'FV_Opp_Picker_Label': 'Opportunity', 'FV_Photo_Section_Title': 'Foto Bukti Kunjungan',
 'FV_Pipeline_Convert_Lead': 'Konversi Lead', 'FV_Pipeline_Create_Opp': 'Buat Opportunity', 'FV_Pipeline_Update_Opp': 'Perbarui Opportunity',
 'FV_Prefill_Hint': 'Diisi otomatis dari data sebelumnya', 'FV_Purpose_Final': 'Konfirmasi Akhir / Kontrak',
 'FV_Purpose_FollowUp': 'Tindak Lanjut / Review Proposal', 'FV_Purpose_Initial': 'Kanvasing Awal / Penjajakan', 'FV_Purpose_Label': 'Tujuan Kunjungan',
 'FV_Reason_Different_Branch': 'Cabang / Gedung Berbeda', 'FV_Reason_External_Meeting': 'Bertemu di Kafe / Restoran', 'FV_Reason_Weak_GPS': 'GPS Lemah / Dalam Gedung',
 'FV_Score_Breakdown_Title': 'Rincian Skor', 'FV_Score_Duration': 'Durasi', 'FV_Score_Location': 'Lokasi', 'FV_Score_Proof': 'Bukti', 'FV_Score_Total': 'Total',
 'FV_Search_Target': 'Cari Account atau Lead...',
 'FV_Short_Visit_Body': 'Kunjungan baru berlangsung {0} mnt, di bawah minimum {1} mnt. Akhiri sekarang?',
 'FV_Short_Visit_Title': 'Kunjungan Terlalu Singkat',
 'FV_Sign_Declined_Reason': 'Alasan tidak ada tanda tangan', 'FV_Sign_Reason_Other': 'Lainnya', 'FV_Sign_Reason_Refused': 'Klien Menolak Tanda Tangan',
 'FV_Sign_Reason_Unavailable': 'Penandatangan Tidak Ada', 'FV_Signature_Empty_Error': 'Tanda tangan masih kosong.', 'FV_Signer_Name_Label': 'Nama Penandatangan',
 'FV_Status_Located': 'Lokasi tersedia', 'FV_Status_No_Location': 'Lokasi belum tersedia', 'FV_Status_Rep_Pinned': 'Lokasi dipin oleh sales',
 'FV_Step_BANT': 'Kualifikasi', 'FV_Step_Checkout': 'Check-Out', 'FV_Step_Info': 'Informasi Kunjungan',
 'FV_Target_Account': 'Account', 'FV_Target_Lead': 'Lead',
 'FV_Telemetry_OffSite': 'Check-in {0} m dari target', 'FV_Telemetry_Verified': 'Terverifikasi di lokasi ({0} m)',
 'Visit_Alert_Audit_Pending': 'Audit AI masih berjalan.',
 'Visit_Alert_Email_Body': 'Sebuah kunjungan lapangan ditandai untuk investigasi. Buka kunjungan tersebut di Salesforce untuk meninjau bukti dan memberi keputusan.',
 'Visit_Alert_Email_Subject': 'Kunjungan ditandai: {0}', 'Visit_Alert_Notif_Body': 'Kunjungan {0} perlu ditinjau.', 'Visit_Alert_Notif_Title': 'Kunjungan Ditandai',
 'Visit_Alert_Reasons_None': 'Tidak ada alasan tercatat',
 'Visit_Alert_Task_Body': 'Sales: {0}\nTarget: {1}\nAlasan: {2}\nAudit AI: {3}', 'Visit_Alert_Task_Subject': 'Tinjau kunjungan: {0}',
 'Visit_Err_Account_Not_Owner': 'Anda bukan pemilik Account ini.', 'Visit_Err_Budget_Invalid': 'Anggaran tidak boleh negatif.',
 'Visit_Err_Cancel_Reason_Invalid': 'Alasan pembatalan tidak valid.', 'Visit_Err_Checkout_Missing': 'Lengkapi dulu sebelum check-out: {0}.',
 'Visit_Err_Contact_Other_Account': 'Kontak tersebut milik Account lain.', 'Visit_Err_Contact_Required': 'Pilih kontak (PIC) untuk kunjungan ini.',
 'Visit_Err_Decline_Reason_Invalid': 'Alasan tidak ada tanda tangan tidak valid.', 'Visit_Err_Draft_Invalid': 'Data draf tidak valid.',
 'Visit_Err_Event_Date_Invalid': 'Tanggal acara tidak boleh sebelum tanggal kunjungan.', 'Visit_Err_Event_Date_Required': 'Tanggal acara wajib diisi.',
 'Visit_Err_Exception_Reason_Invalid': 'Alasan pengecualian tidak valid.', 'Visit_Err_Exception_Reason_Required': 'Pilih alasan karena Anda berada di luar area target.',
 'Visit_Err_Image_Too_Large': 'Ukuran gambar terlalu besar.', 'Visit_Err_Investigation_Status': 'Status investigasi tidak dapat diubah dari status ini.',
 'Visit_Err_Lead_Status_Missing': 'Status konversi Lead tidak ditemukan.', 'Visit_Err_Location_Required': 'Lokasi perangkat wajib tersedia.',
 'Visit_Err_Locked': 'Kunjungan yang sudah selesai atau dibatalkan tidak dapat diubah.', 'Visit_Err_Not_In_Progress': 'Kunjungan ini tidak sedang berlangsung.',
 'Visit_Err_Not_Owner': 'Anda bukan pemilik kunjungan ini.', 'Visit_Err_Open_Visit_Exists': 'Masih ada kunjungan yang berlangsung. Selesaikan atau batalkan dulu.',
 'Visit_Err_Outside_Blocked': 'Check-in di luar area target tidak diizinkan.', 'Visit_Err_Pax_Invalid': 'Jumlah peserta harus bilangan bulat lebih dari 0.',
 'Visit_Err_Photo_Invalid': 'Foto tidak valid.', 'Visit_Err_Pipeline_Already_Linked': 'Kunjungan ini sudah terhubung ke Opportunity.',
 'Visit_Err_Pipeline_Convert_Needs_Lead': 'Konversi hanya untuk Lead yang belum dikonversi.', 'Visit_Err_Pipeline_Create_Needs_Account': 'Membuat Opportunity memerlukan target Account.',
 'Visit_Err_Pipeline_Update_Needs_Opp': 'Pilih Opportunity yang akan diperbarui.', 'Visit_Err_Proof_Delete_Locked': 'Bukti kunjungan tidak dapat dihapus.',
 'Visit_Err_Retry_Admin_Only': 'Hanya administrator yang dapat mengulang penilaian AI.', 'Visit_Err_Retry_Not_Failed': 'Penilaian AI hanya dapat diulang jika berstatus Failed.',
 'Visit_Err_Signature_Blank': 'Tanda tangan masih kosong.', 'Visit_Err_Signature_Invalid': 'Tanda tangan tidak valid.',
 'Visit_Err_Signer_Name_Required': 'Nama penandatangan wajib diisi.', 'Visit_Err_Target_Already_Located': 'Lokasi target sudah terkunci.',
 'Visit_Err_Target_No_Location': 'Target belum memiliki lokasi. Pin lokasi terlebih dahulu.', 'Visit_Err_Target_Not_Found': 'Target kunjungan tidak ditemukan.',
 'Visit_Err_Visit_Not_Found': 'Kunjungan tidak ditemukan.',
 'Visit_Item_Contact': 'kontak (PIC)', 'Visit_Item_Photo': 'foto bukti', 'Visit_Item_Purpose': 'tujuan kunjungan',
 'Visit_Item_Signature': 'tanda tangan klien', 'Visit_Item_Summary': 'ringkasan pertemuan',
 'Visit_Notif_Auto_Cancel_Body': 'Kunjungan Anda dibatalkan otomatis karena tidak diselesaikan tepat waktu.', 'Visit_Notif_Auto_Cancel_Title': 'Kunjungan Dibatalkan Otomatis',
 'Visit_Retry_AI_Success': 'Penilaian AI dijadwalkan ulang.', 'Visit_Retry_AI_Title': 'Ulangi Penilaian AI',
}
x = HDR + '<CustomLabels %s>\n' % NS
for n, t in sorted(LAB.items()):
    x += '    <labels>\n        <fullName>%s</fullName>\n        <categories>FieldVisit</categories>\n        <language>en_US</language>\n        <protected>false</protected>\n        <shortDescription>%s</shortDescription>\n        <value>%s</value>\n    </labels>\n' % (n, n.replace('_', ' '), escape(t))
w('labels/CustomLabels.labels-meta.xml', x + '</CustomLabels>\n')
print('labels', len(LAB), 'fields', len([f for r, _, fs in os.walk(OUT) for f in fs if f.endswith('field-meta.xml')]))
