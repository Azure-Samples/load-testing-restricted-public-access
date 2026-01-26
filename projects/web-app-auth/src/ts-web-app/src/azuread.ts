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

  async signInAsync(): Promise<AccountInfo | null> {
    try {
      await this.MSAuthClient.initialize();
      this.logClient.log("MSAuthClient.initialize");

      await this.MSAuthClient.clearCache();
      this.logClient.log("MSAuthClient.clearCache");
      this.logClient.log("Login interactively");

      const loginResponse = await this.MSAuthClient.loginPopup(this.loginRequest);
      const message = `id_token acquired - expireon: ${loginResponse.expiresOn} cached: ${loginResponse.fromCache} idToken: ${loginResponse.idToken} `;
      this.logClient.log(message);
      const account = this.getAccount();
      if (account)
        this.setAccount(account);
      return account;

    } catch (error) {
      this.logClient.error(error);
      throw error;
    }
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

  async signOutAsync(): Promise<void> {
    await this.MSAuthClient.logoutRedirect();
  }

  async getTokenPopup(request: SilentRequest): Promise<AuthenticationResult | void> {
    await this.MSAuthClient.initialize();
    this.logClient.log("Acquiring Token silently");
    try {
      const result: AuthenticationResult = await this.MSAuthClient.acquireTokenSilent(request);
      if (result) {
        this.logClient.log("Acquire Token silently successful: response received");
        return result;
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
        return result;
      }
      else {
        const error = "Token interactively acquisition failed: Response null";
        this.logClient.error(error);
        throw error;
      }
    }
    catch (error) {
      const message = `Token interactively acquisition failed. Exception: ${error}. acquiring token using popup`;
      this.logClient.error(message);
      throw message;
    }
  }

  // Helper function to call MS Graph API endpoint 
  // using authorization bearer token scheme
  async callMSGraphAsync(endpoint: string, token: string): Promise<any> {
    const headers = new Headers();
    const bearer = `Bearer ${token}`;

    headers.append("Authorization", bearer);

    const options = {
      method: "GET",
      headers: headers
    };

    this.logClient.log('request made to Graph API at: ' + new Date().toString());

    try {
      const response = await fetch(endpoint, options);
      const json = await response.json();
      return json;
    } catch (error) {
      this.logClient.error(error);
      throw error;
    }
  }

  async getStorageTokenAsync(): Promise<any> {
    if (this.getAccount()) {
      this.logClient.log("Get Token for Storage: account present");
      try {
        const response: any = await this.getTokenPopup(this.tokenStorageRequest);
        this.logClient.log("Get Token for Storage: SUCCESS");
        return (<AuthResponse>response).accessToken;
      } catch (error: any) {
        this.logClient.log("Get Token for Storage: Exception:" + error);
        throw error;
      }
    }
    else {
      const error = "Can't get authentication token: No active Azure AD session";
      this.logClient.log("Get Token for Storage:" + error);
      throw "Get Token for Storage:" + error;
    }
  }

  async getAPITokenAsync(): Promise<any> {
    if (this.getAccount()) {
      this.logClient.log("Get Token for API: account present");
      try {
        const response: any = await this.getTokenPopup(this.tokenAPIRequest);
        if (isNullOrUndefinedOrEmpty(response)) {
          const error = "Get Token for API:Response for token undefined";
          this.logClient.error(error);
          throw error;
        }
        else {
          this.logClient.log("Get Token for API: success");
          return (<AuthResponse>response).accessToken;
        }
      } catch (error: any) {
        this.logClient.error("Get Token for API:" + error);
        throw "Get Token for API:" + error;
      };
    }
    else {
      const error = "Can't get authentication token: No active Azure AD session";
      this.logClient.error("Get Token for API: " + error);
      throw "Get Token for API:" + error;
    }
  }

  async getGraphMeDataAsync(): Promise<any> {
    if (this.getAccount()) {
      this.logClient.log("Get Token for GRAPH: account present");
      try {
        const response: void | AuthenticationResult = await this.getTokenPopup(this.loginRequest);
        if (isNullOrUndefinedOrEmpty(response)) {
          const error = "Get Token for GRAPH:Response for token undefined";
          this.logClient.error(error);
          throw error;
        }
        else {
          this.logClient.log("Get Token for GRAPH: SUCCESS");
          const data = await this.callMSGraphAsync(this.graphMeEndpoint, (<AuthResponse>response).accessToken);
          return data;
        }
      } catch (error: any) {
        this.logClient.error(error);
        throw error;
      }
    }
    else {
      const error = "Get Token for GRAPH: No active Azure AD Session";
      this.logClient.log(error);
      throw error;
    }
  }

  async getGraphMailDataAsync(): Promise<any> {
    if (this.getAccount()) {
      this.logClient.log("Get Token for MAIL: account present");
      try {
        const response: any = await this.getTokenPopup(this.tokenStorageRequest);
        if (isNullOrUndefinedOrEmpty(response)) {
          const error = "Get Token for MAIL:Response for token undefined";
          this.logClient.error(error);
          throw error;
        }
        else {
          const message = "Get Token for MAIL: SUCCESS";
          this.logClient.log(message);
          const data = await this.callMSGraphAsync(this.graphMailEndpoint, (<AuthResponse>response).accessToken);
          return data;
        }
      } catch (error: any) {
        this.logClient.error("Get Token for MAIL Exception:" + error);
        throw error;
      };
    }
    else {
      const error = "Get Token for MAIL: No active Azure AD session";
      this.logClient.error(error);
      throw error;
    }
  }


  isConnected(): boolean {
    if (isNullOrUndefinedOrEmpty(this.getAccount()))
      return false;
    return true;
  }

}
