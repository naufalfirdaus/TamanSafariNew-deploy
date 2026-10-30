import { LightningElement, api, wire, track } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getContext from "@salesforce/apex/CheckInService.getContext";
import startCheckIn from "@salesforce/apex/CheckInService.startCheckIn";
import finishCheckOut from "@salesforce/apex/CheckInService.finishCheckOut";
import initTargetFromCurrentLocation from "@salesforce/apex/CheckInService.initTargetFromCurrentLocation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import uploadEventPhoto from "@salesforce/apex/CheckInService.uploadEventPhoto";
import getEventFiles from "@salesforce/apex/CheckInService.getEventFiles";

import PhotoCaptureModal from "c/photoCaptureModal";
import SignaturePadModal from "c/signaturePadModal";

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

export default class GeoCheckinPanel extends NavigationMixin(LightningElement) {
  @api recordId;
  @api objectApiName;

  // App Builder configs
  @api disablePhotoCapture = false;
  @api hideCheckinHistory = false;
  @api historyRowLimit = 6;
  @api geofenceRadius = 300;

  @track parentName;
  @track radiusM = 0;
  @track target = { lat: null, lng: null };
  @track you = { lat: null, lng: null, acc: null };
  @track distanceM = null;

  openEventId = null;
  isChecking = false;
  error;
  overrideReason = "";
  overrideRequested = false;
  showRoute = false;

  mapMarkers = [];
  photos = [];

  // wire / geo internals
  _ctxWire;
  _geoWatchId;
  _geoStarted = false;

  // target init flow
  targetMissingOnRecord = false;
  isTargetInitInProgress = false;
  hasTriedInitTarget = false;

  @api showRemarkerTargetButton = false;

  @api disableSignatureCapture = false;

  get isRemarkerButtonEnabled() {
    return (
      this.showRemarkerTargetButton === true ||
      this.showRemarkerTargetButton === "true"
    );
  }

  get isSignatureCaptureDisabled() {
    return (
      this.disableSignatureCapture === true ||
      this.disableSignatureCapture === "true"
    );
  }

  get canRemarkerTarget() {
    // guardrail: harus ada lokasi user, jangan pas lagi processing, dan idealnya jangan ubah target saat ada open event
    return (
      this.isRemarkerButtonEnabled &&
      this.hasYouLocation &&
      !this.isChecking &&
      !this.isTargetInitInProgress &&
      !this.hasOpenEvent
    );
  }

  get isRemarkerDisabled() {
    return !this.canRemarkerTarget;
  }

  get isPhotoCaptureDisabled() {
    return (
      this.disablePhotoCapture === true || this.disablePhotoCapture === "true"
    );
  }

  get isCheckinHistoryHidden() {
    return (
      this.hideCheckinHistory === true || this.hideCheckinHistory === "true"
    );
  }

  get showCheckinHistory() {
    return !this.isCheckinHistoryHidden;
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
    return this.isInside ? "Inside" : "Outside";
  }

  get statusClass() {
    return this.isInside ? "tag tag--ok" : "tag tag--warn";
  }

  get statusPillClass() {
    return this.isInside
      ? "status-pill status-pill--ok"
      : "status-pill status-pill--warn";
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

  // Field alasan override sengaja disembunyikan sampai user benar-benar menekan
  // Check-In dan tertahan karena di luar geofence -- bukan muncul proaktif.
  get showOverride() {
    return this.overrideRequested && !this.isInside && !this.hasOpenEvent;
  }

  get checkInLabel() {
    return this.hasOpenEvent ? "Already Checked-In" : "Check-In";
  }

  get isDisabled() {
    return (
      this.isChecking ||
      this.hasOpenEvent ||
      !this.hasYouLocation ||
      !this.hasTarget ||
      this.isTargetInitInProgress
    );
  }

  get isDisabledCheckOut() {
    return this.isChecking || !this.hasOpenEvent || !this.hasYouLocation;
  }

  @wire(getContext, { recordId: "$recordId", objectApiName: "$objectApiName" })
  wiredCtx(result) {
    this._ctxWire = result;
    const { data, error } = result;

    if (data) {
      this.parentName = data.parentName;
      this.radiusM = data.radiusM || this.geofenceRadius;
      this.openEventId = data.openEventId || null;

      const hasServerTarget =
        data.targetLat !== null &&
        data.targetLat !== undefined &&
        data.targetLng !== null &&
        data.targetLng !== undefined;

      this.targetMissingOnRecord = !hasServerTarget;

      if (hasServerTarget) {
        this.target = { lat: data.targetLat, lng: data.targetLng };
        this.error = null;
      } else {
        this.target = { lat: null, lng: null };
        this.error =
          data.message ||
          "Target geofence belum diset. Mengambil lokasi saat ini untuk marker target...";
      }

      this.updateAllLayers();
      this.initGeo();

      if (this.openEventId) this.refreshPhotos();
    } else if (error) {
      this.error = this.parseError(error);
      this.initGeo();
    }
  }

  disconnectedCallback() {
    if (this._geoWatchId !== undefined && this._geoWatchId !== null) {
      navigator.geolocation.clearWatch(this._geoWatchId);
      this._geoWatchId = null;
    }
    this._geoStarted = false;
  }

  handleOpenEvent() {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.openEventId,
        objectApiName: "Event",
        actionName: "view"
      }
    });
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

  refreshHistoryPanel() {
    const cmp = this.template.querySelector("c-geo-checkin-history");
    if (cmp && typeof cmp.refresh === "function") {
      cmp.refresh();
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

        // If target missing, auto-pin to current user location first
        if (!this.hasTarget) {
          this.target = { lat: this.you.lat, lng: this.you.lng };
          this.distanceM = 0;
          this.updateAllLayers();
          this.tryInitTargetFromCurrentLocation();
          return;
        }

        this.distanceM = Math.round(
          this.haversine(
            this.you.lat,
            this.you.lng,
            this.target.lat,
            this.target.lng
          )
        );
        this.updateAllLayers();
      },
      (err) => {
        this.error = `Gagal membaca lokasi: ${err.message}`;
      },
      { enableHighAccuracy: true, maximumAge: 5000, timeout: 15000 }
    );
  }

  async tryInitTargetFromCurrentLocation() {
    if (
      !this.targetMissingOnRecord ||
      this.hasTriedInitTarget ||
      this.isTargetInitInProgress ||
      !this.hasYouLocation
    ) {
      return;
    }

    if (this.radiusM === null || this.radiusM === undefined) {
      this.error =
        "Lat/Lng target berhasil ditandai sementara, tapi radius geofence masih kosong di record.";
      return;
    }

    this.hasTriedInitTarget = true;
    this.isTargetInitInProgress = true;

    try {
      await initTargetFromCurrentLocation({
        recordId: this.recordId,
        objectApiName: this.objectApiName,
        lat: this.you.lat,
        lng: this.you.lng
      });

      this.targetMissingOnRecord = false;
      this.error = null;

      if (this._ctxWire) {
        await refreshApex(this._ctxWire);
      }

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Target geofence diset",
          message: "Target otomatis diset dari lokasi Anda saat ini.",
          variant: "success"
        })
      );
    } catch (e) {
      this.hasTriedInitTarget = false;
      this.error = this.parseError(e);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Gagal set target geofence",
          message: this.error,
          variant: "error",
          mode: "dismissable"
        })
      );
    } finally {
      this.isTargetInitInProgress = false;
    }
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

  async handleCheckIn() {
    if (this.hasOpenEvent) return;
    if (!this.hasYouLocation) {
      this.error = "Lokasi belum siap.";
      return;
    }
    if (!this.hasTarget) {
      this.error =
        "Target geofence belum siap. Tunggu marker target dibuat dulu.";
      return;
    }
    if (this.isTargetInitInProgress) {
      this.error =
        "Sedang menyimpan target geofence dari lokasi saat ini. Coba lagi sebentar.";
      return;
    }

    // --- STEP 0: Validasi geofence lebih dulu ---
    // Sebelumnya pengecekan ini hanya ada di Apex, yaitu SETELAH modal foto dan
    // tanda tangan. Akibatnya user menyelesaikan keduanya, baru diberi tahu bahwa
    // posisinya di luar radius. Sekarang jarak divalidasi tepat setelah tombol
    // ditekan, jadi foto/ttd hanya diminta bila check-in memang bisa diteruskan.
    if (!this.isInside && !this.overrideReason?.trim()) {
      this.overrideRequested = true;
      this.error =
        "Di luar geofence \u2014 jarak " +
        this.distanceDisplay +
        "m dari target (radius " +
        this.radiusDisplay +
        "m). Isi alasan override untuk melanjutkan.";
      return;
    }
    this.error = null;

    let photoResult = null;
    let signatureResult = null;

    // --- STEP 1: Process Photo Capture ---
    if (!this.isPhotoCaptureDisabled) {
      photoResult = await PhotoCaptureModal.open({
        size: "medium",
        description: "Capture check-in photo",
        label: "Capture Photo"
      });

      // Modal ditutup/cancel oleh user
      if (!photoResult?.confirmed) return;
    }

    // --- STEP 2: Process Signature Capture ---
    if (!this.isSignatureCaptureDisabled) {
      signatureResult = await SignaturePadModal.open({
        size: "medium", // Signature pad works best with medium size
        description: "Please sign below to confirm your geolocation visit.",
        label: "Digital Signature"
      });

      // Modal ditutup/cancel oleh user
      if (!signatureResult?.confirmed) return;
    }

    // --- STEP 3: Proses Apex DML Start Check-In ---
    this.isChecking = true;
    this.error = null;

    try {
      const eventId = await startCheckIn({
        recordId: this.recordId,
        objectApiName: this.objectApiName,
        lat: this.you.lat,
        lng: this.you.lng,
        accuracyM: this.you.acc ? Math.round(this.you.acc) : null,
        distanceM: this.distanceM,
        inside: this.isInside,
        overrideReason: this.overrideReason
      });

      this.openEventId = eventId;

      // --- STEP 4: Async File Uploads (Photo & Signature) ---
      let uploadPromises = [];

      // Push Photo Upload Promise
      if (photoResult?.dataUrl) {
        uploadPromises.push(
          uploadEventPhoto({
            eventId,
            dataUrl: photoResult.dataUrl,
            fileName: photoResult.fileName || "CheckIn_Photo.png"
          })
        );
      }

      // Push Signature Upload Promise
      if (signatureResult?.dataUrl) {
        uploadPromises.push(
          uploadEventPhoto({
            eventId,
            dataUrl: signatureResult.dataUrl,
            fileName: signatureResult.fileName || "CheckIn_Signature.png"
          })
        );
      }

      // Tembak upload secara paralel jika lebih dari 1 file untuk mempercepat performa
      if (uploadPromises.length > 0) {
        await Promise.all(uploadPromises);
      }

      // --- STEP 5: Success Handling ---
      await this.showToastSuccessWithLink(
        eventId,
        "Check-In berhasil",
        "Open Event"
      );

      await this.refreshPhotos(); // Refresh gallery di tab kiri
      this.refreshHistoryPanel(); // Refresh history tab kanan
    } catch (e) {
      this.error = this.parseError(e);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Check-In gagal",
          message: this.error,
          variant: "error",
          mode: "dismissable"
        })
      );
    } finally {
      this.isChecking = false;
    }
  }

  async handleCheckOut() {
    if (!this.hasOpenEvent) return;

    if (!this.hasYouLocation) {
      this.error = "Lokasi belum siap.";
      return;
    }

    this.isChecking = true;
    this.error = null;

    try {
      // NOTE: Apex finishCheckOut currently expects eventDetails parameter.
      // If your Apex method still requires it, pass a JSON string here.
      await finishCheckOut({
        eventId: this.openEventId,
        lat: this.you.lat,
        lng: this.you.lng,
        accuracyM: this.you.acc ? Math.round(this.you.acc) : null,
        distanceM: this.distanceM,
        inside: this.isInside,
        eventDetails: JSON.stringify({})
      });

      const id = this.openEventId;
      this.openEventId = null;

      await this.showToastSuccessWithLink(
        id,
        "Check-Out berhasil",
        "Open Event"
      );
      this.refreshHistoryPanel();
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

  openPhoto(e) {
    const docId = e.currentTarget?.dataset?.docid;
    const p = this.photos.find((x) => x.contentDocumentId === docId);
    if (!p) return;

    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: p.contentDocumentId,
        objectApiName: "ContentDocument",
        actionName: "view"
      }
    });
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

  openDirections() {
    const hasYou =
      this.you?.lat !== null &&
      this.you?.lat !== undefined &&
      this.you?.lng !== null &&
      this.you?.lng !== undefined;

    const hasTarget =
      this.target?.lat !== null &&
      this.target?.lat !== undefined &&
      this.target?.lng !== null &&
      this.target?.lng !== undefined;

    if (!hasYou || !hasTarget) return;

    const sLat = this.you.lat;
    const sLng = this.you.lng;
    const dLat = this.target.lat;
    const dLng = this.target.lng;

    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    const appleUrl = `maps://?saddr=${sLat},${sLng}&daddr=${dLat},${dLng}`;
    const googleUrl = `https://www.google.com/maps/dir/?api=1&origin=${sLat},${sLng}&destination=${dLat},${dLng}&travelmode=driving`;

    window.open(isIOS ? appleUrl : googleUrl, "_blank");
  }

  async handleRemarkerTarget() {
    if (!this.canRemarkerTarget) return;

    this.isTargetInitInProgress = true;
    this.error = null;

    try {
      await initTargetFromCurrentLocation({
        recordId: this.recordId,
        objectApiName: this.objectApiName,
        lat: this.you.lat,
        lng: this.you.lng
      });

      // update UI cepat
      this.target = { lat: this.you.lat, lng: this.you.lng };
      this.distanceM = 0;
      this.updateAllLayers();

      // refresh context (ambil state server terbaru)
      if (this._ctxWire) {
        await refreshApex(this._ctxWire);
      }

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Target updated",
          message: "Target geofence dipindahkan ke lokasi Anda saat ini.",
          variant: "success"
        })
      );
    } catch (e) {
      this.error = this.parseError(e);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Failed to update target",
          message: this.error,
          variant: "error"
        })
      );
    } finally {
      this.isTargetInitInProgress = false;
    }
  }
}