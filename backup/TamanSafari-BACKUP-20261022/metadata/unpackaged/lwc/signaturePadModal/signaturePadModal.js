import LightningModal from "lightning/modal";
import { api, track } from "lwc";
import labelSignerName from "@salesforce/label/c.FV_Signer_Name_Label";
import labelEmptyError from "@salesforce/label/c.FV_Signature_Empty_Error";
import labelSignerRequired from "@salesforce/label/c.Visit_Err_Signer_Name_Required";
import labelCancel from "@salesforce/label/c.FV_Btn_Cancel";
import labelSave from "@salesforce/label/c.FV_Btn_Save";

export default class SignaturePadModal extends LightningModal {
  @api label = "Tanda Tangan Klien";
  @api description = "Bubuhkan tanda tangan pada area di bawah ini untuk konfirmasi kunjungan.";
  _signerName = "";
  @api
  get signerName() {
    return this._signerName;
  }
  set signerName(val) {
    this._signerName = val || "";
  }
  @api targetName = "";
  @api coords;

  @track errorMessage = "";

  labels = {
    signerName: labelSignerName,
    emptyError: labelEmptyError,
    signerRequired: labelSignerRequired,
    cancel: labelCancel,
    save: labelSave,
    clear: "Hapus"
  };

  get modalTitle() {
    return this.label || this.labels.signerName;
  }

  isDrawing = false;
  canvas;
  ctx;
  hasDrawn = false; // Flag to check if canvas is blank

  renderedCallback() {
    if (!this.canvas) {
      this.canvas = this.template.querySelector(".signature-pad");
      if (this.canvas) {
        this.ctx = this.canvas.getContext("2d");
        this.resizeCanvas();

        if (this.ctx) {
          this.ctx.lineWidth = 2.5;
          this.ctx.lineCap = "round";
          this.ctx.strokeStyle = "#11532F";
        }
      }
    }
  }

  resizeCanvas() {
    const container = this.template.querySelector(".pad-container");
    if (container && this.canvas) {
      this.canvas.width = container.offsetWidth || 350;
      this.canvas.height = 250;
    }
  }

  handleSignerNameChange(event) {
    this._signerName = event.target.value;
    if (this.errorMessage) {
      this.errorMessage = "";
    }
  }

  getCoordinates(event) {
    let clientX;
    let clientY;
    if (event.type && event.type.includes("touch") && event.touches && event.touches.length > 0) {
      clientX = event.touches[0].clientX;
      clientY = event.touches[0].clientY;
    } else {
      clientX = event.clientX;
      clientY = event.clientY;
    }

    const rect = this.canvas.getBoundingClientRect();
    return {
      x: clientX - rect.left,
      y: clientY - rect.top
    };
  }

  handleDrawStart(event) {
    if (event.type && event.type.includes("touch")) {
      event.preventDefault();
    }
    this.isDrawing = true;
    this.hasDrawn = true;
    if (this.errorMessage) {
      this.errorMessage = "";
    }
    const coords = this.getCoordinates(event);

    if (this.ctx) {
      this.ctx.beginPath();
      this.ctx.moveTo(coords.x, coords.y);
    }
  }

  handleDrawing(event) {
    if (!this.isDrawing) return;
    if (event.type && event.type.includes("touch")) {
      event.preventDefault();
    }

    const coords = this.getCoordinates(event);
    if (this.ctx) {
      this.ctx.lineTo(coords.x, coords.y);
      this.ctx.stroke();
    }
  }

  handleDrawEnd() {
    this.isDrawing = false;
    if (this.ctx) {
      this.ctx.closePath();
    }
  }

  handleClear() {
    if (this.ctx && this.canvas) {
      this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    }
    this.hasDrawn = false;
    this.errorMessage = "";
  }

  handleCancel() {
    this.close({ confirmed: false });
  }

  handleSave() {
    const trimmedSigner = (this.signerName || "").trim();
    if (!trimmedSigner) {
      this.errorMessage = this.labels.signerRequired;
      const input = this.template.querySelector(".signer-name-input");
      if (input) {
        input.focus();
      }
      return;
    }

    if (!this.hasDrawn) {
      this.errorMessage = this.labels.emptyError;
      return;
    }

    // Draw subtle watermark line before export: signerName | targetName | ISO timestamp | coords
    this.drawWatermark();

    // Get Base64 PNG image
    const dataUrl = this.canvas.toDataURL("image/png");

    this.close({
      confirmed: true,
      dataUrl: dataUrl,
      signerName: trimmedSigner,
      fileName: `Signature_${Date.now()}.png`
    });
  }

  drawWatermark() {
    if (!this.ctx || !this.canvas) return;

    let coordStr = "Lokasi tidak tersedia";
    if (this.coords?.lat != null && this.coords?.lng != null) {
      coordStr = `${Number(this.coords.lat).toFixed(6)}, ${Number(this.coords.lng).toFixed(6)}`;
      if (this.coords.acc != null) {
        coordStr += ` (±${Math.round(this.coords.acc)}m)`;
      }
    }

    const isoStr = new Date().toISOString();
    const watermarkText = `${this.signerName.trim()} | ${this.targetName || ""} | ${isoStr} | ${coordStr}`.replace(/\s+\|\s+$/, "");

    this.ctx.save();
    this.ctx.font = "10px -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";
    this.ctx.fillStyle = "rgba(17, 83, 47, 0.6)";
    this.ctx.textBaseline = "bottom";
    this.ctx.fillText(watermarkText, 8, this.canvas.height - 6);
    this.ctx.restore();
  }
}