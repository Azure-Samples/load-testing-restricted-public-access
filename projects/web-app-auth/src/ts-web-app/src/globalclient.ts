/**
 * File: globalclient.ts
 * 
 * Description: 
 *  This file contains the implementation of the GlobalClient which expose the following clients:
 *  - Storage Client
 *  - Azure AD Client
 *  - REST API Client
 *  - Log Client
 * 
 */

import { AzureADClient } from "./azuread";
import { StorageClient } from "./storage";
import { APIClient } from "./apiclient";
import { LogClient } from "./logclient";
import "./globalconfig";


const globalConfig = globalThis.globalConfiguration;

export class GlobalClient {
    // Initialize logClient
    private logClient: LogClient = new LogClient(LogClient.getLogLevelFromString(globalConfig.logLevel),globalConfig.appInsightsKey);

    // Initialize azureADClient used for the authentication
    private adClient: AzureADClient = new AzureADClient(this.logClient, globalConfig.msAuthConfig.auth.clientId,
        globalConfig.msAuthConfig.auth.authority,
        globalConfig.msAuthConfig.auth.redirectUri,
        globalConfig.msAuthConfig.cache.cacheLocation.toString(),
        globalConfig.msAuthConfig.cache.storeAuthStateInCookie,
        globalConfig.loginRequest,
        globalConfig.tokenStorageRequest,
        globalConfig.tokenAPIRequest,
        globalConfig.graphMeEndpoint,
        globalConfig.graphMailEndpoint
    )

    // Initialize the StorageClient used for the access to Azure Storage
    private storageClient: StorageClient = new StorageClient(this.logClient, globalConfig.storageAccountName,
        globalConfig.storageInputContainerName,
        globalConfig.storageSASToken,
        globalConfig.msAuthConfig.auth.clientId,
        globalConfig.tenantId,
        globalConfig.msAuthConfig.auth.redirectUri
    )

    // Initialize APIClient
    private apiClient: APIClient = new APIClient(
        this.logClient,
        this.adClient,
        globalConfig.apiEndpoint,
        globalConfig.msAuthConfig.auth.redirectUri,
        globalConfig.authorizationDisabled
    );


    public getLogClient(): LogClient {
        return this.logClient;
    }
    public getAzureADClient(): AzureADClient {
        return this.adClient;
    }
    public getStorageClient(): StorageClient {
        return this.storageClient;
    }
    public getAPIClient(): APIClient {
        return this.apiClient;
    }
}
declare global {
    var globalClient: GlobalClient;
}
declare var globalClient: GlobalClient;
globalThis.globalClient = new GlobalClient();
