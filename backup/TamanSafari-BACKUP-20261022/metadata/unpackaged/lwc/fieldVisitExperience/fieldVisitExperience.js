import { LightningElement, api, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getCurrentLocation } from "c/fieldVisitUtils";

// Apex Imports
import getActiveVisit from "@salesforce/apex/VisitController.getActiveVisit";
import getTargetContext from "@salesforce/apex/VisitController.getTargetContext";
import previewGeofence from "@salesforce/apex/VisitController.previewGeofence";
import pinTargetLocation from "@salesforce/apex/VisitController.pinTargetLocation";
import checkIn from "@salesforce/apex/VisitController.checkIn";
import saveVisitDraft from "@salesforce/apex/VisitController.saveVisitDraft";
import cancelVisit from "@salesforce/apex/VisitController.cancelVisit";
import uploadVisitPhoto from "@salesforce/apex/VisitController.uploadVisitPhoto";
import uploadClientSignature from "@salesforce/apex/VisitController.uploadClientSignature";
import declineClientSignature from "@salesforce/apex/VisitController.declineClientSignature";
import completeVisitCheckOut from "@salesforce/apex/VisitController.completeVisitCheckOut";
import getAccountContacts from "@salesforce/apex/VisitController.getAccountContacts";
import getOpenOpportunities from "@salesforce/apex/VisitController.getOpenOpportunities";
import getOpportunityPrefill from "@salesforce/apex/VisitController.getOpportunityPrefill";
import reverseGeocodeLive from "@salesforce/apex/VisitController.reverseGeocodeLive";
import updateLocationLock from "@salesforce/apex/VisitController.updateLocationLock";

// Modals
import VisitGeofenceModal from "c/visitGeofenceModal";
import VisitCancelModal from "c/visitCancelModal";
import VisitShortDurationModal from "c/visitShortDurationModal";
import VisitContactCreateModal from "c/visitContactCreateModal";
import PhotoCaptureModal from "c/photoCaptureModal";
import SignaturePadModal from "c/signaturePadModal";

// Custom Labels
import labelAppTitle from "@salesforce/label/c.FV_App_Title";
import labelTargetAccount from "@salesforce/label/c.FV_Target_Account";
import labelTargetLead from "@salesforce/label/c.FV_Target_Lead";
import labelSearchTarget from "@salesforce/label/c.FV_Search_Target";
import labelBtnCheckIn from "@salesforce/label/c.FV_Btn_CheckIn";
import labelBtnCheckout from "@salesforce/label/c.FV_Btn_Checkout";
import labelBtnNext from "@salesforce/label/c.FV_Btn_Next";
import labelBtnBack from "@salesforce/label/c.FV_Btn_Back";

const LEGACY_VALUE_MAP = {
  "TSI Bogor": "Taman Safari Bogor",
  "TSI Prigen": "Taman Safari Prigen",
  "TSI Bali": "Taman Safari Bali",
  "Belum Ditentukan": "Multiple / Undecided",
  "Lainnya": "Other",
  "Tiket Masuk": "Tickets",
  "Venue Outdoor / Hall": "Venue",
  "< 500rb": "< IDR 500k",
  "500rb - 1jt": "IDR 500k - 1M",
  "> 1jt": "> IDR 1M",
  "Approved / Ada Anggaran": "Approved / Allocated",
  "Perlu Pengajuan": "In Planning / Pending",
  "Belum Ada Anggaran": "No Budget Yet",
  "HR / GA": "HR (Human Resources)",
  "Direksi / BOD": "Executive / Board",
  "Procurement / Purchasing": "Procurement",
  "Marketing / Comm": "GA (General Affairs)",
  "Influencer": "Influencer / Committee",
  "User": "Gatekeeper",
  "Weekday (Sen-Kam)": "Weekday (Mon-Thu)",
  "Weekend (Jum-Min)": "Weekend (Fri-Sun)",
  "Segera (< 1 Bulan)": "This Month",
  "1-3 Bulan": "This Quarter",
  "> 3 Bulan": "Next Quarter",
  "Fleksibel": "Next Year"
};

export default class FieldVisitExperience extends NavigationMixin(LightningElement) {
  @api recordId;
  @api objectApiName;

  // Views: 'S1', 'ACTIVE', 'S5'
  @track currentView = "S1";
  @track currentStep = 1; // 1: Info/Photo, 2: BANT, 3: Check-Out

  // S1 Target Selection
  @track selectedTargetType = "Account"; // 'Account' or 'Lead'
  @track selectedTargetId = "";
  @track targetContext = null;
  @track targetAddress = "";
  @track gpsAccuracy = null;
  @track currentRepLat = null;
  @track currentRepLng = null;
  @track currentCheckoutAddress = "";

  // S2-S4 Active Visit State
  @track activeVisit = null;
  @track elapsedSeconds = 0;
  @track telemetryLocationStatus = "verified";
  @track currentDistanceMeters = 0;

  @track activeContactId = "";
  @track activePurpose = "Initial Canvassing / Discovery";
  @track activeOppId = "";
  @track hasPrefillNotice = false;

  @track photoSnapshotUrl = "";
  @track photoCapturedAt = "";
  @track isDuplicatePhoto = false;

  @track hasSignature = false;
  @track signedByName = "";
  @track signatureDeclinedReason = "";

  @track activeDraft = {};
  @track draftSaveStatus = ""; // 'saving', 'saved', 'failed'
  @track isSaving = false;

  @track accountContacts = [];
  @track openOpportunities = [];

  // S4 Pipeline State
  @track pipelineAction = "None"; // 'None', 'Convert Lead', 'Create Opportunity', 'Update Opportunity'
  @track oppStage = "Qualification";
  @track oppAmount = 0;
  @track oppCloseDate = "";

  // S5 Completion State
  @track completedVisit = null;

  // General Error / Loading
  @track serverError = "";
  @track isCheckingIn = false;
  @track isSubmittingCheckOut = false;

  timerInterval;
  serverTimeOffsetMs = 0;

  labels = {
    appTitle: labelAppTitle,
    targetAccount: labelTargetAccount,
    targetLead: labelTargetLead,
    searchTarget: labelSearchTarget,
    btnCheckIn: labelBtnCheckIn,
    btnCheckout: labelBtnCheckout,
    btnNext: labelBtnNext,
    btnBack: labelBtnBack
  };

  connectedCallback() {
    this.initSession();
    this.initGpsPreview();
  }

  async initGpsPreview() {
    try {
      const loc = await getCurrentLocation({ timeout: 6000 });
      if (loc) {
        this.currentRepLat = loc.latitude;
        this.currentRepLng = loc.longitude;
        this.gpsAccuracy = loc.accuracy;
      }
    } catch {
      // Rep may not have allowed GPS yet or browser is querying
    }
  }

  disconnectedCallback() {
    this.stopTimer();
  }

  async initSession() {
    this.serverError = "";
    try {
      // 1. Check if user already has an active In Progress visit to resume
      const active = await getActiveVisit();
      if (active) {
        this.restoreActiveVisit(active);
        return;
      }

      // 2. If no active visit, check if recordId is provided on Record Page
      if (this.recordId) {
        this.selectedTargetId = this.recordId;
        this.selectedTargetType =
          this.objectApiName === "Lead" ? "Lead" : "Account";
        await this.loadTarget(this.recordId);
      }
    } catch (err) {
      this.handleServerError(err);
    }
  }

  // --- Target Resolution (S1) ---
  get isRecordPageLocked() {
    return Boolean(this.recordId);
  }

  get isSelectingAccount() {
    return (
      this.selectedTargetType === "Account" ||
      this.selectedTargetType === "Account_Contact"
    );
  }

  get accountToggleClass() {
    return this.selectedTargetType === "Account"
      ? "toggle-btn toggle-btn--active"
      : "toggle-btn";
  }

  get leadToggleClass() {
    return this.selectedTargetType === "Lead"
      ? "toggle-btn toggle-btn--active"
      : "toggle-btn";
  }

  get hasTargetContext() {
    return Boolean(this.targetContext);
  }

  get isViewS1() {
    return this.currentView === "S1";
  }

  get isActiveVisit() {
    return this.currentView === "ACTIVE";
  }

  get isViewS5() {
    return this.currentView === "S5";
  }

  get isStep1() {
    return this.isActiveVisit && this.currentStep === 1;
  }

  get isStep2() {
    return this.isActiveVisit && this.currentStep === 2;
  }

  get isStep3() {
    return this.isActiveVisit && this.currentStep === 3;
  }

  get activeCheckInAddress() {
    return (
      this.activeVisit?.checkInAddress ||
      this.targetAddress ||
      this.targetContext?.address ||
      ""
    );
  }

  async loadLiveCheckoutAddress() {
    try {
      const loc = await getCurrentLocation();
      this.currentRepLat = loc.latitude;
      this.currentRepLng = loc.longitude;
      this.gpsAccuracy = loc.accuracy;
      const addr = await reverseGeocodeLive({
        lat: loc.latitude,
        lng: loc.longitude
      });
      if (addr) {
        this.currentCheckoutAddress = addr;
      }
    } catch {
      // ignore
    }
  }

  handleTargetTypeToggle(event) {
    const type = event.currentTarget.dataset.targetType;
    if (this.selectedTargetType !== type) {
      this.selectedTargetType = type;
      this.selectedTargetId = "";
      this.targetContext = null;
    }
  }

  async handleTargetRecordChange(event) {
    const targetId = event.detail.recordId;
    this.selectedTargetId = targetId;
    if (targetId) {
      await this.loadTarget(targetId);
    } else {
      this.targetContext = null;
    }
  }

  async loadTarget(targetId) {
    try {
      this.targetContext = await getTargetContext({ targetId });
      if (this.targetContext?.address) {
        this.targetAddress = this.targetContext.address;
      }
      if (!this.currentRepLat) {
        this.initGpsPreview();
      }
    } catch (err) {
      this.handleServerError(err);
    }
  }

  async handleUpdateAddress() {
    if (!this.activeTargetId) return;
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: this.activeTargetId,
        actionName: "edit"
      }
    });
  }

  async handlePinLocation() {
    if (!this.activeTargetId) return;
    try {
      this.serverError = "";
      const loc = await getCurrentLocation();
      this.currentRepLat = loc.latitude;
      this.currentRepLng = loc.longitude;
      this.gpsAccuracy = loc.accuracy;
      this.targetContext = await pinTargetLocation({
        targetId: this.activeTargetId,
        lat: loc.latitude,
        lng: loc.longitude
      });
      if (this.targetContext?.address) {
        this.targetAddress = this.targetContext.address;
      }
    } catch (err) {
      this.handleServerError(err);
    }
  }

  async handleLocationLockChange(event) {
    if (!this.activeTargetId) return;
    const isLocked = Boolean(event?.detail?.isLocked);
    try {
      this.serverError = "";
      this.targetContext = await updateLocationLock({
        targetId: this.activeTargetId,
        isLocked
      });
      if (this.targetContext?.address) {
        this.targetAddress = this.targetContext.address;
      }
    } catch (err) {
      this.handleServerError(err);
    }
  }

  // --- Check-In (S1 -> ACTIVE) ---
  async handleCheckIn() {
    if (!this.activeTargetId || this.isCheckingIn) return;
    this.serverError = "";
    this.isCheckingIn = true;

    try {
      this.telemetryLocationStatus = "acquiring";
      const loc = await getCurrentLocation();
      this.currentRepLat = loc.latitude;
      this.currentRepLng = loc.longitude;
      this.gpsAccuracy = loc.accuracy;

      // 1. Preview geofence decision on server
      const preview = await previewGeofence({
        targetId: this.activeTargetId,
        lat: loc.latitude,
        lng: loc.longitude
      });

      let exceptionReason = null;

      // 2. If outside geofence, present geofence modal
      if (preview.hasCoordinates && !preview.inside) {
        const modalResult = await VisitGeofenceModal.open({
          size: "small",
          isHardBlock: !preview.allowOutsideCheckIn,
          distanceMeters: preview.distanceM,
          radiusMeters: preview.radiusM
        });

        if (!modalResult || !modalResult.confirmed) {
          this.telemetryLocationStatus = "verified";
          return; // Cancelled by rep
        }
        exceptionReason = modalResult.reason;
      }

      // 3. Perform check-in on server
      const visit = await checkIn({
        targetId: this.activeTargetId,
        lat: loc.latitude,
        lng: loc.longitude,
        accuracyM: loc.accuracy,
        exceptionReason
      });

      this.restoreActiveVisit(visit);
    } catch (err) {
      this.handleServerError(err);
    } finally {
      this.isCheckingIn = false;
    }
  }

  // --- Active Visit Restoration & Lifecycle ---
  async restoreActiveVisit(visit) {
    this.activeVisit = visit;
    this.currentView = "ACTIVE";
    this.currentStep = 1;
    this.serverError = "";

    const targetId = visit.accountId || visit.leadId;
    this.selectedTargetId = targetId;
    this.selectedTargetType =
      visit.targetType === "Account_Contact" || visit.targetType === "Account"
        ? "Account"
        : "Lead";

    // Load target context if not already loaded
    if (!this.targetContext || this.targetContext.targetId !== targetId) {
      try {
        this.targetContext = await getTargetContext({ targetId });
      } catch {
        // ignore
      }
    }

    // Server time offset & elapsed timer synchronization
    const serverNow = visit.serverNow ? new Date(visit.serverNow).getTime() : Date.now();
    this.serverTimeOffsetMs = serverNow - Date.now();

    const checkInMs = visit.checkInTime ? new Date(visit.checkInTime).getTime() : Date.now();
    this.updateElapsed(checkInMs);
    this.startTimer(checkInMs);

    // Location Telemetry Status
    this.currentDistanceMeters = visit.distanceM || 0;
    this.telemetryLocationStatus = visit.isOutsideGeofence ? "offsite" : "verified";

    // Draft & Fields
    const draft = visit.draft || {};
    this.activeDraft = { ...draft };
    this.activePurpose = draft.visitPurpose || "Initial Canvassing / Discovery";
    this.activeContactId = draft.contactId || "";
    this.activeOppId = draft.opportunityId || "";

    // Photo
    this.photoSnapshotUrl = visit.hasPhoto ? `/sfc/servlet.shepherd/version/download/${visit.photoDocumentId}` : "";
    this.photoCapturedAt = visit.photoCapturedAt ? new Date(visit.photoCapturedAt).toLocaleString("id-ID") : "";
    this.isDuplicatePhoto = Boolean(visit.isDuplicatePhoto);

    // Signature
    this.hasSignature = Boolean(visit.hasSignature);
    this.signedByName = visit.signedByName || "";
    this.signatureDeclinedReason = visit.signatureDeclinedReason || "";

    // Pipeline Action Default
    if (this.activeTargetType === "Lead") {
      this.pipelineAction = draft.pipelineAction || "Convert Lead";
    } else if (this.activeOppId) {
      this.pipelineAction = "Update Opportunity";
    } else {
      this.pipelineAction = draft.pipelineAction || "Create Opportunity";
    }

    // Load Accounts contacts & opportunities if Account visit
    if (visit.accountId) {
      this.loadAccountDependencies(visit.accountId);
    }
  }

  async loadAccountDependencies(accountId) {
    try {
      const [contacts, opps] = await Promise.all([
        getAccountContacts({ accountId }),
        getOpenOpportunities({ accountId })
      ]);
      this.accountContacts = contacts || [];
      this.openOpportunities = opps || [];
      if (!this.activeContactId && this.accountContacts.length === 1) {
        this.activeContactId = this.accountContacts[0].id;
        this.saveDraftPayload({ contactId: this.activeContactId });
      }
    } catch {
      // ignore
    }
  }

  startTimer(checkInMs) {
    this.stopTimer();
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.timerInterval = setInterval(() => {
      this.updateElapsed(checkInMs);
    }, 1000);
  }

  updateElapsed(checkInMs) {
    const currentServerTime = Date.now() + this.serverTimeOffsetMs;
    const diff = Math.max(0, Math.floor((currentServerTime - checkInMs) / 1000));
    this.elapsedSeconds = diff;
  }

  stopTimer() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = null;
    }
  }

  // --- Step 1 Handlers ---
  handleContactChange(event) {
    this.activeContactId = event.detail.contactId;
    this.saveDraftPayload({ contactId: this.activeContactId });
  }

  async handleOpenQuickCreateContact() {
    if (!this.activeAccountId) return;
    const result = await VisitContactCreateModal.open({
      size: "small",
      accountId: this.activeAccountId
    });

    if (result && result.confirmed) {
      this.accountContacts = [...this.accountContacts, result.contact];
      this.activeContactId = result.contactId;
      this.saveDraftPayload({ contactId: this.activeContactId });
    }
  }

  handlePurposeChange(event) {
    this.activePurpose = event.detail.purpose;
    this.saveDraftPayload({ visitPurpose: this.activePurpose });
  }

  async handleOpportunityChange(event) {
    this.activeOppId = event.detail.opportunityId;
    this.saveDraftPayload({ opportunityId: this.activeOppId });

    if (this.activeOppId) {
      this.pipelineAction = "Update Opportunity";
      try {
        const prefill = await getOpportunityPrefill({
          opportunityId: this.activeOppId
        });
        if (prefill && prefill.draft) {
          this.activeDraft = {
            ...this.activeDraft,
            ...prefill.draft
          };
          this.hasPrefillNotice = true;
        }
      } catch {
        // ignore
      }
    }
  }

  async handleTakePhoto() {
    try {
      const loc = await getCurrentLocation();
      const modalResult = await PhotoCaptureModal.open({
        size: "large",
        coords: {
          lat: loc.latitude,
          lng: loc.longitude,
          acc: loc.accuracy,
          address: this.targetAddress
        },
        targetName: this.targetName
      });

      if (modalResult && modalResult.confirmed) {
        this.photoSnapshotUrl = modalResult.dataUrl;
        this.photoCapturedAt = new Date().toLocaleString("id-ID");

        // Upload to server
        const updatedVisit = await uploadVisitPhoto({
          visitId: this.activeVisit.id,
          base64Jpeg: modalResult.dataUrl,
          lat: loc.latitude,
          lng: loc.longitude
        });

        this.isDuplicatePhoto = Boolean(updatedVisit.isDuplicatePhoto);
      }
    } catch (err) {
      this.handleServerError(err);
    }
  }

  // --- Step 2 Handlers ---
  handleFormChange(event) {
    this.activeDraft = { ...event.detail };
    this.saveDraftPayload(this.activeDraft);
  }

  async handleOpenSignature() {
    try {
      const loc = await getCurrentLocation();
      const prefillName =
        this.activeTargetType === "Account"
          ? this.selectedContactName
          : this.activeLeadName;

      const modalResult = await SignaturePadModal.open({
        size: "medium",
        signerName: prefillName,
        targetName: this.targetName,
        coords: {
          lat: loc.latitude,
          lng: loc.longitude,
          acc: loc.accuracy
        }
      });

      if (modalResult && modalResult.confirmed) {
        this.signedByName = modalResult.signerName;
        this.hasSignature = true;
        this.signatureDeclinedReason = "";

        await uploadClientSignature({
          visitId: this.activeVisit.id,
          base64Png: modalResult.dataUrl,
          signerName: modalResult.signerName,
          lat: loc.latitude,
          lng: loc.longitude
        });
      }
    } catch (err) {
      this.handleServerError(err);
    }
  }

  async handleDeclineSignature(event) {
    const reason = event.detail.reason;
    try {
      await declineClientSignature({
        visitId: this.activeVisit.id,
        reason
      });
      this.signatureDeclinedReason = reason;
      this.hasSignature = false;
      this.signedByName = "";
    } catch (err) {
      this.handleServerError(err);
    }
  }

  // --- Step 3 Pipeline & Check-Out Handlers ---
  handlePipelineActionChange(event) {
    this.pipelineAction = event.detail.pipelineAction;
    this.saveDraftPayload({ pipelineAction: this.pipelineAction });
  }

  handleOppFieldChange(event) {
    const { field, value } = event.detail;
    if (field === "oppStage") this.oppStage = value;
    if (field === "oppAmount") this.oppAmount = value;
    if (field === "oppCloseDate") this.oppCloseDate = value;
  }

  handleNavigateToStep(event) {
    this.currentStep = event.detail.step;
    if (this.currentStep === 3) {
      this.loadLiveCheckoutAddress();
    }
  }

  async handleCheckOutSubmit() {
    if (!this.activeVisit?.id) return;
    this.serverError = "";

    try {
      const elapsedMins = Math.floor(this.elapsedSeconds / 60);
      const minDuration = this.targetContext?.minDurationMinutes || 10;

      // Short visit warning check
      if (elapsedMins < minDuration) {
        const modalResult = await VisitShortDurationModal.open({
          size: "small",
          elapsedMinutes: elapsedMins,
          minDurationMinutes: minDuration
        });

        if (!modalResult || !modalResult.confirmed) {
          return; // Rep chose to stay in meeting
        }
      }

      this.isSubmittingCheckOut = true;

      // Ensure latest draft is safely saved before check-out
      await this.saveDraftPayload({});

      // Acquire check-out GPS
      let lat = null;
      let lng = null;
      let accuracy = null;

      try {
        const loc = await getCurrentLocation();
        lat = loc.latitude;
        lng = loc.longitude;
        accuracy = loc.accuracy;
      } catch {
        // Missing GPS fix is permitted by server
      }

      let pipelineJson = null;
      if (this.pipelineAction === "Update Opportunity") {
        pipelineJson = JSON.stringify({
          opportunityStage: this.oppStage,
          amount: this.oppAmount,
          closeDate: this.oppCloseDate
        });
      }

      const completed = await completeVisitCheckOut({
        visitId: this.activeVisit.id,
        lat,
        lng,
        accuracyM: accuracy,
        pipelineJson
      });

      this.stopTimer();
      this.completedVisit = completed;
      this.currentView = "S5";
    } catch (err) {
      this.handleServerError(err);
    } finally {
      this.isSubmittingCheckOut = false;
    }
  }

  // --- Cancel Visit Flow ---
  async handleCancelVisitPrompt() {
    if (!this.activeVisit?.id) return;
    const modalResult = await VisitCancelModal.open({ size: "small" });

    if (modalResult && modalResult.confirmed) {
      try {
        await cancelVisit({
          visitId: this.activeVisit.id,
          reason: modalResult.reason
        });
        this.resetSession();
      } catch (err) {
        this.handleServerError(err);
      }
    }
  }

  // --- Draft Saving ---
  async saveDraftPayload(partial) {
    if (!this.activeVisit?.id) return;
    this.draftSaveStatus = "saving";
    this.isSaving = true;

    const payload = {
      ...this.activeDraft,
      visitPurpose: this.activePurpose,
      contactId: this.activeContactId,
      opportunityId: this.activeOppId,
      pipelineAction: this.pipelineAction,
      ...partial
    };

    for (const [k, v] of Object.entries(payload)) {
      if (Array.isArray(v)) {
        payload[k] = v.map((item) => LEGACY_VALUE_MAP[item] || item);
      } else if (typeof v === "string" && LEGACY_VALUE_MAP[v]) {
        payload[k] = LEGACY_VALUE_MAP[v];
      }
    }

    try {
      await saveVisitDraft({
        visitId: this.activeVisit.id,
        draftJson: JSON.stringify(payload)
      });
      this.draftSaveStatus = "saved";
    } catch {
      this.draftSaveStatus = "failed";
    } finally {
      this.isSaving = false;
    }
  }

  handleRetryDraftSave() {
    this.saveDraftPayload({});
  }

  // --- Footer Navigation ---
  get showStickyBottomBar() {
    return this.isViewS1 || this.isActiveVisit;
  }

  get showBottomPrevious() {
    return this.isActiveVisit && this.currentStep > 1;
  }

  get bottomNextLabel() {
    if (this.isViewS1) {
      return this.labels.btnCheckIn;
    }
    if (this.currentStep === 1) {
      return "Lanjut: Kualifikasi BANT ->";
    }
    if (this.currentStep === 2) {
      return "Lanjut: Check-Out ->";
    }
    return this.labels.btnCheckout;
  }

  get isBottomLoading() {
    if (this.isViewS1) {
      return this.isCheckingIn;
    }
    if (this.currentStep === 3) {
      return this.isSubmittingCheckOut;
    }
    return false;
  }

  get bottomLoadingLabel() {
    if (this.isViewS1 && this.isCheckingIn) {
      return "Memproses Check-In...";
    }
    if (this.currentStep === 3 && this.isSubmittingCheckOut) {
      return "Menyelesaikan Kunjungan...";
    }
    return "";
  }

  get isBottomNextDisabled() {
    if (this.isViewS1) {
      return (
        !this.hasTargetContext ||
        !this.targetContext?.hasCoordinates ||
        this.isCheckingIn
      );
    }
    if (this.currentStep === 1) {
      const hasContact =
        this.activeTargetType === "Lead" ? true : Boolean(this.activeContactId);
      return !hasContact || !this.photoSnapshotUrl;
    }
    if (this.currentStep === 2) {
      return (
        !this.activeDraft.meetingSummary ||
        !this.activeDraft.meetingSummary.trim()
      );
    }
    if (this.currentStep === 3) {
      return !this.isCheckoutReady || this.isSubmittingCheckOut;
    }
    return false;
  }

  async handleBottomNext() {
    if (this.isViewS1) {
      this.handleCheckIn();
    } else if (this.currentStep === 1) {
      await this.saveDraftPayload({});
      this.currentStep = 2;
    } else if (this.currentStep === 2) {
      await this.saveDraftPayload({});
      this.currentStep = 3;
      this.loadLiveCheckoutAddress();
    } else if (this.currentStep === 3) {
      this.handleCheckOutSubmit();
    }
  }

  handleStepPrevious() {
    if (this.currentStep > 1) {
      this.currentStep -= 1;
    }
  }

  handleStartNewVisit() {
    this.resetSession();
  }

  resetSession() {
    this.stopTimer();
    this.currentView = "S1";
    this.currentStep = 1;
    this.activeVisit = null;
    this.completedVisit = null;
    this.photoSnapshotUrl = "";
    this.hasSignature = false;
    this.signedByName = "";
    this.signatureDeclinedReason = "";
    this.activeDraft = {};
    this.draftSaveStatus = "";
    this.serverError = "";

    if (this.recordId) {
      this.loadTarget(this.recordId);
    } else {
      this.selectedTargetId = "";
      this.targetContext = null;
    }
  }

  // --- Getters ---
  get activeTargetId() {
    return (
      this.activeVisit?.accountId ||
      this.activeVisit?.leadId ||
      this.selectedTargetId
    );
  }

  get activeTargetType() {
    const raw = this.activeVisit?.targetType || this.selectedTargetType;
    return raw === "Account_Contact" || raw === "Account" ? "Account" : "Lead";
  }

  get activeAccountId() {
    return this.activeVisit?.accountId || (this.isSelectingAccount ? this.selectedTargetId : null);
  }

  get targetName() {
    return this.targetContext?.name || this.activeVisit?.name || "";
  }

  get activeLeadName() {
    if (this.activeTargetType === "Lead") {
      return this.targetName;
    }
    return "";
  }

  get selectedContactName() {
    const found = this.accountContacts.find((c) => c.id === this.activeContactId);
    return found?.name || "";
  }

  get linkedOpportunityRecord() {
    if (!this.activeOppId) return null;
    return this.openOpportunities.find((o) => o.id === this.activeOppId) || null;
  }

  get checkoutReadiness() {
    return {
      hasPurpose: Boolean(this.activePurpose),
      hasContact: Boolean(
        this.activeTargetType === "Lead" ? true : this.activeContactId
      ),
      hasPhoto: Boolean(this.photoSnapshotUrl),
      hasSummary: Boolean(
        this.activeDraft?.meetingSummary &&
          this.activeDraft.meetingSummary.trim().length > 0
      ),
      hasSignatureOrDeclined: Boolean(
        this.hasSignature || this.signatureDeclinedReason
      )
    };
  }

  get isCheckoutReady() {
    const r = this.checkoutReadiness;
    return (
      r.hasPurpose &&
      r.hasContact &&
      r.hasPhoto &&
      r.hasSummary &&
      r.hasSignatureOrDeclined
    );
  }

  handleClearError() {
    this.serverError = "";
  }

  handleServerError(err) {
    this.serverError =
      err?.body?.message || err?.message || "Terjadi kesalahan pada server.";
  }
}