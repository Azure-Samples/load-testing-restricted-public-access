/**
 * File: addvisitdialog.ts
 * 
 * Description: 
 *  This file contains the Typescript code associated with the Add Visit Dialog
 * 
 */
import { Dialog } from "./dialog";
import { APIClient, Visit, Error, ErrorCode, getTimeString } from "./apiclient";
import { isNullOrUndefinedOrEmpty, isNullOrUndefined } from "./common";
import { StorageClient } from "./storage";
import { LogClient } from './logclient';
/**
 * IDialog
 */
export class AddVisitDialog extends Dialog {
  visitId = "";
  visitRecord: Visit = new Visit();
  visitFolder = "";
  visitExtensions: Array<string> = [];
  message = "";
  arrayMandatoryField = [
    "addVisitUser",
    "addVisitInformation"];

  apiClient: APIClient;
  storageClient: StorageClient;
  logClient: LogClient;
  static current?: AddVisitDialog;
  constructor(id: string, name: string, uri: string | null, content: string | null, okId: string, apiClient: APIClient, storageClient: StorageClient, logClient: LogClient) {
    super(id, name, uri, content, okId);
    this.apiClient = apiClient;
    this.storageClient = storageClient;
    this.logClient = logClient;
    AddVisitDialog.current = this;
  }
  static createAddVisitDialog(id: string, name: string, uri: string | null, content: string | null, okId: string, apiClient: APIClient, storageClient: StorageClient, logClient: LogClient): AddVisitDialog {
    return new AddVisitDialog(id, name, uri, content, okId, apiClient, storageClient, logClient);
  }
  onUpdate?(update: boolean): void;



  updateModalControls(okId: string): void {
    let valid = true;

    for (let i = 0; i < this.arrayMandatoryField.length; i++) {
      const text = this.getHTMLValueText(this.arrayMandatoryField[i]);
      if (isNullOrUndefinedOrEmpty(text)) {
        valid = false;
        break;
      }
    }

    const ok = (<HTMLButtonElement>document.getElementById(okId));
    if (ok) {
      if (valid == true) {
        const message = `Are you sure you want to add visit ${this.visitId}?`;
        this.setHTMLValueText("addMessage", message);
        ok.disabled = false;
      }
      else {
        const message = "";
        this.setHTMLValueText("addMessage", message);
        ok.disabled = true;
      }
    }
    else {
      this.logClient.error(`Resource Id: ${okId} not found`)
    }
  }

  clearInputs(selectId: string): void {
    if (isNullOrUndefined((<HTMLInputElement>document.getElementById(selectId)).files) === false)
      (<HTMLInputElement>document.getElementById(selectId)).value = "";
  }

  logMessage(message: string): void {
    this.logClient.log(message);
    this.setHTMLValueText("addMessage", message);
  }
  logError(message: string): void {
    this.logClient.error(message);
    this.setHTMLValueText("addError", message);
  }
  clearResultAndError() {
    this.setHTMLValueText("addMessage", "");
    this.setHTMLValueText("addError", "");
  }

  valueUpdated() {
    this.updateData(true);
    this.updateModalControls("addOk");
  }
  static StaticOnOkCloseDialog() {
    if (AddVisitDialog.current)
      AddVisitDialog.current.onOkCloseDialog("addOk");
  }
  static StaticOnCancelCloseDialog() {
    if (AddVisitDialog.current)
      AddVisitDialog.current.onCancelCloseDialog("addCancel");
  }


  static StaticValueUpdated() {
    if (AddVisitDialog.current)
      AddVisitDialog.current.valueUpdated();
  }

  registerEvents(): boolean {
    if (super.registerEvents)
      super.registerEvents();
    super.addEvent("addOk", "click", AddVisitDialog.StaticOnOkCloseDialog);
    super.addEvent("addCancel", "click", AddVisitDialog.StaticOnCancelCloseDialog);
    super.addEvent("addVisitUser", "change", AddVisitDialog.StaticValueUpdated);
    super.addEvent("addVisitInformation", "change", AddVisitDialog.StaticValueUpdated);

    return true;
  }
  unregisterEvents(): boolean {
    if (super.unregisterEvents)
      super.unregisterEvents();
    super.removeEvent("addOk", "click", AddVisitDialog.StaticOnOkCloseDialog);
    super.removeEvent("addCancel", "click", AddVisitDialog.StaticOnCancelCloseDialog);
    super.removeEvent("addVisitUser", "change", AddVisitDialog.StaticValueUpdated);
    super.removeEvent("addVisitInformation", "change", AddVisitDialog.StaticValueUpdated);

    return true;
  }
  setVisitRecord() {
    this.visitRecord.id = this.getHTMLValue("addVisitId").value.toString();
    this.visitRecord.user = this.getHTMLValue("addVisitUser").value.toString();
    this.visitRecord.information = this.getHTMLValue("addVisitInformation").value.toString();
    
  }
  onInitializeDialog(): boolean {
    this.message = "";
    this.visitRecord.id = this.visitId;
    this.addHTMLValueMap([
      { id: "addMessage", value: this.message, readonly: true },
      { id: "addVisitUser", value: this.visitRecord.user, readonly: false },
      { id: "addVisitInformation", value: this.visitRecord.information, readonly: false },
    ]);
    this.updateData(false);


    this.updateModalControls("addOk");
    this.updateData(false);
    this.clearResultAndError();
    this.updateModalControls("addOk");

    return true;
  }
  onCancelCloseDialog(id: string) {
    try {
      this.endDialog(id);
    }
    catch (e) {
      return;
    }
  }
  async onOkCloseDialog(id: string) {
    try {
      // Read values from the Web UI
      this.updateData(true);

      for (let i = 0; i < this.arrayMandatoryField.length; i++) {
        const text = this.getHTMLValueText(this.arrayMandatoryField[i]);
        if (isNullOrUndefinedOrEmpty(text)) {
          const message = "Visit creation failed: not all mandatory fields are set";
          this.setHTMLValueText("addMessage", message);
          return;
        }
      }
      this.setVisitRecord();
      const result = await this.AddAsync();
      if (result == true)
        this.endDialog(id);

    }
    catch (e) {
      const message = `Exception while creating Visit ${e}`;
      this.setHTMLValueText("addMessage", message);
    }
  }
  AddAsync(): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      (async () => {
        try {
          const response: Response | null = await this.apiClient.CreateVisit(this.visitId,
            {
              user: this.visitRecord.user,
              information: this.visitRecord.information,              
            }
          );
          if (response) {
            if (response.status == 201) {
              const message = `Visit: ${this.visitRecord.user} successfully added`;
              this.setHTMLValueText("addMessage", message);
              resolve(true);
              return;
            }
            else {
              const message = `Error while adding Visit: response status ${response.status}`;
              this.setHTMLValueText("addMessage", message);
              reject(message);
              return;
            }
          }
          else {
            const message = `Error while adding Visit: response null`;
            this.setHTMLValueText("addMessage", message);
            reject(message);
            return;
          }
        }
        catch (reason) {
          const message = `Exception while adding Visit: ${reason}`;
          this.setHTMLValueText("addMessage", message);
          reject(message);
          return;
        }
      })();
    });
  }
  onCancel(): boolean {
    return true;
  }

}
