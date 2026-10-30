/**
 * Test untuk AffiliateCommissionSummaryController.
 *
 * Catatan data: Payable_Amount__c adalah formula (Total_Commission__c + Carry_Over_In__c,
 * blank dianggap nol), jadi test menyiapkan angka lewat kedua field sumber tersebut,
 * bukan menulis langsung ke Payable_Amount__c.
 */
@IsTest
private class AffiliateCommissionSummaryControllerTest {

    @TestSetup
    static void siapkanData() {
        Account afiliator = new Account(Name = 'Afiliator Komisi Test', Type = 'Partner');
        insert afiliator;

        insert new List<Commission_Statement__c>{
            // Paid -> masuk totalPaid: 100 + (50 + 25) = 175
            new Commission_Statement__c(Afiliator__c = afiliator.Id, Status__c = 'Paid',
                Total_Commission__c = 100, Carry_Over_In__c = 0),
            new Commission_Statement__c(Afiliator__c = afiliator.Id, Status__c = 'Paid',
                Total_Commission__c = 50, Carry_Over_In__c = 25),
            // Empat status di bawah masuk totalUnpaid: 200 + 300 + 400 + 500 = 1400
            new Commission_Statement__c(Afiliator__c = afiliator.Id, Status__c = 'Eligible',
                Total_Commission__c = 200, Carry_Over_In__c = 0),
            new Commission_Statement__c(Afiliator__c = afiliator.Id, Status__c = 'Approved',
                Total_Commission__c = 300, Carry_Over_In__c = 0),
            new Commission_Statement__c(Afiliator__c = afiliator.Id, Status__c = 'Issued',
                Total_Commission__c = 400, Carry_Over_In__c = 0),
            new Commission_Statement__c(Afiliator__c = afiliator.Id, Status__c = 'Claimed',
                Total_Commission__c = 500, Carry_Over_In__c = 0),
            // Draft sengaja diabaikan controller -- angkanya dibuat besar supaya
            // kalau sampai ikut terhitung, assert pasti gagal.
            new Commission_Statement__c(Afiliator__c = afiliator.Id, Status__c = 'Draft',
                Total_Commission__c = 9999, Carry_Over_In__c = 0)
        };
    }

    @IsTest
    static void memisahkanTotalPaidDanUnpaid() {
        Test.startTest();
        AffiliateCommissionSummaryController.CommissionSummary hasil =
            AffiliateCommissionSummaryController.getSummary();
        Test.stopTest();

        System.assertEquals(175, hasil.totalPaid.intValue(),
            'totalPaid harus menjumlahkan seluruh statement berstatus Paid');
        System.assertEquals(1400, hasil.totalUnpaid.intValue(),
            'totalUnpaid harus menjumlahkan status Eligible, Approved, Issued, dan Claimed');
    }

    @IsTest
    static void statusDraftTidakIkutDihitung() {
        Test.startTest();
        AffiliateCommissionSummaryController.CommissionSummary hasil =
            AffiliateCommissionSummaryController.getSummary();
        Test.stopTest();

        Decimal totalSemua = hasil.totalPaid + hasil.totalUnpaid;
        System.assertEquals(1575, totalSemua.intValue(),
            'Statement berstatus Draft (9999) tidak boleh ikut terhitung di total manapun');
    }

    @IsTest
    static void tanpaStatementMengembalikanNol() {
        delete [SELECT Id FROM Commission_Statement__c];

        Test.startTest();
        AffiliateCommissionSummaryController.CommissionSummary hasil =
            AffiliateCommissionSummaryController.getSummary();
        Test.stopTest();

        System.assertEquals(0, hasil.totalPaid.intValue(),
            'Tanpa data, totalPaid harus nol bukan null');
        System.assertEquals(0, hasil.totalUnpaid.intValue(),
            'Tanpa data, totalUnpaid harus nol bukan null');
    }
}
