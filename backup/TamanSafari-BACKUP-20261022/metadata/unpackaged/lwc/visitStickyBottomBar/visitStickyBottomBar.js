import { LightningElement, api } from "lwc";
import labelBack from "@salesforce/label/c.FV_Btn_Back";
import labelNext from "@salesforce/label/c.FV_Btn_Next";
import labelSaving from "@salesforce/label/c.FV_Draft_Saving";
import labelSaved from "@salesforce/label/c.FV_Draft_Saved";
import labelFailed from "@salesforce/label/c.FV_Draft_Failed";

export default class VisitStickyBottomBar extends LightningElement {
  @api currentStep = 1;
  @api totalSteps = 3;
  @api isNextDisabled = false;
  @api nextLabel = "";
  @api prevLabel = "";
  @api showPrevious = false;
  @api saveStatus = ""; // 'saving', 'saved', 'failed'
  @api isLoading = false;
  @api loadingLabel = "";

  labels = {
    back: labelBack,
    next: labelNext,
    saving: labelSaving,
    saved: labelSaved,
    failed: labelFailed
  };

  get hasSaveStatus() {
    return Boolean(this.saveStatus);
  }

  get saveStatusText() {
    if (this.saveStatus === "saving") return this.labels.saving;
    if (this.saveStatus === "saved") return `✓ ${this.labels.saved}`;
    if (this.saveStatus === "failed") return `⚠ ${this.labels.failed}`;
    return "";
  }

  get saveStatusClass() {
    const base = "save-status-text";
    if (this.saveStatus === "saving") return `${base} save-status-text--saving`;
    if (this.saveStatus === "saved") return `${base} save-status-text--saved`;
    if (this.saveStatus === "failed") return `${base} save-status-text--failed`;
    return base;
  }

  get effectiveIsNextDisabled() {
    return Boolean(this.isNextDisabled) || Boolean(this.isLoading);
  }

  get displayNextLabel() {
    if (this.isLoading && this.loadingLabel) {
      return this.loadingLabel;
    }
    return this.nextLabel || this.labels.next;
  }

  get displayPrevLabel() {
    return this.prevLabel || this.labels.back;
  }

  get nextButtonClass() {
    let cls = "btn-footer btn-footer--primary";
    if (!this.showPrevious) {
      cls += " btn-footer--full";
    }
    return cls;
  }

  handlePrevious() {
    this.dispatchEvent(new CustomEvent("previous"));
  }

  handleNext() {
    this.dispatchEvent(new CustomEvent("next"));
  }

  handleSaveStatusClick() {
    if (this.saveStatus === "failed") {
      this.dispatchEvent(new CustomEvent("retrysave"));
    }
  }
}