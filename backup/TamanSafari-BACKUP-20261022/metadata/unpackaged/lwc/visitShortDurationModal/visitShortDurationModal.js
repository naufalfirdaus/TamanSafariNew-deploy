import LightningModal from "lightning/modal";
import { api } from "lwc";
import labelTitle from "@salesforce/label/c.FV_Short_Visit_Title";
import labelBody from "@salesforce/label/c.FV_Short_Visit_Body";
import labelStay from "@salesforce/label/c.FV_Btn_Stay";
import labelConfirmEarly from "@salesforce/label/c.FV_Btn_Confirm_Early_Exit";

export default class VisitShortDurationModal extends LightningModal {
  @api elapsedMinutes = 0;
  @api minDurationMinutes = 10;

  labels = {
    title: labelTitle,
    body: labelBody,
    stay: labelStay,
    confirmEarly: labelConfirmEarly
  };

  get warningBodyText() {
    return this.labels.body
      .replace("{0}", this.elapsedMinutes || 0)
      .replace("{1}", this.minDurationMinutes || 10);
  }

  handleStay() {
    this.close({ confirmed: false });
  }

  handleConfirmEarly() {
    this.close({ confirmed: true });
  }
}