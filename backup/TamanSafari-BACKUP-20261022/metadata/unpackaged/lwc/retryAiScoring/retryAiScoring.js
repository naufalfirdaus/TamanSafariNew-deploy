import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import retry from "@salesforce/apex/VisitAIScoringController.retry";
import labelTitle from "@salesforce/label/c.Visit_Retry_AI_Title";
import labelSuccess from "@salesforce/label/c.Visit_Retry_AI_Success";

/**
 * Headless record action on Visit_Form__c: asks the server to retry AI scoring for a Failed visit
 * (visit-ai-scoring design D12). The server decides who may retry and which visits qualify, so this
 * component only reports the outcome as a toast.
 */
export default class RetryAiScoring extends LightningElement {
  @api recordId;

  @api
  async invoke() {
    try {
      await retry({ visitId: this.recordId });
      this.toast(labelSuccess, "success");
    } catch (error) {
      this.toast(error?.body?.message || error?.message, "error");
    }
  }

  toast(message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title: labelTitle, message, variant }));
  }
}