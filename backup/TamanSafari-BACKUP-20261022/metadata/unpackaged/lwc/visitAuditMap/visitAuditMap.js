import { LightningElement, api, wire } from 'lwc';
import getVisitAuditData from '@salesforce/apex/VisitAuditController.getVisitAuditData';

// Custom Labels
import labelCardTitle from '@salesforce/label/c.FV_AuditMap_CardTitle';
import labelOutsideGeofence from '@salesforce/label/c.FV_Badge_OutsideGeofence';
import labelShortVisit from '@salesforce/label/c.FV_Badge_ShortVisit';
import labelDuplicatePhoto from '@salesforce/label/c.FV_Badge_DuplicatePhoto';
import labelMissingCheckOut from '@salesforce/label/c.FV_Badge_MissingCheckOut';
import labelAiInjection from '@salesforce/label/c.FV_Badge_AiInjection';
import labelVerificationTitle from '@salesforce/label/c.FV_AuditMap_VerificationTitle';
import labelTierVerified from '@salesforce/label/c.FV_AuditMap_Tier_Verified';
import labelTierCoaching from '@salesforce/label/c.FV_AuditMap_Tier_Coaching';
import labelTierFlagged from '@salesforce/label/c.FV_AuditMap_Tier_Flagged';
import labelTotalScore from '@salesforce/label/c.FV_AuditMap_TotalScore';
import labelTelemetryScore from '@salesforce/label/c.FV_AuditMap_TelemetryScore';
import labelFraudReasons from '@salesforce/label/c.FV_AuditMap_FraudReasons';
import labelAiSummaryTitle from '@salesforce/label/c.FV_AuditMap_AiSummaryTitle';
import labelInvestigationStatus from '@salesforce/label/c.FV_AuditMap_InvestigationStatus';
import labelInvestigationNotes from '@salesforce/label/c.FV_AuditMap_InvestigationNotes';
import labelNoFraudReasons from '@salesforce/label/c.FV_AuditMap_NoFraudReasons';
import labelNoAiSummary from '@salesforce/label/c.FV_AuditMap_NoAiSummary';
import labelNoInvestigationNotes from '@salesforce/label/c.FV_AuditMap_NoInvestigationNotes';
import labelLoading from '@salesforce/label/c.FV_AuditMap_Loading';
import labelErrorTitle from '@salesforce/label/c.FV_AuditMap_ErrorTitle';
import labelNoLocations from '@salesforce/label/c.FV_AuditMap_NoLocations';

export default class VisitAuditMap extends LightningElement {
    @api recordId;

    auditData = null;
    isLoading = true;
    errorMessage = null;

    labels = {
        cardTitle: labelCardTitle,
        outsideGeofence: labelOutsideGeofence,
        shortVisit: labelShortVisit,
        duplicatePhoto: labelDuplicatePhoto,
        missingCheckOut: labelMissingCheckOut,
        aiInjection: labelAiInjection,
        verificationTitle: labelVerificationTitle,
        tierVerified: labelTierVerified,
        tierCoaching: labelTierCoaching,
        tierFlagged: labelTierFlagged,
        totalScore: labelTotalScore,
        telemetryScore: labelTelemetryScore,
        fraudReasons: labelFraudReasons,
        aiSummaryTitle: labelAiSummaryTitle,
        investigationStatus: labelInvestigationStatus,
        investigationNotes: labelInvestigationNotes,
        noFraudReasons: labelNoFraudReasons,
        noAiSummary: labelNoAiSummary,
        noInvestigationNotes: labelNoInvestigationNotes,
        loading: labelLoading,
        errorTitle: labelErrorTitle,
        noLocations: labelNoLocations
    };

    @wire(getVisitAuditData, { visitId: '$recordId' })
    wiredAudit({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.auditData = data;
            this.errorMessage = null;
        } else if (error) {
            this.auditData = null;
            this.errorMessage = error?.body?.message || (typeof error === 'string' ? error : JSON.stringify(error));
        }
    }

    get isReady() {
        return !this.isLoading && !this.errorMessage && this.auditData != null;
    }

    get hasError() {
        return !this.isLoading && !!this.errorMessage;
    }

    get isManagerView() {
        return this.auditData && this.auditData.isManagerView === true;
    }

    get mapMarkers() {
        if (!this.auditData || !this.auditData.markers) {
            return [];
        }
        return this.auditData.markers.map(m => ({
            location: {
                Latitude: m.latitude,
                Longitude: m.longitude
            },
            title: m.title,
            description: m.description,
            icon: m.icon,
            value: m.key
        }));
    }

    get hasMarkers() {
        return this.mapMarkers.length > 0;
    }

    get badges() {
        if (!this.auditData) return [];
        const list = [];

        // 1. Outside Geofence
        if (this.auditData.isOutsideGeofence) {
            let label = this.labels.outsideGeofence;
            if (this.auditData.geofenceExceptionReason) {
                label += ` (${this.auditData.geofenceExceptionReason})`;
            }
            list.push({
                id: 'outside-geofence',
                label: label,
                icon: 'utility:warning',
                iconVariant: 'warning',
                cssClass: 'anomaly-badge badge-warning'
            });
        }

        // 2. Short Visit
        if (this.auditData.isShortVisit) {
            list.push({
                id: 'short-visit',
                label: this.labels.shortVisit,
                icon: 'utility:clock',
                iconVariant: 'warning',
                cssClass: 'anomaly-badge badge-warning'
            });
        }

        // 3. Duplicate Photo
        if (this.auditData.isDuplicatePhoto) {
            list.push({
                id: 'duplicate-photo',
                label: this.labels.duplicatePhoto,
                icon: 'utility:copy',
                iconVariant: 'error',
                cssClass: 'anomaly-badge badge-danger'
            });
        }

        // 4. Missing Check-Out GPS
        if (this.auditData.isCheckOutLocationMissing) {
            list.push({
                id: 'missing-checkout',
                label: this.labels.missingCheckOut,
                icon: 'utility:location_offline',
                iconVariant: 'warning',
                cssClass: 'anomaly-badge badge-warning'
            });
        }

        // 5. Suspected AI Injection (Manager Only)
        if (this.auditData.isManagerView && this.auditData.aiInjectionSuspected) {
            list.push({
                id: 'ai-injection',
                label: this.labels.aiInjection,
                icon: 'utility:shield',
                iconVariant: 'error',
                cssClass: 'anomaly-badge badge-danger'
            });
        }

        return list;
    }

    get hasAnomalies() {
        return this.badges.length > 0;
    }

    get tierBadgeClass() {
        const tier = this.auditData?.verificationTier;
        if (tier === 'Verified') {
            return 'tier-badge tier-verified';
        } else if (tier === 'Coaching Needed') {
            return 'tier-badge tier-coaching';
        } else if (tier === 'Flagged for Investigation') {
            return 'tier-badge tier-flagged';
        }
        return 'tier-badge tier-neutral';
    }

    get tierBadgeIcon() {
        const tier = this.auditData?.verificationTier;
        if (tier === 'Verified') {
            return 'utility:success';
        } else if (tier === 'Coaching Needed') {
            return 'utility:warning';
        } else if (tier === 'Flagged for Investigation') {
            return 'utility:incident';
        }
        return 'utility:info';
    }

    get tierBadgeLabel() {
        const tier = this.auditData?.verificationTier;
        if (tier === 'Verified') {
            return this.labels.tierVerified;
        } else if (tier === 'Coaching Needed') {
            return this.labels.tierCoaching;
        } else if (tier === 'Flagged for Investigation') {
            return this.labels.tierFlagged;
        }
        return tier || '-';
    }

    get formattedTotalScore() {
        const score = this.auditData?.totalVisitScore;
        return score != null ? `${score} / 100` : '-';
    }

    get formattedTelemetryScore() {
        const score = this.auditData?.telemetryScore;
        return score != null ? `${score} / 50` : '-';
    }

    get fraudFlagReasons() {
        return this.auditData?.fraudFlagReasons || [];
    }

    get hasFraudReasons() {
        return this.fraudFlagReasons.length > 0;
    }

    get aiAuditSummary() {
        return this.auditData?.aiAuditSummary;
    }

    get hasAiSummary() {
        return !!this.aiAuditSummary;
    }

    get investigationStatusDisplay() {
        return this.auditData?.investigationStatus || '-';
    }

    get investigationNotesDisplay() {
        return this.auditData?.investigationNotes || this.labels.noInvestigationNotes;
    }

    get layoutGridClass() {
        return this.isManagerView ? 'audit-grid audit-grid_split' : 'audit-grid audit-grid_full';
    }

    get mapColumnClass() {
        return this.isManagerView ? 'map-column map-column_split' : 'map-column map-column_full';
    }
}