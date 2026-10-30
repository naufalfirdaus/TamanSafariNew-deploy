import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import labelCompleteTitle from "@salesforce/label/c.FV_Complete_Title";
import labelCompleteDuration from "@salesforce/label/c.FV_Complete_Duration";
import labelScoreBreakdownTitle from "@salesforce/label/c.FV_Score_Breakdown_Title";
import labelScoreLocation from "@salesforce/label/c.FV_Score_Location";
import labelScoreDuration from "@salesforce/label/c.FV_Score_Duration";
import labelScoreProof from "@salesforce/label/c.FV_Score_Proof";
import labelScoreTotal from "@salesforce/label/c.FV_Score_Total";
import labelBtnNewVisit from "@salesforce/label/c.FV_Btn_New_Visit";

export default class VisitCompletionSummary extends NavigationMixin(LightningElement) {
  @api completionResult = {};

  labels = {
    completeTitle: labelCompleteTitle,
    completeDuration: labelCompleteDuration,
    scoreBreakdownTitle: labelScoreBreakdownTitle,
    scoreLocation: labelScoreLocation,
    scoreDuration: labelScoreDuration,
    scoreProof: labelScoreProof,
    scoreTotal: labelScoreTotal,
    btnNewVisit: labelBtnNewVisit
  };

  get durationText() {
    const dur = this.completionResult?.durationMinutes || 0;
    return this.labels.completeDuration.replace("{0}", dur);
  }

  get locationScoreText() {
    const score = this.completionResult?.locationScore ?? 0;
    return `${score} / 20`;
  }

  get durationScoreText() {
    const score = this.completionResult?.durationScore ?? 0;
    return `${score} / 15`;
  }

  get proofScoreText() {
    const score = this.completionResult?.proofScore ?? 0;
    return `${score} / 15`;
  }

  get totalScoreText() {
    const score = this.completionResult?.telemetryScore ?? 0;
    return `${score} / 50`;
  }

  get hasAddressSummary() {
    return Boolean(
      this.completionResult?.checkInAddress ||
      this.completionResult?.checkOutAddress
    );
  }

  get checkInAddressText() {
    return this.completionResult?.checkInAddress || "Alamat Check-In tidak tercatat";
  }

  get checkOutAddressText() {
    return this.completionResult?.checkOutAddress || "Alamat Check-Out tidak tercatat";
  }

  get distanceMeters() {
    return Math.round(this.completionResult?.checkOutFromCheckInM ?? 0);
  }

  get isLocationMatch() {
    return this.distanceMeters <= 300;
  }

  get addressMatchBadgeClass() {
    return this.isLocationMatch
      ? "match-badge match-badge--success"
      : "match-badge match-badge--warning";
  }

  get addressMatchBadgeText() {
    return this.isLocationMatch
      ? `✓ Lokasi Sesuai (${this.distanceMeters}m)`
      : `⚠️ Di Luar Lokasi (${this.distanceMeters}m)`;
  }

  get hasRelatedRecords() {
    return Boolean(
      this.completionResult?.eventId ||
      this.completionResult?.opportunityId ||
      this.completionResult?.accountId
    );
  }

  handleNavigateRecord(event) {
    const recordId = event.currentTarget.dataset.id;
    if (recordId) {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: recordId,
          actionName: "view"
        }
      });
    }
  }

  handleNewVisit() {
    this.dispatchEvent(new CustomEvent("startnewvisit"));
  }
}