/**
 * RentTrack backend — Google Apps Script Web App
 *
 * Acts as a simple REST API over a Google Sheet, storing one payment
 * record per row. Column order (A:H) matches the Payment model:
 *   A: id              String (UUID)
 *   B: month           String, e.g. "August 2026"
 *   C: amountDue       Number
 *   D: amountPaid      Number
 *   E: status          String: "Paid" | "Partial" | "Unpaid"
 *   F: paidDate        String
 *   G: referenceNumber String
 *   H: notes           String
 *
 * Endpoints:
 *   GET  ?action=getPayments
 *        -> 200 { ok: true, data: [ [id, month, amountDue, ...], ... ] }
 *
 *   POST { action: "addPayment", data: [id, month, amountDue, ...] }
 *        -> appends a new row
 *
 *   POST { action: "updatePayment", data: [id, month, amountDue, ...] }
 *        -> finds the row whose column A equals data[0] and overwrites it
 *
 *   POST { action: "deletePayment", id: "..." }
 *        -> removes the row whose column A equals id
 *
 * All responses are JSON: { ok: true, ... } or { ok: false, error: "..." }
 */

var SHEET_NAME = 'Payments';
var NUM_COLUMNS = 8;

function getSheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
    sheet.appendRow(['id', 'month', 'amountDue', 'amountPaid', 'status', 'paidDate', 'referenceNumber', 'notes']);
  }
  return sheet;
}

function jsonResponse_(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function doGet(e) {
  try {
    var action = e.parameter.action;

    if (action === 'getPayments') {
      return jsonResponse_({ ok: true, data: getAllPayments_() });
    }

    return jsonResponse_({ ok: false, error: 'Unknown action: ' + action });
  } catch (err) {
    return jsonResponse_({ ok: false, error: String(err) });
  }
}

function doPost(e) {
  try {
    var body = JSON.parse(e.postData.contents);
    var action = body.action;

    if (action === 'addPayment') {
      addPayment_(body.data);
      return jsonResponse_({ ok: true });
    }

    if (action === 'updatePayment') {
      var updated = updatePayment_(body.data);
      if (!updated) {
        return jsonResponse_({ ok: false, error: 'Payment not found: ' + body.data[0] });
      }
      return jsonResponse_({ ok: true });
    }

    if (action === 'deletePayment') {
      var deleted = deletePayment_(body.id);
      if (!deleted) {
        return jsonResponse_({ ok: false, error: 'Payment not found: ' + body.id });
      }
      return jsonResponse_({ ok: true });
    }

    return jsonResponse_({ ok: false, error: 'Unknown action: ' + action });
  } catch (err) {
    return jsonResponse_({ ok: false, error: String(err) });
  }
}

function getAllPayments_() {
  var sheet = getSheet_();
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return [];

  var range = sheet.getRange(2, 1, lastRow - 1, NUM_COLUMNS);
  var values = range.getValues();

  return values
    .filter(function (row) { return row[0] !== '' && row[0] !== null; })
    .map(function (row) {
      return row.map(function (cell) {
        return cell instanceof Date ? cell.toISOString() : cell;
      });
    });
}

function addPayment_(data) {
  var sheet = getSheet_();
  sheet.appendRow(normalizeRow_(data));
}

function updatePayment_(data) {
  var sheet = getSheet_();
  var id = data[0];
  var rowIndex = findRowById_(sheet, id);
  if (rowIndex === -1) return false;

  sheet.getRange(rowIndex, 1, 1, NUM_COLUMNS).setValues([normalizeRow_(data)]);
  return true;
}

function deletePayment_(id) {
  var sheet = getSheet_();
  var rowIndex = findRowById_(sheet, id);
  if (rowIndex === -1) return false;

  sheet.deleteRow(rowIndex);
  return true;
}

function findRowById_(sheet, id) {
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return -1;

  var ids = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  for (var i = 0; i < ids.length; i++) {
    if (String(ids[i][0]) === String(id)) {
      return i + 2; // +2: 1-indexed rows, plus header row
    }
  }
  return -1;
}

function normalizeRow_(data) {
  var row = data.slice(0, NUM_COLUMNS);
  while (row.length < NUM_COLUMNS) row.push('');
  return row;
}
