import { LightningElement, api, track } from "lwc";
import { formatCurrencyIDR, parseCurrencyIDR } from "c/fieldVisitUtils";
import labelPark from "@salesforce/label/c.FV_BANT_Park_Label";
import labelEventType from "@salesforce/label/c.FV_BANT_EventType_Label";
import labelPackages from "@salesforce/label/c.FV_BANT_Packages_Label";
import labelPax from "@salesforce/label/c.FV_BANT_Pax_Label";
import labelBudget from "@salesforce/label/c.FV_BANT_Budget_Label";
import labelDate from "@salesforce/label/c.FV_BANT_Date_Label";
import labelSummary from "@salesforce/label/c.FV_BANT_Summary_Label";
import labelConsentPDP from "@salesforce/label/c.FV_Consent_PDP";
import labelBtnSign from "@salesforce/label/c.FV_Btn_Sign";
import labelBtnDeclineSign from "@salesforce/label/c.FV_Btn_Decline_Sign";
import labelSignDeclinedReason from "@salesforce/label/c.FV_Sign_Declined_Reason";
import labelSignRefused from "@salesforce/label/c.FV_Sign_Reason_Refused";
import labelSignUnavailable from "@salesforce/label/c.FV_Sign_Reason_Unavailable";
import labelSignOther from "@salesforce/label/c.FV_Sign_Reason_Other";
import labelStepInfo from "@salesforce/label/c.FV_Step_Info";
import labelStepBANT from "@salesforce/label/c.FV_Step_BANT";
import labelStepCheckout from "@salesforce/label/c.FV_Step_Checkout";

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

function normalizeFormValue(value) {
  if (value == null) return value;
  if (Array.isArray(value)) {
    return value.map((v) => LEGACY_VALUE_MAP[v] || v);
  }
  return LEGACY_VALUE_MAP[value] || value;
}

export default class VisitQualificationForm extends LightningElement {
  @api purpose = "Initial Canvassing / Discovery";
  @api hasSignature = false;
  @api signedByName = "";
  @api signatureDeclinedReason = "";

  @track state = {
    preferredPark: "Taman Safari Bogor",
    eventType: "Corporate Meeting",
    interestedPackages: ["Tickets"],
    estimatedPax: 50,
    budgetPerPax: "IDR 500k - 1M",
    totalBudget: 25000000,
    budgetStatus: "Approved / Allocated",
    picDepartment: "HR (Human Resources)",
    decisionRole: "Decision Maker",
    finalApproverIdentified: true,
    targetEventDate: "",
    preferredDayType: "Weekday (Mon-Thu)",
    bookingUrgency: "This Quarter",
    meetingSummary: "",
    uuPdpConsent: true
  };

  @track showDeclinePicker = false;
  debounceTimeout;

  labels = {
    parkLabel: labelPark,
    eventTypeLabel: labelEventType,
    packagesLabel: labelPackages,
    paxLabel: labelPax,
    budgetLabel: labelBudget,
    dateLabel: labelDate,
    summaryLabel: labelSummary,
    consentPDP: labelConsentPDP,
    btnSign: labelBtnSign,
    btnDeclineSign: labelBtnDeclineSign,
    signDeclinedReason: labelSignDeclinedReason,
    signRefused: labelSignRefused,
    signUnavailable: labelSignUnavailable,
    signOther: labelSignOther,
    stepInfo: labelStepInfo,
    stepBANT: labelStepBANT,
    stepCheckout: labelStepCheckout
  };

  @api
  get formData() {
    return this.state;
  }
  set formData(val) {
    if (val && typeof val === "object") {
      const normalized = {};
      for (const [k, v] of Object.entries(val)) {
        normalized[k] = normalizeFormValue(v);
      }
      this.state = {
        ...this.state,
        ...normalized
      };
    }
  }

  get isFinalConfirmation() {
    return this.purpose === "Final Confirmation / Contracting";
  }

  get paxValue() {
    return this.state.estimatedPax || "";
  }

  get formattedBudgetValue() {
    return this.state.totalBudget != null
      ? formatCurrencyIDR(this.state.totalBudget)
      : "";
  }

  get targetEventDate() {
    return this.state.targetEventDate || "";
  }

  get meetingSummary() {
    return this.state.meetingSummary || "";
  }

  get uuPdpConsent() {
    return Boolean(this.state.uuPdpConsent);
  }

  get finalApproverIdentified() {
    return Boolean(this.state.finalApproverIdentified);
  }

  get isDeclined() {
    return Boolean(this.signatureDeclinedReason);
  }

  get hasSignatureOrDeclined() {
    return Boolean(this.hasSignature || this.isDeclined);
  }

  get displayDeclinedReason() {
    if (this.signatureDeclinedReason === "Client Declined to Sign") {
      return this.labels.signRefused;
    }
    if (this.signatureDeclinedReason === "Signer Not Available") {
      return this.labels.signUnavailable;
    }
    return this.labels.signOther;
  }

  // --- Pill Options ---
  // --- Pill Options ---
  rawParks = [
    { value: "Taman Safari Bogor", label: "TSI Bogor" },
    { value: "Taman Safari Prigen", label: "TSI Prigen" },
    { value: "Taman Safari Bali", label: "TSI Bali" },
    { value: "Beach Safari Batang", label: "Beach Safari Batang" },
    { value: "Solo Safari", label: "Solo Safari" },
    { value: "Multiple / Undecided", label: "Belum Ditentukan" }
  ];
  get parkOptions() {
    return this.rawParks.map((p) => {
      const isSelected = this.state.preferredPark === p.value;
      return {
        value: p.value,
        label: p.label,
        isSelected,
        cssClass: isSelected ? "touch-chip touch-chip--selected" : "touch-chip"
      };
    });
  }

  rawEventTypes = [
    { value: "Team Building", label: "Team Building" },
    { value: "Family Gathering", label: "Family Gathering" },
    { value: "Corporate Meeting", label: "Corporate Meeting" },
    { value: "Other", label: "Lainnya" }
  ];
  get eventTypeOptions() {
    return this.rawEventTypes.map((t) => {
      const isSelected = this.state.eventType === t.value;
      return {
        value: t.value,
        label: t.label,
        isSelected,
        cssClass: isSelected ? "touch-chip touch-chip--selected" : "touch-chip"
      };
    });
  }

  rawPackages = [
    { value: "Tickets", label: "Tiket Masuk" },
    { value: "Hotel", label: "Hotel" },
    { value: "Catering", label: "Catering" },
    { value: "Venue", label: "Venue Outdoor / Hall" }
  ];
  get packageOptions() {
    const list = this.state.interestedPackages || [];
    return this.rawPackages.map((pkg) => {
      const isSelected = list.includes(pkg.value);
      return {
        value: pkg.value,
        label: pkg.label,
        isSelected,
        cssClass: isSelected ? "touch-chip touch-chip--selected" : "touch-chip"
      };
    });
  }

  rawBudgetPerPax = [
    { value: "< IDR 500k", label: "< 500rb" },
    { value: "IDR 500k - 1M", label: "500rb - 1jt" },
    { value: "> IDR 1M", label: "> 1jt" }
  ];
  get budgetPerPaxOptions() {
    return this.rawBudgetPerPax.map((b) => {
      const isSelected = this.state.budgetPerPax === b.value;
      return {
        value: b.value,
        label: b.label,
        isSelected,
        cssClass: isSelected ? "touch-chip touch-chip--selected" : "touch-chip"
      };
    });
  }

  rawBudgetStatus = [
    { value: "Approved / Allocated", label: "Approved / Ada Anggaran" },
    { value: "In Planning / Pending", label: "Perlu Pengajuan" },
    { value: "No Budget Yet", label: "Belum Ada Anggaran" }
  ];
  get budgetStatusOptions() {
    return this.rawBudgetStatus.map((s) => {
      const isSelected = this.state.budgetStatus === s.value;
      return {
        value: s.value,
        label: s.label,
        isSelected,
        cssClass: isSelected ? "touch-chip touch-chip--selected" : "touch-chip"
      };
    });
  }

  rawDepts = [
    { value: "HR (Human Resources)", label: "HR / Human Resources" },
    { value: "GA (General Affairs)", label: "GA / General Affairs" },
    { value: "Procurement", label: "Procurement / Purchasing" },
    { value: "Event Committee (Panitia)", label: "Panitia Acara" },
    { value: "Executive / Board", label: "Direksi / BOD" }
  ];
  get deptOptions() {
    return this.rawDepts.map((d) => {
      const isSelected = this.state.picDepartment === d.value;
      return {
        value: d.value,
        label: d.label,
        isSelected,
        cssClass: isSelected ? "touch-chip touch-chip--selected" : "touch-chip"
      };
    });
  }

  rawDecisionRoles = [
    { value: "Decision Maker", label: "Decision Maker" },
    { value: "Influencer / Committee", label: "Influencer / Panitia" },
    { value: "Gatekeeper", label: "Gatekeeper" }
  ];
  get decisionRoleOptions() {
    return this.rawDecisionRoles.map((r) => {
      const isSelected = this.state.decisionRole === r.value;
      return {
        value: r.value,
        label: r.label,
        isSelected,
        cssClass: isSelected ? "touch-chip touch-chip--selected" : "touch-chip"
      };
    });
  }

  rawDayTypes = [
    { value: "Weekday (Mon-Thu)", label: "Weekday (Sen-Kam)" },
    { value: "Weekend (Fri-Sun)", label: "Weekend (Jum-Min)" }
  ];
  get dayTypeOptions() {
    return this.rawDayTypes.map((d) => {
      const isSelected = this.state.preferredDayType === d.value;
      return {
        value: d.value,
        label: d.label,
        isSelected,
        cssClass: isSelected ? "touch-chip touch-chip--selected" : "touch-chip"
      };
    });
  }

  rawUrgencies = [
    { value: "This Month", label: "Bulan Ini (< 1 Bln)" },
    { value: "This Quarter", label: "Kuartal Ini (1-3 Bln)" },
    { value: "Next Quarter", label: "Kuartal Depan (3-6 Bln)" },
    { value: "Next Year", label: "Tahun Depan (> 6 Bln)" }
  ];
  get urgencyOptions() {
    return this.rawUrgencies.map((u) => {
      const isSelected = this.state.bookingUrgency === u.value;
      return {
        value: u.value,
        label: u.label,
        isSelected,
        cssClass: isSelected ? "touch-chip touch-chip--selected" : "touch-chip"
      };
    });
  }

  get declineReasonOptions() {
    return [
      { value: "Client Declined to Sign", label: this.labels.signRefused },
      { value: "Signer Not Available", label: this.labels.signUnavailable },
      { value: "Other", label: this.labels.signOther }
    ];
  }

  // --- Handlers ---
  handleSinglePillClick(event) {
    const field = event.currentTarget.dataset.field;
    const value = event.currentTarget.dataset.value;
    this.updateFieldImmediate(field, value);
  }

  handlePackageToggle(event) {
    const val = event.currentTarget.dataset.value;
    let list = [...(this.state.interestedPackages || [])];
    if (list.includes(val)) {
      list = list.filter((item) => item !== val);
    } else {
      list.push(val);
    }
    this.updateFieldImmediate("interestedPackages", list);
  }

  handlePaxChange(event) {
    const raw = event.detail?.value !== undefined ? event.detail.value : event.target.value;
    const val = parseInt(raw, 10);
    this.updateFieldDebounced("estimatedPax", isNaN(val) ? null : val);
  }

  handleBudgetChange(event) {
    const raw = event.detail?.value !== undefined ? event.detail.value : event.target.value;
    const num = parseCurrencyIDR(raw);
    this.updateFieldDebounced("totalBudget", num);
  }

  handleDateChange(event) {
    const val = event.detail?.value !== undefined ? event.detail.value : event.target.value;
    this.updateFieldImmediate("targetEventDate", val);
  }

  handleFinalApproverChange(event) {
    const checked = event.detail?.checked !== undefined ? event.detail.checked : event.target.checked;
    this.updateFieldImmediate("finalApproverIdentified", checked);
  }

  handleSummaryChange(event) {
    const val = event.detail?.value !== undefined ? event.detail.value : event.target.value;
    this.updateFieldDebounced("meetingSummary", val);
  }

  handlePdpConsentChange(event) {
    this.updateFieldImmediate("uuPdpConsent", event.target.checked);
  }

  handleOpenSignature() {
    this.dispatchEvent(new CustomEvent("opensignature"));
  }

  handleDeclineSignatureClick() {
    this.showDeclinePicker = !this.showDeclinePicker;
  }

  handleSelectDeclineReason(event) {
    const reason = event.currentTarget.dataset.value;
    this.showDeclinePicker = false;
    this.dispatchEvent(
      new CustomEvent("declinesignature", {
        detail: { reason }
      })
    );
  }

  updateFieldImmediate(field, value) {
    this.state = {
      ...this.state,
      [field]: value
    };
    this.dispatchFormChange();
  }

  updateFieldDebounced(field, value) {
    this.state = {
      ...this.state,
      [field]: value
    };
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout);
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.debounceTimeout = setTimeout(() => {
      this.dispatchFormChange();
    }, 1500);
  }

  dispatchFormChange() {
    this.dispatchEvent(
      new CustomEvent("formchange", {
        detail: { ...this.state }
      })
    );
  }
}