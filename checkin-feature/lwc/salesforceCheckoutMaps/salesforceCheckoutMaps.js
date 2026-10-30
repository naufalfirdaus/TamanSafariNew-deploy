import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';

import GeoapifyReverse from '@salesforce/apex/Geolocation_Controller.GeoapifyReverse';
import CheckOut_Controller from '@salesforce/apex/Geolocation_Controller.CreateEventCheckOut';
import validateCheckOut from '@salesforce/apex/Geolocation_Controller.ValidateCheckOut';

export default class CheckOutLocation extends LightningElement {

    @api latitude;
    @api longitude;
    @api zoomLevel = 15;
    @api showErrors = false;
    @api showMap = false;
    @api recordId;

    @track markers = [];

    locationFetched = false;
    isCommunity = false;

    // =========================
    // CONTEXT HANDLER
    // =========================
    @wire(CurrentPageReference)
    getPageRef(pageRef) {
        if (!pageRef) return;

        const path = window.location.pathname;

        this.isCommunity = path.includes('/s/');

        // ambil recordId dari semua kemungkinan
        this.recordId =
            pageRef?.attributes?.recordId ||
            pageRef?.state?.recordId ||
            this.extractFromPath(path) ||
            this.recordId;

        // showMap logic (FIX)
        if (this.isCommunity) {
            this.showMap = true;
        }
    }

    extractFromPath(path) {
        const match = path.match(/\/detail\/([a-zA-Z0-9]{15,18})/);
        return match ? match[1] : null;
    }

    // =========================
    // GEOLOCATION (FIX LOOP)
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
            this.showError('Geolocation tidak didukung');
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
    // CHECK OUT
    // =========================
    CheckOut() {

        if (!this.recordId) {
            this.showError('RecordId tidak ditemukan');
            return;
        }

        validateCheckOut({ EventID: this.recordId })
        .then(parms => {

            if (parms === 'Update') {

                return GeoapifyReverse({
                    latitude: this.latitude,
                    longitude: this.longitude
                });

            } else {
                throw new Error('ALREADY_CHECKOUT');
            }

        })
        .then(address => {

            return CheckOut_Controller({
                latitude: this.latitude,
                longitude: this.longitude,
                EventID: this.recordId,
                Address: address
            })
            .then(() => address);

        })
        .then(address => {

            this.showSuccess('Check Out Success', 'Location ' + address);

        })
        .catch(error => {

            if (error.message === 'ALREADY_CHECKOUT') {
                this.showWarning('You already check out');
            } else {
                console.error(error);
                this.showError('Check Out gagal');
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

    showWarning(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Warning',
            message,
            variant: 'warning'
        }));
    }
}