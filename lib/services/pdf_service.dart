import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/payment.dart';
import '../models/rent_settings.dart';
import '../models/tenant.dart';

/// Builds a one-page, professionally formatted PDF invoice for a single
/// rent payment.
class PdfService {
  static const _navy = PdfColor.fromInt(0xFF1A1A2E);
  static const _navyLight = PdfColor.fromInt(0xFF0F3460);
  static const _slate = PdfColor.fromInt(0xFF6B7280);
  static const _paid = PdfColor.fromInt(0xFF1E8E4F);
  static const _unpaid = PdfColor.fromInt(0xFFC0392B);
  static const _partial = PdfColor.fromInt(0xFFB8790C);

  final _money = NumberFormat('#,##0.00');

  Future<Uint8List> buildInvoice({
    required RentSettings settings,
    required Tenant tenant,
    required Payment payment,
  }) async {
    final doc = pw.Document();
    final currency = settings.currencySymbol;
    final invoiceNumber = payment.id.length >= 8
        ? payment.id.substring(0, 8).toUpperCase()
        : payment.id.toUpperCase();
    final issueDate = DateFormat('d MMM yyyy').format(DateTime.now());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _header(settings, invoiceNumber, issueDate),
              pw.SizedBox(height: 4),
              pw.Container(height: 3, color: _navyLight),
              pw.SizedBox(height: 28),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _billTo(tenant)),
                  pw.SizedBox(width: 16),
                  pw.Expanded(child: _invoiceMeta(payment)),
                ],
              ),
              pw.SizedBox(height: 28),
              _itemsTable(payment, currency),
              pw.SizedBox(height: 4),
              _totals(payment, currency),
              if (payment.notes.isNotEmpty) ...[
                pw.SizedBox(height: 24),
                pw.Text('NOTES',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: _slate,
                        letterSpacing: 0.5)),
                pw.SizedBox(height: 4),
                pw.Text(payment.notes,
                    style: const pw.TextStyle(fontSize: 10)),
              ],
              pw.Spacer(),
              _footer(settings),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _header(
      RentSettings settings, String invoiceNumber, String issueDate) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              settings.landlordName.isEmpty ? 'Landlord' : settings.landlordName,
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: _navy),
            ),
            if (settings.landlordAddress.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(settings.landlordAddress,
                    style: const pw.TextStyle(fontSize: 9, color: _slate)),
              ),
            if (settings.landlordPhone.isNotEmpty)
              pw.Text(settings.landlordPhone,
                  style: const pw.TextStyle(fontSize: 9, color: _slate)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('INVOICE',
                style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                    letterSpacing: 1.5)),
            pw.SizedBox(height: 6),
            pw.Text('No. $invoiceNumber',
                style: const pw.TextStyle(fontSize: 9, color: _slate)),
            pw.Text('Issued $issueDate',
                style: const pw.TextStyle(fontSize: 9, color: _slate)),
          ],
        ),
      ],
    );
  }

  pw.Widget _billTo(Tenant tenant) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('BILL TO',
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _slate,
                letterSpacing: 0.5)),
        pw.SizedBox(height: 6),
        pw.Text(tenant.name,
            style:
                pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        if (tenant.propertyDescription.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(tenant.propertyDescription,
                style: const pw.TextStyle(fontSize: 9.5, color: _slate)),
          ),
        if (tenant.phone.isNotEmpty)
          pw.Text(tenant.phone,
              style: const pw.TextStyle(fontSize: 9.5, color: _slate)),
      ],
    );
  }

  pw.Widget _invoiceMeta(Payment payment) {
    final color = switch (payment.status) {
      'Paid' => _paid,
      'Partial' => _partial,
      _ => _unpaid,
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('BILLING PERIOD',
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _slate,
                letterSpacing: 0.5)),
        pw.SizedBox(height: 6),
        pw.Text(payment.month,
            style:
                pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            payment.status.toUpperCase(),
            style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  pw.Widget _itemsTable(Payment payment, String currency) {
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _navy, width: 1.5)),
          ),
          children: [
            _headerCell('DESCRIPTION'),
            _headerCell('PERIOD'),
            _headerCell('AMOUNT', alignRight: true),
          ],
        ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
          ),
          children: [
            _cell('Monthly Rent'),
            _cell(payment.month),
            _cell('$currency ${_money.format(payment.amountDue)}',
                alignRight: true),
          ],
        ),
        if (payment.referenceNumber.isNotEmpty)
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
            ),
            children: [
              _cell('Reference: ${payment.referenceNumber}', muted: true),
              _cell(''),
              _cell(''),
            ],
          ),
      ],
    );
  }

  pw.Widget _headerCell(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _slate,
            letterSpacing: 0.5),
      ),
    );
  }

  pw.Widget _cell(String text, {bool alignRight = false, bool muted = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: muted ? 8.5 : 10.5,
          color: muted ? _slate : PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _totals(Payment payment, String currency) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 220,
        child: pw.Column(
          children: [
            pw.SizedBox(height: 8),
            _totalRow('Amount Due', payment.amountDue, currency),
            _totalRow('Amount Paid', payment.amountPaid, currency),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Divider(color: PdfColors.grey400, thickness: 0.75),
            ),
            _totalRow('Balance Due', payment.balance, currency, bold: true),
          ],
        ),
      ),
    );
  }

  pw.Widget _totalRow(String label, double amount, String currency,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: bold ? 12 : 10.5,
                  color: bold ? _navy : _slate,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('$currency ${_money.format(amount)}',
              style: pw.TextStyle(
                  fontSize: bold ? 13 : 10.5,
                  color: bold ? _navy : PdfColors.black,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  pw.Widget _footer(RentSettings settings) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: PdfColors.grey300, thickness: 0.75),
        pw.SizedBox(height: 8),
        pw.Text(
          'Thank you${settings.landlordName.isEmpty ? '' : ' - ${settings.landlordName}'}',
          style: pw.TextStyle(
              fontSize: 9, color: _slate, fontStyle: pw.FontStyle.italic),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Generated by RentTrack',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey400),
        ),
      ],
    );
  }
}
