// salesreturnpdf.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class SalesReturnPdf {
  static Future<void> generate({
    required Map<String, dynamic> header,
    required Map<String, dynamic> itemsMap,
    String heading = 'RETURN SALES',
  }) async {
    final pdf = pw.Document(
      title: '$heading - ${header['receiptid'] ?? ''}',
      author: header['createdby'] ?? '',
    );

    final ttfRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final ttfBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );

    final timestamp = header['createdat'];
    final DateTime date = timestamp is Timestamp
        ? timestamp.toDate()
        : timestamp is DateTime
        ? timestamp
        : DateTime.now();

    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    final items = itemsMap.values.whereType<Map>().map((rawItem) {
      final item = Map<String, dynamic>.from(rawItem);
      return item.map(
        (key, value) => MapEntry(
          key.startsWith('returned_') ? key.substring(9) : key,
          value,
        ),
      );
    }).toList();

    // Grand total from returned_totalamount (already remapped → totalamount)
    final double grandTotal = items.fold(0.0, (sum, item) {
      return sum +
          (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
    });

    // ── Colors ──
    const dividerColor = PdfColor.fromInt(0xFFDDDDDD);
    const darkText = PdfColor.fromInt(0xFF1A1A2E);
    const mutedText = PdfColor.fromInt(0xFF666666);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        build: (context) => [
          //HEADER
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          (header['company'] ?? '').toString().toUpperCase(),
                          style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 20,
                            color: darkText,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          header['branchname']?.toString() ?? '',
                          style: pw.TextStyle(
                            font: ttfRegular,
                            fontSize: 12,
                            color: darkText,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          heading.toUpperCase(),
                          style: pw.TextStyle(
                            font: ttfBold,
                            fontSize: 11,
                            color: darkText,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          dateFormat.format(date),
                          style: pw.TextStyle(
                            font: ttfRegular,
                            fontSize: 11,
                            color: darkText,
                          ),
                        ),
                        pw.Text(
                          timeFormat.format(date),
                          style: pw.TextStyle(
                            font: ttfRegular,
                            fontSize: 10,
                            color: darkText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),
                pw.Divider(color: dividerColor, thickness: 0.5),
                pw.SizedBox(height: 12),

                // Return reference + Staff row
                pw.Row(
                  children: [
                    _infoChip(
                      ttfRegular: ttfRegular,
                      ttfBold: ttfBold,
                      label: 'RETURN SALES',
                      value: '#${header['receiptid']?.toString() ?? ''}',
                    ),
                    pw.SizedBox(width: 16),
                    _infoChip(
                      ttfRegular: ttfRegular,
                      ttfBold: ttfBold,
                      label: 'STAFF',
                      value: header['createdby']?.toString() ?? '',
                    ),
                    pw.SizedBox(width: 16),
                    _infoChip(
                      ttfRegular: ttfRegular,
                      ttfBold: ttfBold,
                      label: 'TRANS MODE',
                      value: (header['transmode'] ?? '')
                          .toString()
                          .toUpperCase(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // ── ITEMS TABLE ──────────────────────────────────────
          pw.Text(
            'RETURNED ITEMS',
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 11,
              color: mutedText,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),

          pw.Table(
            border: pw.TableBorder(
              bottom: pw.BorderSide(color: dividerColor, width: 0.5),
              horizontalInside: pw.BorderSide(color: dividerColor, width: 0.3),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.4), // #
              1: pw.FlexColumnWidth(2.8), // Item
              2: pw.FlexColumnWidth(0.8), // Qty
              3: pw.FlexColumnWidth(0.9), // Mode
              4: pw.FlexColumnWidth(0.9), // Price
              5: pw.FlexColumnWidth(0.9), // Total
              6: pw.FlexColumnWidth(1.2), // Condition
            },
            children: [
              // Table header
              pw.TableRow(
                children: [
                  _th('#', ttfBold),
                  _th('ITEM', ttfBold),
                  _th('QTY', ttfBold),
                  _th('MODE', ttfBold),
                  _th('PRICE', ttfBold),
                  _th('TOTAL', ttfBold),
                  _th('CONDITION', ttfBold),
                ],
              ),
              // Data rows
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final qty =
                    (item['quantity'] ?? item['totalpieces'])?.toString() ??
                    '0';
                final mode = item['mode']?.toString() ?? '';
                final price = item['price']?.toString() ?? '0';
                final total = item['totalamount']?.toString() ?? '0';
                final condition = item['condition']?.toString() ?? '';
                final itemName = item['item']?.toString() ?? '';

                return pw.TableRow(
                  children: [
                    _td('${i + 1}', ttfRegular, center: true),
                    _td(itemName, ttfBold),
                    _td(qty, ttfRegular, center: true),
                    _td(mode, ttfRegular),
                    _td('GHS $price', ttfRegular),
                    _td('GHS $total', ttfBold),
                    _tdCondition(condition, ttfRegular),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),

          // ── TOTAL SECTION ────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.all(16),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Items Returned:',
                        style: pw.TextStyle(
                          font: ttfRegular,
                          fontSize: 11,
                          color: darkText,
                        ),
                      ),
                      pw.Text(
                        '${items.length}',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 11,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: dividerColor, thickness: 0.5),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL RETURN:',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 13,
                          color: darkText,
                        ),
                      ),
                      pw.Text(
                        'GHS ${grandTotal.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 14,
                          color: darkText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 24),

          // ── FOOTER
          pw.Divider(color: dividerColor, thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'This is a computer-generated sales return document.',
              style: pw.TextStyle(
                font: ttfRegular,
                fontSize: 9,
                color: mutedText,
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ── Helpers

  static pw.Widget _infoChip({
    required pw.Font ttfRegular,
    required pw.Font ttfBold,
    required String label,
    required String value,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: ttfRegular,
            fontSize: 8,
            color: const PdfColor.fromInt(0xFF666666),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: ttfBold,
            fontSize: 11,
            color: const PdfColor.fromInt(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  static pw.Widget _th(String text, pw.Font ttfBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: ttfBold,
          fontSize: 9,
          color: const PdfColor.fromInt(0xFF333333),
        ),
      ),
    );
  }

  static pw.Widget _td(String text, pw.Font font, {bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          color: const PdfColor.fromInt(0xFF222222),
        ),
      ),
    );
  }

  static pw.Widget _tdCondition(String condition, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        condition,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          color: const PdfColor.fromInt(0xFF222222),
        ),
      ),
    );
  }
}
