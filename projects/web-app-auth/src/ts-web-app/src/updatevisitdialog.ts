/**
 * File: updatevisitdialog.ts
 * 
 * Description: 
 *  This file contains the Typescript code associated with the Update Visit Dialog
 * 
 */
import { Dialog } from "./dialog";
import { APIClient, Visit,  getTimeString, ErrorCode, Error } from "./apiclient";
import { isNullOrUndefinedOrEmpty } from "./common";
import { StorageClient } from "./storage";
import { LogClient } from './logclient';

/**
 * IDialog
 */
export class UpdateVisitDialog extends Dialog {
  visitId = "";
  visitName = "";
  visitExtensions: Array<string> = [];
  message = "";
  selectedRecord: Visit = new Visit();
  visitRecord: Visit = new Visit();
  arrayMandatoryField = [
    "updateVisitUser",
    "updateVisitInformation"];
  apiClient: APIClient;
  storageClient: StorageClient;
  logClient: LogClient;
  static current?: UpdateVisitDialog;
  constructor(id: string, name: string, uri: string | null, content: string | null, okId: string, apiClient: APIClient, storageClient: StorageClient, logClient: LogClient) {
    super(id, name, uri, content, okId);
    this.apiClient = apiClient;
    this.storageClient = storageClient;
    this.logClient = logClient;
    UpdateVisitDialog.current = this;
  }
  static createUpdateVisitDialog(id: string, name: string, uri: string | null, content: string | null, okId: string, apiClient: APIClient, storageClient: StorageClient, logClient: LogClient): UpdateVisitDialog {
    return new UpdateVisitDialog(id, name, uri, content, okId, apiClient, storageClient, logClient);
  }
  onUpdate?(update: boolean): void;
  logError(message: string): void {
    console.log(message);
    this.setHTMLValueText("updateMessage", message);

  }
  getOldValueText(id: string): string | null {
    switch (id) {
      case "updateVisitId":
        return this.selectedRecord.id;
        break;
      case "updateVisitUser":
        return this.selectedRecord.user;
        break;
      case "updateVisitInformation":
        return this.selectedRecord.information;
        break;
    }
    return "";
  }
  updateModalControls(okId: string): void {
    let update = false;

    for (let i = 0; i < this.arrayMandatoryField.length; i++) {
      const text = this.getHTMLValueText(this.arrayMandatoryField[i]);
      if (!isNullOrUndefinedOrEmpty(text)) {
        const oldtext = this.getOldValueText(this.arrayMandatoryField[i]);
        if (oldtext != text) {
          update = true;
          break;
        }
      }
    }

    const ok = (<HTMLButtonElement>document.getElementById(okId));
    if (ok) {
      if (update == true) {
        const message = `Are you sure you want to update visit ${this.visitId}?`;
        this.setHTMLValueText("updateMessage", message);
        ok.disabled = false;
      }
      else {
        const message = "";
        this.setHTMLValueText("updateMessage", message);
        ok.disabled = true;
      }
    }
    else {
      this.logClient.error(`Resource Id: ${okId} not found`)
    }
  }



  logMessage(message: string): void {
    this.logClient.log(message);
    this.setHTMLValueText("updateMessage", message);
  }

  clearResultAndError() {
    this.setHTMLValueText("updateMessage", "");
    this.setHTMLValueText("updateError", "");
  }



  valueUpdated() {
    this.updateData(true);
    this.updateModalControls("updateOk");
  }
  static StaticOnOkCloseDialog() {
    if (UpdateVisitDialog.current)
      UpdateVisitDialog.current.onOkCloseDialog("updateOk");
  }
  static StaticOnCancelCloseDialog() {
    if (UpdateVisitDialog.current)
      UpdateVisitDialog.current.onCancelCloseDialog("updateCancel");
  }
  static StaticValueUpdated() {
    if (UpdateVisitDialog.current)
      UpdateVisitDialog.current.valueUpdated();
  }
  registerEvents(): boolean {
    if (super.registerEvents)
      super.registerEvents();
    super.addEvent("updateOk", "click", UpdateVisitDialog.StaticOnOkCloseDialog);
    super.addEvent("updateCancel", "click", UpdateVisitDialog.StaticOnCancelCloseDialog);
    super.addEvent("updateVisitUser", "change", UpdateVisitDialog.StaticValueUpdated);
    super.addEvent("updateVisitInformation", "change", UpdateVisitDialog.StaticValueUpdated);

    return true;
  }
  unregisterEvents(): boolean {
    if (super.unregisterEvents)
      super.unregisterEvents();
    super.removeEvent("updateOk", "click", UpdateVisitDialog.StaticOnOkCloseDialog);
    super.removeEvent("updateCancel", "click", UpdateVisitDialog.StaticOnCancelCloseDialog);
    super.removeEvent("updateVisitUser", "change", UpdateVisitDialog.StaticValueUpdated);
    super.removeEvent("updateVisitInformation", "change", UpdateVisitDialog.StaticValueUpdated);
    return true;
  }
  onInitializeDialog(): boolean {
    this.message = "";
    this.addHTMLValueMap([
      { id: "updateMessage", value: this.message, readonly: true },
      { id: "updateVisitId", value: this.selectedRecord.id, readonly: false },
      { id: "updateVisitUser", value: this.selectedRecord.user, readonly: false },
      { id: "updateVisitInformation", value: this.selectedRecord.information, readonly: false },
      { id: "updateVisitLocalIp", value: this.selectedRecord.localIp, readonly: true },
      { id: "updateVisitLocalPort", value: this.selectedRecord.localPort, readonly: true },
      { id: "updateVisitRemoteIp", value: this.selectedRecord.remoteIp, readonly: true },
      { id: "updateVisitRemotePort", value: this.selectedRecord.remotePort, readonly: true },
    ]);

    this.updateData(false);
    this.updateModalControls("updateOk");
    this.updateData(false);
    this.clearResultAndError();
    this.updateModalControls("updateOk");

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
  setVisitRecord() {
    this.visitRecord.id = this.getHTMLValue("updateVisitId").value.toString();
    this.visitRecord.user = this.getHTMLValue("updateVisitUser").value.toString();
    this.visitRecord.information = this.getHTMLValue("updateVisitInformation").value.toString();
    this.visitRecord.localIp = this.selectedRecord.localIp;
    this.visitRecord.localPort = this.selectedRecord.localPort;
    this.visitRecord.remoteIp = this.selectedRecord.remoteIp;
    this.visitRecord.remotePort = this.selectedRecord.remotePort;
    
  }
  async onOkCloseDialog(id: string) {
    try {
      // Read values from the Web UI
      this.updateData(true);
      for (let i = 0; i < this.arrayMandatoryField.length; i++) {
        const text = this.getHTMLValueText(this.arrayMandatoryField[i]);
        if (isNullOrUndefinedOrEmpty(text)) {
          const message = "Visit update failed: not all mandatory fields are set";
          this.setHTMLValueText("updateMessage", message);
          return;
        }
      }
      this.setVisitRecord();

      const result = await this.updateAsync();
      if (result == true)
        this.endDialog(id);
    }
    catch (e) {
      const message = `Exception while creating Visit ${e}`;
      this.setHTMLValueText("updateMessage", message);
    }
  }

  updateAsync(): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      (async () => {
        try {
          const response: Response | null = await this.apiClient.UpdateVisit(this.visitId,
            {
              id: this.visitId,
              user: this.visitRecord.user,
              information: this.visitRecord.information,
              locapIp: this.visitRecord.localIp,
              locapPort: this.visitRecord.localPort,
              remoteIp: this.visitRecord.remoteIp,
              remotePort: this.visitRecord.remotePort
            }
          );
          if (response) {
            if (response.status == 200) {
              const message = `Visit: ${this.visitName} successfully updated`;
              this.setHTMLValueText("updateMessage", message);
              resolve(true);
              return;
            }
            else {
              const message = `Error while updating visit: response status ${response.status}`;
              this.setHTMLValueText("updateMessage", message);
              reject(message);
              return;
            }
          }
          else {
            const message = `Error while updating visit: response null`;
            this.setHTMLValueText("updateMessage", message);
            reject(message);
            return;
          }
        }
        catch (reason) {
          const message = `Exception while updating visit: ${reason}`;
          this.setHTMLValueText("updateMessage", message);
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
