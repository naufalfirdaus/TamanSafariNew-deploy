import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import gelocation_Controller from '@salesforce/apex/Geolocation_Controller.GeoapifyReverse';
import CheckIn_Controller from '@salesforce/apex/Geolocation_Controller.CreateEventCheckIn';

export default class SalesforceMaps extends NavigationMixin(LightningElement) {

    // ===== PUBLIC (Record Page config) =====
    @api recordId;
    @api objectApiName;
    @api showMap = false;     // default record page
    @api zoomLevel = 15;
    @api showErrors = false;

    @track markers = [];

    latitude;
    longitude;

    locationFetched = false;
    isCommunity = false;

    // =========================
    // CONTEXT RESOLVER (FIXED)
    // =========================
    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (!pageRef) return;

        const context = this.resolveContext(pageRef);

        this.recordId = context.recordId;
        this.objectApiName = context.objectApiName;
        this.isCommunity = context.isCommunity;

        // ===== FIX showMap logic =====
        if (this.isCommunity) {
            if (context.showMap !== undefined) {
                this.showMap = context.showMap;   // dari URL
            } else {
                this.showMap = true;              // default community = ON
            }
        }

        console.log('Context:', JSON.stringify(context));
    }

    resolveContext(pageRef) {
        const path = window.location.pathname;

        return {
            recordId:
                pageRef?.attributes?.recordId ||     // /s/detail/:id
                pageRef?.state?.recordId ||          // ?recordId=
                this.extractFromPath(path),          // fallback

            objectApiName:
                pageRef?.attributes?.objectApiName || null,

            // hanya set jika ada di URL
            showMap:
                pageRef?.state?.showMap !== undefined
                    ? pageRef.state.showMap === 'true'
                    : undefined,

            isCommunity: path.includes('/s/')
        };
    }

    extractFromPath(path) {
        const match = path.match(/\/detail\/([a-zA-Z0-9]{15,18})/);
        return match ? match[1] : null;
    }

    // =========================
    // GEOLOCATION
    // =========================
    renderedCallback() {
        if (this.locationFetched) return;
        this.locationFetched = true;

        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                this.success.bind(this),
                this.problem.bind(this),
                { enableHighAccuracy: true, timeout: 5000 }
            );
        } else {
            this.showError('Geolocation tidak didukung.');
        }
    }

    success(position) {
        this.latitude = position.coords.latitude;
        this.longitude = position.coords.longitude;

        if (this.showMap) {
            this.markers = [{
                location: {
                    Latitude: this.latitude,
                    Longitude: this.longitude
                }
            }];
        }
    }

    problem(error) {
        console.error(error);
        if (this.showErrors) {
            this.showError(`Error ${error.code}: ${error.message}`);
        }
    }

    // =========================
    // CHECK-IN
    // =========================
    handleCheckIn() {

        if (!this.latitude || !this.longitude) {
            this.showError('Lokasi belum tersedia');
            return;
        }

        if (!this.recordId) {
            this.showError('RecordId tidak ditemukan');
            return;
        }

        gelocation_Controller({
            latitude: this.latitude,
            longitude: this.longitude
        })
        .then(address => {
            this.showSuccess('Check In Success', address);

            return CheckIn_Controller({
                latitude: this.latitude,
                longitude: this.longitude,
                RecordID: this.recordId,
                Address: address,
                ObjectName: this.objectApiName
            });
        })
        .then(() => {
            // FIX: jangan redirect ke Event
            this.navigateToRecord(this.recordId);
        })
        .catch(err => {
            console.error(err);
            this.showError('Check-in gagal');
        });
    }

    // =========================
    // NAVIGATION
    // =========================
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `${recordId}`
            }
        });
    }

    // =========================
    // TOAST
    // =========================
    showError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message,
            variant: 'error'
        }));
    }

    showSuccess(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant: 'success'
        }));
    }
}