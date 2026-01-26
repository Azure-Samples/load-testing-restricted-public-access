/**
 * File: azuread.ts
 * 
 * Description: 
 *  This file contains the calls to the Azure AD for the Authentication
 * 
 */

import { PublicClientApplication, LogLevel, Configuration, AccountInfo, SilentRequest, AuthenticationResult  } from '@azure/msal-browser';
import { isNullOrUndefinedOrEmpty } from './common';
import { LogClient } from './logclient';

type LoginRequest = {
  scopes: Array<string>;
};
type TokenRequest = {
  scopes: Array<string>;
};
type AuthResponse = {
  accessToken: string;
};

export class AzureADClient {
  logClient: LogClient;
  MSAuthClient: PublicClientApplication
  loginRequest: LoginRequest;
  tokenStorageRequest: TokenRequest;
  tokenAPIRequest: TokenRequest;
  graphMeEndpoint: string;
  graphMailEndpoint: string;

  constructor(
    logClient: LogClient,
    clientId: string,
    authority: string,
    redirectUri: string,
    cacheLocation: string,
    storeAuthStateInCookie: boolean,
    loginRequest: LoginRequest,
    tokenStorageRequest: TokenRequest,
    tokenAPIRequest: TokenRequest,
    graphMeEndpoint: string,
    graphMailEndpoint: string
  ) {
    this.logClient = logClient;
    const msAuthConfig: Configuration  = {
      auth: {
        clientId: clientId,
        authority: authority,
        redirectUri: redirectUri,
        postLogoutRedirectUri: redirectUri
      },
      cache: {
        cacheLocation: (cacheLocation == "localStorage" ? "localStorage" : "sessionStorage"), // This configures where your cache will be stored
        storeAuthStateInCookie: storeAuthStateInCookie, // Set this to "true" if you are having issues on IE11 or Edge
      },
      system: {
        //allowNativeBroker: false, // Prevents Windows issues
        loggerOptions: {
          loggerCallback(level, message, containsPii) {
            if (!containsPii) console.log(message);
          },
          logLevel: LogLevel.Info,
        },
      },

    }
    this.loginRequest = loginRequest;
    this.tokenStorageRequest = tokenStorageRequest;
    this.tokenAPIRequest = tokenAPIRequest;
    this.graphMeEndpoint = graphMeEndpoint;
    this.graphMailEndpoint = graphMailEndpoint;

    this.MSAuthClient = new PublicClientApplication(msAuthConfig);
  }

  getAccount(): AccountInfo | null {
    let currentAccounts = [];
    try {
      // In case multiple accounts exist, you can select
      currentAccounts = this.MSAuthClient.getAllAccounts();
      if (currentAccounts === null) {
        // no accounts detected
      } else if (currentAccounts.length >= 1) {
        return currentAccounts[0];
      }
    }
    catch (err) {
      this.logClient.error(err);
    }
    return null;
  }

  setAccount(account: AccountInfo): boolean {
    try {
      this.MSAuthClient.setActiveAccount(account);
      return true;
    }
    catch (err) {
      this.logClient.error(err);
    }
    return false;
  }

  signInAsync(): Promise<AccountInfo | null> {
    return new Promise<AccountInfo | null>((resolve, reject) => {
      this.MSAuthClient.initialize().then(() => { 
        this.logClient.log("MSAuthClient.initialize");
        this.MSAuthClient.clearCache().then(() => {
          this.logClient.log("MSAuthClient.clearCache");
          this.logClient.log("Login interactively");
          this.MSAuthClient.loginPopup(this.loginRequest)
            .then(loginResponse => {
              const message = `id_token acquired - expireon: ${loginResponse.expiresOn} cached: ${loginResponse.fromCache} idToken: ${loginResponse.idToken} `;
              this.logClient.log(message);
              const account = this.getAccount();
              if (account)
                this.setAccount(account);
              resolve(account);
            }).catch(error => {
              this.logClient.error(error);
              reject(error)
            });
          }).catch(error => {
            this.logClient.error(error);
            reject(error)
          });
        }).catch(error => {
          this.logClient.error(error);
          reject(error)
        });
    });
  }

  
  async initAuthAsync(): Promise<AccountInfo | null> {
    // Must be invoked before your app renders routes relying on auth.
    await this.MSAuthClient.initialize();
    let response: AuthenticationResult | null = null;
    try {
      response = await this.MSAuthClient.handleRedirectPromise();
    } catch (e) {
      this.logClient.log(`handleRedirectPromise ignored error: ${e}`);
    }

    if (response?.account) {
      this.MSAuthClient.setActiveAccount(response.account);
      return response.account;
    }

    const accounts = this.MSAuthClient.getAllAccounts();
    if (accounts.length > 0) {
      this.MSAuthClient.setActiveAccount(accounts[0]);
      return accounts[0];
    }

    return null;
  }



  // signInAsync(): Promise<AccountInfo | null> {
  //   // Force account picker to avoid reusing cached account implicitly.
  //   var interactive = Object.assign({}, loginRequest, { prompt: "select_account" });

  //   this.logClient.log("Login interactively (popup) ...");

  //   // 1) Interactive login
  //   return this.MSAuthClient.loginPopup(interactive)
  //     .then(function (loginResponse: AuthenticationResult) {
  //       // 2) Choose account: prefer the one returned by login
  //       var account: AccountInfo | null =
  //         (loginResponse && loginResponse.account) ||
  //         (function () {
  //           var accts = this.MSAuthClient.getAllAccounts();
  //           return (accts && accts.length > 0) ? accts[0] : null;
  //         })();

  //       // 3) Make it the active account so future acquireTokenSilent() doesn’t need `account`
  //       if (account) {
  //         this.MSAuthClient.setActiveAccount(account);
  //       }

  //       // 4) Minimal, non‑PII logging
  //       var exp = loginResponse && loginResponse.expiresOn
  //         ? loginResponse.expiresOn.toISOString()
  //         : "unknown";
  //       var cacheFlag = loginResponse && (loginResponse as any).fromCache ? " (from cache)" : "";
  //       this.logClient.log("ID token acquired; expiresOn=" + exp + cacheFlag);

  //       return account;
  //     })
  //     .catch(function (error) {
  //       this.logClient.error(error);
  //       return Promise.reject(error);
  //     });
  // }

  async signOutAsync(): Promise<void> {
    await this.MSAuthClient.logoutRedirect();
  }

  getTokenPopup(request: SilentRequest): Promise<AuthenticationResult | void> {

    return new Promise<AuthenticationResult | void>((resolve, reject) => {
      (async () => {
        await this.MSAuthClient.initialize();
        this.logClient.log("Acquiring Token silently");
        try {
          const result: AuthenticationResult = await this.MSAuthClient.acquireTokenSilent(request);
          if (result) {
            this.logClient.log("Acquire Token silently successful: response received");
            resolve(result);
            return;
          }
          else {
            this.logClient.error(`Silent token acquisition fails. Response null `);
          }
        }
        catch (error) {
          this.logClient.error(`Silent token acquisition fails. Exception: ${error}. acquiring token using popup`);
        }

        this.logClient.log("Acquiring Token interactively");
        try {
          const result: AuthenticationResult = await this.MSAuthClient.acquireTokenPopup(request);
          if (result) {
            this.logClient.log("Acquire Token interactively successful: response received");
            resolve(result);
            return;
          }
          else {
            const error = "Token interactively acquisition failed: Response null";
            this.logClient.error(error);
            reject(error);
            return;
          }
        }
        catch (error) {
          const message = `Token interactively acquisition failed. Exception: ${error}. acquiring token using popup`;
          this.logClient.error(message);
          reject(message);
        }
      })();
    });
  }

  // Helper function to call MS Graph API endpoint 
  // using authorization bearer token scheme
  callMSGraphAsync(endpoint: string, token: string): Promise<any> {
    return new Promise<any>((resolve, reject) => {
      const headers = new Headers();
      const bearer = `Bearer ${token}`;

      headers.append("Authorization", bearer);

      const options = {
        method: "GET",
        headers: headers
      };

      this.logClient.log('request made to Graph API at: ' + new Date().toString());

      fetch(endpoint, options)
        .then(response => response.json())
        .then(response => resolve(response))
        .catch(error => {
          this.logClient.error(error);
          reject(error)
        })
    });
  }

  getStorageTokenAsync(): Promise<any> {
    return new Promise<any>((resolve, reject) => {
      if (this.getAccount()) {
        this.logClient.log("Get Token for Storage: account present");
        this.getTokenPopup(this.tokenStorageRequest)
          .then(async (response: any) => {
            this.logClient.log("Get Token for Storage: SUCCESS");
            resolve((<AuthResponse>response).accessToken);
          }).catch((error: any) => {
            this.logClient.log("Get Token for Storage: Exception:" + error);
            reject(error);
          });
      }
      else {
        const error = "Can't get authentication token: No active Azure AD session";
        this.logClient.log("Get Token for Storage:" + error);
        reject("Get Token for Storage:" + error);
      }
    });
  }

  getAPITokenAsync(): Promise<any> {
    return new Promise<any>((resolve, reject) => {
      if (this.getAccount()) {
        this.logClient.log("Get Token for API: account present");
        this.getTokenPopup(this.tokenAPIRequest)
          .then(async (response: any) => {
            if (isNullOrUndefinedOrEmpty(response)) {
              const error = "Get Token for API:Response for token undefined";
              this.logClient.error(error);
              reject(error);
            }
            else {
              this.logClient.log("Get Token for API: success");
              resolve((<AuthResponse>response).accessToken);
            }
          }).catch((error: any) => {
            this.logClient.error("Get Token for API:" + error);
            reject("Get Token for API:" + error);
          });
      }
      else {
        const error = "Can't get authentication token: No active Azure AD session";
        this.logClient.error("Get Token for API: " + error);
        reject("Get Token for API:" + error);
      }
    });
  }

  getGraphMeDataAsync(): Promise<any> {
    return new Promise<any>((resolve, reject) => {
      if (this.getAccount()) {
        this.logClient.log("Get Token for GRAPH: account present");
        this.getTokenPopup(this.loginRequest)
          .then(async (response: void | AuthenticationResult) => {
            if (isNullOrUndefinedOrEmpty(response)) {
              const error = "Get Token for GRAPH:Response for token undefined";
              this.logClient.error(error);
              reject(error);
            }
            else {
              this.logClient.log("Get Token for GRAPH: SUCCESS");
              const data = await this.callMSGraphAsync(this.graphMeEndpoint, (<AuthResponse>response).accessToken);
              resolve(data);
            }
          }).catch((error: any) => {
            this.logClient.error(error);
            reject(error);
          });
      }
      else {
        const error = "Get Token for GRAPH: No active Azure AD Session";
        this.logClient.log(error);
        reject(error);
      }

    });
  }

  getGraphMailDataAsync(): Promise<any> {
    return new Promise<any>((resolve, reject) => {
      if (this.getAccount()) {
        this.logClient.log("Get Token for MAIL: account present");
        this.getTokenPopup(this.tokenStorageRequest)
          .then(async (response: any) => {
            if (isNullOrUndefinedOrEmpty(response)) {
              const error = "Get Token for MAIL:Response for token undefined";
              this.logClient.error(error);
              reject(error);
            }
            else {
              const message = "Get Token for MAIL: SUCCESS";
              this.logClient.log(message);
              const data = await this.callMSGraphAsync(this.graphMailEndpoint, (<AuthResponse>response).accessToken);
              resolve(data);
            }
          }).catch((error: any) => {
            this.logClient.error("Get Token for MAIL Exception:" + error);
            reject(error);
          });
      }
      else {
        const error = "Get Token for MAIL: No active Azure AD session";
        this.logClient.error(error);
        reject(error);
      }
    });
  }

  isConnected(): boolean {
    if (isNullOrUndefinedOrEmpty(this.getAccount()))
      return false;
    return true;
  }

}
