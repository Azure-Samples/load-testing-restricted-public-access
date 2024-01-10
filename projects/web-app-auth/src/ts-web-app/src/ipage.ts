/**
 * File: ipage.ts
 * 
 * Description: 
 *  This file contains the declaration of the Page Interface used by the Pages (Home, Visit, ...)
 *  
 */

import { IHTMLValue } from "./ihtmlvalue";

/**
 * IPage
 */
export interface IPage {

    registerEvents?(): boolean;
    unregisterEvents?(): boolean;

    onInitializePage?(): boolean;
    onClose?(): boolean;
    canClose?(): boolean;
    onUpdate?(update: boolean): void;

    initializePage(): boolean;
    openPage(): Promise<boolean>;
    closePage(): boolean;

    setHTMLValueMap(map: Map<string, IHTMLValue>): boolean;
    getHTMLValueMap(): Map<string, IHTMLValue>;
    addHTMLValueMap(array: Array<IHTMLValue>): boolean;
    addHTMLValue(value: IHTMLValue): boolean;

    updateData(update: boolean): void;


}
