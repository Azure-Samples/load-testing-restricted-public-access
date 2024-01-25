/**
 * File: home.ts
 * 
 * Description: 
 *  This file contains the implementation of the Home Page
 *  
 */


import './globalconfig';

const globalConfig = globalThis.globalConfiguration;
if (globalConfig) {
  //console.log("Reading globalConfig")

  const s = document.getElementById('versionButton');
  if (s) {
    //console.log(`versionButton set to ${globalConfig.version}`);
    s.innerHTML = globalConfig.version;
  }
  else
    console.log("Error: versionButton not defined");
}
else
  console.log("Error: getGlobalConfiguration not defined");
