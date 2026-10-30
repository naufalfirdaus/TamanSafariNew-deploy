import { LightningElement } from 'lwc';
import validateCode from '@salesforce/apex/GuestRedeemVoucherController.validateCode';
import submitRedemption from '@salesforce/apex/GuestRedeemVoucherController.submitRedemption';

const PRODUCT_FAMILY_OPTIONS = [
    { label: 'Ticket & Voucher', value: 'Ticket & Voucher' },
    { label: 'Accommodation', value: 'Accommodation' },
    { label: 'Team Building', value: 'Team Building' },
    { label: 'Transport', value: 'Transport' },
    { label: 'F&B', value: 'F&B' },
    { label: 'Bundled Package', value: 'Bundled Package' }
];

export default class GuestRedeemVoucher extends LightningElement {
    step = 'code'; // code | detail | success | fail
    isLoading = false;
    errorMessage = '';
    successMessage = '';

    voucherCode = '';
    customerName = '';
    bookingNumber = '';
    productFamily = '';
    qty = 1;
    grossAmount;

    productFamilyOptions = PRODUCT_FAMILY_OPTIONS;

    get isCodeStep() {
        return this.step === 'code';
    }
    get isDetailStep() {
        return this.step === 'detail';
    }
    get isSuccessStep() {
        return this.step === 'success';
    }
    get isFailStep() {
        return this.step === 'fail';
    }

    handleCodeChange(event) {
        this.voucherCode = event.target.value;
    }
    handleCustomerNameChange(event) {
        this.customerName = event.target.value;
    }
    handleBookingNumberChange(event) {
        this.bookingNumber = event.target.value;
    }
    handleProductFamilyChange(event) {
        this.productFamily = event.target.value;
    }
    handleQtyChange(event) {
        this.qty = event.target.value;
    }
    handleGrossAmountChange(event) {
        this.grossAmount = event.target.value;
    }

    async handleCheckCode() {
        if (!this.voucherCode) {
            this.errorMessage = 'Masukkan kode voucher terlebih dahulu.';
            return;
        }
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const result = await validateCode({ voucherCode: this.voucherCode });
            if (result.valid) {
                this.step = 'detail';
            } else {
                this.errorMessage = result.message;
            }
        } catch (e) {
            this.errorMessage = 'Terjadi kesalahan. Coba lagi.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleSubmitRedemption() {
        if (!this.customerName || !this.bookingNumber || !this.productFamily || !this.qty || !this.grossAmount) {
            this.errorMessage = 'Semua field wajib diisi.';
            return;
        }
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const result = await submitRedemption({
                voucherCode: this.voucherCode,
                customerName: this.customerName,
                bookingNumber: this.bookingNumber,
                productFamily: this.productFamily,
                qty: this.qty,
                grossAmount: this.grossAmount
            });
            if (result.success) {
                this.successMessage = result.message;
                this.step = 'success';
            } else {
                this.errorMessage = result.message;
                this.step = 'fail';
            }
        } catch (e) {
            this.errorMessage = 'Terjadi kesalahan saat memproses redemption.';
            this.step = 'fail';
        } finally {
            this.isLoading = false;
        }
    }

    handleRestart() {
        this.step = 'code';
        this.voucherCode = '';
        this.customerName = '';
        this.bookingNumber = '';
        this.productFamily = '';
        this.qty = 1;
        this.grossAmount = undefined;
        this.errorMessage = '';
        this.successMessage = '';
    }
}