import { LightningElement, api, wire, track } from "lwc";
import getContext from "@salesforce/apex/CheckInService.getContextEvent";
import finishCheckOut from "@salesforce/apex/CheckInService.finishCheckOut";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import getEventFiles from "@salesforce/apex/CheckInService.getEventFiles";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
// import TextractWizard from "c/textractWizard";

const ICONS = {
  targetBuilding: {
    path: "M6,2 L18,2 L18,22 L6,22 Z M8,6 H10 V9 H8 Z M11,6 H13 V10 H11 Z M14,6 H16 V8 H14 Z M8,11 H10 V13 H8 Z M11,11 H13 V14 H11 Z M14,11 H16 V12 H14 Z M8,15 H16 V17 H8 Z",
    fillColor: "#1A73E8",
    fillOpacity: 1,
    strokeColor: "#FFFFFF",
    strokeOpacity: 1,
    strokeWeight: 2,
    scale: 1.25
  },
  youPerson: {
    path: "M12,7 A3,3 0 1,0 12,1 A3,3 0 1,0 12,7 Z M4,22 C4,17.6 8,15 12,15 C16,15 20,17.6 20,22 Z",
    fillColor: "#D93025",
    fillOpacity: 1,
    strokeColor: "#111111",
    strokeOpacity: 0.95,
    strokeWeight: 1.8,
    scale: 1.2
  }
};

export default class GeoCheckoutPanel extends NavigationMixin(
  LightningElement
) {
  @api recordId;
  @api objectApiName;

  @track parentName;
  @track radiusM = 0;
  @track target = { lat: null, lng: null };
  @track you = { lat: null, lng: null, acc: null };
  @track distanceM = null;

  openEventId = null;
  isChecking = false;
  error;
  overrideReason = "";
  showRoute = false;

  mapMarkers = [];
  photos = [];

  _geoWatchId;
  _geoStarted = false;

  @track alreadyCheckedOut = false;

  @api hideTextractWizard = false;

  get isTextractHidden() {
    return (
      this.hideTextractWizard === true || this.hideTextractWizard === "true"
    );
  }

  get checkOutLabel() {
    return this.isTextractHidden ? "Quick Check-Out" : "Check-Out";
  }

  get hasTarget() {
    return (
      this.target?.lat !== null &&
      this.target?.lat !== undefined &&
      this.target?.lng !== null &&
      this.target?.lng !== undefined
    );
  }

  get hasYouLocation() {
    return (
      this.you?.lat !== null &&
      this.you?.lat !== undefined &&
      this.you?.lng !== null &&
      this.you?.lng !== undefined
    );
  }

  get distanceDisplay() {
    return this.distanceM === null || this.distanceM === undefined
      ? "-"
      : this.distanceM;
  }

  get radiusDisplay() {
    return this.radiusM === null || this.radiusM === undefined
      ? "-"
      : this.radiusM;
  }

  get statusText() {
    if (this.distanceM === null || !this.hasTarget) return "Lokasi belum aktif";
    if (this.alreadyCheckedOut) return "Already Checked Out";
    return this.isInside ? "Inside" : "Outside";
  }

  get statusClass() {
    return this.isInside ? "tag tag--ok" : "tag tag--warn";
  }

  get statusPillClass() {
    return `status-pill ${this.alreadyCheckedOut ? "status-pill--info" : this.isInside ? "status-pill--ok" : "status-pill--warn"}`;

    // if (this.salreadyCheckedOut) return "status-pill--info";
    // return this.isInside
    //   ? "status-pill status-pill--ok"
    //   : "status-pill status-pill--warn";
  }

  get isInside() {
    return (
      this.distanceM !== null &&
      this.radiusM !== null &&
      this.radiusM !== undefined &&
      this.distanceM <= this.radiusM
    );
  }

  get hasOpenEvent() {
    return !!this.openEventId;
  }

  get isDisabledCheckOut() {
    return (
      this.isChecking ||
      !this.hasOpenEvent ||
      !this.hasYouLocation ||
      !this.hasTarget ||
      this.alreadyCheckedOut
    );
  }

  @wire(getContext, { recordId: "$recordId" })
  wiredCtx({ data, error }) {
    if (data) {
      //   console.log("Checkout context:", JSON.stringify(data, null, 2));

      this.parentName = data.parentName;
      this.radiusM = data.radiusM;
      this.openEventId = data.openEventId || this.recordId || null;

      const hasTarget =
        data.targetLat !== null &&
        data.targetLat !== undefined &&
        data.targetLng !== null &&
        data.targetLng !== undefined;

      if (hasTarget) {
        this.target = { lat: data.targetLat, lng: data.targetLng };
        this.error = null;
      } else {
        this.target = { lat: null, lng: null };
        this.error = data.message || "Geofence belum diset.";
      }
      this.alreadyCheckedOut = data.hasCheckedOut;

      this.updateAllLayers();
      this.initGeo();

      if (this.openEventId) this.refreshPhotos();
    } else if (error) {
      this.error = this.parseError(error);
    }
  }

  disconnectedCallback() {
    if (this._geoWatchId !== undefined && this._geoWatchId !== null) {
      navigator.geolocation.clearWatch(this._geoWatchId);
      this._geoWatchId = null;
    }
    this._geoStarted = false;
  }

  async refreshPhotos() {
    if (!this.openEventId) return;
    try {
      const list = await getEventFiles({ eventId: this.openEventId });
      this.photos = list || [];
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e);
    }
  }

  updateAllLayers() {
    this.updateMarkers();
  }

  updateMarkers() {
    const markers = [];

    const hasTarget =
      this.target?.lat !== null &&
      this.target?.lat !== undefined &&
      this.target?.lng !== null &&
      this.target?.lng !== undefined;

    const hasYou =
      this.you?.lat !== null &&
      this.you?.lat !== undefined &&
      this.you?.lng !== null &&
      this.you?.lng !== undefined;

    if (hasTarget) {
      markers.push({
        location: { Latitude: this.target.lat, Longitude: this.target.lng },
        title: "Target",
        description: `Radius: ${this.radiusM ?? "-"} m`,
        mapIcon: ICONS.targetBuilding
      });
    }

    if (hasYou) {
      markers.push({
        location: { Latitude: this.you.lat, Longitude: this.you.lng },
        title: "You",
        description:
          this.distanceM !== null
            ? `Jarak: ${this.distanceM} m • Akurasi: ${this.you.acc ?? "-"} m`
            : "Lokasi terkini",
        mapIcon: ICONS.youPerson
      });
    }

    this.mapMarkers = markers;
  }

  initGeo() {
    if (this._geoStarted) return;
    this._geoStarted = true;

    if (!navigator.geolocation) {
      this.error = "Geolocation tidak tersedia di perangkat ini.";
      return;
    }

    this._geoWatchId = navigator.geolocation.watchPosition(
      (pos) => {
        this.you = {
          lat: pos.coords.latitude,
          lng: pos.coords.longitude,
          acc: pos.coords.accuracy
        };

        if (this.hasTarget) {
          this.distanceM = Math.round(
            this.haversine(
              this.you.lat,
              this.you.lng,
              this.target.lat,
              this.target.lng
            )
          );
        } else {
          this.distanceM = null;
        }

        this.updateAllLayers();
      },
      (err) => {
        this.error = `Gagal membaca lokasi: ${err.message}`;
      },
      { enableHighAccuracy: true, maximumAge: 5000, timeout: 15000 }
    );
  }

  haversine(lat1, lon1, lat2, lon2) {
    const toRad = (x) => (x * Math.PI) / 180;
    const R = 6371000;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    return Math.round(R * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))));
  }

  handleReason(e) {
    this.overrideReason = e.target.value;
  }

  async handleCheckOut() {
    if (!this.hasOpenEvent) {
      this.error = "Event check-in tidak ditemukan.";
      return;
    }

    if (!this.hasYouLocation) {
      this.error = "Lokasi belum siap.";
      return;
    }

    if (!this.hasTarget) {
      this.error = "Target geofence belum tersedia.";
      return;
    }

    this.isChecking = true;
    this.error = null;

    try {
      let eventDetailsPayload = {};

      // Only open Textract when NOT hidden
      if (!this.isTextractHidden) {
        // const result = await TextractWizard.open({
        //   size: "medium",
        //   description: "Capture check-out photo",
        //   label: this.parentName || "Event Check-Out"
        // });
        // user cancel
        // if (!result?.confirmed) {
        //   return;
        // }
        // eslint-disable-next-line no-console
        // console.log("Check-Out wizard data:", result.data);
        // eventDetailsPayload = result.data || {};
      }

      await finishCheckOut({
        eventId: this.openEventId,
        lat: this.you.lat,
        lng: this.you.lng,
        accuracyM: this.you.acc ? Math.round(this.you.acc) : null,
        distanceM: this.distanceM,
        inside: this.isInside,
        eventDetails: JSON.stringify(eventDetailsPayload)
      });

      const id = this.openEventId;
      notifyRecordUpdateAvailable([{ recordId: this.openEventId }]);
      this.openEventId = null;

      await this.showToastSuccessWithLink(
        id,
        "Check-Out berhasil",
        "Open Event"
      );
    } catch (e) {
      this.error = this.parseError(e);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Check-Out gagal",
          message: this.error,
          variant: "error",
          mode: "dismissable"
        })
      );
    } finally {
      this.isChecking = false;
    }
  }

  openDirections() {
    if (!this.hasYouLocation || !this.hasTarget) return;

    const sLat = this.you.lat;
    const sLng = this.you.lng;
    const dLat = this.target.lat;
    const dLng = this.target.lng;

    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    const appleUrl = `maps://?saddr=${sLat},${sLng}&daddr=${dLat},${dLng}`;
    const googleUrl = `https://www.google.com/maps/dir/?api=1&origin=${sLat},${sLng}&destination=${dLat},${dLng}&travelmode=driving`;

    window.open(isIOS ? appleUrl : googleUrl, "_blank");
  }

  async showToastSuccessWithLink(recordId, title, linkLabel = "Open Record") {
    const url = await this[NavigationMixin.GenerateUrl]({
      type: "standard__recordPage",
      attributes: { recordId, objectApiName: "Event", actionName: "view" }
    });

    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message: "{0}",
        messageData: [{ url, label: linkLabel }],
        variant: "success",
        mode: "dismissable"
      })
    );
  }

  parseError(e) {
    try {
      return (
        e?.body?.message ||
        e?.body?.pageErrors?.[0]?.message ||
        e?.message ||
        "Unknown error"
      );
    } catch {
      return "Unknown error";
    }
  }
}