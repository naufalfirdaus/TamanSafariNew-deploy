import { LightningElement, wire } from 'lwc';
import getSummary from '@salesforce/apex/AffiliateCommissionSummaryController.getSummary';

export default class AffiliateCommissionSummary extends LightningElement {
    totalUnpaid = 0;
    totalPaid = 0;
    hasError = false;

    @wire(getSummary)
    wiredSummary({ data, error }) {
        if (data) {
            this.totalUnpaid = data.totalUnpaid;
            this.totalPaid = data.totalPaid;
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
        }
    }
}