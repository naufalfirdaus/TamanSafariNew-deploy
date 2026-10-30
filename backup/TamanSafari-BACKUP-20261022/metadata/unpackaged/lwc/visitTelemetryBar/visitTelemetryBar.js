import { LightningElement, api } from "lwc";
import { formatTimer } from "c/fieldVisitUtils";
import labelCancelVisit from "@salesforce/label/c.FV_Action_Cancel_Visit";
import labelTelemetryVerified from "@salesforce/label/c.FV_Telemetry_Verified";
import labelTelemetryOffSite from "@salesforce/label/c.FV_Telemetry_OffSite";
import labelGpsAcquiring from "@salesforce/label/c.FV_GPS_Acquiring";
import labelDraftSaving from "@salesforce/label/c.FV_Draft_Saving";

export default class VisitTelemetryBar extends LightningElement {
  @api elapsedSeconds = 0;
  @api locationStatus = "verified"; // 'verified', 'offsite', 'acquiring', 'error'
  @api distanceMeters = 0;
  @api targetName = "";
  @api isSaving = false;

  labels = {
    cancelVisit: labelCancelVisit,
    saving: labelDraftSaving,
    acquiring: labelGpsAcquiring
  };

  get formattedTime() {
    return formatTimer(this.elapsedSeconds);
  }

  get gpsLabel() {
    const dist = Math.round(this.distanceMeters || 0);
    if (this.locationStatus === "offsite") {
      return labelTelemetryOffSite.replace("{0}", dist);
    }
    if (this.locationStatus === "acquiring") {
      return this.labels.acquiring;
    }
    if (this.locationStatus === "error") {
      return "GPS Tidak Tersedia";
    }
    return labelTelemetryVerified.replace("{0}", dist);
  }

  get gpsPillClass() {
    const base = "telemetry-bar__gps-pill";
    if (this.locationStatus === "offsite") {
      return `${base} ${base}--warning`;
    }
    if (this.locationStatus === "acquiring") {
      return `${base} ${base}--acquiring`;
    }
    if (this.locationStatus === "error") {
      return `${base} ${base}--error`;
    }
    return `${base} ${base}--success`;
  }

  handleCancelClick() {
    this.dispatchEvent(new CustomEvent("cancelclick"));
  }
}