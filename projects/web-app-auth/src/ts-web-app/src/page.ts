/**
 * File: page.ts
 * 
 * Description: 
 *  This file contains the implementation of the Page class 
 *  
 */
import { isNullOrUndefinedOrEmpty, getFileContentAsync } from "./common";
import { IPage } from "./ipage";
import { IHTMLValue } from "./ihtmlvalue";
export interface EventCallback {
  (file: string, folder: string, progress: number): void;
}

export class Page implements IPage {
  id = "";
  name = "";
  uri: string | null = null;
  content: string | null = null;
  private valuemap: Map<string, IHTMLValue> = new Map<string, IHTMLValue>();
  constructor(id: string, name: string, uri: string | null, content: string | null) {
    this.id = id;
    this.name = name;
    this.uri = uri;
    this.content = content;
  }

  onUpdate?(update: boolean): void;
  static createPage(id: string, name: string, uri: string | null, content: string | null): Page {
    return new Page(id, name, uri, content);
  }
  openPage(): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      (async () => {
        if (this.content == null) {
          if (this.uri) {
            try {
              this.content = await getFileContentAsync(this.uri);
            }
            catch (e) {
              reject(e);
            }
          }
          else {
            reject("page uri undefined");
          }
        }
        const contentDiv: HTMLDivElement = (<HTMLDivElement>document.getElementById(this.id));
        if (contentDiv) {
          if (this.content) {
            contentDiv.innerHTML = this.content;
          }
          else {
            contentDiv.innerHTML = "";
          }
        }
        resolve(true);
      })();
    });
  }
  public initializePage(): boolean {
    if (this.registerEvents)
      this.registerEvents();
    if (this.onInitializePage)
      this.onInitializePage();
    return true;
  }
  closePage(): boolean {
    if (this.canClose) {
      if (this.canClose() != true)
        return false;
    }
    if (this.onClose) {
      if (this.onClose() != true)
        return false;
    }
    if (this.unregisterEvents)
      this.unregisterEvents();
    const contentDiv: HTMLDivElement = (<HTMLDivElement>document.getElementById(this.id));
    if (contentDiv) {
      contentDiv.innerHTML = "";
    }
    else {
      return false;
    }
    return true;
  }
  /*
   protected and override methods
  */
  onInitializePage?(): boolean;
  registerEvents?(): boolean;
  unregisterEvents?(): boolean;
  onClose?(): boolean;
  canClose?(): boolean;
  /*

  */
  setHTMLValueMap(map: Map<string, IHTMLValue>): boolean {
    this.valuemap = map;
    return true;
  }
  addHTMLValueMap(array: Array<IHTMLValue>): boolean {
    array.forEach((value: IHTMLValue) => {
      this.valuemap.set(value.id, value);
    })
    return true;
  }
  addHTMLValue(value: IHTMLValue): boolean {
    this.valuemap.set(value.id, value);
    return true;
  }
  getHTMLValueMap(): Map<string, IHTMLValue> {
    return this.valuemap;
  }
  getHTMLValue(id: string): IHTMLValue {
    const value = this.valuemap.get(id);
    if (value)
      return value;
    return { id: "", value: "", readonly: true };
  }
  setHTMLValueText(id: string, value: string): void {
    const element = <HTMLElement>document.getElementById(id);
    if (element) {
      switch (element.tagName) {
        case "LABEL":
          {
            const label = <HTMLLabelElement>document.getElementById(id);
            if (label)
              label.innerHTML = value;
          }
          break;
        case "SELECT":
          {
            const select = <HTMLSelectElement>document.getElementById(id);
            if (select) {
              for (let i = 0; i < select.options.length; i++) {
                if (select.options[i].value == String(value)) {
                  select.options.selectedIndex = i;
                  break;
                }
              }
            }
          }
          break;
        case "INPUT":
          {
            const input = <HTMLInputElement>document.getElementById(id);
            if (input) {
              input.value = value;
            }
          }
          break;
        default:
          {
            const elt = <HTMLElement>document.getElementById(id);
            if (elt)
              elt.innerHTML = value;
          }
          break;
      }
    }
  }
  getHTMLValueText(id: string): string | null {
    const element = <HTMLElement>document.getElementById(id);
    if (element) {
      switch (element.tagName) {
        case "LABEL":
          {
            const label = <HTMLLabelElement>document.getElementById(id);
            if (label)
              return label.innerHTML;
          }
          break;
        case "SELECT":
          {
            const select = <HTMLSelectElement>document.getElementById(id);
            if ((select) && (select.selectedIndex >= 0)) {
              return select.options[select.selectedIndex].value;
            }
          }
          break;
        case "INPUT":
          {
            const input = <HTMLInputElement>document.getElementById(id);
            if (input) {
              return input.value;
            }
          }
          break;
        default:
          {
            const elt = <HTMLElement>document.getElementById(id);
            if (elt)
              return elt.innerHTML;
          }
          break;
      }
    }
    return null;
  }

  updateData(update: boolean): boolean {
    let bUpdated = false;
    if (update) {
      for (const key of Array.from(this.valuemap.keys())) {
        if (key) {
          const element = <HTMLElement>document.getElementById(key);
          const value = this.valuemap.get(key);
          if ((value) && (element) && (value.readonly == false)) {
            switch (element.tagName) {
              case "LABEL":
                {
                  const label = <HTMLLabelElement>document.getElementById(value.id);
                  if (label)
                    if (value.value != label.innerHTML) {
                      value.value = label.innerHTML;
                      bUpdated = true;
                    }
                }
                break;
              case "SELECT":
                {
                  const select = <HTMLSelectElement>document.getElementById(value.id);
                  if ((select) && (select.selectedIndex >= 0)) {
                    if (value.value != select.options[select.selectedIndex].value) {
                      value.value = select.options[select.selectedIndex].value;
                      bUpdated = true;
                    }
                  }
                }
                break;
              case "INPUT":
                {
                  const input = <HTMLInputElement>document.getElementById(value.id);
                  if (input) {
                    if (input.type == "text") {
                      if (value.value != input.value.toString()) {
                        value.value = input.value;
                        bUpdated = true;
                      }
                    }
                    if (input.type == "number") {
                      if (value.value != input.value) {
                        value.value = input.value;
                        bUpdated = true;
                      }
                    }
                    if (input.type == "checkbox") {
                      if (value.value != input.checked.toString()) {
                        value.value = input.checked.toString();
                        bUpdated = true;
                      }
                    }
                  }
                }
                break;
              default:
                {
                  const label = <HTMLLabelElement>document.getElementById(value.id);
                  if (label)
                    if (value.value != label.innerHTML) {
                      value.value = label.innerHTML;
                      bUpdated = true;
                    }
                }
                break;
            }
          }
        }
      }
    }
    else {
      for (const key of Array.from(this.valuemap.keys())) {
        if (key) {
          const element = <HTMLElement>document.getElementById(key);
          const value = this.valuemap.get(key);
          if ((value) && (element)) {
            switch (element.tagName) {
              case "LABEL":
                {
                  const label = <HTMLLabelElement>document.getElementById(value.id);
                  if (label)
                    if (label.innerHTML != String(value.value)) {
                      label.innerHTML = String(value.value);
                      bUpdated = true;
                    }
                }
                break;
              case "SELECT":
                {
                  const select = <HTMLSelectElement>document.getElementById(value.id);
                  if (select) {
                    for (let i = 0; i < select.options.length; i++) {
                      if (select.options[i].value == String(value.value)) {
                        if (select.options.selectedIndex != i) {
                          select.options.selectedIndex = i;
                          bUpdated = true;
                        }
                        break;
                      }
                    }
                  }
                }
                break;
              case "INPUT":
                {
                  const input = <HTMLInputElement>document.getElementById(value.id);
                  if (input) {
                    if (input.type == "text")
                      input.value = value.value.toString();
                    if (input.type == "number") {
                      if (!isNullOrUndefinedOrEmpty(value.value))
                        input.value = value.value;
                    }
                    if (input.type == "checkbox")
                      input.checked = JSON.parse(value.value.toString());
                  }
                }
                break;
              default:
                {
                  const label = <HTMLLabelElement>document.getElementById(value.id);
                  if (label)
                    if (label.innerHTML != String(value.value)) {
                      label.innerHTML = String(value.value);
                      bUpdated = true;
                    }
                }
                break;
            }
          }
        }
      }
    }

    if (bUpdated == true) {
      if (this.onUpdate)
        this.onUpdate(update);
    }
    return true;
  }


  addEvent(id: string, event: string, listener: (ev: any) => any): void {
    const control: HTMLElement = (<HTMLElement>document.getElementById(id));
    if (control)
      control.addEventListener(event, listener);
  }
  removeEvent(id: string, event: string, listener: (ev: any) => any): void {
    const control: HTMLElement = (<HTMLElement>document.getElementById(id));
    if (control)
      control.removeEventListener(event, listener);
  }

}