/* eslint-disable consistent-return */
import { track, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import analyzeFormsFromDataUrl from "@salesforce/apex/TextractDirectService.analyzeFormsFromDataUrl";
import LightningModal from "lightning/modal";
// import upsertForm from '@salesforce/apex/SaveService.upsertForm';

const MAX_W = 1600,
  MAX_H = 1600;

export default class TextractWizard extends LightningModal {
  @api recordId;

  @api label;
  // enables
  get disableCapture() {
    return !this.busy && !this.streaming;
  }
  get disableRetake() {
    return !this.busy && !this.hasPhoto;
  }

  // 2-step state
  @track step = 1;
  get isStep1() {
    return this.step === 1;
  }
  get isStep2() {
    return this.step === 2;
  }
  get step1Class() {
    return this.step >= 1
      ? this.step === 1
        ? "step-active"
        : "step-done"
      : "";
  }
  get step2Class() {
    return this.step >= 2
      ? this.step === 2
        ? "step-active"
        : "step-done"
      : "";
  }

  // media
  videoEl;
  canvasEl;
  ctx;
  stream;
  streaming = false;

  // data
  dataUrl = null;
  busy = false;
  lastAction = "";
  @track rawText = "";
  @track kvRows = [];

  // form draft
  @track formDraft = {
    meetingNotes: "",
    wasCallRequested: false,
    matterDiscussed: "",
    followUpDetail: ""
  };

  closeModal() {
    this.close({ confirmed: false });
  }
  renderedCallback() {
    if (!this.videoEl) {
      this.videoEl = this.template.querySelector("video.preview-el");
      this.canvasEl = this.template.querySelector("canvas.preview-el");
      this.ctx = this.canvasEl?.getContext("2d");
    }
  }

  // step nav
  goStep1 = () => {
    this.step = 1;
  };

  // Next now = run analyze + go step 2 with spinner
  goStep2 = async () => {
    if (!this.hasPhoto) {
      return this.toast("Info", "Ambil foto dulu", "info");
    }
    this.busy = true;
    try {
      // Optional: draw once to fix orientation/scale for record keeping (not shown in UI)
      this.drawToCanvas(this.ctx);

      // Run FORMS (includes raw text summary from Apex if you return it)
      const res = await analyzeFormsFromDataUrl({ dataUrl: this.dataUrl });
      this.rawText = (res?.rawText || "").trim();

      console.log("Textract FORMS result:", JSON.stringify(res, null, 2));

      const kv = res?.keyValues || [];
      this.kvRows = kv.map((k, i) => ({
        id: String(i),
        key: k.key || "",
        value: k.value || "",
        confidence: k.confidence != null ? Number(k.confidence).toFixed(1) : ""
      }));

      this.lastAction = "AnalyzeDocument(FORMS)";
      this.autoMapToForm();
      this.step = 2;
    } catch (e) {
      this.toast("Textract Error", e?.body?.message || e.message, "error");
    } finally {
      this.busy = false;
    }
  };

  // Next is allowed as long as photo exists (analysis will run during transition)
  get disableNextFrom1() {
    return !this.hasPhoto || this.busy;
  }

  // camera / capture
  async startCamera() {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: "environment" } },
        audio: false
      });
      this.videoEl.srcObject = this.stream;
      this.streaming = true;
      this.resetOutputs();
      this.videoEl.classList.remove("slds-hide");
      this.canvasEl.classList.add("slds-hide");
    } catch (e) {
      this.toast(
        "Camera Error",
        e.message || "Unable to access camera",
        "error"
      );
    }
  }

  capture() {
    if (!this.streaming) return;
    this.dataUrl = this.snapshotFromVideo(this.ctx);
    this.canvasEl.classList.remove("slds-hide");
    this.videoEl.classList.add("slds-hide");
  }

  retake() {
    this.dataUrl = null;
    this.resetOutputs();
    this.canvasEl.classList.add("slds-hide");
    if (this.streaming) this.videoEl.classList.remove("slds-hide");
  }

  onPick(e) {
    const f = e.target.files && e.target.files[0];
    if (!f) return;
    const fr = new FileReader();
    fr.onload = () => {
      this.dataUrl = fr.result;
      this.resetOutputs();
      this.drawToCanvas(this.ctx);
      this.canvasEl.classList.remove("slds-hide");
      this.videoEl.classList.add("slds-hide");
    };
    fr.readAsDataURL(f);
  }

  get hasPhoto() {
    return !!this.dataUrl;
  }
  get showPlaceholder() {
    return !this.dataUrl && !this.streaming;
  }

  snapshotFromVideo(ctx) {
    const w = this.videoEl.videoWidth || 1280;
    const h = this.videoEl.videoHeight || 720;
    const scale = Math.min(MAX_W / w, MAX_H / h, 1);
    const tw = Math.max(1, Math.floor(w * scale));
    const th = Math.max(1, Math.floor(h * scale));
    ctx.canvas.width = tw;
    ctx.canvas.height = th;
    ctx.drawImage(this.videoEl, 0, 0, tw, th);
    return ctx.canvas.toDataURL("image/jpeg", 0.9);
  }

  drawToCanvas(ctx) {
    if (!this.dataUrl) return;
    const img = new Image();
    img.onload = () => {
      const scale = Math.min(MAX_W / img.width, MAX_H / img.height, 1);
      const tw = Math.max(1, Math.floor(img.width * scale));
      const th = Math.max(1, Math.floor(img.height * scale));
      ctx.canvas.width = tw;
      ctx.canvas.height = th;
      ctx.drawImage(img, 0, 0, tw, th);
    };
    img.src = this.dataUrl;
  }

  resetOutputs() {
    this.rawText = "";
    this.kvRows = [];
    this.lastAction = "";
    this.formDraft = {
      meetingNotes: "",
      wasCallRequested: false,
      matterDiscussed: "",
      followUpDetail: ""
    };
  }

  // auto mapping
  autoMapToForm() {
    const kv = new Map(this.kvRows.map((k) => [k.key.toLowerCase(), k.value]));
    console.log("KV Map:", JSON.stringify([...kv.entries()], null, 2));
    const getByContains = (cands) => {
      for (const c of cands) {
        for (const [k, v] of kv.entries()) if (k.includes(c)) return v;
      }
      return "";
    };
    const yesNo = (v) => {
      const t = (v || "").toString().toLowerCase();
      if (
        [
          "yes",
          "ya",
          "y",
          "true",
          "requested",
          "requested yes",
          "requested: yes",
          "1"
        ].some((s) => t.includes(s))
      )
        return true;
      if (["no", "tidak", "n", "false", "0"].some((s) => t.includes(s)))
        return false;
      return false;
    };

    const notes = getByContains([
      "general note about meeting",
      "catatan",
      "notes"
    ]);
    const matter = getByContains(["matter discussed", "topik", "pembahasan"]);
    const follow = getByContains(["follow up", "action", "tindak lanjut"]);
    const requestedRaw = getByContains([
      "requested",
      "call requested",
      "request call"
    ]);

    const fallbackAfter = (label) => {
      const re = new RegExp(`^\\s*${label}\\s*:\\s*(.+)$`, "i");
      const line = (this.rawText || "").split(/\r?\n/).find((l) => re.test(l));
      return line ? line.replace(re, "$1").trim() : "";
    };

    this.formDraft = {
      meetingNotes: notes || fallbackAfter("general note about meeting"),
      wasCallRequested: yesNo(
        requestedRaw || fallbackAfter("was the call requested")
      ),
      matterDiscussed: matter || fallbackAfter("matter discussed"),
      followUpDetail: follow || fallbackAfter("follow up action detail")
    };
  }

  // inputs
  onChangeNotes(e) {
    this.formDraft = { ...this.formDraft, meetingNotes: e.detail.value };
  }
  onChangeMatter(e) {
    this.formDraft = { ...this.formDraft, matterDiscussed: e.detail.value };
  }
  onChangeRequested(e) {
    this.formDraft = { ...this.formDraft, wasCallRequested: e.target.checked };
  }
  onChangeFollowUp(e) {
    this.formDraft = { ...this.formDraft, followUpDetail: e.detail.value };
  }

  // save
  async save() {
    try {
      this.busy = true;
      const payload = {
        General_Note_about_Meeting__c: this.formDraft.meetingNotes || null,
        Was_Call_Requested__c: this.formDraft.wasCallRequested ? "Yes" : "No",
        Matter_Discussed__c: this.formDraft.matterDiscussed || null,
        Follow_Up_Action_Detail__c: this.formDraft.followUpDetail || null
      };

      // await upsertForm({ recordId: this.recordId, payload: JSON.stringify(payload) });
      console.log("SAVE payload", JSON.stringify(payload, null, 2));
      this.close({ confirmed: true, data: payload });
    } catch (e) {
      this.toast("Save Error", e?.body?.message || e.message, "error");
    } finally {
      this.busy = false;
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  disconnectedCallback() {
    try {
      this.stream?.getTracks()?.forEach((t) => t.stop());
    } catch (e) {
      console.warn("Error stopping stream", e);
    }
    this.streaming = false;
  }
}