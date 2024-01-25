/**
 * File: globalvars.ts
 * 
 * Description: 
 *  This file contains the implementation of the GlobalVariables object which exposes the following UI variables:
 *  - getGlobalPageSize: number of row display in the Visit Table
 *  - getGlobalCache: true the local cache is activated.
 *  - getGlobalLanguage: the default UI language
 *  - getGlobalColor: the default UI color
 * 
 */

class GlobalVariables {
  private globalLanguage = "en";
  private globalColor = "blue";
  private globalCache = true;
  private globalPageSize = 10;
  public getGlobalPageSize(): number {
    if (typeof (Storage) !== "undefined") {
      const l = localStorage.getItem("visitwebapp-pagesize")
      if (l) {
        const value = Number.parseInt(l);
        this.setGlobalPageSize(value)
      }
    }
    return this.globalPageSize;
  }
  public setGlobalPageSize(value: number) {
    if (typeof (Storage) !== "undefined")
      localStorage.setItem("visitwebapp-pagesize", value.toString());
    this.globalPageSize = value;
  }

  public getGlobalCache(): boolean {
    if (typeof (Storage) !== "undefined") {
      const l = localStorage.getItem("visitwebapp-cache")
      if (l) {
        const value = JSON.parse(l);
        this.setGlobalCache(value)
      }
    }
    return this.globalCache;
  }
  public setGlobalCache(value: boolean) {
    if (typeof (Storage) !== "undefined")
      localStorage.setItem("visitwebapp-cache", value.toString());
    this.globalCache = value;
  }

  public getGlobalLanguage(): string {
    if (typeof (Storage) !== "undefined") {
      const l = localStorage.getItem("visitwebapp-language")
      if (l)
        this.setGlobalLanguage(l)
    }
    return this.globalLanguage;
  }
  public getGlobalColor(): string {
    if (typeof (Storage) !== "undefined") {
      const c = localStorage.getItem("visitwebapp-color")
      if (c)
        this.setGlobalColor(c)
    }
    return this.globalColor;
  }
  public setGlobalLanguage(value: string) {
    if (typeof (Storage) !== "undefined")
      localStorage.setItem("visitwebapp-language", value);
    this.globalLanguage = value;
  }
  protected stringsMap: Map<string, Map<string, string>> = new Map<string, Map<string, string>>([
  ])
  public setStringMap(lang: string, map: Map<string, string>) {
    this.stringsMap.set(lang, map);
  }
  public getCurrentString(id: string): string {
    const localStrings = this.stringsMap.get(this.getGlobalLanguage());
    if (localStrings) {
      const s = localStrings.get(id);
      if (s) {
        return s;
      }
    }
    return id;
  }
  public setGlobalColor(value: string) {
    if (typeof (Storage) !== "undefined")
      localStorage.setItem("visitwebapp-color", value);
    this.globalColor = value;
  }
  public clearData() {
    if (typeof (Storage) !== "undefined") {
      localStorage.removeItem("visitwebapp-language");
      localStorage.removeItem("visitwebapp-color");
    }
  }
}

declare var globalVars: GlobalVariables;
globalThis.globalVars = new GlobalVariables();

