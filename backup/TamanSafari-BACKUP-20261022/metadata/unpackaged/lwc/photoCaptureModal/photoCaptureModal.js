import { api, track } from "lwc";
import LightningModal from "lightning/modal";
import labelPhotoTitle from "@salesforce/label/c.FV_Photo_Section_Title";
import labelCancel from "@salesforce/label/c.FV_Btn_Cancel";
import labelTakePhoto from "@salesforce/label/c.FV_Btn_Take_Photo";
import labelRetakePhoto from "@salesforce/label/c.FV_Btn_Retake_Photo";
import labelSave from "@salesforce/label/c.FV_Btn_Save";
import labelCameraError from "@salesforce/label/c.FV_Camera_Error";

export default class PhotoCaptureModal extends LightningModal {
  @api size; // small/medium/large
  @api coords; // { lat, lng, acc, address }
  @api targetName = "";
  @api watermarkTitle = "Taman Safari Indonesia - Verifikasi Lapangan";
  @api fileNamePrefix = "visit_photo";
  @track error;

  labels = {
    title: labelPhotoTitle,
    cancel: labelCancel,
    snap: labelTakePhoto,
    retake: labelRetakePhoto,
    save: labelSave,
    cameraError: labelCameraError,
    previewHint: "Pratinjau foto bukti kunjungan. Gambar penuh disimpan ke Berkas Salesforce.",
    retryCamera: "Coba Lagi"
  };

  stream;
  videoEl;
  canvasEl;

  hasSnapshot = false;
  snapshotUrl = null;

  get isSnapDisabled() {
    return !!this.error;
  }

  renderedCallback() {
    if (!this.videoEl) {
      this.videoEl = this.template.querySelector("video.cam__video");
      this.canvasEl = this.template.querySelector("canvas");
      if (this.videoEl) {
        this.initCamera();
      }
    }
  }

  async initCamera() {
    this.error = null;
    try {
      if (!navigator.mediaDevices?.getUserMedia) {
        this.error = this.labels.cameraError;
        return;
      }
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: "environment" } },
        audio: false
      });
      if (this.videoEl) {
        this.videoEl.srcObject = this.stream;
      }
    } catch (e) {
      this.error = `${this.labels.cameraError} (${e?.message || e})`;
    }
  }

  handleRetryCamera() {
    this.initCamera();
  }

  handleSnap() {
    if (!this.videoEl || !this.canvasEl) return;
    let w = this.videoEl.videoWidth || 1280;
    let h = this.videoEl.videoHeight || 720;
    const MAX_WIDTH = 1280;

    if (w > MAX_WIDTH) {
      const scale = MAX_WIDTH / w;
      w = MAX_WIDTH;
      h = Math.round(h * scale);
    }

    this.canvasEl.width = w;
    this.canvasEl.height = h;

    const ctx = this.canvasEl.getContext("2d");
    if (ctx) {
      ctx.drawImage(this.videoEl, 0, 0, w, h);
      this.drawOverlay(ctx, w, h);
      this.snapshotUrl = this.canvasEl.toDataURL("image/jpeg", 0.7);
    }

    this.hasSnapshot = true;
    this.stopStream();
  }

  drawOverlay(ctx, w, h) {
    const isoStr = new Date().toISOString();

    const addrStr =
      this.coords?.address && this.coords.address.trim().length > 0
        ? this.coords.address
        : "Alamat tidak tersedia";

    let coordStr = "Lokasi tidak tersedia";
    if (this.coords?.lat != null && this.coords?.lng != null) {
      const lat = Number(this.coords.lat).toFixed(6);
      const lng = Number(this.coords.lng).toFixed(6);
      coordStr = `${lat}, ${lng}`;
      if (this.coords.acc != null) {
        coordStr += ` (±${Math.round(this.coords.acc)}m)`;
      }
    }

    const fontSize = Math.max(14, Math.round(w * 0.022));
    const lineHeight = Math.round(fontSize * 1.35);
    const pad = Math.round(fontSize * 0.6);
    const maxTextWidth = w - pad * 2;

    const lines = [
      this.watermarkTitle,
      this.targetName ? `Target: ${this.targetName}` : "",
      `Waktu: ${isoStr}`,
      `Koordinat: ${coordStr}`,
      `Alamat: ${addrStr}`
    ].filter(Boolean);

    ctx.font = `${fontSize}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;
    const wrappedLines = [];
    for (const line of lines) {
      wrappedLines.push(...this.wrapLine(ctx, line, maxTextWidth));
    }

    const bandHeight = lineHeight * wrappedLines.length + pad * 2;

    // Taman Safari Deep Forest Green watermark overlay
    ctx.fillStyle = "rgba(17, 83, 47, 0.85)";
    ctx.fillRect(0, h - bandHeight, w, bandHeight);

    ctx.fillStyle = "#FFFFFF";
    ctx.textBaseline = "middle";
    wrappedLines.forEach((line, i) => {
      ctx.fillText(line, pad, h - bandHeight + pad + lineHeight * (i + 0.5));
    });
  }

  wrapLine(ctx, text, maxWidth) {
    const words = String(text).split(" ");
    const out = [];
    let current = "";
    for (const word of words) {
      const candidate = current ? `${current} ${word}` : word;
      if (ctx.measureText(candidate).width > maxWidth && current) {
        out.push(current);
        current = word;
      } else {
        current = candidate;
      }
    }
    if (current) out.push(current);
    return out.length > 0 ? out : [""];
  }

  handleRetake() {
    this.hasSnapshot = false;
    this.snapshotUrl = null;
    this.initCamera();
  }

  handleCancel() {
    this.stopStream();
    this.close({ confirmed: false });
  }

  handleConfirm() {
    if (!this.snapshotUrl) {
      this.error = this.labels.cameraError;
      return;
    }
    const payload = {
      confirmed: true,
      dataUrl: this.snapshotUrl,
      fileName: `${this.fileNamePrefix}_${Date.now()}.jpg`
    };
    this.cleanup();
    this.close(payload);
  }

  stopStream() {
    try {
      this.stream?.getTracks().forEach((t) => t.stop());
    } catch {
      // ignore
    }
  }

  cleanup() {
    this.stopStream();
    this.videoEl = null;
    this.canvasEl = null;
  }
}