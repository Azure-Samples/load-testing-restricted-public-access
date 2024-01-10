/**
 * File: settings.ts
 * 
 * Description: 
 *  This file contains the implementation of the Table class.
 *  This class uses bootstrap-table 
 *  
 */

import { isNullOrUndefinedOrEmpty } from "./common";
import "bootstrap";
import "bootstrap-table";

const $: JQueryStatic = (window as any)["jQuery"];
/**
 * ITableColumn
 */
export interface ITableColumn {
  title: string;
  field: string;
}
/**
 * Table
 */
export class Table {
  tableId = "";
  tableLoaded = false;
  pageSize: number;

  constructor(id: string) {
    this.tableId = id;
    this.tableLoaded = false;
    this.pageSize = 10;
  }
  setColumns(columns: Array<ITableColumn>) {
    const $table = $(`#${this.tableId}`);
    $table.bootstrapTable({
      columns: columns
    });
  }
  destroyTable() {
    const $table = $(`#${this.tableId}`);
    $table.bootstrapTable('destroy');
  }
  createTableHeader(columns: Array<ITableColumn> | null = null) {
    if (columns) {
      const table = document.getElementById(this.tableId);
      if (table == null)
        return;

      while (table.hasChildNodes()) {
        if (table.firstChild != null)
          table.removeChild(table.firstChild);
      }
      // create header
      const tableHeader = document.createElement('THEAD');
      const trHeader = document.createElement('TR');
      tableHeader.appendChild(trHeader);
      for (let i = 0; i < columns.length; i++) {
        const th = document.createElement('TH');
        if (isNullOrUndefinedOrEmpty(columns[i].field)) {
          th.appendChild(document.createTextNode(columns[i].title));
          th.setAttribute("data-checkbox", "true");
        }
        else {
          th.appendChild(document.createTextNode(columns[i].title));
          th.setAttribute("data-sortable", "true");
          th.setAttribute("data-field", columns[i].field);
        }
        trHeader.appendChild(th);
      }
      tableHeader.style.display = "none"
      table.appendChild(tableHeader);
    }
  }
  createTable(columns: Array<ITableColumn> | null = null, pageSize: number, key: string, buttonArray: string[]): boolean {
    this.createTableHeader(columns);
    const $table = $(`#${this.tableId}`);
    this.pageSize = pageSize;
    // Set Pagination Size 
    $table.attr("data-page-size", this.pageSize);
    // Set Table data properties
    $table.attr("data-pagination", "true");
    $table.attr("data-search", "true");
    $table.attr("data-resizable", "true");
    // Detect when table is loaded
    $table.on('post-body.bs.table', () => {
      this.tableLoaded = true;
    });
    // Event on row checkbox
    $table.on('check.bs.table', function (e, row) {
      const array = $table.bootstrapTable('getSelections');
      if ((array) && (array.length)) {
        for (let i = 0; i < array.length; i++) {
          if (array[i].id != row.id)
            $table.bootstrapTable('uncheckBy', { field: key, values: [array[i][key]] });
        }
      }
      const select = !$table.bootstrapTable('getSelections').length;
      for (let i = 0; i < buttonArray.length; i++) {
        const $btn = $(`#${buttonArray[i]}`);
        $btn.prop('disabled', select);
      }
    })
    $table.on('uncheck.bs.table', function () {
      const select = !$table.bootstrapTable('getSelections').length;
      for (let i = 0; i < buttonArray.length; i++) {
        const $btn = $(`#${buttonArray[i]}`);
        $btn.prop('disabled', select);
      }
    })
    // Disable the buttons 
    for (let i = 0; i < buttonArray.length; i++) {
      const $btn = $(`#${buttonArray[i]}`);
      $btn.prop('disabled', true);
    }
    return true;
  }
  fillTable(payload: any): boolean {
    const $table = $(`#${this.tableId}`);
    if (this.tableLoaded != true) {
      (<any>$table).bootstrapTable(
        {
          data: payload,
          locale: globalThis.globalVars.getGlobalLanguage(),
          onPageChange: () => {
            this.hidePaginationDropDown();
          }
        });
    }
    else {
      // $table.bootstrapTable('removeAll');
      $table.bootstrapTable(
        'load',
        payload
      );
    }
    // Add background color 
    $(`#${this.tableId} th`).addClass("mini-table-header");
    // Hide select all checkbox 
    const importTable = document.getElementById(this.tableId);
    if (importTable) {
      const checkboxes = (<NodeListOf<HTMLInputElement>>document.getElementsByName("btSelectAll"));
      for (let i = 0; i < checkboxes.length; i++) {
        checkboxes[i].classList.add("d-none");
      }
    }
    // Hide pagination drop down
    this.hidePaginationDropDown();

    return true;
  }
  getSelection(): any {
    const $table = $(`#${this.tableId}`);
    return $table.bootstrapTable('getSelections');
  }
  selectRow(fieldId: string, fieldValue: string) {
    const $table = $(`#${this.tableId}`);
    if (!isNullOrUndefinedOrEmpty(fieldValue)) {
      if ($table) {
        $table.bootstrapTable('checkBy', { field: fieldId, values: [fieldValue] });
        return true;
      }
    }
    return false;
  }

  protected hidePaginationDropDown() {
    const collection = document.getElementsByClassName("page-list");
    if ((collection) && (collection.length)) {
      for (let i = 0; i < collection.length; i++) {
        collection[i].classList.add("d-none");
      }
    }
  }
}
