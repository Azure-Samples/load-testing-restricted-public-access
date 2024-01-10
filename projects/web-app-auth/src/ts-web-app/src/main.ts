/**
 * File: main.ts
 * 
 * Description: 
 *  This file contains the entrypoint of the Web UI. 
 *  1. it creates the Navigation Manager
 *  2. it defines the list of pages to manage
 *  3. it defines the list of pages available without authentication (Guest mode)
 *  4. it defines the list of pages which requires Azure AD authentication 
 *  5. it initialize the Navigation Manager
 *  6. it launch the Navigation Manager calling navigate method
 */

import './globalconfig';
import './globalclient';
import { NavigationManager, PageConfiguration } from "./navmanager";

// Get global configuration
const globalConfig = globalThis.globalConfiguration;

// Initialize azureADClient used for the authentication
const azureADClient = globalThis.globalClient.getAzureADClient();

// Initialize the StorageClient used for the access to Azure Storage
const storageClient = globalThis.globalClient.getStorageClient();

// Initialize APIClient
const apiClient = globalThis.globalClient.getAPIClient();


const manager: NavigationManager = new NavigationManager();

function openPage(nav: NavigationManager, pageId: string) {
  console.log(`Opening page: ${pageId}`)
  nav.selectPage(pageId);
}
const authorizationDisabledPages: Array<string> = ["home",  "visit",  "settings"];
const connectedPages: Array<string> = ["home",  "visit",  "settings", "signout"];
const offlinePages: Array<string> = ["home",   "settings", "signin"];
function isPageVisible(nav: NavigationManager, pageId: string): boolean {
  if (globalConfig.authorizationDisabled == true)
  {
    if (authorizationDisabledPages.includes(pageId)) {
      //console.log(`Page ${pageId} is visible`)
      return true;
    }
  }
  else
  {
    //console.log(`Checking if page ${pageId} will be visible`)
    if (azureADClient.isConnected()) {
      if (connectedPages.includes(pageId)) {
        //console.log(`Page ${pageId} is visible`)
        return true;
      }
    }
    else {
      if (offlinePages.includes(pageId)) {
        //console.log(`Page ${pageId} is visible`)
        return true;
      }
    }
  }
  //console.log(`Page ${pageId} is not visible`)
  return false;
}

async function signIn(nav: NavigationManager, pageId: string) {
  console.log(`SignIn: ${pageId}`)
  await manager.selectPage(pageId);
  try {
    const account = await azureADClient.signInAsync();
    if (account) {
      await manager.selectPage("home");
    }
    else {
      const error = "Authentication failed"
      console.log(`Error while calling signIn: ${error}`)
      await manager.selectPage("home");
    }
  }
  catch (e) {
    console.log(`Exception while calling signIn: ${e}`)
    await manager.selectPage("home");
  }
}

async function signOut(nav: NavigationManager, pageId: string) {
  console.log(`SignOut: ${pageId}`)
  await manager.selectPage(pageId);
  await azureADClient.signOutAsync();
  if (azureADClient.isConnected() == false) {
    await manager.selectPage("home");
  }
}

const pageConfiguration: Array<PageConfiguration> = [
  {
    pageId: "home",
    pageTitle: "Home",
    pageHTMLUri: "home.html",
    pageJavascriptUri: "home-bundle.js",
    pageNavigateFunction: openPage,
    pageConditionFunction: isPageVisible
  },
  {
    pageId: "visit",
    pageTitle: "Visit",
    pageHTMLUri: "visit.html",
    pageJavascriptUri: "visit-bundle.js",
    pageNavigateFunction: openPage,
    pageConditionFunction: isPageVisible
  },
  {
    pageId: "settings",
    pageTitle: "Settings",
    pageHTMLUri: "settings.html",
    pageJavascriptUri: "settings-bundle.js",
    pageNavigateFunction: openPage,
    pageConditionFunction: isPageVisible
  },
  {
    pageId: "signin",
    pageTitle: "SignIn",
    pageHTMLUri: null,
    pageJavascriptUri: null,
    pageNavigateFunction: signIn,
    pageConditionFunction: isPageVisible
  },
  {
    pageId: "signout",
    pageTitle: "SignOut",
    pageHTMLUri: null,
    pageJavascriptUri: null,
    pageNavigateFunction: signOut,
    pageConditionFunction: isPageVisible
  }
];

const result = manager.initialization(
  "navbarsExampleDefault",
  "mediaburgerbutton",
  "content",
  globalThis.globalVars.getGlobalLanguage(),
  globalThis.globalVars.getGlobalColor(),
  pageConfiguration
);

if (result == true) {
  manager.navigate();
}
else {
  console.log("Error while initializing navigation manager");
}
