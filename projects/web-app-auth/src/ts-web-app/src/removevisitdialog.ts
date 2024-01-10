/**
 * File: removevisitdialog.ts
 * 
 * Description: 
 *  This file contains the Typescript code associated with the Remove Visit Dialog
 * 
 */
import { Dialog } from "./dialog";
import { APIClient } from "./apiclient";
import { LogClient } from "./logclient";

/**
 * IDialog
 */
export class RemoveVisitDialog extends Dialog {
  visitId = "";
  message = "";
  logClient: LogClient;
  apiClient: APIClient;
  static current?: RemoveVisitDialog;
  constructor(id: string, name: string, uri: string | null, content: string | null, okId: string, logClient: LogClient, apiClient: APIClient) {
    super(id, name, uri, content, okId);
    this.logClient = logClient;
    this.apiClient = apiClient;
    RemoveVisitDialog.current = this;
  }
  static createRemoveVisitDialog(id: string, name: string, uri: string | null, content: string | null, okId: string, logClient: LogClient, apiClient: APIClient): RemoveVisitDialog {
    return new RemoveVisitDialog(id, name, uri, content, okId, logClient, apiClient);
  }
  onUpdate?(update: boolean): void;


  registerEvents(): boolean {
    if (super.registerEvents)
      super.registerEvents();
    super.addEvent("removeOk", "click", RemoveVisitDialog.StaticOnOkCloseDialog);
    super.addEvent("removeCancel", "click", RemoveVisitDialog.StaticOnCancelCloseDialog);
    this.logClient.log("RemoveVisitDialog registerEvents");
    return true;
  }
  static StaticOnOkCloseDialog() {
    if (RemoveVisitDialog.current)
      RemoveVisitDialog.current.onOkCloseDialog("removeOk");
  }
  static StaticOnCancelCloseDialog() {
    if (RemoveVisitDialog.current)
      RemoveVisitDialog.current.onCancelCloseDialog("removeCancel");
  }
  unregisterEvents(): boolean {
    if (super.unregisterEvents)
      super.unregisterEvents();
    super.removeEvent("removeOk", "click", RemoveVisitDialog.StaticOnOkCloseDialog);
    super.removeEvent("removeCancel", "click", RemoveVisitDialog.StaticOnCancelCloseDialog);
    this.logClient.log("RemoveVisitDialog unregisterEvents");
    return true;
  }
  onInitializeDialog(): boolean {
    this.message = `Are you sure you want to remove visit ${this.visitId}?`;
    this.addHTMLValueMap([
      { id: "removeMessage", value: this.message, readonly: true },
    ]);

    return true;
  }
  async onOkCloseDialog(id: string) {
    try {
      const result = await this.DeleteAsync();
      if (result == true)
        this.endDialog(id);
    }
    catch (e) {
      return;
    }
  }
  onCancelCloseDialog(id: string) {
    try {
      this.endDialog(id);
    }
    catch (e) {
      return;
    }
  }
  DeleteAsync(): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      (async () => {
        try {
          const response: Response | null = await this.apiClient.DeleteVisit(this.visitId);
          if (response) {
            if (response.status == 200) {
              resolve(true);
              return;
            }
            else {
              const message = `Error while removing visit: response status ${response.status}`;
              this.setHTMLValueText("removeMessage", message);
              reject(message);
              return;
            }
          }
          else {
            const message = `Error while removing visit: response null`;
            this.setHTMLValueText("removeMessage", message);
            reject(message);
            return;
          }
        }
        catch (reason) {
          const message = `Exception while removing visit: ${reason}`;
          this.setHTMLValueText("removeMessage", message);
          reject(message);
          return;
        }
      })();
    });
  }
  onCancel(): void {
    return;
  }

}
