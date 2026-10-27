import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';

Future<pw.Document> _buildItemHistoryPdfDoc({
  required List<dynamic> entries,
  required String itemName,
  required String dateLabel,
  String companyName = '',
}) async {
  final pdf = pw.Document(
    title: 'Stock History - $itemName',
    author: companyName,
  );

  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );

  final now = DateTime.now();
  final money = NumberFormat('#,##0.00');
  final quantityFormat = NumberFormat('#,##0.########');

  const headerBg = PdfColors.white;
  const positive = PdfColor.fromInt(0xFF27AE60);
  const negative = PdfColor.fromInt(0xFFE74C3C);

  String fmtDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = ts as DateTime;
      return DateFormat('dd MMM yyyy hh:mm a').format(dt);
    } catch (_) {
      return '-';
    }
  }

  pw.Widget cell(
    String text, {
    bool head = false,
    bool isBold = false,
    bool right = true,
    PdfColor? color,
    double? size,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          font: (head || isBold) ? bold : regular,
          fontSize: size ?? (head ? 6.5 : 7.5),
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget infoRow(
    String label,
    String val, {
    bool end = false,
    PdfColor? valColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        mainAxisAlignment: end
            ? pw.MainAxisAlignment.end
            : pw.MainAxisAlignment.start,
        children: [
          pw.Text('$label:  ', style: pw.TextStyle(font: bold, fontSize: 10)),
          pw.Text(
            val,
            style: pw.TextStyle(
              font: regular,
              fontSize: 10,
              color: valColor ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget sectionLabel(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: bold,
        fontSize: 10,
        color: PdfColors.grey600,
        letterSpacing: 1.4,
      ),
    ),
  );

  double totalIn = 0, totalOut = 0, totalValue = 0;

  for (final e in entries) {
    final sign = e.sign as String;
    final qty = e.qty as double;
    final total = e.total as double;

    if (sign == '+') {
      totalIn += qty;
    } else {
      totalOut += qty;
      totalValue += total;
    }
  }

  final headers = <String>[
    '#',
    'DATE',
    'TYPE',
    '±QTY',
    'PRICE',
    'TOTAL',
    'MODE',
    'BRANCH',
    'STAFF',
    'TRNX ID',
  ];

  const leftCols = {0, 1, 2, 6, 7, 8, 9};

  final colWidths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(20),
    1: const pw.FlexColumnWidth(2.2),
    2: const pw.FlexColumnWidth(1.8),
    3: const pw.FlexColumnWidth(1),
    4: const pw.FlexColumnWidth(1),
    5: const pw.FlexColumnWidth(1.3),
    6: const pw.FlexColumnWidth(1.2),
    7: const pw.FlexColumnWidth(1.6),
    8: const pw.FlexColumnWidth(1.6),
    9: const pw.FlexColumnWidth(2.2),
  };

  final border = pw.TableBorder.all(color: PdfColors.grey300, width: 0.8);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.portrait,
      margin: const pw.EdgeInsets.all(24),
      footer: (ctx) => pw.Column(
        children: [
          pw.Divider(thickness: 0.1, color: PdfColors.grey),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(now)}',
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 9,
                  color: PdfColors.grey500,
                ),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 9,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
      build: (ctx) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  companyName.toUpperCase(),
                  style: pw.TextStyle(font: bold, fontSize: 22),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'STOCK HISTORY REPORT',
                  style: pw.TextStyle(font: bold, fontSize: 18),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  infoRow('Item', itemName),
                  infoRow('Period', dateLabel),
                  infoRow('Records', '${entries.length}'),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  infoRow(
                    'Stock In',
                    '+${quantityFormat.format(totalIn)} pcs',
                    end: true,
                    valColor: positive,
                  ),
                  infoRow(
                    'Stock Out',
                    '-${quantityFormat.format(totalOut)} pcs',
                    end: true,
                    valColor: negative,
                  ),
                  // infoRow('Total Value', 'GHS ${money.format(totalValue)}', end: true),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        sectionLabel('STOCK HISTORY'),
        pw.Table(
          border: border,
          columnWidths: colWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: headerBg),
              children: [
                for (int i = 0; i < headers.length; i++)
                  cell(headers[i], head: true, right: !leftCols.contains(i)),
              ],
            ),
            ...entries.asMap().entries.map((e) {
              final t = e.value;
              final sign = t.sign as String;
              final qtyStr = '$sign${quantityFormat.format(t.qty as double)}';

              return pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.white),
                children: [
                  cell('${e.key + 1}', right: false),
                  cell(fmtDate(t.date), right: false, size: 6.5),
                  cell(t.type as String, right: false),
                  cell(
                    qtyStr,
                    isBold: true,
                    color: sign == '+' ? positive : negative,
                  ),
                  cell((t.price as double).toStringAsFixed(2)),
                  cell((t.total as double).toStringAsFixed(2), isBold: true),
                  cell(t.mode as String, right: false),
                  cell(t.branch as String, right: false),
                  cell(t.staff as String, right: false),
                  cell(t.transactionid as String, right: false, size: 6.5),
                ],
              );
            }),
          ],
        ),
      ],
    ),
  );

  return pdf;
}

/// Opens the OS print / share dialog (the person can print or "Save as PDF"
/// from there). Works on every platform via the `printing` package.
Future<void> printItemHistory(
  BuildContext context, {
  required List<dynamic> entries,
  required String itemName,
  required String dateLabel,
  String companyName = '',
}) async {
  final pdf = await _buildItemHistoryPdfDoc(
    entries: entries,
    itemName: itemName,
    dateLabel: dateLabel,
    companyName: companyName,
  );

  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  await Printing.layoutPdf(
    onLayout: (_) async => pdf.save(),
    name: 'KologSoft_${itemName.replaceAll(' ', '_')}_$ts',
  );
}

/// Saves the PDF directly to disk / triggers a browser download — no print
/// dialog — on Android, iOS, Web, Windows, macOS and Linux.
Future<void> downloadItemHistoryPdf({
  required List<dynamic> entries,
  required String itemName,
  required String dateLabel,
  String companyName = '',
}) async {
  final pdf = await _buildItemHistoryPdfDoc(
    entries: entries,
    itemName: itemName,
    dateLabel: dateLabel,
    companyName: companyName,
  );

  final bytes = await pdf.save();
  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final fileName = 'KologSoft_${itemName.replaceAll(' ', '_')}_$ts';

  await FileSaver.instance.saveFile(
    name: fileName,
    bytes: Uint8List.fromList(bytes),
    fileExtension: 'pdf',
    mimeType: MimeType.pdf,
  );
}

/// Exports the same stock-history data to an .xlsx file, saved/downloaded
/// directly on every platform.
Future<void> exportItemHistoryExcel({
  required List<dynamic> entries,
  required String itemName,
  required String dateLabel,
  String companyName = '',
}) async {
  final quantityFormat = NumberFormat('#,##0.########');

  String fmtDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = ts as DateTime;
      return DateFormat('dd MMM yyyy hh:mm a').format(dt);
    } catch (_) {
      return '-';
    }
  }

  final excelFile = xls.Excel.createExcel();
  const sheetName = 'Stock History';
  final sheet = excelFile[sheetName];
  excelFile.delete('Sheet1');

  final titleStyle = xls.CellStyle(bold: true, fontSize: 16);
  final headerStyle = xls.CellStyle(
    bold: true,
    backgroundColorHex: xls.ExcelColor.fromHexString('#DDDDDD'),
  );

  // --- Title block ---
  sheet.appendRow([xls.TextCellValue(companyName.toUpperCase())]);
  sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .cellStyle =
      titleStyle;
  sheet.appendRow([xls.TextCellValue('STOCK HISTORY REPORT')]);
  sheet.appendRow([xls.TextCellValue('Item: $itemName')]);
  sheet.appendRow([xls.TextCellValue('Period: $dateLabel')]);
  sheet.appendRow([xls.TextCellValue('Records: ${entries.length}')]);
  sheet.appendRow([]); // spacer

  // --- Headers ---
  final headers = <String>[
    '#',
    'DATE',
    'TYPE',
    '±QTY',
    'PRICE',
    'TOTAL',
    'MODE',
    'BRANCH',
    'STAFF',
    'TRNX ID',
  ];
  sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());
  final headerRowIdx = sheet.maxRows - 1;
  for (int c = 0; c < headers.length; c++) {
    sheet
            .cell(
              xls.CellIndex.indexByColumnRow(
                columnIndex: c,
                rowIndex: headerRowIdx,
              ),
            )
            .cellStyle =
        headerStyle;
  }

  // --- Data rows ---
  for (int i = 0; i < entries.length; i++) {
    final t = entries[i];
    final sign = t.sign as String;
    final qty = t.qty as double;

    sheet.appendRow([
      xls.IntCellValue(i + 1),
      xls.TextCellValue(fmtDate(t.date)),
      xls.TextCellValue(t.type as String),
      xls.TextCellValue('$sign${quantityFormat.format(qty)}'),
      xls.DoubleCellValue((t.price as double)),
      xls.DoubleCellValue((t.total as double)),
      xls.TextCellValue(t.mode as String),
      xls.TextCellValue(t.branch as String),
      xls.TextCellValue(t.staff as String),
      xls.TextCellValue(t.transactionid as String),
    ]);
  }

  // --- Save (works on web, Windows, macOS, Linux, Android, iOS) ---
  final bytes = excelFile.encode();
  if (bytes == null) {
    throw Exception('Failed to encode Excel file — no data to export.');
  }

  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final fileName = '$companyName${itemName.replaceAll(' ', '_')}_history_$ts';

  await FileSaver.instance.saveFile(
    name: fileName,
    bytes: Uint8List.fromList(bytes),
    fileExtension: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}
