/**
 * File: apiclient.ts
 * 
 * Description: 
 *  This file contains the calls to the REST API used to managed Visit.
 * 
 */

import { isNullOrUndefinedOrEmpty } from "./common";
import { AzureADClient } from "./azuread";
import { LogClient } from "./logclient";

export function getTimeString(d: Date): string{
  // Expected format: 2022-05-19T23:15:17.0243482Z
  return d.getUTCFullYear() + "-" + (d.getUTCMonth()+1) + "-" + d.getUTCDate() + "T" + d.getUTCHours() + ":" + d.getUTCMinutes() + ":" + d.getUTCSeconds + "." + d.getUTCMilliseconds() + "00000Z";
}

export enum ErrorCode {
  NoError = 0,
  Exception,
}

export class Error {
  code = ErrorCode.NoError;
  message: string | null = "";
  source: string | null = "";
  creationDate = "";
}


export class Visit {
  id = "";
  user = "";
  information = "";
  localIp = "";
  localPort = 0;
  remoteIp = "";
  remotePort = 0;
  creationDate = "";
}

export class APIClient {
  adClient: AzureADClient;
  logClient: LogClient;
  endpointUri: string;
  redirectUri: string;
  authorizationDisabled: boolean;
  constructor(logClient: LogClient, adClient: AzureADClient, endpointUri: string, redirectUri: string, authorizationDisabled: boolean = false) {
    this.logClient = logClient;
    this.adClient = adClient;
    this.endpointUri = endpointUri;
    this.redirectUri = redirectUri;
    this.authorizationDisabled = authorizationDisabled
  }
  protected callAPIAsync(method: string, endpoint: string, token: string, payload: string | null): Promise<Response> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {
          const headers = new Headers();
          const bearer = `Bearer ${token}`;
          if(this.authorizationDisabled == false)
            headers.append("Authorization", bearer);
          if (!isNullOrUndefinedOrEmpty(this.redirectUri)) {
            let url = this.redirectUri;
            const last = url.charAt(url.length - 1);
            if (last == '/') {
              url = url.substring(0, url.length - 1);
            }
            headers.append("Access-Control-Allow-Origin", url);
          }
          headers.append("Content-Type", "application/json");

          let options;
          if (method == "GET") {
            options = {
              method: method,
              headers: headers,
            };
          }
          else if (method == "POST") {
            options = {
              method: method,
              headers: headers,
              body: JSON.stringify(payload)
            };
          }
          else if (method == "PUT") {
            options = {
              method: method,
              headers: headers,
              body: JSON.stringify(payload)
            };
          }
          else if (method == "DELETE") {
            options = {
              method: method,
              headers: headers,
            };
          }
          const response = await fetch(endpoint, options);
          if (response)
            resolve(response)
        }
        catch (error) {
          this.logClient.error(error);
          reject(error);
        }
      })();
    });
  }
  async GetVersion(): Promise<Response | null> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {
          let token: string = "";
          if(this.authorizationDisabled == false){
            token = await this.adClient.getAPITokenAsync();
            if (isNullOrUndefinedOrEmpty(token)) {
              const error = `Calling API GET Version : token null`;
              this.logClient.log(error);
              reject(error);
            }
          }
          const response = await this.callAPIAsync("GET", this.endpointUri.concat('version'), token, null);
          this.logClient.log(`Calling API GET Version: response received`);
          resolve(response);          
        }
        catch (e) {
          const error = `Calling API GET Version: Exception - ${e}`;
          this.logClient.log(error);
          reject(error);
        }
        return null;
      })();
    });
  }
  async GetTime(): Promise<Response | null> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {
          let token: string = "";
          if(this.authorizationDisabled == false){
            token = await this.adClient.getAPITokenAsync();
            if (isNullOrUndefinedOrEmpty(token)) {
              const error = `Calling API GET Time : token null`;
              this.logClient.log(error);
              reject(error);
            }
          }          
          const response = await this.callAPIAsync("GET", this.endpointUri.concat('time'), token, null);
          this.logClient.log(`Calling API GET Time: response received`);
          resolve(response);
        }
        catch (e) {
          const error = `Calling API GET Time: Exception - ${e}`;
          this.logClient.log(error);
          reject(error);
        }
      })();
    });
  }
  /* Generic API

  */
  GetItems(api: string): Promise<Response | null> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {          
          this.logClient.log(`Calling API GET ${api}s`);
          let token: string = "";
          if(this.authorizationDisabled == false){
            token = await this.adClient.getAPITokenAsync();
            if (isNullOrUndefinedOrEmpty(token)) {
              this.logClient.log(`Calling API GET ${api}s : token null`);
              reject("token is null");
            }
          }
          const response = await this.callAPIAsync("GET", this.endpointUri.concat(api), token, null);
          this.logClient.log(`Calling API GET ${api}s: response received`);
          resolve(response);
        }
        catch (e) {
          this.logClient.log(`Calling API GET ${api}s: Exception - ${e}`);
          reject(e);
        }
        return null;
      })();
    });
  }
  GetItem(api: string, id: string): Promise<Response> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {
          this.logClient.log(`Calling API GET ${api} ${id}`);

          let token: string = "";
          if(this.authorizationDisabled == false){
            token = await this.adClient.getAPITokenAsync();
            if (isNullOrUndefinedOrEmpty(token)) {
              this.logClient.log(`Calling API GET ${api} ${id} : token null`);
              reject("token is null");
            }
          }

          const response = await this.callAPIAsync("GET", this.endpointUri.concat(api + '/' + id), token, null);
          this.logClient.log(`Calling API GET ${api} ${id} response received`);
          resolve(response);
        }
        catch (e) {
          this.logClient.log(`Calling API GET ${api} ${id}: Exception - ${e}`);
          reject(e);
        }
        return null;
      })();
    });
  }
  DeleteItem(api: string, id: string): Promise<Response | null> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {
          this.logClient.log(`Calling API DELETE ${api} ${id}`);

          let token: string = "";
          if(this.authorizationDisabled == false){
            token = await this.adClient.getAPITokenAsync();
            if (isNullOrUndefinedOrEmpty(token)) {
              this.logClient.log(`Calling API DELETE ${api} ${id} : token null`);
              reject("token is null");
            }
          }

          const response = await this.callAPIAsync("DELETE", this.endpointUri.concat(api + '/' + id), token, null);
          this.logClient.log(`Calling API DELETE ${api} ${id} response received`);
          resolve(response);
        }
        catch (e) {
          this.logClient.log(`Calling API DELETE ${api} ${id}: Exception - ${e}`);
          reject(e);
        }
        return null;
      })();
    });
  }
  async UpdateItem(api: string, id: string, payload: string | null): Promise<Response | null> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {
          this.logClient.log(`Calling API PUT ${api} ${id}`);

          let token: string = "";
          if(this.authorizationDisabled == false){
            token = await this.adClient.getAPITokenAsync();
            if (isNullOrUndefinedOrEmpty(token)) {
              this.logClient.log(`Calling API PUT ${api} ${id} : token null`);
              reject("token is null");
            }
          }

          const response = await this.callAPIAsync("PUT", this.endpointUri.concat(api + '/' + id), token, payload);
          this.logClient.log(`Calling API PUT ${api} ${id} response received`);
          resolve(response);
        }
        catch (e) {
          this.logClient.log(`Calling API PUT ${api} ${id}: Exception - ${e}`);
          reject(e);
        }
        return null;
      })();
    });
  }
  async CreateItem(api: string, id: string, payload: string | null): Promise<Response | null> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {
          this.logClient.log(`Calling API POST ${api} ${id}`);

          let token: string = "";
          if(this.authorizationDisabled == false){
            token = await this.adClient.getAPITokenAsync();
            if (isNullOrUndefinedOrEmpty(token)) {
              this.logClient.log(`Calling API POST ${api} ${id} : token null`);
              reject("token is null");
            }
          }

          const response = await this.callAPIAsync("POST", this.endpointUri.concat(api), token, payload);
          this.logClient.log(`Calling API POST ${api} ${id} response received`);
          resolve(response);
        }
        catch (e) {
          this.logClient.log(`Calling API POST ${api} ${id}: Exception - ${e}`);
          reject(e);
        }
        return null;
      })();
    });
  }

  async TriggerItem(api: string, id: string, action: string, payload: string | null): Promise<Response | null> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {
          this.logClient.log(`Calling Trigger API POST ${api} ${id} ${action}`);

          let token: string = "";
          if(this.authorizationDisabled == false){
            token = await this.adClient.getAPITokenAsync();
            if (isNullOrUndefinedOrEmpty(token)) {
              this.logClient.log(`Calling API POST ${api} ${id} ${action}: token null`);
              reject("token is null");
            }
          }

          const response = await this.callAPIAsync("POST", this.endpointUri.concat(api + '/' + id + '/' + action), token, payload);
          this.logClient.log(`Calling API POST ${api} ${id} ${action} response received`);
          resolve(response);
        }
        catch (e) {
          this.logClient.log(`Calling API POST ${api} ${id} ${action}: Exception - ${e}`);
          reject(e);
        }
        return null;
      })();
    });
  }

  GetTriggerItems(api: string, id: string, action: string): Promise<Response | null> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {
          this.logClient.log(`Calling API GET ${api} ${id} ${action}s`);

          let token: string = "";
          if(this.authorizationDisabled == false){
            token = await this.adClient.getAPITokenAsync();
            if (isNullOrUndefinedOrEmpty(token)) {
              this.logClient.log(`Calling API GET ${api} ${id} ${action}s : token null`);
              reject("token is null");
            }
          }

          const response = await this.callAPIAsync("GET", this.endpointUri.concat(api + '/' + id + '/' + action), token, null);
          this.logClient.log(`Calling API GET ${api} ${id} ${action}s: response received`);
          resolve(response);
        }
        catch (e) {
          this.logClient.log(`Calling API GET ${api}s: Exception - ${e}`);
          reject(e);
        }
        return null;
      })();
    });
  }

  GetTriggerItem(api: string, id: string, action: string, subId: string): Promise<Response | null> {
    return new Promise<Response>((resolve, reject) => {
      (async () => {
        try {
          this.logClient.log(`Calling API GET ${api} ${id} ${action}s`);

          let token: string = "";
          if(this.authorizationDisabled == false){
            token = await this.adClient.getAPITokenAsync();
            if (isNullOrUndefinedOrEmpty(token)) {
              this.logClient.log(`Calling API GET ${api} ${id} ${action}s : token null`);
              reject("token is null");
            }
          }

          const response = await this.callAPIAsync("GET", this.endpointUri.concat(api + '/' + id + '/' + action + '/' + subId), token, null);
          this.logClient.log(`Calling API GET ${api} ${id} ${action}s: response received`);
          resolve(response);
        }
        catch (e) {
          this.logClient.log(`Calling API GET ${api}s: Exception - ${e}`);
          reject(e);
        }
        return null;
      })();
    });
  }

  
  /* Visit API

  */
  async GetVisits(): Promise<Response | null> {
    return this.GetItems("visit");
  }

  async CreateVisit(id: string, payload: any): Promise<Response | null> {
    return this.CreateItem("visit", id, payload);
  }

  async UpdateVisit(id: string, payload: any): Promise<Response | null> {
    return this.UpdateItem("visit", id, payload);
  }

  async DeleteVisit(id: string): Promise<Response | null> {
    return this.DeleteItem("visit", id);
  }

  async GetVisit(id: string): Promise<Response | null> {
    return this.GetItem("visit", id);
  }
}