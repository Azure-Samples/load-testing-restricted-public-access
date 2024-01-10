/**
 * File: settings.ts
 * 
 * Description: 
 *  This file contains the implementation of the SettingsPage class 
 *  
 */
import './globalconfig';
import { isNullOrUndefined } from "./common";
import { Page } from "./page";

class SettingsPage extends Page {
  version: string;
  constructor(id: string, name: string, uri: string | null, content: string | null, version: string) {
    super(id, name, uri, content);
    this.version = version;
  }

  registerEvents(): boolean {
    if (super.registerEvents)
      super.registerEvents();
    super.addEvent("colorselection", "change", () => { this.updateData(true); });
    super.addEvent("languageselection", "change", () => { this.updateData(true); });
    super.addEvent("paginationsizeselection", "change", () => { this.updateData(true); });
    super.addEvent("navigationcache", "click", () => { this.updateData(true); });
    super.addEvent("configurationtab", "click", () => { this.UpdateTabBar("configurationtab"); });
    super.addEvent("cloudtab", "click", () => { this.UpdateTabBar("cloudtab"); });
    super.addEvent("favoritetab", "click", () => { this.UpdateTabBar("favoritetab"); });
    super.addEvent("devicetab", "click", () => { this.UpdateTabBar("devicetab"); });
    return true;
  }

  unregisterEvents(): boolean {
    if (super.unregisterEvents)
      super.unregisterEvents();
    super.removeEvent("colorselection", "change", () => { this.updateData(true); });
    super.removeEvent("languageselection", "change", () => { this.updateData(true); });
    super.removeEvent("paginationsizeselection", "change", () => { this.updateData(true); });
    super.removeEvent("navigationcache", "click", () => { this.updateData(true); });
    super.removeEvent("configurationtab", "click", () => { this.UpdateTabBar("configurationtab"); });
    super.removeEvent("cloudtab", "click", () => { this.UpdateTabBar("cloudtab"); });
    super.removeEvent("favoritetab", "click", () => { this.UpdateTabBar("favoritetab"); });
    super.removeEvent("devicetab", "click", () => { this.UpdateTabBar("devicetab"); });
    return true;
  }
  onUpdate(update: boolean): void {
    if (update == true) {
      const color = this.getHTMLValue('colorselection');
      if (color) {
        const oldcolor = globalThis.globalVars.getGlobalColor();
        if (color.value != oldcolor) {
          globalThis.globalVars.setGlobalColor(String(color.value));
          document.documentElement.setAttribute('theme', String(color.value));
          window.location.reload();
        }
      }
      const language = this.getHTMLValue('languageselection');
      if (language) {
        const oldlanguage = globalThis.globalVars.getGlobalLanguage();
        if (language.value != oldlanguage) {
          globalThis.globalVars.setGlobalLanguage(String(language.value));
          window.location.reload();
        }
      }

      const paginationsize = this.getHTMLValue('paginationsizeselection');
      if (paginationsize) {
        const oldpaginationsize = globalThis.globalVars.getGlobalPageSize();
        if (paginationsize.value != oldpaginationsize) {
          globalThis.globalVars.setGlobalPageSize(Number.parseInt(paginationsize.value.toString()));
        }
      }

      const cache = this.getHTMLValue('navigationcache');
      if (cache) {
        const oldcache = globalThis.globalVars.getGlobalCache();
        if (cache.value != oldcache) {
          globalThis.globalVars.setGlobalCache(JSON.parse(cache.value.toString()));
        }
      }
    }
  }
  UpdateTabBar(id: string) {
    const array: string[] = ["cloudtab", "favoritetab", "devicetab", "configurationtab"];
    for (let index = 0; index < array.length; index++) {
      const menu: HTMLAnchorElement = document.getElementById(array[index]) as HTMLAnchorElement;
      if (!isNullOrUndefined(menu)) {
        if (id == array[index]) {
          menu.style.backgroundColor = getComputedStyle(document.documentElement)
            .getPropertyValue('--mini-button-bg-color'); // #999999
          menu.style.color = getComputedStyle(document.documentElement)
            .getPropertyValue('--mini-button-text-color'); // #999999
        }
        else {
          menu.style.backgroundColor = 'Transparent';
          menu.style.color = getComputedStyle(document.documentElement)
            .getPropertyValue('--mini-button-bg-color'); // #999999
        }
      }
    }
  }
  onInitializePage(): boolean {
    this.addHTMLValueMap([
      { id: "versionButton", value: this.version, readonly: true },
      { id: "languageselection", value: globalThis.globalVars.getGlobalLanguage(), readonly: false },
      { id: "paginationsizeselection", value: globalThis.globalVars.getGlobalPageSize(), readonly: false },
      { id: "colorselection", value: globalThis.globalVars.getGlobalColor(), readonly: false },
      { id: "navigationcache", value: globalThis.globalVars.getGlobalCache(), readonly: false },
    ]);

    this.updateData(false);
    // Update Tab
    this.UpdateTabBar("configurationtab");
    return true;
  }

}

const localPage = new SettingsPage("content", "Settings", "settings.html", null, globalThis.globalConfiguration.version);
if (localPage) {
  // Initialize Page  
  localPage.initializePage();
}

