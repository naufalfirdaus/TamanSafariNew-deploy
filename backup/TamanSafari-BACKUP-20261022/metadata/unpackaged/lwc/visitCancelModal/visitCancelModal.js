import LightningModal from "lightning/modal";
import { track } from "lwc";
import labelTitle from "@salesforce/label/c.FV_Cancel_Title";
import labelBody from "@salesforce/label/c.FV_Cancel_Body";
import labelNoShow from "@salesforce/label/c.FV_Cancel_Reason_NoShow";
import labelWrongTarget from "@salesforce/label/c.FV_Cancel_Reason_WrongTarget";
import labelRescheduled from "@salesforce/label/c.FV_Cancel_Reason_Rescheduled";
import labelCancel from "@salesforce/label/c.FV_Btn_Cancel";
import labelCancelVisit from "@salesforce/label/c.FV_Action_Cancel_Visit";

export default class VisitCancelModal extends LightningModal {
  @track selectedReason = "";

  labels = {
    title: labelTitle,
    body: labelBody,
    noShow: labelNoShow,
    wrongTarget: labelWrongTarget,
    rescheduled: labelRescheduled,
    cancel: labelCancel,
    confirmCancel: labelCancelVisit
  };

  rawReasons = [
    { value: "Client Not Available", labelKey: "noShow" },
    { value: "Wrong Target Selected", labelKey: "wrongTarget" },
    { value: "Rescheduled", labelKey: "rescheduled" }
  ];

  get reasonOptions() {
    return this.rawReasons.map((r) => {
      const isSelected = this.selectedReason === r.value;
      let cssClass = "touch-pill";
      if (isSelected) {
        cssClass += " touch-pill--selected";
      }
      return {
        value: r.value,
        label: this.labels[r.labelKey],
        isSelected,
        cssClass
      };
    });
  }

  get isConfirmDisabled() {
    return !this.selectedReason;
  }

  handleSelectReason(event) {
    this.selectedReason = event.currentTarget.dataset.value;
  }

  handleCancel() {
    this.close({ confirmed: false });
  }

  handleConfirm() {
    if (!this.selectedReason) return;
    this.close({
      confirmed: true,
      reason: this.selectedReason
    });
  }
}