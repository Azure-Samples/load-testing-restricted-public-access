/**
 * File: dialog.ts
 * 
 * Description: 
 *  This file contains the implementation of Dialog class used to display a dialog box.
 * 
 */

import { IHTMLValue } from "./ihtmlvalue";
import { IDialog, EndDialogCallback } from "./idialog";
import { isNullOrUndefinedOrEmpty, getFileContentAsync } from "./common";
/**
 * IDialog
 */
export class Dialog implements IDialog {
  id = "";
  okId = "";
  name = "";
  uri: string | null = null;
  content: string | null = null;
  removeContent = false;
  endok?(): void;
  endcancel?(): void;
  private valuemap: Map<string, IHTMLValue> = new Map<string, IHTMLValue>();
  constructor(id: string, name: string, uri: string | null, content: string | null, okId: string) {
    this.id = id;
    this.name = name;
    this.uri = uri;
    this.content = content;
    this.okId = okId;
  }
  static createDialg(id: string, name: string, uri: string | null, content: string | null, okId: string): Dialog {
    return new Dialog(id, name, uri, content, okId);
  }
  openDialog(): Promise<boolean> {
    return new Promise<boolean>((resolve, reject) => {
      (async () => {
        try {
          if (this.dialogLoaded() == false) {
            await this.loadDialog();
            resolve(true);
          }
        }
        catch (e) {
          reject(e);
        }
      })();
    });
  }
  closeDialog(): void {
    if (this.unregisterEvents)
      this.unregisterEvents();
    if (this.removeContent) {
      const contentDiv: HTMLDivElement = (<HTMLDivElement>document.getElementById(this.id));
      if (contentDiv) {
        contentDiv.innerHTML = "";
        return;
      }
    }
    return;
  }
  protected dialogLoaded(): boolean {
    const contentDiv: HTMLDivElement = (<HTMLDivElement>document.getElementById(this.id));
    if (contentDiv) {
      if (!isNullOrUndefinedOrEmpty(contentDiv.innerHTML))
        return true;
    }
    return false;
  }
  protected loadDialog(): Promise<boolean> {
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
            this.removeContent = true;
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
  public initializeDialog(): boolean {
    if (this.registerEvents)
      this.registerEvents();
    if (this.onInitializeDialog)
      this.onInitializeDialog();
    if (this.updateData)
      this.updateData(false);
    return true;
  }
  onUpdate?(update: boolean): void;
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
        case "INPUT": {
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
                  if (label) {
                    let text = "";
                    if (!isNullOrUndefinedOrEmpty(value.value)) {
                      text = String(value.value);
                      if (label.innerHTML != text) {
                        label.innerHTML = text;
                        bUpdated = true;
                      }
                    }
                  }
                }
                break;
              case "SELECT":
                {
                  const select = <HTMLSelectElement>document.getElementById(value.id);
                  if (select) {
                    for (let i = 0; i < select.options.length; i++) {
                      let text = "";
                      if (!isNullOrUndefinedOrEmpty(value.value))
                        text = String(value.value);

                      if (select.options[i].value == text) {
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
                    if (input.type == "text") {
                      let text = "";
                      if (!isNullOrUndefinedOrEmpty(value.value))
                        text = String(value.value);
                      input.value = text;
                    }
                    if (input.type == "number") {
                      if (!isNullOrUndefinedOrEmpty(value.value))
                        input.value = value.value;
                    }
                    if (input.type == "checkbox") {
                      let text = "";
                      if (!isNullOrUndefinedOrEmpty(value.value))
                        text = String(value.value);
                      input.checked = JSON.parse(text);
                    }
                  }
                }
                break;
              default:
                {
                  const label = <HTMLLabelElement>document.getElementById(value.id);
                  if (label) {
                    let text = "";
                    if (!isNullOrUndefinedOrEmpty(value.value))
                      text = String(value.value);
                    if (label.innerHTML != text) {
                      label.innerHTML = text;
                      bUpdated = true;
                    }
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

  registerEvents?(): boolean;
  unregisterEvents?(): boolean;

  onInitializeDialog?(): boolean;
  onOk?(): void;
  onCancel?(): void;

  showDialog(endok: EndDialogCallback | null = null, endcancel: EndDialogCallback | null = null): boolean {
    if (endok)
      this.endok = endok;
    if (endcancel)
      this.endcancel = endcancel;
    const control = (<HTMLDivElement>document.getElementById(this.id));
    if (control) {
      control.style.display = "block";
      control.style.paddingRight = "17px";
      control.className = "modal fade show";
      document.body.className = "modal-open";
      const div: HTMLDivElement = <HTMLDivElement>document.createElement('div');
      if (div) {
        div.className = "modal-backdrop fade show";
        document.body.appendChild(div);
        return true;
      }
    }
    return false;
  }
  endDialog(id: string): boolean {
    if (id == this.okId) {
      this.updateData(true);
      if (this.onOk)
        this.onOk();
    }
    else {
      if (this.onCancel)
        this.onCancel()
    }
    const control = (<HTMLDivElement>document.getElementById(this.id));
    if (control) {
      control.style.display = "none";
      control.className = "modal fade";
      document.body.className = "";
      const list: HTMLCollectionOf<Element> = document.body.getElementsByClassName("modal-backdrop");
      if ((list) && (list.length > 0)) {
        document.body.removeChild(list[0]);
      }
      this.closeDialog();
      if (this.removeContent) {
        while (control.hasChildNodes()) {
          if (control.firstChild != null)
            control.removeChild(control.firstChild);
        }
      }
      if (id == this.okId) {
        if (this.endok)
          this.endok();
      }
      else {
        if (this.endcancel)
          this.endcancel();
      }
      return true;
    }
    return false;
  }
}
