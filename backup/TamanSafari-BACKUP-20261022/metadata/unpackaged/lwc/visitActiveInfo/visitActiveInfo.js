import { LightningElement, api } from "lwc";
import labelContactLabel from "@salesforce/label/c.FV_Contact_Picker_Label";
import labelQuickCreateContact from "@salesforce/label/c.FV_Btn_Quick_Create_Contact";
import labelPurposeLabel from "@salesforce/label/c.FV_Purpose_Label";
import labelPurposeInitial from "@salesforce/label/c.FV_Purpose_Initial";
import labelPurposeFollowUp from "@salesforce/label/c.FV_Purpose_FollowUp";
import labelPurposeFinal from "@salesforce/label/c.FV_Purpose_Final";
import labelOppLabel from "@salesforce/label/c.FV_Opp_Picker_Label";
import labelPrefillHint from "@salesforce/label/c.FV_Prefill_Hint";
import labelPhotoTitle from "@salesforce/label/c.FV_Photo_Section_Title";
import labelTakePhoto from "@salesforce/label/c.FV_Btn_Take_Photo";
import labelRetakePhoto from "@salesforce/label/c.FV_Btn_Retake_Photo";
import labelStepInfo from "@salesforce/label/c.FV_Step_Info";
import labelStepBANT from "@salesforce/label/c.FV_Step_BANT";
import labelStepCheckout from "@salesforce/label/c.FV_Step_Checkout";

export default class VisitActiveInfo extends LightningElement {
  @api targetType = "Account";
  @api accountId;
  @api leadName = "";
  @api contacts = [];
  @api opportunities = [];
  @api selectedContactId = "";
  @api purpose = "Initial Canvassing / Discovery";
  @api linkedOpportunityId = "";
  @api photoSnapshotUrl = "";
  @api photoCapturedAt = "";
  @api isDuplicatePhoto = false;
  @api hasPrefillNotice = false;

  labels = {
    contactLabel: labelContactLabel,
    quickCreateContact: labelQuickCreateContact,
    purposeLabel: labelPurposeLabel,
    purposeInitial: labelPurposeInitial,
    purposeFollowUp: labelPurposeFollowUp,
    purposeFinal: labelPurposeFinal,
    oppLabel: labelOppLabel,
    prefillHint: labelPrefillHint,
    photoTitle: labelPhotoTitle,
    takePhoto: labelTakePhoto,
    retakePhoto: labelRetakePhoto,
    stepInfo: labelStepInfo,
    stepBANT: labelStepBANT,
    stepCheckout: labelStepCheckout
  };

  rawPurposes = [
    { value: "Initial Canvassing / Discovery", labelKey: "purposeInitial" },
    { value: "Follow-Up / Proposal Review", labelKey: "purposeFollowUp" },
    { value: "Final Confirmation / Contracting", labelKey: "purposeFinal" }
  ];

  get isAccount() {
    return (
      this.targetType === "Account" || this.targetType === "Account_Contact"
    );
  }

  get displayLeadName() {
    return this.leadName || "Prospek (Lead)";
  }

  get contactOptions() {
    if (!this.contacts || this.contacts.length === 0) {
      return [{ label: "Belum ada kontak terdaftar", value: "" }];
    }
    return this.contacts.map((c) => ({
      label: `${c.name}${c.title ? " (" + c.title + ")" : ""}`,
      value: c.id
    }));
  }

  get oppOptions() {
    if (!this.opportunities || this.opportunities.length === 0) {
      return [{ label: "Tidak ada peluang aktif", value: "" }];
    }
    return this.opportunities.map((o) => ({
      label: `${o.name} (${o.stageName || ""})`,
      value: o.id
    }));
  }

  get purposeOptions() {
    return this.rawPurposes.map((p) => {
      const isSelected = this.purpose === p.value;
      let cssClass = "purpose-pill";
      if (isSelected) {
        cssClass += " purpose-pill--selected";
      }
      return {
        value: p.value,
        label: this.labels[p.labelKey],
        isSelected,
        cssClass
      };
    });
  }

  get showOpportunityPicker() {
    return (
      this.isAccount &&
      (this.purpose === "Follow-Up / Proposal Review" ||
        this.purpose === "Final Confirmation / Contracting")
    );
  }

  get hasPhoto() {
    return Boolean(this.photoSnapshotUrl);
  }

  handleContactChange(event) {
    this.dispatchEvent(
      new CustomEvent("contactchange", {
        detail: { contactId: event.detail.value }
      })
    );
  }

  handleQuickCreateContact() {
    this.dispatchEvent(new CustomEvent("quickcreatecontact"));
  }

  handlePurposeClick(event) {
    const val = event.currentTarget.dataset.value;
    this.dispatchEvent(
      new CustomEvent("purposechange", {
        detail: { purpose: val }
      })
    );
  }

  handleOpportunityChange(event) {
    this.dispatchEvent(
      new CustomEvent("opportunitychange", {
        detail: { opportunityId: event.detail.value }
      })
    );
  }

  handleTakePhoto() {
    this.dispatchEvent(new CustomEvent("takephoto"));
  }

  handleRetakePhoto() {
    this.dispatchEvent(new CustomEvent("retakephoto"));
  }
}