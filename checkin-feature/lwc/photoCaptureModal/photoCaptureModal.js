import { api, track } from "lwc";
import LightningModal from "lightning/modal";

export default class PhotoCaptureModal extends LightningModal {
  @api size; // small/medium/large
  @track error;

  stream;
  videoEl;
  canvasEl;

  hasSnapshot = false;
  snapshotUrl = null;
  mimeType = "image/jpeg";

  renderedCallback() {
    if (!this.videoEl) {
      this.videoEl = this.template.querySelector("video.cam__video");
      this.canvasEl = this.template.querySelector("canvas");
      if (this.videoEl) this.initCamera();
    }
  }

  async initCamera() {
    this.error = null;
    try {
      if (!navigator.mediaDevices?.getUserMedia) {
        this.error = "Camera API tidak tersedia. Gunakan upload file.";
        return;
      }
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: "environment" } },
        audio: false
      });
      this.videoEl.srcObject = this.stream;
    } catch (e) {
      this.error = "Tidak bisa akses kamera: " + (e?.message || e);
    }
  }

  handleSnap() {
    if (!this.videoEl) return;
    const w = this.videoEl.videoWidth || 1280;
    const h = this.videoEl.videoHeight || 720;
    this.canvasEl.width = w;
    this.canvasEl.height = h;

    const ctx = this.canvasEl.getContext("2d");
    ctx.drawImage(this.videoEl, 0, 0, w, h);

    this.snapshotUrl = this.canvasEl.toDataURL(this.mimeType, 0.9);
    this.hasSnapshot = true;
    this.stopStream();
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
      this.error = "Belum ada foto.";
      return;
    }
    const payload = {
      confirmed: true,
      dataUrl: this.snapshotUrl,
      fileName: "checkin_" + Date.now() + ".jpg"
    };
    this.cleanup();
    this.close(payload);
  }

  handleFilePick(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      this.snapshotUrl = reader.result; // dataURL
      this.hasSnapshot = true;
      this.stopStream();
    };
    reader.readAsDataURL(file);
  }

  stopStream() {
    try {
      this.stream?.getTracks().forEach((t) => t.stop());
    } catch (e) {
      console.log(e);
    }
  }

  cleanup() {
    this.stopStream();
    this.videoEl = null;
    this.canvasEl = null;
  }
}