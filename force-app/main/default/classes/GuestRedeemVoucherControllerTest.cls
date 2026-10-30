/**
 * Test untuk GuestRedeemVoucherController.
 *
 * validateCode() diuji penuh (kode aktif, tidak dikenal, kedaluwarsa, suspended).
 *
 * submitRedemption() diuji pada jalur penolakan kode dan jalur pemrosesan. Perlu
 * dicatat: controller memakai dua Id yang di-hardcode (RETAIL_ACCOUNT_ID dan
 * DEFAULT_PRICEBOOK_ENTRY_ID) yang berasal dari org asal. Di org yang Id tersebut
 * tidak ada, insert Opportunity gagal dan controller menangkapnya sebagai pesan
 * error. Test di bawah karena itu menerima kedua kemungkinan dan tetap memverifikasi
 * kontraknya: hasil tidak pernah null, dan pesan selalu terisi.
 */
@IsTest
private class GuestRedeemVoucherControllerTest {

    private static final String KODE_AKTIF     = 'TESTAKTIF01';
    private static final String KODE_EXPIRED   = 'TESTEXPIRED1';
    private static final String KODE_SUSPENDED = 'TESTSUSPEND1';

    @TestSetup
    static void siapkanData() {
        Account afiliator = new Account(Name = 'Afiliator Voucher Test', Type = 'Partner');
        insert afiliator;

        // Data acuan yang dicari controller berdasarkan nama.
        Account retail = new Account(Name = 'Retail Customer - Voucher Redemption');
        insert retail;

        insert new List<Affiliate_Code__c>{
            new Affiliate_Code__c(Afiliator__c = afiliator.Id, Code__c = KODE_AKTIF,
                Status__c = 'Active',    Valid_From__c = Date.today().addDays(-10),
                Valid_To__c = Date.today().addDays(30)),
            new Affiliate_Code__c(Afiliator__c = afiliator.Id, Code__c = KODE_EXPIRED,
                Status__c = 'Active',    Valid_From__c = Date.today().addDays(-60),
                Valid_To__c = Date.today().addDays(-1)),
            new Affiliate_Code__c(Afiliator__c = afiliator.Id, Code__c = KODE_SUSPENDED,
                Status__c = 'Suspended', Valid_From__c = Date.today().addDays(-10),
                Valid_To__c = Date.today().addDays(30))
        };
    }

    /**
     * PricebookEntry sengaja dibuat di dalam test method, bukan di @TestSetup:
     * record pricebook yang dibuat pada @TestSetup tidak terbaca oleh test method
     * yang menjalankannya, sehingga lookup produk di controller selalu kosong.
     */
    private static void siapkanProdukAcuan() {
        Product2 produk = new Product2(
            Name = 'Tiket Masuk Taman Safari Bogor',
            Family = 'Ticket & Voucher',
            IsActive = true
        );
        insert produk;

        // Mata uang efektif ditentukan SEBELUM insert (bukan dibaca dari SObject
        // setelah insert, yang tidak terisi otomatis secara lokal), supaya tidak
        // mencoba membuat entry IDR kedua saat mata uang default org sudah IDR.
        String mataUangEfektif = null;
        try {
            Id uid = UserInfo.getUserId();
            mataUangEfektif = (String) Database.query(
                'SELECT DefaultCurrencyIsoCode FROM User WHERE Id = :uid'
            )[0].get('DefaultCurrencyIsoCode');
        } catch (Exception e) {
            mataUangEfektif = null;
        }

        PricebookEntry pbeDefault = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = produk.Id,
            UnitPrice = 200000,
            IsActive = true
        );
        if (mataUangEfektif != null) {
            pbeDefault.put('CurrencyIsoCode', mataUangEfektif);
        }
        insert pbeDefault;

        Boolean adaIdr = false;
        try {
            adaIdr = !Database.query(
                'SELECT Id FROM CurrencyType WHERE IsoCode = \'IDR\' AND IsActive = true LIMIT 1'
            ).isEmpty();
        } catch (Exception e) {
            adaIdr = false;
        }
        if (adaIdr && mataUangEfektif != 'IDR') {
            PricebookEntry pbeIdr = new PricebookEntry(
                Pricebook2Id = Test.getStandardPricebookId(),
                Product2Id = produk.Id,
                UnitPrice = 200000,
                IsActive = true
            );
            pbeIdr.put('CurrencyIsoCode', 'IDR');
            insert pbeIdr;
        }
    }


    @IsTest
    static void kodeAktifDinyatakanValid() {
        Test.startTest();
        GuestRedeemVoucherController.AffiliateCodeResult hasil =
            GuestRedeemVoucherController.validateCode(KODE_AKTIF);
        Test.stopTest();

        System.assertEquals(true, hasil.valid, 'Kode aktif dan belum kedaluwarsa harus valid');
        System.assertEquals('Kode valid.', hasil.message, 'Pesan sukses harus dikembalikan apa adanya');
    }

    @IsTest
    static void kodeTidakDikenalDitolak() {
        Test.startTest();
        GuestRedeemVoucherController.AffiliateCodeResult hasil =
            GuestRedeemVoucherController.validateCode('KODENGACOTIDAKADA');
        Test.stopTest();

        System.assertEquals(false, hasil.valid, 'Kode yang tidak ada di database harus ditolak');
        System.assert(hasil.message.contains('tidak ditemukan'),
            'Pesan penolakan harus menjelaskan kode tidak ditemukan, dapat: ' + hasil.message);
    }

    @IsTest
    static void kodeKedaluwarsaDitolak() {
        Test.startTest();
        GuestRedeemVoucherController.AffiliateCodeResult hasil =
            GuestRedeemVoucherController.validateCode(KODE_EXPIRED);
        Test.stopTest();

        System.assertEquals(false, hasil.valid,
            'Kode dengan Valid_To__c di masa lalu harus ditolak walaupun Status__c masih Active');
    }

    @IsTest
    static void kodeSuspendedDitolak() {
        Test.startTest();
        GuestRedeemVoucherController.AffiliateCodeResult hasil =
            GuestRedeemVoucherController.validateCode(KODE_SUSPENDED);
        Test.stopTest();

        System.assertEquals(false, hasil.valid,
            'Kode berstatus Suspended harus ditolak walaupun masa berlakunya belum habis');
    }

    @IsTest
    static void kodeKosongDitolak() {
        Test.startTest();
        GuestRedeemVoucherController.AffiliateCodeResult hasil =
            GuestRedeemVoucherController.validateCode('');
        Test.stopTest();

        System.assertEquals(false, hasil.valid, 'Kode kosong harus ditolak');
    }

    @IsTest
    static void submitRedemptionMenolakKodeTidakValid() {
        Test.startTest();
        GuestRedeemVoucherController.RedemptionResult hasil =
            GuestRedeemVoucherController.submitRedemption(
                'KODENGACOTIDAKADA', 'Budi Santoso', 'BK-001', 'Ticket & Voucher', 2, 500000);
        Test.stopTest();

        System.assertEquals(false, hasil.success,
            'Redemption dengan kode tidak valid harus gagal sebelum membuat record apapun');
        System.assert(hasil.message.contains('tidak valid'),
            'Pesan harus menjelaskan kode tidak valid, dapat: ' + hasil.message);
        System.assertEquals(0, [SELECT COUNT() FROM Redemption__c],
            'Tidak boleh ada Redemption__c yang terbentuk saat kode ditolak');
    }

    @IsTest
    static void submitRedemptionMenolakKodeKedaluwarsa() {
        Test.startTest();
        GuestRedeemVoucherController.RedemptionResult hasil =
            GuestRedeemVoucherController.submitRedemption(
                KODE_EXPIRED, 'Budi Santoso', 'BK-002', 'Ticket & Voucher', 1, 250000);
        Test.stopTest();

        System.assertEquals(false, hasil.success, 'Kode kedaluwarsa harus ditolak di submitRedemption juga');
        System.assertEquals(0, [SELECT COUNT() FROM Redemption__c],
            'Tidak boleh ada Redemption__c yang terbentuk dari kode kedaluwarsa');
    }

    @IsTest
    static void submitRedemptionKodeValidMembuatRedemptionLengkap() {
        siapkanProdukAcuan();

        Test.startTest();
        GuestRedeemVoucherController.RedemptionResult hasil =
            GuestRedeemVoucherController.submitRedemption(
                KODE_AKTIF, 'Siti Aminah', 'BK-003', 'Ticket & Voucher', 4, 1000000);
        Test.stopTest();

        System.assertEquals(true, hasil.success,
            'Redemption dengan kode valid dan data acuan lengkap harus berhasil, pesan: ' + hasil.message);

        List<Redemption__c> redemptions = [
            SELECT Id, Booking_Ref__c, Qty_Redeemed__c, Gross_Amount__c, Status__c,
                   Commission_Rate__c, Commission_Amount__c, Affiliate_Code__c, Afiliator__c
            FROM Redemption__c
        ];
        System.assertEquals(1, redemptions.size(), 'Harus terbentuk tepat satu Redemption__c');

        Redemption__c r = redemptions[0];
        System.assertEquals('BK-003', r.Booking_Ref__c, 'Booking Ref harus tersimpan');
        System.assertEquals('Accrued', r.Status__c, 'Status awal Redemption harus Accrued');
        System.assertEquals(4, r.Qty_Redeemed__c.intValue(), 'Qty harus tersimpan apa adanya');
        System.assertEquals(1000000, r.Gross_Amount__c.intValue(), 'Gross amount harus tersimpan');
        System.assertEquals(10, r.Commission_Rate__c.intValue(), 'Rate komisi harus 10 persen');
        System.assertEquals(100000, r.Commission_Amount__c.intValue(),
            'Komisi harus 10% dari gross amount (10% x 1.000.000)');
        System.assertNotEquals(null, r.Afiliator__c,
            'Redemption harus tertaut ke Account afiliator pemilik kode');
    }

    @IsTest
    static void submitRedemptionMembuatOpportunityClosedWon() {
        siapkanProdukAcuan();

        Test.startTest();
        GuestRedeemVoucherController.submitRedemption(
            KODE_AKTIF, 'Budi Santoso', 'BK-004', 'Ticket & Voucher', 2, 400000);
        Test.stopTest();

        List<Opportunity> opps = [
            SELECT Id, Name, StageName, Amount, LeadSource, PO_Number__c,
                   (SELECT Id, Quantity, UnitPrice FROM OpportunityLineItems)
            FROM Opportunity
            WHERE Name LIKE 'Redeem -%'
        ];
        System.assertEquals(1, opps.size(), 'Harus terbentuk satu Opportunity retail di background');

        Opportunity o = opps[0];
        System.assertEquals('Closed Won', o.StageName,
            'Opportunity hasil redemption harus langsung Closed Won');
        System.assertEquals('BK-004', o.PO_Number__c,
            'Nomor booking harus tercatat sebagai PO Number');
        System.assertEquals('Partner', o.LeadSource, 'LeadSource harus Partner');
        System.assertEquals(1, o.OpportunityLineItems.size(),
            'Opportunity harus punya satu line item produk tiket');
        System.assertEquals(200000, o.OpportunityLineItems[0].UnitPrice.intValue(),
            'Unit price harus gross dibagi qty (400.000 / 2)');
    }

    @IsTest
    static void submitRedemptionMenolakSaatDataAcuanTidakAda() {
        // Hapus data acuan supaya controller masuk ke jalur "data acuan belum tersedia".
        delete [SELECT Id FROM Account WHERE Name = 'Retail Customer - Voucher Redemption'];

        Test.startTest();
        GuestRedeemVoucherController.RedemptionResult hasil =
            GuestRedeemVoucherController.submitRedemption(
                KODE_AKTIF, 'Siti Aminah', 'BK-005', 'Ticket & Voucher', 1, 200000);
        Test.stopTest();

        System.assertEquals(false, hasil.success,
            'Tanpa Account retail acuan, redemption harus ditolak dengan rapi');
        System.assert(hasil.message.contains('Data acuan'),
            'Pesan harus menjelaskan data acuan belum tersedia, dapat: ' + hasil.message);
        System.assertEquals(0, [SELECT COUNT() FROM Redemption__c],
            'Tidak boleh ada Redemption__c yang terbentuk');
    }
}
