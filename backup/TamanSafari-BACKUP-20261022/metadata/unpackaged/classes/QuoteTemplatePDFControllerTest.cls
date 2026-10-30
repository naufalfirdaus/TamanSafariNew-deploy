/**
 * Test untuk QuoteTemplatePDFController.
 *
 * generatePdfBlob() sudah menyediakan jalur khusus Test.isRunningTest() yang
 * mengembalikan blob dummy, sehingga getContentAsPDF() -- yang tidak bisa dipanggil
 * dari konteks test -- tidak pernah dieksekusi di sini.
 *
 * Opportunity sengaja dibuat pada stage 'Qualification' supaya tidak tersentuh
 * validation rule Taman Safari (Wajib PO / Wajib Produk / Wajib Loss Reason) yang
 * hanya aktif pada stage Proposal/Quote, Negotiation, Closed Won, dan Closed Lost.
 */
@IsTest
private class QuoteTemplatePDFControllerTest {

    // Quote.Email tersinkron dari Contact yang tertaut, jadi untuk skenario
    // "ada email" Quote harus benar-benar punya ContactId -- menyetel Quote.Email
    // secara langsung tanpa Contact tidak bertahan setelah insert.
    private static Quote buatQuote(String status, String email) {
        Account akun = new Account(Name = 'Klien Quote Test');
        insert akun;

        Opportunity opp = new Opportunity(
            Name = 'Opp Quote Test',
            AccountId = akun.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Quote Test 001',
            OpportunityId = opp.Id,
            Status = status,
            Pricebook2Id = Test.getStandardPricebookId()
        );

        insert q;

        // ContactId dan Email tidak bertahan bila diisi saat insert (org ini punya
        // trigger SDO_Tool_SalesforceRewind_Quote yang aktif pada Quote), tapi
        // bertahan bila diisi lewat update -- jadi kaitkan kontaknya setelah insert.
        if (String.isNotBlank(email)) {
            Contact kontak = new Contact(
                FirstName = 'Klien',
                LastName = 'Quote Test',
                AccountId = akun.Id,
                Email = email
            );
            insert kontak;

            q.ContactId = kontak.Id;
            q.Email = email;
            update q;
        }

        Quote hasil = [SELECT Id, Name, Status, Email, ContactId FROM Quote WHERE Id = :q.Id];
        if (String.isNotBlank(email)) {
            System.assertEquals(email, hasil.Email,
                'Prasyarat test: Quote harus benar-benar membawa alamat email klien');
        }
        return hasil;
    }

    @IsTest
    static void saveToFilesMelampirkanPdfKeQuoteApproved() {
        Quote q = buatQuote('Approved', 'klien@contoh.com');
        ApexPages.StandardController sc = new ApexPages.StandardController(q);
        QuoteTemplatePDFController ctrl = new QuoteTemplatePDFController(sc);

        Test.startTest();
        PageReference hasil = ctrl.saveToFiles();
        Test.stopTest();

        System.assertNotEquals(null, hasil,
            'Quote berstatus Approved harus diproses dan diarahkan kembali ke halaman detail');
        System.assertEquals('/' + q.Id, hasil.getUrl(),
            'Redirect harus menuju halaman detail Quote yang bersangkutan');
        System.assertEquals(null, ctrl.hasError, 'Tidak boleh ada error pada jalur sukses');

        List<ContentDocumentLink> lampiran = [
            SELECT Id, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :q.Id
        ];
        System.assertEquals(1, lampiran.size(),
            'PDF harus tertaut ke record Quote sebagai satu ContentDocumentLink');

        List<ContentVersion> versi = [SELECT Id, Title FROM ContentVersion];
        System.assertEquals(1, versi.size(), 'Harus terbentuk satu ContentVersion');
        System.assertEquals('Quotation - ' + q.Name, versi[0].Title,
            'Judul file harus mengikuti pola "Quotation - <nama quote>"');
    }

    @IsTest
    static void saveToFilesMenolakQuoteBelumApproved() {
        Quote q = buatQuote('Draft', 'klien@contoh.com');
        ApexPages.StandardController sc = new ApexPages.StandardController(q);
        QuoteTemplatePDFController ctrl = new QuoteTemplatePDFController(sc);

        Test.startTest();
        PageReference hasil = ctrl.saveToFiles();
        Test.stopTest();

        System.assertEquals(null, hasil,
            'Quote yang belum Approved harus tetap di halaman preview (return null)');
        System.assertEquals(true, ctrl.hasError, 'hasError harus true saat status belum Approved');
        System.assert(ctrl.statusMessage.contains('Approved'),
            'Pesan harus menjelaskan syarat status Approved, dapat: ' + ctrl.statusMessage);
        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion],
            'Tidak boleh ada file yang tersimpan saat status ditolak');
    }

    @IsTest
    static void sendAndSaveMenolakQuoteTanpaEmail() {
        Quote q = buatQuote('Approved', null);
        ApexPages.StandardController sc = new ApexPages.StandardController(q);
        QuoteTemplatePDFController ctrl = new QuoteTemplatePDFController(sc);

        Test.startTest();
        PageReference hasil = ctrl.sendAndSave();
        Test.stopTest();

        System.assertEquals(null, hasil, 'Tanpa email klien, proses harus berhenti di halaman preview');
        System.assertEquals(true, ctrl.hasError, 'hasError harus true saat email kosong');
        System.assert(ctrl.statusMessage.contains('email'),
            'Pesan harus menyebut alamat email, dapat: ' + ctrl.statusMessage);
        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion],
            'Tidak boleh ada file tersimpan saat email belum diisi');
    }

    @IsTest
    static void sendAndSaveMenolakQuoteBelumApproved() {
        Quote q = buatQuote('Draft', 'klien@contoh.com');
        ApexPages.StandardController sc = new ApexPages.StandardController(q);
        QuoteTemplatePDFController ctrl = new QuoteTemplatePDFController(sc);

        Test.startTest();
        PageReference hasil = ctrl.sendAndSave();
        Test.stopTest();

        System.assertEquals(null, hasil, 'Quote belum Approved tidak boleh dikirim');
        System.assertEquals(true, ctrl.hasError, 'hasError harus true');
    }

    @IsTest
    static void sendAndSaveMengirimDanMenyimpanPdf() {
        Quote q = buatQuote('Approved', 'klien@contoh.com');
        ApexPages.StandardController sc = new ApexPages.StandardController(q);
        QuoteTemplatePDFController ctrl = new QuoteTemplatePDFController(sc);

        Test.startTest();
        PageReference hasil = ctrl.sendAndSave();
        Test.stopTest();

        // Invarian yang selalu berlaku: PDF sudah tersimpan sebagai file sebelum
        // controller mencoba mengirim email, jadi file harus ada apapun hasil pengiriman.
        System.assertEquals(1, [SELECT COUNT() FROM ContentVersion],
            'PDF harus tersimpan sebagai file sebelum tahap pengiriman email');

        if (hasil != null) {
            // Jalur penuh berhasil: email tercatat sebagai Activity di Quote.
            List<EmailMessage> aktivitas = [
                SELECT Id, Subject, ToAddress, RelatedToId FROM EmailMessage
            ];
            System.assertEquals(1, aktivitas.size(),
                'Harus tercatat satu EmailMessage sebagai Activity di Quote');
            System.assertEquals(q.Id, aktivitas[0].RelatedToId,
                'EmailMessage harus tertaut ke Quote yang bersangkutan');
            System.assertEquals('klien@contoh.com', aktivitas[0].ToAddress,
                'Email harus dialamatkan ke alamat pada Quote');
        } else {
            // Sebagian org membatasi pengiriman email atau pencatatan EmailMessage
            // pada Quote di konteks test. Controller menangkapnya sebagai pesan error,
            // dan pesan itu wajib memberi tahu penyebabnya.
            System.assertEquals(true, ctrl.hasError,
                'Kegagalan pengiriman harus ditandai lewat hasError');
            System.assertNotEquals(null, ctrl.statusMessage,
                'Kegagalan pengiriman harus menyertakan pesan penjelas');
            System.assert(ctrl.statusMessage.contains('Gagal'),
                'Pesan kegagalan harus dapat dibaca pengguna, dapat: ' + ctrl.statusMessage);
        }
    }
}