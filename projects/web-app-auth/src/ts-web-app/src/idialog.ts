/**
 * File: idialog.ts
 * 
 * Description: 
 *  This file contains the declaration of the Dialog Interface used by the Dialog Pages
 *  
 */

import { IHTMLValue } from "./ihtmlvalue";

export interface EndDialogCallback {
    (): void;
}

/**
 * IDialog
 **/
export interface IDialog {

    registerEvents?(): boolean;
    unregisterEvents?(): boolean;

    onInitializeDialog?(): boolean;
    onOk?(): void;
    onCancel?(): void;

    initializeDialog(): boolean;
    showDialog(endok: EndDialogCallback | null, endcancel: EndDialogCallback | null): boolean;
    endDialog(id: string): void;

    updateData?(update: boolean): void;
    onUpdate?(update: boolean): void;

    openDialog(): Promise<boolean>;
    closeDialog(): void;

    setHTMLValueMap(map: Map<string, IHTMLValue>): boolean;
    addHTMLValueMap(array: Array<IHTMLValue>): boolean;
    addHTMLValue(value: IHTMLValue): boolean;
    getHTMLValueMap(): Map<string, IHTMLValue>;
    getHTMLValue(id: string): IHTMLValue;

}
