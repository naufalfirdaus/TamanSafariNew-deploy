import LightningModal from "lightning/modal";
import { api, track } from "lwc";
import labelWarningTitle from "@salesforce/label/c.FV_Geofence_Warning_Title";
import labelWarningBody from "@salesforce/label/c.FV_Geofence_Warning_Body";
import labelBlockingTitle from "@salesforce/label/c.FV_Geofence_Blocking_Title";
import labelBlockingBody from "@salesforce/label/c.FV_Geofence_Blocking_Body";
import labelReasonWeakGPS from "@salesforce/label/c.FV_Reason_Weak_GPS";
import labelReasonExternalMeeting from "@salesforce/label/c.FV_Reason_External_Meeting";
import labelReasonDifferentBranch from "@salesforce/label/c.FV_Reason_Different_Branch";
import labelConfirmCheckIn from "@salesforce/label/c.FV_Btn_Confirm_CheckIn";
import labelCancel from "@salesforce/label/c.FV_Btn_Cancel";
import labelBack from "@salesforce/label/c.FV_Btn_Back";

export default class VisitGeofenceModal extends LightningModal {
  @api isHardBlock = false;
  @api distanceMeters = 0;
  @api radiusMeters = 300;

  @track selectedReason = "";

  labels = {
    warningTitle: labelWarningTitle,
    warningBody: labelWarningBody,
    blockingTitle: labelBlockingTitle,
    blockingBody: labelBlockingBody,
    reasonWeakGPS: labelReasonWeakGPS,
    reasonExternalMeeting: labelReasonExternalMeeting,
    reasonDifferentBranch: labelReasonDifferentBranch,
    confirmCheckIn: labelConfirmCheckIn,
    cancel: labelCancel,
    back: labelBack
  };

  rawReasons = [
    { value: "Weak GPS / Indoor Tower", labelKey: "reasonWeakGPS" },
    { value: "Met at External Cafe/Restaurant", labelKey: "reasonExternalMeeting" },
    { value: "Different Branch/Building", labelKey: "reasonDifferentBranch" }
  ];

  get modalTitle() {
    return this.isHardBlock ? this.labels.blockingTitle : this.labels.warningTitle;
  }

  get warningBodyText() {
    const dist = Math.round(this.distanceMeters || 0);
    const rad = Math.round(this.radiusMeters || 300);
    return this.labels.warningBody.replace("{0}", dist).replace("{1}", rad);
  }

  get blockingBodyText() {
    const dist = Math.round(this.distanceMeters || 0);
    const rad = Math.round(this.radiusMeters || 300);
    return this.labels.blockingBody.replace("{0}", dist).replace("{1}", rad);
  }

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