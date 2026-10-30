/**
 * Menggantikan Screen Flow "Redeem_Affiliate_Voucher" khusus untuk konteks Guest User --
 * Screen Flow terbukti tidak bisa dijalankan Guest di situs Aura Community ini
 * (sudah dicoba lewat reserved page /flow/, Visualforce flow:interview, dan ditanam
 * langsung di halaman Home; ketiganya gagal). Logic bisnisnya sama persis dengan flow:
 * validasi kode -> buat Opportunity+OpportunityLineItem retail di background -> buat Redemption__c.
 *
 * "without sharing" secara sengaja: Guest User tidak punya sharing rule ke Account
 * afiliator manapun (beda dengan Partner User yang punya implicit AccountShare ke
 * Account sendiri), jadi query record Affiliate_Code__c akan selalu kosong kalau
 * class ini "with sharing". Query & DML tetap dibatasi ketat oleh filter bisnis
 * (Status__c='Active', Valid_To__c>=TODAY) supaya tidak jadi lubang akses sembarangan.
 */
public without sharing class GuestRedeemVoucherController {

    // Record acuan dicari berdasarkan nama, bukan Id mati. Id Salesforce bersifat
    // per-org, jadi konstanta Id membuat class ini hanya bisa jalan di org tempat
    // ia dibuat -- begitu dideploy ke org lain, redemption selalu gagal.
    private static final String RETAIL_ACCOUNT_NAME = 'Retail Customer - Voucher Redemption';
    private static final String DEFAULT_PRODUCT_NAME = 'Tiket Masuk Taman Safari Bogor';
    private static final Decimal COMMISSION_RATE_PERCENT = 10.0;

    private static Id getRetailAccountId() {
        List<Account> akun = [
            SELECT Id FROM Account WHERE Name = :RETAIL_ACCOUNT_NAME LIMIT 1
        ];
        return akun.isEmpty() ? null : akun[0].Id;
    }

    /**
     * Sengaja TIDAK memfilter Pricebook2.IsStandard di SOQL: pada konteks Apex test,
     * pricebook dari Test.getStandardPricebookId() tidak membawa flag IsStandard,
     * sehingga filter itu selalu menghasilkan nol baris. Entry di Standard Price Book
     * tetap diutamakan, tapi lewat pemilihan di Apex, bukan di klausa WHERE.
     */
    private static Id getDefaultPricebookEntryId() {
        String namaProduk = DEFAULT_PRODUCT_NAME;
        String soql =
            'SELECT Id, Pricebook2.IsStandard FROM PricebookEntry '
            + 'WHERE Product2.Name = :namaProduk AND IsActive = true';
        // Mata uang PricebookEntry WAJIB sama dengan mata uang Opportunity, kalau
        // tidak Salesforce menolak OpportunityLineItem dengan FIELD_INTEGRITY_EXCEPTION.
        // Karena setMataUang() memakai IDR bila tersedia, entry IDR pula yang dicari.
        if (idrTersedia()) {
            soql += ' AND CurrencyIsoCode = \'IDR\'';
        }
        soql += ' ORDER BY CreatedDate';

        List<PricebookEntry> entri = Database.query(soql);
        if (entri.isEmpty()) {
            return null;
        }
        for (PricebookEntry e : entri) {
            if (e.Pricebook2.IsStandard == true) {
                return e.Id;
            }
        }
        return entri[0].Id;
    }

    public class AffiliateCodeResult {
        @AuraEnabled public Boolean valid;
        @AuraEnabled public String message;
    }

    public class RedemptionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    /**
     * Menyetel mata uang hanya bila IDR benar-benar aktif di org. Org tujuan bisa
     * saja belum mengaktifkan IDR (mis. hanya USD), dan memaksakan 'IDR' membuat
     * insert gagal total dengan INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST. Bila IDR
     * tidak tersedia, record memakai mata uang default org.
     */
    private static Boolean idrTersediaCache = null;

    private static Boolean idrTersedia() {
        if (idrTersediaCache == null) {
            idrTersediaCache = false;
            try {
                idrTersediaCache = !Database.query(
                    'SELECT Id FROM CurrencyType WHERE IsoCode = \'IDR\' AND IsActive = true LIMIT 1'
                ).isEmpty();
            } catch (Exception e) {
                idrTersediaCache = false;
            }
        }
        return idrTersediaCache;
    }

    private static void setMataUang(SObject record) {
        if (idrTersedia()) {
            record.put('CurrencyIsoCode', 'IDR');
        }
    }

    @AuraEnabled
    public static AffiliateCodeResult validateCode(String voucherCode) {
        AffiliateCodeResult result = new AffiliateCodeResult();
        List<Affiliate_Code__c> codes = [
            SELECT Id, Afiliator__c
            FROM Affiliate_Code__c
            WHERE Code__c = :voucherCode
            AND Status__c = 'Active'
            AND Valid_To__c >= TODAY
            LIMIT 1
        ];
        if (codes.isEmpty()) {
            result.valid = false;
            result.message = 'Kode voucher tidak ditemukan, sudah kedaluwarsa, atau tidak aktif.';
        } else {
            result.valid = true;
            result.message = 'Kode valid.';
        }
        return result;
    }

    @AuraEnabled
    public static RedemptionResult submitRedemption(
        String voucherCode,
        String customerName,
        String bookingNumber,
        String productFamily,
        Decimal qty,
        Decimal grossAmount
    ) {
        RedemptionResult result = new RedemptionResult();

        List<Affiliate_Code__c> codes = [
            SELECT Id, Afiliator__c
            FROM Affiliate_Code__c
            WHERE Code__c = :voucherCode
            AND Status__c = 'Active'
            AND Valid_To__c >= TODAY
            LIMIT 1
        ];
        if (codes.isEmpty()) {
            result.success = false;
            result.message = 'Kode voucher tidak valid lagi. Silakan ulangi dari awal.';
            return result;
        }
        Affiliate_Code__c affCode = codes[0];

        Id retailAccountId = getRetailAccountId();
        Id pricebookEntryId = getDefaultPricebookEntryId();
        if (retailAccountId == null || pricebookEntryId == null) {
            List<String> kurang = new List<String>();
            if (retailAccountId == null) {
                kurang.add('Account "' + RETAIL_ACCOUNT_NAME + '"');
            }
            if (pricebookEntryId == null) {
                kurang.add('produk "' + DEFAULT_PRODUCT_NAME + '" yang aktif di Standard Price Book');
            }
            result.success = false;
            result.message = 'Data acuan redemption belum tersedia di org ini: '
                + String.join(kurang, ' dan ') + ' tidak ditemukan.';
            return result;
        }

        try {
            Opportunity opp = new Opportunity(
                Name = 'Redeem - ' + voucherCode + ' - ' + String.valueOf(Date.today()),
                AccountId = retailAccountId,
                CloseDate = Date.today(),
                StageName = 'Qualification',
                Amount = grossAmount,
                LeadSource = 'Partner'
            );
            setMataUang(opp);
            opp.put('SDO_Sales_Partner_Owner__c', affCode.Afiliator__c);
            insert opp;

            OpportunityLineItem oli = new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = pricebookEntryId,
                Quantity = qty,
                UnitPrice = (qty != 0 ? grossAmount / qty : grossAmount)
            );
            insert oli;

            opp.StageName = 'Closed Won';
            opp.put('PO_Number__c', bookingNumber);
            update opp;

            Redemption__c red = new Redemption__c(
                Affiliate_Code__c = affCode.Id,
                Afiliator__c = affCode.Afiliator__c,
                Redemption_Date__c = Date.today(),
                Status__c = 'Accrued',
                Product_Family__c = productFamily,
                Qty_Redeemed__c = qty,
                Gross_Amount__c = grossAmount,
                Commission_Rate__c = COMMISSION_RATE_PERCENT,
                Commission_Amount__c = grossAmount * (COMMISSION_RATE_PERCENT / 100.0),
                Booking_Ref__c = bookingNumber
            );
            setMataUang(red);
            insert red;

            result.success = true;
            result.message = 'Voucher berhasil diredeem! Selamat menikmati layanan Taman Safari Indonesia.';
        } catch (Exception e) {
            result.success = false;
            result.message = 'Terjadi kesalahan saat memproses redemption: ' + e.getMessage();
        }
        return result;
    }
}