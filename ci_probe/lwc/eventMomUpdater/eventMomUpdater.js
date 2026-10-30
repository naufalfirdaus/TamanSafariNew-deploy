import { LightningElement, api, wire } from "lwc";
import { getRecord, notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import generateMinutesFromAI from "@salesforce/apex/DocumentController.generateMinutesFromAI";
import createEventRecord from "@salesforce/apex/DocumentController.createEventRecord";

// Menarik data lama secara senyap agar tidak tertimpa/terhapus saat Update
const FIELDS = [
  "Event.Subject",
  "Event.Location",
  "Event.StartDateTime",
  "Event.EndDateTime",
  "Event.Meeting_Objective__c"
];

export default class EventMomUpdater extends LightningElement {
  @api recordId; // Otomatis menangkap ID Event yang sedang dibuka

  // Data Bawaan (Eksisting) dari Event
  existingSubject = "";
  existingLocation = "";
  existingStart = "";
  existingEnd = "";

  // Data Form & AI
  objective = "";
  attendance = "";
  discussion = "";
  conclusions = "";
  nextStep = "";
  summary = "";

  fileName = "";
  fileContent = "";

  // UI States
  isLoading = false;
  isSaving = false;
  showPreviewModal = false;

  // Menarik Data Event Bawaan via @wire
  @wire(getRecord, { recordId: "$recordId", fields: FIELDS })
  wiredEvent({ error, data }) {
    if (data) {
      this.existingSubject = data.fields.Subject.value || "";
      this.existingLocation = data.fields.Location.value || "";
      this.existingStart = data.fields.StartDateTime.value;
      this.existingEnd = data.fields.EndDateTime.value;

      // Pre-define Objective jika user sebelumnya sudah pernah mengisi
      this.objective = data.fields.Meeting_Objective__c.value || "";
    } else if (error) {
      console.error("Error fetching Event data", error);
    }
  }

  // TRIGGER 1: Saat User Milih File, Otomatis Panggil AI
  handleFileUpload(event) {
    const file = event.target.files[0];
    if (!file) return;

    this.isLoading = true;
    this.fileName = file.name;

    const reader = new FileReader();
    reader.onload = () => {
      this.fileContent = reader.result;
      this.processTranscriptAI(); // Eksekusi Callout AI!
    };
    reader.readAsText(file);
  }

  // TRIGGER 2: Callout AI & Munculkan Pop-up
  async processTranscriptAI() {
    try {
      const result = await generateMinutesFromAI({
        transcript: this.fileContent
      });

      this.attendance = result.Attendance || "";
      this.discussion = result.Point_of_Discussion || "";
      this.conclusions = result.Conclusions || "";
      this.nextStep = result.Next_Step || "";
      this.summary = result.Summary || "";
      this.objective = result.Objective || "";

      // AI Selesai, matikan loading kotak & Munculkan Modal Preview!
      this.isLoading = false;
      this.showPreviewModal = true;
    } catch (error) {
      this.isLoading = false;
      this.showToast(
        "AI Error",
        error?.body?.message || error?.message,
        "error"
      );
    }
  }

  // Handlers Edit Textarea di Modal
  handleObjectiveChange(e) {
    this.objective = e.target.value;
  }
  handleAttendanceChange(e) {
    this.attendance = e.target.value;
  }
  handleDiscussionChange(e) {
    this.discussion = e.target.value;
  }
  handleConclusionsChange(e) {
    this.conclusions = e.target.value;
  }
  handleNextStepChange(e) {
    this.nextStep = e.target.value;
  }
  handleSummaryChange(e) {
    this.summary = e.target.value;
  }

  // TRIGGER 3: Tombol Cancel (Buang Data & Tutup Pop-Up)
  handleCancel() {
    this.showPreviewModal = false;

    // Reset state
    this.fileContent = "";
    this.fileName = "";
    this.attendance = "";
    this.discussion = "";
    this.conclusions = "";
    this.nextStep = "";
    this.summary = "";
    this.objective = "";
  }

  // TRIGGER 4: Tombol Update Event Server
  async handleUpdateEvent() {
    this.isSaving = true;

    try {
      await createEventRecord({
        recordId: this.recordId,
        subject: this.existingSubject, // Data dijaga agar tak hilang
        location: this.existingLocation,
        objective: this.objective, // Update dari Form
        startStr: this.existingStart,
        endStr: this.existingEnd,
        attendance: this.attendance,
        discussion: this.discussion,
        conclusions: this.conclusions,
        nextStep: this.nextStep,
        summary: this.summary,
        fileName: this.fileName,
        fileContent: this.fileContent
      });

      this.showToast(
        "Success",
        "Event updated and Transcript attached!",
        "success"
      );

      // Minta Browser Refresh Data Background (Agar file langsung muncul di tab Related)
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);

      // AUTO-RETURN KE RECORD PAGE (Tutup Pop-up)
      this.handleCancel();
    } catch (error) {
      this.showToast(
        "Error Updating Event",
        error?.body?.message || error?.message,
        "error"
      );
    } finally {
      this.isSaving = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}