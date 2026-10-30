import { LightningElement, api, wire, track } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getCheckInHistory from "@salesforce/apex/CheckInService.getCheckInHistory";
import { NavigationMixin } from "lightning/navigation";

const PERIODS = [
  { label: "Today", value: "TODAY" },
  { label: "This Week", value: "THIS_WEEK" },
  { label: "All", value: "ALL" }
];

export default class GeoCheckinHistory extends NavigationMixin(
  LightningElement
) {
  @api recordId;
  @api objectApiName;
  @api rowLimit = 6;

  @track rows = [];
  @track error;
  @track isLoading = true;
  @track selectedPeriod = "TODAY";

  _wiredHistory;

  get hasRows() {
    return Array.isArray(this.rows) && this.rows.length > 0;
  }

  get normalizedRowLimit() {
    const n = Number(this.rowLimit);
    if (!Number.isFinite(n) || n <= 0) return 6;
    return Math.min(n, 20);
  }

  get filterOptions() {
    return PERIODS.map((p) => ({
      ...p,
      className:
        p.value === this.selectedPeriod
          ? "filter-btn filter-btn--active"
          : "filter-btn"
    }));
  }

  @wire(getCheckInHistory, {
    recordId: "$recordId",
    objectApiName: "$objectApiName",
    rowLimit: "$normalizedRowLimit",
    periodFilter: "$selectedPeriod"
  })
  wiredHistory(result) {
    this._wiredHistory = result;
    const { data, error } = result;

    this.isLoading = false;

    if (data) {
      this.error = null;
      this.rows = (data || []).map((r, idx) => {
        const isOpen = !r.checkOutAt;

        let insideLabel = "Unknown";
        let insideClass = "badge badge--neutral";
        if (r.insideCheckIn === true) {
          insideLabel = "Inside";
          insideClass = "badge badge--inside";
        } else if (r.insideCheckIn === false) {
          insideLabel = "Outside";
          insideClass = "badge badge--outside";
        }

        const checkInDistanceText =
          r.checkInDistanceMDisplay != null
            ? `${r.checkInDistanceMDisplay} m`
            : "-";
        const checkOutDistanceText =
          r.checkOutDistanceMDisplay != null
            ? `${r.checkOutDistanceMDisplay} m`
            : null;

        const hasCheckInCoords =
          r.checkInLat !== null &&
          r.checkInLat !== undefined &&
          r.checkInLng !== null &&
          r.checkInLng !== undefined;

        const hasCheckOutCoords =
          r.checkOutLat !== null &&
          r.checkOutLat !== undefined &&
          r.checkOutLng !== null &&
          r.checkOutLng !== undefined;

        let checkOutInsideLabel = "Unknown";
        let checkOutInsideClass = "badge badge--neutral";
        if (r.insideCheckOut === true) {
          checkOutInsideLabel = "Out: Inside";
          checkOutInsideClass = "badge badge--inside";
        } else if (r.insideCheckOut === false) {
          checkOutInsideLabel = "Out: Outside";
          checkOutInsideClass = "badge badge--outside";
        }

        const durationLabel = this.formatDuration(r.durationMinutes);

        return {
          ...r,
          rowKey: `${r.eventId}-${idx}`,
          isOpen,
          openStateLabel: isOpen ? "Open" : "Closed",
          openStateClass: isOpen ? "badge badge--open" : "badge badge--closed",
          insideLabel,
          insideClass,
          checkInDistanceText,
          checkOutDistanceText,
          hasPhoto: r.hasPhoto === true,
          hasCheckInCoords,
          hasCheckOutCoords,
          checkOutInsideLabel,
          checkOutInsideClass,
          hasCheckOutInsideBadge:
            r.checkOutAt !== null && r.checkOutAt !== undefined,
          durationLabel
        };
      });
    } else if (error) {
      this.rows = [];
      this.error = this.parseError(error);
    }
  }

  handleFilterClick(e) {
    const next = e.currentTarget?.dataset?.value;
    if (!next || next === this.selectedPeriod) return;

    this.selectedPeriod = next;
    this.isLoading = true;
  }

  handleRefresh() {
    this.refresh();
  }

  @api
  async refresh() {
    if (this._wiredHistory) {
      this.isLoading = true;
      try {
        await refreshApex(this._wiredHistory);
      } finally {
        this.isLoading = false;
      }
    }
  }

  openEvent(e) {
    const eventId = e.currentTarget?.dataset?.id;
    if (!eventId) return;

    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: eventId,
        objectApiName: "Event",
        actionName: "view"
      }
    });
  }

  openMap(e) {
    const lat = Number(e.currentTarget?.dataset?.lat);
    const lng = Number(e.currentTarget?.dataset?.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;

    const label = e.currentTarget?.dataset?.label || "Location";
    const url = `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
    window.open(url, "_blank");

    // optional debug
    // console.log(`Opening map for ${label}:`, lat, lng);
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

  formatDuration(minutes) {
    const n = Number(minutes);
    if (!Number.isFinite(n) || n < 0) return null;

    if (n < 1) return "<1m";

    const days = Math.floor(n / 1440);
    const hours = Math.floor((n % 1440) / 60);
    const mins = n % 60;

    const parts = [];
    if (days > 0) parts.push(`${days}d`);
    if (hours > 0) parts.push(`${hours}h`);
    if (mins > 0) parts.push(`${mins}m`);

    return parts.join(" ");
  }
}