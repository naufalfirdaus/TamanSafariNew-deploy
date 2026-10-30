/**
 * Menghitung ringkasan total komisi afiliator (belum dicairkan vs sudah dicairkan)
 * untuk ditampilkan di banner atas halaman "Kode Afiliasi dan Klaim Saya" di portal.
 * Sengaja "with sharing" -- tidak melakukan filter Account manual, murni mengandalkan
 * sharing model (Master-Detail/ControlledByParent) supaya setiap afiliator otomatis
 * hanya melihat total milik Account mereka sendiri.
 */
public with sharing class AffiliateCommissionSummaryController {

    @AuraEnabled(cacheable=true)
    public static CommissionSummary getSummary() {
        CommissionSummary result = new CommissionSummary();

        for (AggregateResult ar : [
            SELECT Status__c st, SUM(Payable_Amount__c) total
            FROM Commission_Statement__c
            GROUP BY Status__c
        ]) {
            String status = (String) ar.get('st');
            Decimal total = (Decimal) ar.get('total');
            if (total == null) {
                continue;
            }
            if (status == 'Paid') {
                result.totalPaid += total;
            } else if (status == 'Eligible' || status == 'Approved' || status == 'Issued' || status == 'Claimed') {
                result.totalUnpaid += total;
            }
        }
        return result;
    }

    public class CommissionSummary {
        @AuraEnabled public Decimal totalUnpaid = 0;
        @AuraEnabled public Decimal totalPaid = 0;
    }
}