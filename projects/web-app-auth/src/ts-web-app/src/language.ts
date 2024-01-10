/**
 * File: language.ts
 * 
 * Description: 
 *  This file contains the language supported for visit generation.
 * 
 */

import './globalconfig';
import './globalclient';
import { LogClient } from './logclient';
import { StorageClient } from './storage';
import { APIClient, Visit } from './apiclient';
import { AzureADClient } from './azuread';
import { Page } from "./page";
import { AddVisitDialog } from './addvisitdialog';
import { UpdateVisitDialog } from './updatevisitdialog';
import { RemoveVisitDialog } from './removevisitdialog';

import { Table } from './table';
import { PageWaiting, Alert } from './notificationclient';

export class VisitVersionText {
  language: string = ""
  titleLowerCase: string = ""
  titleUpperCase: string = ""
  code: string = ""
}
export const listLanguage: VisitVersionText[]  = [
  { language: "Arabic Egyptian", titleLowerCase: "النسخة المصریة", titleUpperCase: "النسخة المصریة", code: "ar-eg" }, 
  { language: "Arabic Modern Standard",  titleLowerCase: "النسخة العربیة", titleUpperCase:"النسخة العربیة", code: "ar" },
  { language: "Arabic Hybrid" ,  titleLowerCase: "النسخة العربیة" ,titleUpperCase:"النسخة العربیة", code: "ar??" },
  { language: "Bahasa Indonesian",  titleLowerCase: 	"Versi Bahasa Indonesia" 	,titleUpperCase:"VERSI BAHASA INDONESIA", code: "id" }, 
  { language: "Bahasa Malay",  titleLowerCase: 	"Versi Bahasa Melayu" 	,titleUpperCase:"VERSI BAHASA MELAYU", code: "ms" }, 
  { language: "Bulgarian",	 titleLowerCase: "Български", titleUpperCase:"БЪЛГАРСКИ" , code: "bg" },
  { language: "Cantonese" , titleLowerCase: 	"粵語版製作" ,titleUpperCase:	"粵語版製作" , code: "zh-hk" },
  { language: "Croatian" , titleLowerCase: 	"Hrvatska verzija" ,titleUpperCase:	"HRVATSKA VERZIJA", code: "	hr" }, 
  { language: "Czech" 	, titleLowerCase: "České znění", titleUpperCase:	"ČESKÉ ZNĚNÍ" , code: "cs" },
  { language: "Danish" ,	 titleLowerCase: "Dansk version" ,titleUpperCase:	"DANSK VERSION" , code: "da" },
  { language: "Dutch" 	, titleLowerCase: "Nederlandse versie" ,titleUpperCase:	"NEDERLANDSE VERSIE" , code: "nl" },
  { language: "Dutch/Flemish" , titleLowerCase: 	"Nederlands-Vlaamse versie" ,titleUpperCase:	"NEDERLANDS-VLAAMSE VERSIE", code: "nl-be??" }, 
  { language: "Flemish" ,	 titleLowerCase: "Nederlands-Vlaamse versie", titleUpperCase:	"NEDERLANDS-VLAAMSE VERSIE", code: "nl-be??" }, 
  { language: "Estonian" ,	 titleLowerCase: "Eestikeelne versioon" ,titleUpperCase:	"EESTIKEELNE VERSIOON" , code: "et" },
  { language: "Finnish" ,	 titleLowerCase: "Suomenkielinen versio", titleUpperCase:	"SUOMENKIELINEN VERSIO", code: "fi" }, 
  { language: "Flemish" ,	 titleLowerCase: "Vlaamse Versie" ,	titleUpperCase:"VLAAMSE VERSIE" , code: "nl-be" },
  { language: "French Canadian",  titleLowerCase: 	"Version Québécoise" ,titleUpperCase:	"VERSION QUÉBÉCOISE" , code: "fr-ca" },
  { language: "French Parisian" , titleLowerCase: "Version Française" ,titleUpperCase:	"VERSION FRANÇAISE", code: "fr-fr" }, 
  { language: "German" , titleLowerCase: 	"Deutsche Fassung" ,titleUpperCase:	"DEUTSCHE FASSUNG" , code: "de" },
  { language: "Greek" ,	 titleLowerCase: "Ελληνική Προσαρμογή" ,titleUpperCase:	"ΕΛΛΗΝΙΚΗ ΠΡΟΣΑΡΜΟΓΗ", code: "el" }, 
  { language: "Hebrew" , titleLowerCase: "גרסה עברית" ,titleUpperCase:"גרסה עברית", code: "he" },
  { language: "Hindi" 	, titleLowerCase: "Hindi version" ,titleUpperCase:"HINDI VERSION" , code: "hi" },
  { language: "Hungarian",  titleLowerCase: 	"Magyar változat", titleUpperCase:	"MAGYAR VÁLTOZAT" , code: "hu" },
  { language: "Icelandic",  titleLowerCase: 	"Íslensk talsetning", titleUpperCase:	"ÍSLENSK TALSETNING" , code: "is" },
  { language: "Italian", titleLowerCase:  	"Versione Italiana" 	,titleUpperCase:"VERSIONE ITALIANA", code: "it" }, 
  { language: "Japanese",  titleLowerCase: 	"日本語版" ,titleUpperCase:	"日本語版" , code: "ja" },
  { language: "Korean",  titleLowerCase: 	"우리말 제작" ,titleUpperCase:	"우리말 제작" , code: "ko" },
  { language: "Latvian",  titleLowerCase: 	"Latviešu valodas versija" ,titleUpperCase:	"LATVIEŠU VALODAS VERSIJA" , code: "lv" },
  { language: "Lithuanian",  titleLowerCase: 	"Lietuviška filmo versija" ,titleUpperCase:	"LIETUVIŠKA FILMO VERSIJA", code: "lt" }, 
  { language: "Malayalam",  titleLowerCase: 	"Malayalam version" ,titleUpperCase:	"MALAYALAM VERSION", code: "ml" }, 
  { language: "Norwegian", titleLowerCase: 	"Norsk versjon" ,titleUpperCase:	"NORSK VERSJON" , code: "nn" },
  { language: "Polish",  titleLowerCase: 	"Wersja polska" ,titleUpperCase:	"WERSJA POLSKA" , code: "pl" },
  { language: "Portuguese Brazil",  titleLowerCase: 	"Versão Português - Brasil" ,titleUpperCase:	"VERSÃO PORTUGUÊS - BRASIL", code: "pt-br" }, 
  { language: "Portuguese Euro",  titleLowerCase: 	"Versão portuguesa" ,titleUpperCase:	"VERSÃO PORTUGUESA" , code: "pt" },
  { language: "Romanian",  titleLowerCase: 	"Versiunea în limba română" ,titleUpperCase:	"VERSIUNEA ÎN LIMBA ROMÂNĂ" , code: "ro" },
  { language: "Russian",  titleLowerCase: 	"Над русской версией работали" 	,titleUpperCase:"НАД РУССКОЙ ВЕРСИЕЙ РАБОТАЛИ", code: "ru" }, 
  { language: "Simplified Chinese (Mandarin PRC)",  titleLowerCase: 	"中文版", titleUpperCase:	"中文版" , code: "zh-cn" },
  { language: "Slovakian",  titleLowerCase: 	"Výroba slovenskej verzie" ,titleUpperCase:	"VÝROBA SLOVENSKEJ VERZIE" , code: "sk" },
  { language: "Slovenian", titleLowerCase:  	"Izvedba slovenske sinhronizacije" ,titleUpperCase:	"IZVEDBA SLOVENSKE SINHRONIZACIJE", code: "sl" }, 
  { language: "Spanish Castilian",  titleLowerCase: 	"Versión castellana" ,	titleUpperCase:"VERSIÓN CASTELLANA", code: "es" }, 
  { language: "Spanish Catalan", titleLowerCase:  	"Versió catalana" ,titleUpperCase:	"VERSIÓ CATALANA" , code: "es??" },
  { language: "Spanish LatAm", titleLowerCase:  	"Versión al Español Latino Americano" ,	titleUpperCase:"VERSIÓN AL ESPAÑOL LATINO AMERICANO", code: "es-mx??" }, 
  { language: "Swedish", 	 titleLowerCase: "Svensk version" ,	titleUpperCase:"SVENSK VERSION", code: "sv" },
  { language: "Tagalog",  titleLowerCase: 	"Bersyong Tagalog", titleUpperCase:	"BERSYONG TAGALOG", code: "tag??" }, 
  { language: "Tamil", 	 titleLowerCase: "Tamil version" ,	titleUpperCase:"TAMIL VERSION" , code: "tam??" },
  { language: "Telugu",  titleLowerCase: 	"Telugu version", titleUpperCase:	"TELUGU VERSION", code: "te??" }, 
  { language: "Thai", 	 titleLowerCase: "ไทยเวอร์ชั ่น" ,titleUpperCase:	"ไทยเวอร์ชั ่น" , code: "th" },
  { language: "Traditional Chinese (Mandarin Taiwan)",  titleLowerCase: 	"中文版", titleUpperCase:	"中文版" , code: "zh-tw" },
  { language: "Turkish", titleLowerCase:  	"Türkçe Seslendirme", titleUpperCase:	"TÜRKÇE SESLENDİRME", code: "tr" }, 
  { language: "Ukrainian",  titleLowerCase: 	"Виробництво української версії", titleUpperCase:	"ВИРОБНИЦТВО УКРАЇНСЬКОЇ ВЕРСІЇ", code: "ua" }, 
  { language: "Vietnamese",  titleLowerCase: 	"Phiên Bản Nói Tiếng Việt", titleUpperCase:	"PHIÊN BẢN NÓI TIẾNG VIỆT", code: "vi" } 
 ] ;
