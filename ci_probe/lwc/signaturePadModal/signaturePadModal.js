import LightningModal from "lightning/modal";
import { api } from "lwc";

export default class SignaturePadModal extends LightningModal {
  @api label = "Capture Signature";
  @api description = "Please sign below to confirm your check-in.";

  isDrawing = false;
  canvas;
  ctx;
  hasDrawn = false; // Flag to check if canvas is blank

  renderedCallback() {
    if (!this.canvas) {
      this.canvas = this.template.querySelector(".signature-pad");
      this.ctx = this.canvas.getContext("2d");
      this.resizeCanvas();

      // Setting up stroke style
      this.ctx.lineWidth = 2.5;
      this.ctx.lineCap = "round";
      this.ctx.strokeStyle = "#0f172a"; // Dark blue/black color
    }
  }

  // Ensures canvas scaling is 1:1 with CSS rendering to avoid stretched lines
  resizeCanvas() {
    const container = this.template.querySelector(".pad-container");
    this.canvas.width = container.offsetWidth;
    this.canvas.height = 250; // Fixed touch area height
  }

  getCoordinates(event) {
    let clientX, clientY;
    if (event.type.includes("touch")) {
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
    if (event.type.includes("touch")) event.preventDefault(); // Stop screen scroll
    this.isDrawing = true;
    this.hasDrawn = true;
    const coords = this.getCoordinates(event);

    this.ctx.beginPath();
    this.ctx.moveTo(coords.x, coords.y);
  }

  handleDrawing(event) {
    if (!this.isDrawing) return;
    if (event.type.includes("touch")) event.preventDefault(); // Stop screen scroll

    const coords = this.getCoordinates(event);
    this.ctx.lineTo(coords.x, coords.y);
    this.ctx.stroke();
  }

  handleDrawEnd() {
    this.isDrawing = false;
    this.ctx.closePath();
  }

  handleClear() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    this.hasDrawn = false;
  }

  handleCancel() {
    this.close({ confirmed: false });
  }

  handleSave() {
    if (!this.hasDrawn) {
      // Can be expanded to show a toast, but simply bouncing back is fine
      alert("Please provide a signature before saving.");
      return;
    }

    // Get Base64 image
    const dataUrl = this.canvas.toDataURL("image/png");

    // Return object structure matches photoCaptureModal
    this.close({
      confirmed: true,
      dataUrl: dataUrl,
      fileName: "Signature_CheckIn.png"
    });
  }
}