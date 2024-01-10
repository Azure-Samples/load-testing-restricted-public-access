/**
 * File: visit.ts
 * 
 * Description: 
 *  This file contains the implementation of Visit page.
 * 
 */

import './globalconfig';
import './globalclient';
import { LogClient } from './logclient';
import { StorageClient } from './storage';
import { APIClient, Visit } from './apiclient';
import { AzureADClient } from './azuread';
import { Page } from "./page";
import { AddVisitDialog } from './addvisitdialog';
import { UpdateVisitDialog } from './updatevisitdialog';
import { RemoveVisitDialog } from './removevisitdialog';
import { Table } from './table';
import { PageWaiting, Alert } from './notificationclient';

class VisitPage extends Page {
  version: string;
  visitId: string;
  logClient: LogClient;
  adClient: AzureADClient;
  storageClient: StorageClient;
  apiClient: APIClient;
  removeVisitDlg?: RemoveVisitDialog;
  addVisitDlg?: AddVisitDialog;
  updateVisitDlg?: UpdateVisitDialog;
  table?: Table;
  static current?: VisitPage;
  constructor(id: string,
    name: string,
    uri: string | null,
    content: string | null,
    version: string,
    logClient: LogClient,
    adClient: AzureADClient,
    storageClient: StorageClient,
    apiClient: APIClient
  ) {
    super(id, name, uri, content);
    this.version = version;
    this.visitId = "";
    this.logClient = logClient;
    this.adClient = adClient;
    this.storageClient = storageClient;
    this.apiClient = apiClient;
    VisitPage.current = this;
  }


  logMessage(message: string) {
    this.logClient.log(message);
    this.setHTMLValueText("visitMessage", message);
  }
  logError(message: string) {
    this.logClient.error(message);
    this.setHTMLValueText("visitError", message);
  }
  getListVisit() {
    return new Promise<number>((resolve: (value: number | PromiseLike<number>) => void, reject: (reason?: any) => void) => {
      (async () => {
        try {
          if (this.apiClient) {
            console.log("Calling GetVisits")
            const response: Response | null = await this.apiClient.GetVisits();
            if (response) {
              if (response.status == 200) {
                let count = 0;
                const payload: Array<Visit> = await response.json() as Array<Visit>;
                if (payload) {
                  count = payload.length;
                  // Fill table
                  this.fillTable(payload);
                }
                resolve(count);
              }
              else {
                const error = "Error while calling GetVisits: response.status != 200";
                this.logError(error);
                reject(error);
              }
            }
            else {
              const error = "Error while calling GetVisits: response null";
              this.logError(error);
              reject(error);
            }
          }
          else {
            const error = "Internal Error apiclient null";
            this.logError(error);
            reject(error);
          }
        }
        catch (e) {
          const error = `Exception while calling GetVisits: ${e}`;
          this.logError(error);
          reject(error);
        }
        return true;
      })();
    });
  }
  newGuid(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      const r = Math.random() * 16 | 0,
        v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }
  formatDatetime(date: Date, format: string) {
    const _padStart = (value: number): string => value.toString().padStart(2, '0');
    return format
      .replace("yyyy", _padStart(date.getFullYear()))
      .replace("dd", _padStart(date.getDate()))
      .replace("mm", _padStart(date.getMonth() + 1))
      .replace("hh", _padStart(date.getHours()))
      .replace("ii", _padStart(date.getMinutes()))
      .replace("ss", _padStart(date.getSeconds()));
  }
  getFolder(format: string, visitid: string) {
    const account = this.adClient.getAccount();
    let user = "unknown";
    if (account)
      user = account.username
    // Add "/" add the end of format string
    if (!format.endsWith("/"))
      format += "/";
    return format.replace("{visit-id}", visitid)
      .replace("{date}", this.formatDatetime(new Date(Date.now()), "yyyy-mm-dd"))
      .replace("{time}", this.formatDatetime(new Date(Date.now()), "yyyy-mm-ddThh:ii:ss"))
      .replace("{user}", user)
      .replace("{random-id}", this.newGuid())
  }
  getNewVisitId(): Promise<string | null> {
    return new Promise<string | null>((resolve, reject) => {
      (async () => {
        // Create new Guid
        const id = this.newGuid();
        // Check if the new Guid is not used in the database
        try {
          const response = await this.apiClient.GetVisit(id);
          if (response) {
            if (response.status == 404) {
              // New Guid ok
              resolve(id);
            }
            else if (response.status == 200) {
              resolve(null);
            }
            reject(`Visit API return status code: ${response.status}`);
          }
          else
            reject("Visit API return null response");
        }
        catch (e) {
          reject(e);
        }
      })();
    });
  }
  // Callback after successful visit deletion
  // Reload page
  removeVisitok() {
    this.initializePage();
  }
  // Callback after successful visit creation
  // Reload page
  addVisitok() {
    this.initializePage();
  }
  createAddVisitDialog(): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      (async () => {
        try {
          const id = await this.getNewVisitId();
          if (id)
            this.visitId = id;
        }
        catch (e) {
          this.logClient.error(e);
          reject(e);
          return;
        }
        this.updateData(true);
        if (!this.addVisitDlg)
          this.addVisitDlg = new AddVisitDialog("addVisitModal", "AddVisit", null, null, "addOk", this.apiClient, this.storageClient, this.logClient);
        if (this.addVisitDlg) {
          this.addVisitDlg.visitId = this.visitId;
          this.addVisitDlg.initializeDialog();
          this.addVisitDlg.showDialog(() => { this.initializePage(); this.logClient.log("End dialog AddVisitDialog") });
        }
        resolve(true);
        return;
      })();
    });
  }
  createRemoveVisitDialog() {
    this.updateData(true);
    if (!this.removeVisitDlg)
      this.removeVisitDlg = new RemoveVisitDialog("removeVisitModal", "RemoveVisit", null, null, "removeOk", this.logClient, this.apiClient);
    if (this.removeVisitDlg) {
      this.removeVisitDlg.visitId = this.getSelectedRecordId();
      this.removeVisitDlg.initializeDialog();
      this.removeVisitDlg.showDialog(() => { this.initializePage(); this.logClient.log("End dialog RemoveVisitDialog") });
    }
  }
  createUpdateVisitDialog() {
    this.updateData(true);
    if (!this.updateVisitDlg)
      this.updateVisitDlg = new UpdateVisitDialog("updateVisitModal", "UpdateVisit", null, null, "updateOk", this.apiClient, this.storageClient, this.logClient);
    if (this.updateVisitDlg) {
      this.visitId = this.getSelectedRecordId();
      this.updateVisitDlg.visitId = this.visitId;
      this.updateVisitDlg.selectedRecord = this.getSelectedRecord();
      this.updateVisitDlg.initializeDialog();
      this.updateVisitDlg.showDialog(() => { this.initializePage(); this.logClient.log("End dialog UpdateVisitDialog") });
    }
    return;
  }

  static StaticCreateAddVisitDialog() {
    if (VisitPage.current)
      VisitPage.current.createAddVisitDialog();
  }
  static StaticCreateUpdateVisitDialog() {
    if (VisitPage.current)
      VisitPage.current.createUpdateVisitDialog();
  }
  static StaticCreateRemoveVisitDialog() {
    if (VisitPage.current)
      VisitPage.current.createRemoveVisitDialog();
  }
  registerEvents(): boolean {
    this.logClient.log("VisitPage registerEvents");

    super.addEvent("addVisit", "click", VisitPage.StaticCreateAddVisitDialog);
    super.addEvent("updateVisit", "click", VisitPage.StaticCreateUpdateVisitDialog);
    super.addEvent("removeVisit", "click", VisitPage.StaticCreateRemoveVisitDialog);

    return true;
  }

  unregisterEvents(): boolean {
    this.logClient.log("VisitPage unregisterEvents");

    super.removeEvent("addVisit", "click", VisitPage.StaticCreateAddVisitDialog);
    super.removeEvent("updateVisit", "click", VisitPage.StaticCreateUpdateVisitDialog);
    super.removeEvent("removeVisit", "click", VisitPage.StaticCreateRemoveVisitDialog);

    return true;
  }

  /*
  Table Management
  */
  fillTable(payload: any) {

    this.table?.fillTable(payload);
    this.table?.selectRow('id', this.visitId);
  }
  createTable() {
    const array: Array<Array<string>> = [
      ["id", "Id"],
      ["user", "user"],
      ["information", "information"],
      ["creationDate", "creationDate"],
      ["localIp", "localIp"],
      ["localPort", "localPort"],
      ["remoteIp", "remoteIp"],
      ["remotePort", "remotePort"],
    ]
    if (this.table == null) {
      const columns =
        [{
          title: '',
          field: ''
        }];
      for (let i = 0; i < array.length; i++) {
        columns.push({
          title: globalThis.globalVars.getCurrentString(array[i][1]),
          field: array[i][0]
        });
      }
      this.table = new Table('visitTableId');
      this.table?.createTable(columns, globalThis.globalVars.getGlobalPageSize(), 'id', ["removeVisit", "updateVisit"]);
    }
  }
  getSelectedRecord(): any {
    return this.table?.getSelection()[0];
  }

  getSelectedRecordId(): string {
    const array = this.table?.getSelection();
    if ((array) && (array.length)) {
      return array[0].id;
    }
    return "";
  }
  getSelectedName(): string {
    const array = this.table?.getSelection();
    if ((array) && (array.length)) {
      return array[0].name;
    }
    return "";
  }

  selectedId(id: string): boolean {
    if (this.table)
      return this.table?.selectRow('id', id);
    return false;
  }




  onInitializePage(): boolean {
    const waiting = new PageWaiting("visitWaiting");
    waiting.show(globalThis.globalVars.getCurrentString("Loading visit records"));
    this.addHTMLValueMap([
      { id: "versionButton", value: this.version, readonly: true },
      { id: "addVisit", value: globalThis.globalVars.getCurrentString("Add"), readonly: true },
      { id: "updateVisit", value: globalThis.globalVars.getCurrentString("Update"), readonly: true },
      { id: "removeVisit", value: globalThis.globalVars.getCurrentString("Remove"), readonly: true },
      { id: "VisitPageVersion", value: globalThis.globalVars.getCurrentString("Version:"), readonly: true },
      { id: "VisitPageTitle", value: globalThis.globalVars.getCurrentString("Visit Page"), readonly: true },
    ]);
    this.updateData(false);
    // Initialize Page  
    this.createTable();
    this.getListVisit()
      .then((count) => {
        this.logMessage(`${count} record(s) in Visit table`);
      })
      .catch((e) => {
        this.logError(`Error while loading page: ${e}`);
      })
      .finally(() => {
        waiting.hide();
      });

    return true;
  }
}



const localPage = new VisitPage("content", "Visit", "visit.html", null,
  globalThis.globalConfiguration.version,
  globalThis.globalClient.getLogClient(),
  globalThis.globalClient.getAzureADClient(),
  globalThis.globalClient.getStorageClient(),
  globalThis.globalClient.getAPIClient(),
);
if (localPage) {
  localPage.initializePage();
}

