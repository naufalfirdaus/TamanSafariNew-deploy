import { LightningElement, api } from "lwc";
import labelStatusLocated from "@salesforce/label/c.FV_Status_Located";
import labelStatusRepPinned from "@salesforce/label/c.FV_Status_Rep_Pinned";
import labelStatusNoLocation from "@salesforce/label/c.FV_Status_No_Location";
import labelActionUpdateAddress from "@salesforce/label/c.FV_Action_Update_Address";
import labelActionPinLocation from "@salesforce/label/c.FV_Action_Pin_Location";
import labelGpsAccuracy from "@salesforce/label/c.FV_GPS_Accuracy";
import labelTargetAccount from "@salesforce/label/c.FV_Target_Account";
import labelTargetLead from "@salesforce/label/c.FV_Target_Lead";
import labelTargetNoLocation from "@salesforce/label/c.Visit_Err_Target_No_Location";

export default class VisitTargetCard extends LightningElement {
  @api targetContext;
  @api address = "";
  @api gpsAccuracy;
  @api repLatitude;
  @api repLongitude;

  labels = {
    statusLocated: labelStatusLocated,
    statusRepPinned: labelStatusRepPinned,
    statusNoLocation: labelStatusNoLocation,
    actionUpdateAddress: labelActionUpdateAddress,
    actionPinLocation: labelActionPinLocation,
    gpsAccuracy: labelGpsAccuracy,
    targetAccount: labelTargetAccount,
    targetLead: labelTargetLead,
    unlocatedHint: labelTargetNoLocation
  };

  get targetName() {
    return this.targetContext?.name || "";
  }

  get targetTypeLabel() {
    if (this.targetContext?.targetType === "Lead") {
      return this.labels.targetLead;
    }
    return this.labels.targetAccount;
  }

  get effectiveAddress() {
    return this.address || this.targetContext?.address || "";
  }

  get hasAddress() {
    return Boolean(this.effectiveAddress && this.effectiveAddress.trim().length > 0);
  }

  get isUnlocated() {
    return !this.targetContext?.hasCoordinates;
  }

  get isRepPinned() {
    return Boolean(
      this.targetContext?.hasCoordinates &&
      this.targetContext?.locationSource === "Rep Pinned"
    );
  }

  get isLocated() {
    return Boolean(this.targetContext?.hasCoordinates && !this.isRepPinned);
  }

  get showLockToggle() {
    return Boolean(this.targetContext?.hasCoordinates);
  }

  get isLocationLocked() {
    return this.targetContext?.isLocationLocked !== false;
  }

  get lockIconName() {
    return this.isLocationLocked ? "utility:lock" : "utility:unlock";
  }

  get lockIconClass() {
    return this.isLocationLocked ? "lock-icon lock-icon--locked" : "lock-icon lock-icon--unlocked";
  }

  get lockStatusText() {
    return this.isLocationLocked
      ? "Lokasi Terkunci (Location Locked)"
      : "Lokasi Terbuka (Location Unlocked)";
  }

  get lockHintText() {
    return this.isLocationLocked
      ? "Titik peta terkunci. Perubahan alamat di CRM tidak akan merubah titik peta."
      : "Titik peta terbuka. Perubahan alamat di CRM akan memperbarui posisi titik peta.";
  }

  get statusLabel() {
    if (this.isUnlocated) return this.labels.statusNoLocation;
    if (this.isRepPinned) return this.labels.statusRepPinned;
    return this.labels.statusLocated;
  }

  get statusBadgeClass() {
    const base = "status-badge";
    if (this.isUnlocated) return `${base} ${base}--unlocated`;
    if (this.isRepPinned) return `${base} ${base}--pinned`;
    return `${base} ${base}--located`;
  }

  get accuracyText() {
    if (this.gpsAccuracy == null) return "";
    return this.labels.gpsAccuracy.replace("{0}", Math.round(this.gpsAccuracy));
  }

  get hasMapMarkers() {
    return this.mapMarkers.length > 0;
  }

  get mapMarkers() {
    const markers = [];
    const hasTargetCoords =
      this.targetContext?.latitude != null &&
      this.targetContext?.longitude != null;

    if (hasTargetCoords) {
      markers.push({
        location: {
          Latitude: this.targetContext.latitude,
          Longitude: this.targetContext.longitude
        },
        title: this.targetName || "Target Kunjungan",
        description: this.effectiveAddress || this.targetName,
        icon: this.targetContext?.targetType === "Lead" ? "standard:lead" : "standard:account"
      });
    }

    if (this.repLatitude != null && this.repLongitude != null) {
      markers.push({
        location: {
          Latitude: this.repLatitude,
          Longitude: this.repLongitude
        },
        title: "Posisi Anda",
        description: "Lokasi Sales Representative saat ini",
        icon: "standard:user"
      });
    }

    return markers;
  }

  get zoomLevel() {
    return this.mapMarkers.length === 1 ? 15 : undefined;
  }

  handleUpdateAddress() {
    this.dispatchEvent(new CustomEvent("updateaddress"));
  }

  handlePinLocation() {
    this.dispatchEvent(new CustomEvent("pinlocation"));
  }

  handleToggleLock(event) {
    const isLocked = event.target.checked;
    this.dispatchEvent(
      new CustomEvent("locationlockchange", {
        detail: { isLocked }
      })
    );
  }
}