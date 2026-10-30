import LightningModal from "lightning/modal";
import { api, track } from "lwc";
import quickCreateContact from "@salesforce/apex/VisitController.quickCreateContact";
import labelCancel from "@salesforce/label/c.FV_Btn_Cancel";
import labelSave from "@salesforce/label/c.FV_Btn_Save";
import labelContactRequired from "@salesforce/label/c.Visit_Err_Contact_Required";

export default class VisitContactCreateModal extends LightningModal {
  @api accountId;

  @track name = "";
  @track mobile = "";
  @track email = "";
  @track department = "";
  @track role = "";
  @track error = "";
  @track isLoading = false;

  labels = {
    cancel: labelCancel,
    save: labelSave,
    requiredError: labelContactRequired
  };

  get isSaveDisabled() {
    return this.isLoading || !this.name.trim() || !this.mobile.trim();
  }

  handleNameChange(event) {
    this.name = event.target.value;
    this.error = "";
  }

  handleMobileChange(event) {
    this.mobile = event.target.value;
    this.error = "";
  }

  handleEmailChange(event) {
    this.email = event.target.value;
  }

  handleDepartmentChange(event) {
    this.department = event.target.value;
  }

  handleRoleChange(event) {
    this.role = event.target.value;
  }

  handleCancel() {
    this.close({ confirmed: false });
  }

  async handleSave() {
    if (!this.name.trim() || !this.mobile.trim()) {
      this.error = this.labels.requiredError;
      return;
    }

    this.isLoading = true;
    this.error = "";

    try {
      const payload = {
        name: this.name.trim(),
        mobile: this.mobile.trim(),
        email: this.email.trim(),
        department: this.department.trim(),
        role: this.role.trim()
      };

      const contactId = await quickCreateContact({
        accountId: this.accountId,
        contactJson: JSON.stringify(payload)
      });

      this.close({
        confirmed: true,
        contactId,
        contact: {
          id: contactId,
          name: this.name.trim(),
          mobilePhone: this.mobile.trim(),
          title: this.role.trim() || this.department.trim(),
          email: this.email.trim()
        }
      });
    } catch (err) {
      this.error = err?.body?.message || err?.message || "Gagal membuat kontak.";
    } finally {
      this.isLoading = false;
    }
  }
}