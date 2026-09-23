import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';

Future<void> printStockReportPdf({
  required List<Map<String, dynamic>> reportData,
  required String companyName,
  String branchName = 'All Branches',
  String dateRange = '',
  String? productType,
  String? category,
}) async {
  final pdf = pw.Document();

  final regular =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final bold =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

  final bool showTransfers = branchName != 'All Branches';
  final money = NumberFormat('#,##0.00');
  final now = DateTime.now();



  String fmt(dynamic v) {
    if (v == null) return '0';
    final d = double.tryParse(v.toString()) ?? 0.0;
    return d == d.truncateToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(2);
  }

  double num0(dynamic v) => double.tryParse('${v ?? 0}') ?? 0.0;

  pw.Widget cell(
      String text, {
        bool head = false,
        bool isBold = false,
        bool right = true,
      }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          font: (head || isBold) ? bold : regular,
          fontSize: head ? 6.5 : 7.5,
          // color: head ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget infoRow(String label, String val, {bool end = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        mainAxisAlignment:
        end ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
        children: [
          pw.Text('$label:  ', style: pw.TextStyle(font: bold, fontSize: 10)),
          pw.Text(val, style: pw.TextStyle(font: regular, fontSize: 10)),
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

  final headers = <String>[
    '#',
    'PRODUCT',
    'OPENING',
    'NEW',
    if (showTransfers) 'TRANSFER IN',
    'SALE RETURN',
    'TOTAL',
    'SALES',
    'PURCHASE RETURN',
    'DAMAGES',
    if (showTransfers) 'TRANSFER OUT',
    'PCS BAL',
    'CTN BAL',
  ];

  double totOpening = 0, totNew = 0, totTransferIn = 0, totSaleReturns = 0;
  double totTotal = 0, totSalesQty = 0;
  double totPurchaseRet = 0, totDamages = 0, totTransfer = 0, totBalance = 0;
  double totCP = 0, totSP = 0;

  for (final item in reportData) {
    totOpening     += num0(item['opening_stock']);
    totNew         += num0(item['newstock']);
    totTransferIn  += num0(item['transfer_recieved_qty']);
    totSaleReturns += num0(item['sale_returns']);
    totTotal       += num0(item['total_stock']);
    totSalesQty    += num0(item['sales_qty']);
    totPurchaseRet += num0(item['purchase_returns']);
    totDamages     += num0(item['damages']);
    totTransfer    += num0(item['transfer_qty']);
    totBalance     += num0(item['balance_cd']);
    totCP          += num0(item['stock_value']);
    totSP          += num0(item['selling_value']);
  }

  final colWidths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(20),
    1: const pw.FlexColumnWidth(3),
    for (int i = 2; i < headers.length; i++) i: const pw.FlexColumnWidth(1.1),
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
                    font: regular, fontSize: 9, color: PdfColors.grey500),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(
                    font: regular, fontSize: 9, color: PdfColors.grey500),
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
                pw.SizedBox(height: 2),
                pw.Text(
                  branchName,
                  style: pw.TextStyle(
                      font: regular, fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('STOCK REPORT',
                    style: pw.TextStyle(font: bold, fontSize: 18)),
                pw.SizedBox(height: 4),

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
                  infoRow('Period', dateRange),
                  infoRow('Products', '${reportData.length}'),
                  infoRow('Value @ Cost Price', money.format(totCP)),
                  infoRow('Value@Selling Price', money.format(totSP)),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  infoRow('Product Type', productType ?? 'All', end: true),
                  infoRow('Category', category ?? 'All', end: true),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        sectionLabel('STOCK'),
        pw.Table(
          border: border,
          columnWidths: colWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(),
              children: [
                for (int i = 0; i < headers.length; i++)
                  cell(headers[i], head: true, right: i != 1),
              ],
            ),
            ...reportData.asMap().entries.map((e) {
              final item = e.value;
              final balanceCd = num0(item['balance_cd']);
              final boxPiece =
                  double.tryParse(item['cartonqty_bal'].toString()) ?? 1;
              final carton = balanceCd / (boxPiece == 0 ? 1 : boxPiece);

              return pw.TableRow(
                children: [
                  cell('${e.key + 1}', right: false),
                  cell(item['item']?.toString() ?? '',
                      isBold: true, right: false),
                  cell(fmt(item['opening_stock'])),
                  cell(fmt(item['newstock'])),
                  if (showTransfers) cell(fmt(item['transfer_recieved_qty'])),
                  cell(fmt(item['sale_returns'])),
                  cell(fmt(item['total_stock'])),
                  cell(fmt(item['sales_qty'])),
                  cell(fmt(item['purchase_returns'])),
                  cell(fmt(item['damages'])),
                  if (showTransfers) cell(fmt(item['transfer_qty'])),
                  cell(fmt(balanceCd), isBold: true),
                  cell(carton > 0 ? fmt(carton) : '-'),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(),
              children: [
                cell(''),
                cell('GRAND TOTAL', isBold: true, right: false),
                cell(fmt(totOpening), isBold: true),
                cell(fmt(totNew), isBold: true),
                if (showTransfers) cell(fmt(totTransferIn), isBold: true),
                cell(fmt(totSaleReturns), isBold: true),
                cell(fmt(totTotal), isBold: true),
                cell(fmt(totSalesQty), isBold: true),
                cell(fmt(totPurchaseRet), isBold: true),
                cell(fmt(totDamages), isBold: true),
                if (showTransfers) cell(fmt(totTransfer), isBold: true),
                cell(fmt(totBalance), isBold: true),
                cell(''),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (_) async => pdf.save(),
    name: 'stock_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
}

Future<void> exportStockReportExcel({
  required List<Map<String, dynamic>> reportData,
  required String companyName,
  String branchName = 'All Branches',
  String dateRange = '',
  String? productType,
  String? category,
}) async {
  final bool showTransfers = branchName != 'All Branches';

  double num0(dynamic v) => double.tryParse('${v ?? 0}') ?? 0.0;

  final excelFile = xls.Excel.createExcel();
  final sheetName = 'Stock Report';
  final sheet = excelFile[sheetName];
  excelFile.delete('Sheet1');

  xls.CellStyle titleStyle = xls.CellStyle(
    bold: true,
    fontSize: 16,
  );
  xls.CellStyle headerStyle = xls.CellStyle(
    bold: true,
    backgroundColorHex: xls.ExcelColor.fromHexString('#DDDDDD'),
  );
  xls.CellStyle boldStyle = xls.CellStyle(bold: true);

  // --- Title block ---
  sheet.appendRow([xls.TextCellValue(companyName.toUpperCase())]);
  sheet.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
  sheet.appendRow([xls.TextCellValue('STOCK REPORT')]);
  sheet.appendRow([xls.TextCellValue('Branch: $branchName')]);
  sheet.appendRow([xls.TextCellValue('Period: $dateRange')]);
  sheet.appendRow([xls.TextCellValue('Product Type: ${productType ?? 'All'}')]);
  sheet.appendRow([xls.TextCellValue('Category: ${category ?? 'All'}')]);
  sheet.appendRow([]); // blank spacer row

  // --- Headers ---
  final headers = <String>[
    '#',
    'PRODUCT',
    'OPENING',
    'NEW',
    if (showTransfers) 'TRANSFER IN',
    'SALE RETURN',
    'TOTAL',
    'SALES',
    'PURCHASE RETURN',
    'DAMAGES',
    if (showTransfers) 'TRANSFER OUT',
    'PCS BAL',
    'CTN BAL',
  ];
  sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());
  final headerRowIdx = sheet.maxRows - 1;
  for (int c = 0; c < headers.length; c++) {
    sheet
        .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIdx))
        .cellStyle = headerStyle;
  }

  // --- Data rows + totals ---
  double totOpening = 0, totNew = 0, totTransferIn = 0, totSaleReturns = 0;
  double totTotal = 0, totSalesQty = 0;
  double totPurchaseRet = 0, totDamages = 0, totTransfer = 0, totBalance = 0;

  for (int i = 0; i < reportData.length; i++) {
    final item = reportData[i];
    final balanceCd = num0(item['balance_cd']);
    final boxPiece = double.tryParse(item['cartonqty_bal'].toString()) ?? 1;
    final carton = balanceCd / (boxPiece == 0 ? 1 : boxPiece);

    totOpening     += num0(item['opening_stock']);
    totNew         += num0(item['newstock']);
    totTransferIn  += num0(item['transfer_recieved_qty']);
    totSaleReturns += num0(item['sale_returns']);
    totTotal       += num0(item['total_stock']);
    totSalesQty    += num0(item['sales_qty']);
    totPurchaseRet += num0(item['purchase_returns']);
    totDamages     += num0(item['damages']);
    totTransfer    += num0(item['transfer_qty']);
    totBalance     += balanceCd;

    sheet.appendRow([
      xls.IntCellValue(i + 1),
      xls.TextCellValue(item['item']?.toString() ?? ''),
      xls.DoubleCellValue(num0(item['opening_stock'])),
      xls.DoubleCellValue(num0(item['newstock'])),
      if (showTransfers) xls.DoubleCellValue(num0(item['transfer_recieved_qty'])),
      xls.DoubleCellValue(num0(item['sale_returns'])),
      xls.DoubleCellValue(num0(item['total_stock'])),
      xls.DoubleCellValue(num0(item['sales_qty'])),
      xls.DoubleCellValue(num0(item['purchase_returns'])),
      xls.DoubleCellValue(num0(item['damages'])),
      if (showTransfers) xls.DoubleCellValue(num0(item['transfer_qty'])),
      xls.DoubleCellValue(balanceCd),
      xls.TextCellValue(carton > 0 ? carton.toStringAsFixed(2) : '-'),
    ]);
  }

  // --- Grand total row ---
  sheet.appendRow([
    xls.TextCellValue(''),
    xls.TextCellValue('GRAND TOTAL'),
    xls.DoubleCellValue(totOpening),
    xls.DoubleCellValue(totNew),
    if (showTransfers) xls.DoubleCellValue(totTransferIn),
    xls.DoubleCellValue(totSaleReturns),
    xls.DoubleCellValue(totTotal),
    xls.DoubleCellValue(totSalesQty),
    xls.DoubleCellValue(totPurchaseRet),
    xls.DoubleCellValue(totDamages),
    if (showTransfers) xls.DoubleCellValue(totTransfer),
    xls.DoubleCellValue(totBalance),
    xls.TextCellValue(''),
  ]);
  final totalRowIdx = sheet.maxRows - 1;
  for (int c = 0; c < headers.length; c++) {
    sheet
        .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx))
        .cellStyle = boldStyle;
  }


  final bytes = excelFile.encode();
  if (bytes == null) {
    throw Exception('Failed to encode Excel file — no data to export.');
  }

  final fileName = 'stock_report_${DateTime.now().millisecondsSinceEpoch}';

  try {
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  } catch (e) {

    rethrow;
  }
}