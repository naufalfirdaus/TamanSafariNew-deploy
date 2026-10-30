import { LightningElement, api } from "lwc";
import { formatCurrencyIDR, parseCurrencyIDR } from "c/fieldVisitUtils";
import labelChecklistTitle from "@salesforce/label/c.FV_Checklist_Title";
import labelItemPurpose from "@salesforce/label/c.FV_Checklist_Purpose";
import labelItemContact from "@salesforce/label/c.FV_Checklist_Contact";
import labelItemPhoto from "@salesforce/label/c.FV_Checklist_Photo";
import labelItemSummary from "@salesforce/label/c.FV_Checklist_Summary";
import labelItemSignature from "@salesforce/label/c.FV_Checklist_Signature";
import labelPipelineConvertLead from "@salesforce/label/c.FV_Pipeline_Convert_Lead";
import labelPipelineCreateOpp from "@salesforce/label/c.FV_Pipeline_Create_Opp";
import labelPipelineUpdateOpp from "@salesforce/label/c.FV_Pipeline_Update_Opp";
import labelGpsAccuracy from "@salesforce/label/c.FV_GPS_Accuracy";
import labelStepInfo from "@salesforce/label/c.FV_Step_Info";
import labelStepBANT from "@salesforce/label/c.FV_Step_BANT";
import labelStepCheckout from "@salesforce/label/c.FV_Step_Checkout";

export default class VisitCheckoutPanel extends LightningElement {
  @api readiness = {
    hasPurpose: false,
    hasContact: false,
    hasPhoto: false,
    hasSummary: false,
    hasSignatureOrDeclined: false
  };

  @api targetType = "Account";
  @api linkedOpp = null;
  @api pipelineAction = "None";
  @api oppStage = "Qualification";
  @api oppAmount = 0;
  @api oppCloseDate = "";
  @api gpsAccuracy;
  @api checkInAddress = "";
  @api checkoutAddress = "";
  @api distanceMeters = 0;

  labels = {
    checklistTitle: labelChecklistTitle,
    itemPurpose: labelItemPurpose,
    itemContact: labelItemContact,
    itemPhoto: labelItemPhoto,
    itemSummary: labelItemSummary,
    itemSignature: labelItemSignature,
    pipelineConvertLead: labelPipelineConvertLead,
    pipelineCreateOpp: labelPipelineCreateOpp,
    pipelineUpdateOpp: labelPipelineUpdateOpp,
    gpsAccuracy: labelGpsAccuracy,
    stepInfo: labelStepInfo,
    stepBANT: labelStepBANT,
    stepCheckout: labelStepCheckout
  };

  stageOptions = [
    { label: "Qualification", value: "Qualification" },
    { label: "Proposal/Price Quote", value: "Proposal/Price Quote" },
    { label: "Negotiation/Review", value: "Negotiation/Review" },
    { label: "Closed Won", value: "Closed Won" },
    { label: "Closed Lost", value: "Closed Lost" }
  ];

  get isLead() {
    return this.targetType === "Lead";
  }

  get isAccount() {
    return (
      this.targetType === "Account" || this.targetType === "Account_Contact"
    );
  }

  get isAccountWithoutOpp() {
    return this.isAccount && !this.linkedOpp;
  }

  get isAccountWithOpp() {
    return this.isAccount && Boolean(this.linkedOpp);
  }

  get linkedOppName() {
    return this.linkedOpp?.name || "";
  }

  get isConvertLeadChecked() {
    return this.pipelineAction === "Convert Lead";
  }

  get isCreateOppChecked() {
    return this.pipelineAction === "Create Opportunity";
  }

  get formattedOppAmount() {
    return this.oppAmount != null ? formatCurrencyIDR(this.oppAmount) : "";
  }

  get isAllReady() {
    return Boolean(
      this.readiness.hasPurpose &&
      this.readiness.hasContact &&
      this.readiness.hasPhoto &&
      this.readiness.hasSummary &&
      this.readiness.hasSignatureOrDeclined
    );
  }

  get readinessSummaryText() {
    const total = 5;
    let count = 0;
    if (this.readiness.hasPurpose) count++;
    if (this.readiness.hasContact) count++;
    if (this.readiness.hasPhoto) count++;
    if (this.readiness.hasSummary) count++;
    if (this.readiness.hasSignatureOrDeclined) count++;

    return `${count} / ${total} Lengkap`;
  }

  get readinessSummaryClass() {
    return this.isAllReady
      ? "readiness-badge readiness-badge--ready"
      : "readiness-badge readiness-badge--pending";
  }

  get purposeIcon() {
    return this.readiness.hasPurpose ? "utility:check" : "utility:clear";
  }
  get purposeIconClass() {
    return this.readiness.hasPurpose ? "icon-check-ok" : "icon-check-missing";
  }

  get contactIcon() {
    return this.readiness.hasContact ? "utility:check" : "utility:clear";
  }
  get contactIconClass() {
    return this.readiness.hasContact ? "icon-check-ok" : "icon-check-missing";
  }

  get photoIcon() {
    return this.readiness.hasPhoto ? "utility:check" : "utility:clear";
  }
  get photoIconClass() {
    return this.readiness.hasPhoto ? "icon-check-ok" : "icon-check-missing";
  }

  get summaryIcon() {
    return this.readiness.hasSummary ? "utility:check" : "utility:clear";
  }
  get summaryIconClass() {
    return this.readiness.hasSummary ? "icon-check-ok" : "icon-check-missing";
  }

  get signatureIcon() {
    return this.readiness.hasSignatureOrDeclined ? "utility:check" : "utility:clear";
  }
  get signatureIconClass() {
    return this.readiness.hasSignatureOrDeclined ? "icon-check-ok" : "icon-check-missing";
  }

  get gpsStatusText() {
    if (this.gpsAccuracy == null) {
      return "Lokasi check-out akan dicatat saat tombol ditekan.";
    }
    return this.labels.gpsAccuracy.replace("{0}", Math.round(this.gpsAccuracy));
  }

  handleConvertLeadToggle(event) {
    const checked = event.target.checked;
    this.dispatchEvent(
      new CustomEvent("pipelineactionchange", {
        detail: { pipelineAction: checked ? "Convert Lead" : "None" }
      })
    );
  }

  handleCreateOppToggle(event) {
    const checked = event.target.checked;
    this.dispatchEvent(
      new CustomEvent("pipelineactionchange", {
        detail: { pipelineAction: checked ? "Create Opportunity" : "None" }
      })
    );
  }

  handleStageChange(event) {
    this.dispatchEvent(
      new CustomEvent("oppfieldchange", {
        detail: { field: "oppStage", value: event.detail.value }
      })
    );
  }

  handleAmountChange(event) {
    const raw = event.target.value;
    const num = parseCurrencyIDR(raw);
    this.dispatchEvent(
      new CustomEvent("oppfieldchange", {
        detail: { field: "oppAmount", value: num }
      })
    );
  }

  handleCloseDateChange(event) {
    this.dispatchEvent(
      new CustomEvent("oppfieldchange", {
        detail: { field: "oppCloseDate", value: event.target.value }
      })
    );
  }

  handleNavigateStep(event) {
    const step = parseInt(event.currentTarget.dataset.step, 10);
    this.dispatchEvent(
      new CustomEvent("navigatetostep", {
        detail: { step }
      })
    );
  }

  get displayCheckInAddress() {
    return this.checkInAddress || "Sesuai titik awal check-in";
  }

  get displayCheckoutAddress() {
    return this.checkoutAddress || "Mendeteksi posisi GPS saat ini...";
  }

  get isLocationMismatch() {
    return (this.distanceMeters || 0) > 300;
  }

  get locationMatchBadgeClass() {
    return this.isLocationMismatch
      ? "match-badge match-badge--warning"
      : "match-badge match-badge--success";
  }

  get locationMatchBadgeText() {
    const dist = Math.round(this.distanceMeters || 0);
    return this.isLocationMismatch
      ? `⚠️ Luar Lokasi (${dist}m)`
      : `✓ Sesuai Lokasi (${dist}m)`;
  }

  get distanceText() {
    return `${Math.round(this.distanceMeters || 0)} meter`;
  }
}