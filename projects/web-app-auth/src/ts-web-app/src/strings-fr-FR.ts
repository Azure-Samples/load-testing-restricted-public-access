/**
 * File: strings-fr-FR.ts
 * 
 * Description: 
 *  This file contains the UI strings in French
 * 
 */

const frStrings: Map<string, string> = new Map
    ([
        ["ImportProfile", "ImportProfile"],
        ["Visit", "Visit"],
        ["Style", "Style"],
        ["{0} record(s) in ImportProfile table", "{0} enregistrement(s) dans la table ImportProfile"],
        ["Add", "Ajouter"],
        ["Update", "Modifier"],
        ["Remove", "Supprimer"],
        ["ImportProfile Page", "Page Import Profile"],
        ["ExportProfile Page", "Page Export Profile"],
        ["Version:", "Version:"],

        ["Path", "Chemin"],
        ["Size", "Taille"],
        ["Status", "Etat"],
        ["No file selected", "Aucun fichier sélectionné"],

    ]);
globalThis.globalVars.setStringMap("fr", frStrings);
globalThis.globalVars.setStringMap("fr-FR", frStrings);

