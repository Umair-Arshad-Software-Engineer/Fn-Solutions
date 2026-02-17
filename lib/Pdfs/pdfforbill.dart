import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../Models/bill_model.dart';
import '../Models/labour_model.dart';
import '../Models/quotation_model.dart';

class PdfService {
  // ─── Minimal Professional Palette ───────────────────────────────────────────
  static const PdfColor _ink        = PdfColor.fromInt(0xFF1A1A1A); // near-black text
  static const PdfColor _slate      = PdfColor.fromInt(0xFF4B5563); // secondary text
  static const PdfColor _border     = PdfColor.fromInt(0xFFD1D5DB); // light border
  static const PdfColor _rowAlt     = PdfColor.fromInt(0xFFF9FAFB); // table alt row
  static const PdfColor _accent     = PdfColor.fromInt(0xFF1D4ED8); // single blue accent
  static const PdfColor _accentSoft = PdfColor.fromInt(0xFFEFF6FF); // very light blue
  static const PdfColor _white      = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor _success    = PdfColor.fromInt(0xFF16A34A); // paid / positive
  static const PdfColor _warning    = PdfColor.fromInt(0xFFCA8A04); // partial
  static const PdfColor _danger     = PdfColor.fromInt(0xFFDC2626); // overdue / negative

  // ─── Public API ─────────────────────────────────────────────────────────────

  static Future<Uint8List> generateBillPdf(BillModel bill) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (context) => _header(bill),
        footer: (context) => _footer(context),
        build: (context) => [
          pw.SizedBox(height: 24),
          _partyRow(bill),
          pw.SizedBox(height: 20),
          _metaRow(bill),
          pw.SizedBox(height: 28),
          _sectionLabel('Materials'),
          pw.SizedBox(height: 8),
          _materialsTable(bill),
          if (bill.labourItems.isNotEmpty && bill.isLabourProvidedByUs) ...[
            pw.SizedBox(height: 24),
            _sectionLabel('Labour Services'),
            pw.SizedBox(height: 8),
            _labourTable(bill),
          ],
          pw.SizedBox(height: 28),
          _summaryBlock(bill),
          pw.SizedBox(height: 20),
          _paymentBlock(bill),
          if (bill.notes != null || bill.termsAndConditions != null) ...[
            pw.SizedBox(height: 20),
            _notesBlock(bill),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> printBill(BuildContext context, BillModel bill) async {
    try {
      final bytes = await generateBillPdf(bill);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Bill_${bill.billNumber}.pdf',
      );
    } catch (e) {
      debugPrint('Error printing bill: $e');
      rethrow;
    }
  }

  static Future<void> saveBillPdf(BuildContext context, BillModel bill) async {
    try {
      final bytes = await generateBillPdf(bill);
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Bill_${bill.billNumber}.pdf');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text('PDF saved to: ${file.path}',
                style: const TextStyle(fontSize: 12))),
          ]),
          backgroundColor: Colors.grey[900],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      debugPrint('Error saving bill PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      rethrow;
    }
  }

  static Future<void> shareBillPdf(BuildContext context, BillModel bill) async {
    try {
      final bytes = await generateBillPdf(bill);
      await Printing.sharePdf(
          bytes: bytes, filename: 'Bill_${bill.billNumber}.pdf');
    } catch (e) {
      debugPrint('Error sharing bill PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error sharing PDF: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      rethrow;
    }
  }

  // ─── Page Header ────────────────────────────────────────────────────────────

  static pw.Widget _header(BillModel bill) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Company / sender block
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(
              bill.createdByName,
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink),
            ),
            if (bill.teamName != null)
              pw.Text(bill.teamName!,
                  style: pw.TextStyle(fontSize: 10, color: _slate)),
          ]),

          // Invoice badge
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('INVOICE',
                style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: _accent)),
            pw.SizedBox(height: 2),
            pw.Text(bill.billNumber,
                style: pw.TextStyle(fontSize: 11, color: _slate)),
          ]),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Divider(color: _border, thickness: 1),
    ]);
  }

  // ─── Page Footer ────────────────────────────────────────────────────────────

  static pw.Widget _footer(pw.Context context) {
    return pw.Column(children: [
      pw.Divider(color: _border, thickness: 0.5),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Thank you for your business.',
              style: pw.TextStyle(fontSize: 8, color: _slate)),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  -  Generated ${_fmtDate(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: _slate),
          ),
        ],
      ),
    ]);
  }

  // ─── Bill-To / Dates ────────────────────────────────────────────────────────

  static pw.Widget _partyRow(BillModel bill) {
    final overdue = bill.dueDate.isBefore(DateTime.now()) &&
        bill.paymentStatus != 'Paid';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Bill-To
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('BILL TO',
                  style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: _slate,
                      letterSpacing: 1.2)),
              pw.SizedBox(height: 6),
              pw.Text(bill.customerName,
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink)),
              if (bill.customerEmail?.isNotEmpty == true)
                _infoLine(bill.customerEmail!),
              if (bill.customerPhone?.isNotEmpty == true)
                _infoLine(bill.customerPhone!),
              if (bill.customerAddress?.isNotEmpty == true)
                _infoLine(bill.customerAddress!),
            ],
          ),
        ),

        // Dates + status
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _labelValue('Issue Date', _fmtDate(bill.billDate)),
            pw.SizedBox(height: 4),
            _labelValue(
              'Due Date',
              _fmtDate(bill.dueDate),
              valueColor: overdue ? _danger : null,
            ),
            pw.SizedBox(height: 10),
            _statusBadge(bill.paymentStatus),
          ],
        ),
      ],
    );
  }

  // ─── Meta row (Bill #, Quotation #, Created By) ──────────────────────────────

  static pw.Widget _metaRow(BillModel bill) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _rowAlt,
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(children: [
        _metaCell('Bill No.', bill.billNumber),
        _dividerV(),
        _metaCell('Quotation', bill.quotationNumber ?? 'N/A'),
        _dividerV(),
        _metaCell('Prepared By', bill.createdByName),
      ]),
    );
  }

  // ─── Materials Table ────────────────────────────────────────────────────────

  static pw.Widget _materialsTable(BillModel bill) {
    final headers = ['#', 'Item', 'Qty', 'Rate', 'Disc', 'Tax', 'Amount'];
    final colWidths = [
      pw.FixedColumnWidth(24),
      pw.FlexColumnWidth(3),
      pw.FixedColumnWidth(40),
      pw.FixedColumnWidth(64),
      pw.FixedColumnWidth(50),
      pw.FixedColumnWidth(40),
      pw.FixedColumnWidth(72),
    ];

    final rows = <pw.TableRow>[
      _tableHeader(headers),
      ...bill.materialItems.asMap().entries.map((e) {
        final i = e.key;
        final it = e.value;
        String disc = '-';
        if (it.discountAmount > 0) {
          disc = it.discountType == DiscountType.percentage
              ? '${it.discountValue.toStringAsFixed(0)}%'
              : '${it.discountAmount.toStringAsFixed(2)}';
        }
        final tax = it.taxPercent > 0
            ? '${it.taxPercent.toStringAsFixed(0)}%'
            : '-';

        return _dataRow(
          isAlt: i.isOdd,
          cells: [
            _cell('${i + 1}', color: _slate, fontSize: 8),
            _nameCell(it.name, it.description),
            _cell('${it.quantity}', align: pw.TextAlign.center),
            _cell('${it.rate.toStringAsFixed(2)}',
                align: pw.TextAlign.right),
            _cell(disc,
                align: pw.TextAlign.right,
                color: it.discountAmount > 0 ? _danger : _slate),
            _cell(tax,
                align: pw.TextAlign.right,
                color: it.taxPercent > 0 ? _success : _slate),
            _cell('${it.total.toStringAsFixed(2)}',
                align: pw.TextAlign.right,
                bold: true),
          ],
        );
      }),
    ];

    // Totals rows
    if (bill.materialDiscountTotal > 0) {
      rows.add(_subtotalRow('Subtotal',
          '${bill.materialSubtotal.toStringAsFixed(2)}', 7));
      rows.add(_subtotalRow('Discount',
          '-${bill.materialDiscountTotal.toStringAsFixed(2)}', 7,
          valueColor: _danger));
    }
    if (bill.materialTaxTotal > 0) {
      rows.add(_subtotalRow(
          'Tax', '${bill.materialTaxTotal.toStringAsFixed(2)}', 7));
    }
    rows.add(_totalRow(
        'Materials Total', '${bill.materialTotal.toStringAsFixed(2)}', 7));

    return pw.Table(
      columnWidths: {for (var i = 0; i < colWidths.length; i++) i: colWidths[i]},
      children: rows,
    );
  }

  // ─── Labour Table ───────────────────────────────────────────────────────────

  static pw.Widget _labourTable(BillModel bill) {
    final headers = ['#', 'Service', 'Hrs', 'Rate/Hr', 'Disc', 'Amount'];
    final colWidths = [
      pw.FixedColumnWidth(24),
      pw.FlexColumnWidth(3),
      pw.FixedColumnWidth(40),
      pw.FixedColumnWidth(64),
      pw.FixedColumnWidth(50),
      pw.FixedColumnWidth(72),
    ];

    final rows = <pw.TableRow>[
      _tableHeader(headers),
      ...bill.labourItems.asMap().entries.map((e) {
        final i = e.key;
        final it = e.value;
        String disc = '-';
        if (it.discountAmount > 0) {
          disc = it.discountType == DiscountType.percentage
              ? '${it.discountValue.toStringAsFixed(0)}%'
              : '${it.discountAmount.toStringAsFixed(2)}';
        }
        return _dataRow(
          isAlt: i.isOdd,
          cells: [
            _cell('${i + 1}', color: _slate, fontSize: 8),
            _nameCell(it.name, it.description),
            _cell('${it.hours}', align: pw.TextAlign.center),
            _cell('${it.rate.toStringAsFixed(2)}',
                align: pw.TextAlign.right),
            _cell(disc,
                align: pw.TextAlign.right,
                color: it.discountAmount > 0 ? _danger : _slate),
            _cell('${it.total.toStringAsFixed(2)}',
                align: pw.TextAlign.right,
                bold: true),
          ],
        );
      }),
    ];

    if (bill.labourDiscountTotal > 0) {
      rows.add(_subtotalRow('Subtotal',
          '${bill.labourSubtotal.toStringAsFixed(2)}', 6));
      rows.add(_subtotalRow('Discount',
          '-${bill.labourDiscountTotal.toStringAsFixed(2)}', 6,
          valueColor: _danger));
    }
    rows.add(_totalRow(
        'Labour Total', '${bill.labourTotal.toStringAsFixed(2)}', 6));

    return pw.Table(
      columnWidths: {for (var i = 0; i < colWidths.length; i++) i: colWidths[i]},
      children: rows,
    );
  }

  // ─── Summary Block ──────────────────────────────────────────────────────────

  static pw.Widget _summaryBlock(BillModel bill) {
    final beforeDiscount = bill.materialTotal + bill.labourTotal;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 260,
          child: pw.Column(children: [
            _summaryLine('Materials', '${bill.materialTotal.toStringAsFixed(2)}'),
            if (bill.labourItems.isNotEmpty && bill.isLabourProvidedByUs)
              _summaryLine('Labour', '${bill.labourTotal.toStringAsFixed(2)}'),
            _summaryLine('Subtotal', '${beforeDiscount.toStringAsFixed(2)}'),
            if (bill.grandDiscountAmount > 0) ...[
              pw.Divider(color: _border, thickness: 0.5),
              _summaryLine(
                'Grand Discount'
                    '${bill.grandDiscountType == DiscountType.percentage ? ' (${bill.grandDiscountValue}%)' : ''}',
                '−${bill.grandDiscountAmount.toStringAsFixed(2)}',
                valueColor: _danger,
              ),
            ],
            pw.SizedBox(height: 6),
            // Grand Total band
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: _accent,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL DUE',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _white)),
                  pw.Text('${bill.grandTotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: _white)),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ─── Payment Block ──────────────────────────────────────────────────────────

  static pw.Widget _paymentBlock(BillModel bill) {
    final overdue = bill.paymentStatus != 'Paid' &&
        bill.dueDate.isBefore(DateTime.now());
    final statusLabel = overdue ? 'Overdue' : bill.paymentStatus;
    final statusColor = overdue ? _danger : _statusColor(bill.paymentStatus);

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('PAYMENT DETAILS',
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: _slate,
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 10),
          pw.Row(children: [
            pw.Expanded(child: _payCell('Amount Paid',
                '${bill.amountPaid.toStringAsFixed(2)}', _success)),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _payCell('Balance Due',
                '${bill.balanceDue.toStringAsFixed(2)}',
                bill.balanceDue <= 0 ? _success : _danger)),
            pw.SizedBox(width: 12),
            pw.Expanded(
                child: _payCell('Status', statusLabel.toUpperCase(), statusColor)),
          ]),
          if (bill.paymentMethod != null) ...[
            pw.SizedBox(height: 10),
            pw.Text('Payment Method: ${bill.paymentMethod}',
                style: pw.TextStyle(fontSize: 9, color: _slate)),
          ],
        ],
      ),
    );
  }

  // ─── Notes & Terms ──────────────────────────────────────────────────────────

  static pw.Widget _notesBlock(BillModel bill) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _rowAlt,
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (bill.notes?.isNotEmpty == true) ...[
            pw.Text('Notes',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink)),
            pw.SizedBox(height: 4),
            pw.Text(bill.notes!,
                style: const pw.TextStyle(fontSize: 9)),
            if (bill.termsAndConditions?.isNotEmpty == true)
              pw.SizedBox(height: 10),
          ],
          if (bill.termsAndConditions?.isNotEmpty == true) ...[
            pw.Text('Terms & Conditions',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink)),
            pw.SizedBox(height: 4),
            pw.Text(bill.termsAndConditions!,
                style: const pw.TextStyle(fontSize: 9)),
          ],
        ],
      ),
    );
  }

  // ─── Small Re-usable Widgets ─────────────────────────────────────────────────

  static pw.Widget _sectionLabel(String text) {
    return pw.Row(children: [
      pw.Container(
        width: 3,
        height: 14,
        decoration: pw.BoxDecoration(
          color: _accent,
          borderRadius: pw.BorderRadius.circular(2),
        ),
      ),
      pw.SizedBox(width: 6),
      pw.Text(text,
          style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _ink)),
    ]);
  }

  static pw.Widget _infoLine(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 9, color: _slate)),
    );
  }

  static pw.Widget _labelValue(String label, String value,
      {PdfColor? valueColor}) {
    return pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Text('$label: ',
          style: pw.TextStyle(fontSize: 9, color: _slate)),
      pw.Text(value,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: valueColor ?? _ink)),
    ]);
  }

  static pw.Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 0.8),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(status.toUpperCase(),
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: color)),
    );
  }

  static pw.Widget _metaCell(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 7,
                  color: _slate,
                  letterSpacing: 0.8)),
          pw.SizedBox(height: 3),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink)),
        ],
      ),
    );
  }

  static pw.Widget _dividerV() {
    return pw.Container(
      width: 0.5,
      height: 28,
      margin: const pw.EdgeInsets.symmetric(horizontal: 12),
      color: _border,
    );
  }

  // ─── Table Helpers ───────────────────────────────────────────────────────────

  static pw.TableRow _tableHeader(List<String> labels) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: _ink),
      children: labels
          .map((l) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(
            horizontal: 8, vertical: 7),
        child: pw.Text(l,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: _white),
            textAlign: l == '#' || l == 'Qty' || l == 'Hrs'
                ? pw.TextAlign.center
                : l == 'Item' || l == 'Service'
                ? pw.TextAlign.left
                : pw.TextAlign.right),
      ))
          .toList(),
    );
  }

  static pw.TableRow _dataRow({
    required bool isAlt,
    required List<pw.Widget> cells,
  }) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
          color: isAlt ? _rowAlt : _white),
      children: cells,
    );
  }

  static pw.TableRow _subtotalRow(String label, String value, int colSpan,
      {PdfColor? valueColor}) {
    final emptyCells = List.generate(
      colSpan - 2,
          (_) => pw.Container(
          padding: const pw.EdgeInsets.all(7),
          child: pw.Text('')),
    );
    return pw.TableRow(children: [
      ...emptyCells,
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(label,
            style: pw.TextStyle(fontSize: 8, color: _slate),
            textAlign: pw.TextAlign.right),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(value,
            style: pw.TextStyle(
                fontSize: 8,
                color: valueColor ?? _ink),
            textAlign: pw.TextAlign.right),
      ),
    ]);
  }

  static pw.TableRow _totalRow(String label, String value, int colSpan) {
    final emptyCells = List.generate(
      colSpan - 2,
          (_) => pw.Container(
          decoration: pw.BoxDecoration(color: _accentSoft),
          padding: const pw.EdgeInsets.all(7),
          child: pw.Text('')),
    );
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: _accentSoft),
      children: [
        ...emptyCells,
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _accent),
              textAlign: pw.TextAlign.right),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _accent),
              textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  static pw.Widget _cell(
      String text, {
        pw.TextAlign align = pw.TextAlign.left,
        PdfColor? color,
        bool bold = false,
        double fontSize = 9,
      }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? pw.FontWeight.bold : null,
            color: color ?? _ink),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _nameCell(String name, String? description) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name,
              style: const pw.TextStyle(fontSize: 9)),
          if (description?.isNotEmpty == true)
            pw.Text(description!,
                style: pw.TextStyle(fontSize: 7, color: _slate)),
        ],
      ),
    );
  }

  static pw.Widget _summaryLine(String label, String value,
      {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: _slate)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9,
                  color: valueColor ?? _ink)),
        ],
      ),
    );
  }

  static pw.Widget _payCell(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 7,
                  color: _slate,
                  letterSpacing: 0.8)),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  // ─── Utilities ───────────────────────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

  static PdfColor _statusColor(String status) {
    switch (status) {
      case 'Paid':    return _success;
      case 'Partial': return _warning;
      case 'Overdue': return _danger;
      default:        return _slate;
    }
  }
}