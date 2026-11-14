import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';

String _stockReportFileName(String companyName) {
  final safeCompanyName = companyName
      .trim()
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '');
  return '${safeCompanyName.isEmpty ? 'Company' : safeCompanyName}'
      '_stock_report_${DateTime.now().millisecondsSinceEpoch}';
}

Future<void> printStockReportPdf({
  required List<Map<String, dynamic>> reportData,
  required String companyName,
  String branchName = 'All Branches',
  String dateRange = '',
  String? productType,
  String? category,
  bool download = false,
}) async {
  final pdf = pw.Document(
    title: '$companyName - Stock Report',
    author: companyName,
  );

  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );

  final bool showTransfers = branchName != 'All Branches';
  final money = NumberFormat('#,##0.00');
  final now = DateTime.now();

  String fmt(dynamic v) {
    if (v == null) return '0';
    final d = (double.tryParse(v.toString()) ?? 0.0).abs();
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
    bool center = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: center
            ? pw.TextAlign.center
            : right
            ? pw.TextAlign.right
            : pw.TextAlign.left,
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
        mainAxisAlignment: end
            ? pw.MainAxisAlignment.end
            : pw.MainAxisAlignment.start,
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
    'PIECES BALANCE',
    'CARTON BALANCE',
    'COST VALUE (GHS)',
    'SELLING VALUE (GHS)',
  ];

  double totOpening = 0, totNew = 0, totTransferIn = 0, totSaleReturns = 0;
  double totTotal = 0, totSalesQty = 0;
  double totPurchaseRet = 0, totDamages = 0, totTransfer = 0, totBalance = 0;
  double totCP = 0, totSP = 0;

  for (final item in reportData) {
    totOpening += num0(item['opening_stock']);
    totNew += num0(item['newstock']);
    totTransferIn += num0(item['transfer_recieved_qty']);
    totSaleReturns += num0(item['sale_returns']);
    totTotal += num0(item['total_stock']);
    totSalesQty += num0(item['sales_qty']);
    totPurchaseRet += num0(item['purchase_returns']);
    totDamages += num0(item['damages']);
    totTransfer += num0(item['transfer_qty']);
    totBalance += num0(item['balance_cd']);
    totCP += num0(item['stock_value']);
    totSP += num0(item['selling_value']);
  }

  final colWidths = <int, pw.TableColumnWidth>{
    0: const pw.FixedColumnWidth(34),
    1: const pw.FlexColumnWidth(2.5),
    for (int i = 2; i < headers.length; i++) i: const pw.FlexColumnWidth(1),
  };

  final border = pw.TableBorder.all(color: PdfColors.grey300, width: 0.8);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
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
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              companyName.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: bold, fontSize: 22),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              branchName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: regular,
                fontSize: 11,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'STOCK REPORT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: bold, fontSize: 18),
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
                  cell(headers[i], head: true, right: false, center: true),
              ],
            ),
            ...reportData.asMap().entries.map((e) {
              final item = e.value;
              final balanceCd = num0(item['balance_cd']);
              final boxPiece = num0(item['cartonqty_bal']).abs();
              final carton = balanceCd.abs() / (boxPiece == 0 ? 1 : boxPiece);

              return pw.TableRow(
                children: [
                  cell('${e.key + 1}', right: false, center: true),
                  cell(
                    item['item']?.toString() ?? '',
                    isBold: true,
                    right: false,
                  ),
                  cell(fmt(item['opening_stock']), right: false, center: true),
                  cell(fmt(item['newstock']), right: false, center: true),
                  if (showTransfers)
                    cell(
                      fmt(item['transfer_recieved_qty']),
                      right: false,
                      center: true,
                    ),
                  cell(fmt(item['sale_returns']), right: false, center: true),
                  cell(fmt(item['total_stock']), right: false, center: true),
                  cell(fmt(item['sales_qty']), right: false, center: true),
                  cell(
                    fmt(item['purchase_returns']),
                    right: false,
                    center: true,
                  ),
                  cell(fmt(item['damages']), right: false, center: true),
                  if (showTransfers)
                    cell(fmt(item['transfer_qty']), right: false, center: true),
                  cell(
                    fmt(balanceCd),
                    isBold: true,
                    right: false,
                    center: true,
                  ),
                  cell(
                    carton > 0 ? fmt(carton) : '-',
                    right: false,
                    center: true,
                  ),
                  cell(
                    money.format(num0(item['stock_value']).abs()),
                    right: false,
                    center: true,
                  ),
                  cell(
                    money.format(num0(item['selling_value']).abs()),
                    right: false,
                    center: true,
                  ),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(),
              children: [
                cell(''),
                cell('GRAND TOTAL', isBold: true, right: false),
                cell(fmt(totOpening), isBold: true, right: false, center: true),
                cell(fmt(totNew), isBold: true, right: false, center: true),
                if (showTransfers)
                  cell(
                    fmt(totTransferIn),
                    isBold: true,
                    right: false,
                    center: true,
                  ),
                cell(
                  fmt(totSaleReturns),
                  isBold: true,
                  right: false,
                  center: true,
                ),
                cell(fmt(totTotal), isBold: true, right: false, center: true),
                cell(
                  fmt(totSalesQty),
                  isBold: true,
                  right: false,
                  center: true,
                ),
                cell(
                  fmt(totPurchaseRet),
                  isBold: true,
                  right: false,
                  center: true,
                ),
                cell(fmt(totDamages), isBold: true, right: false, center: true),
                if (showTransfers)
                  cell(
                    fmt(totTransfer),
                    isBold: true,
                    right: false,
                    center: true,
                  ),
                cell(fmt(totBalance), isBold: true, right: false, center: true),
                cell(''),
                cell(
                  money.format(totCP.abs()),
                  isBold: true,
                  right: false,
                  center: true,
                ),
                cell(
                  money.format(totSP.abs()),
                  isBold: true,
                  right: false,
                  center: true,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  if (download) {
    final bytes = await pdf.save();
    await FileSaver.instance.saveFile(
      name: _stockReportFileName(companyName),
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  } else {
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: '${_stockReportFileName(companyName)}.pdf',
    );
  }
}

Future<void> exportStockReportWord({
  required List<Map<String, dynamic>> reportData,
  required String companyName,
  String branchName = 'All Branches',
  String dateRange = '',
  String? productType,
  String? category,
}) async {
  final showTransfers = branchName != 'All Branches';
  final headers = [
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
    'PIECES BALANCE',
    'CARTON BALANCE',
    'COST VALUE (GHS)',
    'SELLING VALUE (GHS)',
  ];
  double number(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;
  final quantityFormat = NumberFormat('#,##0.##');
  final moneyFormat = NumberFormat('#,##0.00');
  String escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
  String cell(String value, {bool product = false}) =>
      '<td class="${product ? 'product' : 'number'}">${escape(value)}</td>';
  final rows = reportData.asMap().entries.map((entry) {
    final item = entry.value;
    final balance = number(item['balance_cd']).abs();
    final packSize = number(item['cartonqty_bal']).abs();
    final values = [
      cell('${entry.key + 1}'),
      cell(item['item']?.toString() ?? '', product: true),
      cell(quantityFormat.format(number(item['opening_stock']).abs())),
      cell(quantityFormat.format(number(item['newstock']).abs())),
      if (showTransfers)
        cell(
          quantityFormat.format(number(item['transfer_recieved_qty']).abs()),
        ),
      cell(quantityFormat.format(number(item['sale_returns']).abs())),
      cell(quantityFormat.format(number(item['total_stock']).abs())),
      cell(quantityFormat.format(number(item['sales_qty']).abs())),
      cell(quantityFormat.format(number(item['purchase_returns']).abs())),
      cell(quantityFormat.format(number(item['damages']).abs())),
      if (showTransfers)
        cell(quantityFormat.format(number(item['transfer_qty']).abs())),
      cell(quantityFormat.format(balance)),
      cell(packSize == 0 ? '-' : quantityFormat.format(balance / packSize)),
      cell(moneyFormat.format(number(item['stock_value']).abs())),
      cell(moneyFormat.format(number(item['selling_value']).abs())),
    ];
    return '<tr>${values.join()}</tr>';
  }).join();
  double sum(String key) =>
      reportData.fold(0, (total, item) => total + number(item[key]).abs());
  final totalCostValue = sum('stock_value');
  final totalSellingValue = sum('selling_value');
  final totalCells = [
    cell(''),
    cell('GRAND TOTAL', product: true),
    cell(quantityFormat.format(sum('opening_stock'))),
    cell(quantityFormat.format(sum('newstock'))),
    if (showTransfers)
      cell(quantityFormat.format(sum('transfer_recieved_qty'))),
    cell(quantityFormat.format(sum('sale_returns'))),
    cell(quantityFormat.format(sum('total_stock'))),
    cell(quantityFormat.format(sum('sales_qty'))),
    cell(quantityFormat.format(sum('purchase_returns'))),
    cell(quantityFormat.format(sum('damages'))),
    if (showTransfers) cell(quantityFormat.format(sum('transfer_qty'))),
    cell(quantityFormat.format(sum('balance_cd'))),
    cell(''),
    cell(moneyFormat.format(sum('stock_value'))),
    cell(moneyFormat.format(sum('selling_value'))),
  ];
  final columnWidths = [
    4,
    18,
    ...List<double>.filled(headers.length - 2, 78 / (headers.length - 2)),
  ];
  final colGroup = columnWidths
      .map((width) => '<col style="width:${width.toStringAsFixed(2)}%">')
      .join();
  final html =
      '''
<!doctype html><html><head><meta charset="utf-8"><style>
@page{size:landscape;margin:0.4in}
body{font-family:Arial,sans-serif;font-size:10px;color:#111;margin:0}
h1,h2{text-align:center;margin:0}
h1{font-size:22px;margin-bottom:2px}
h2{font-size:18px;margin:6px 0 10px}
.branch{text-align:center;color:#666;font-size:11px;margin:0}
.metadata{width:100%;border-collapse:collapse;margin:0 0 14px;font-size:10px}
.metadata td{width:50%;border:0;padding:0;vertical-align:top}
.metadata td:last-child{text-align:right}
.metadata p{margin:0 0 5px}
.section{font-size:10px;font-weight:bold;letter-spacing:1.4px;color:#666;margin:0 0 6px}
table{border-collapse:collapse;width:100%;table-layout:fixed;font-size:8px}
thead{display:table-header-group}
tr{page-break-inside:avoid}
th,td{border:1px solid #888;padding:4px;text-align:center;vertical-align:middle;overflow-wrap:break-word}
th{background:#e5e7eb;font-weight:bold}
td.product{text-align:left}
tfoot td{font-weight:bold;background:#f1f1f1}
</style><title>${escape(companyName)} - Stock Report</title></head><body>
<h1>${escape(companyName.toUpperCase())}</h1>
<p class="branch">${escape(branchName)}</p>
<h2>STOCK REPORT</h2>
<table class="metadata"><tr>
<td>
<p><b>Period:</b> ${escape(dateRange)}</p>
<p><b>Products:</b> ${reportData.length}</p>
<p><b>Value @ Cost Price:</b> ${moneyFormat.format(totalCostValue)}</p>
<p><b>Value @ Selling Price:</b> ${moneyFormat.format(totalSellingValue)}</p>
</td>
<td>
<p><b>Product Type:</b> ${escape(productType ?? 'All')}</p>
<p><b>Category:</b> ${escape(category ?? 'All')}</p>
</td>
</tr></table>
<p class="section">STOCK</p>
<table><colgroup>$colGroup</colgroup>
<thead><tr>${headers.map((header) => '<th>${escape(header)}</th>').join()}</tr></thead>
<tbody>$rows</tbody><tfoot><tr>${totalCells.join()}</tr></tfoot></table></body></html>
''';
  await FileSaver.instance.saveFile(
    name: _stockReportFileName(companyName),
    bytes: Uint8List.fromList(utf8.encode(html)),
    fileExtension: 'doc',
    mimeType: MimeType.custom,
    customMimeType: 'application/msword',
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
    horizontalAlign: xls.HorizontalAlign.Center,
  );
  // --- Title block ---
  sheet.appendRow([xls.TextCellValue(companyName.toUpperCase())]);
  sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .cellStyle =
      titleStyle;
  sheet.appendRow([xls.TextCellValue('STOCK REPORT')]);
  sheet
      .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      .cellStyle = xls.CellStyle(
    bold: true,
    fontSize: 14,
    horizontalAlign: xls.HorizontalAlign.Center,
  );
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
    'PIECES BALANCE',
    'CARTON BALANCE',
    'COST VALUE (GHS)',
    'SELLING VALUE (GHS)',
  ];
  final lastColumn = headers.length - 1;
  for (final rowIndex in [0, 1]) {
    sheet.merge(
      xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      xls.CellIndex.indexByColumnRow(
        columnIndex: lastColumn,
        rowIndex: rowIndex,
      ),
    );
  }
  for (final rowIndex in [2, 3, 4, 5]) {
    sheet.merge(
      xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      xls.CellIndex.indexByColumnRow(
        columnIndex: lastColumn,
        rowIndex: rowIndex,
      ),
    );
    sheet
        .cell(
          xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
        )
        .cellStyle = xls.CellStyle(
      horizontalAlign: xls.HorizontalAlign.Left,
    );
  }
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
        .cellStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#DDDDDD'),
      horizontalAlign: xls.HorizontalAlign.Center,
    );
  }
  sheet.setColumnWidth(0, 6);
  sheet.setColumnWidth(1, 30);
  for (int c = 2; c < headers.length; c++) {
    sheet.setColumnWidth(c, c >= headers.length - 2 ? 18 : 14);
  }

  // --- Data rows + totals ---
  double totOpening = 0, totNew = 0, totTransferIn = 0, totSaleReturns = 0;
  double totTotal = 0, totSalesQty = 0;
  double totPurchaseRet = 0, totDamages = 0, totTransfer = 0, totBalance = 0;
  double totCostValue = 0, totSellingValue = 0;

  for (int i = 0; i < reportData.length; i++) {
    final item = reportData[i];
    final balanceCd = num0(item['balance_cd']).abs();
    final boxPiece = num0(item['cartonqty_bal']).abs();
    final carton = balanceCd / (boxPiece == 0 ? 1 : boxPiece);

    totOpening += num0(item['opening_stock']);
    totNew += num0(item['newstock']);
    totTransferIn += num0(item['transfer_recieved_qty']);
    totSaleReturns += num0(item['sale_returns']);
    totTotal += num0(item['total_stock']);
    totSalesQty += num0(item['sales_qty']);
    totPurchaseRet += num0(item['purchase_returns']);
    totDamages += num0(item['damages']);
    totTransfer += num0(item['transfer_qty']);
    totBalance += balanceCd;
    totCostValue += num0(item['stock_value']);
    totSellingValue += num0(item['selling_value']);

    sheet.appendRow([
      xls.IntCellValue(i + 1),
      xls.TextCellValue(item['item']?.toString() ?? ''),
      xls.DoubleCellValue(num0(item['opening_stock']).abs()),
      xls.DoubleCellValue(num0(item['newstock']).abs()),
      if (showTransfers)
        xls.DoubleCellValue(num0(item['transfer_recieved_qty']).abs()),
      xls.DoubleCellValue(num0(item['sale_returns']).abs()),
      xls.DoubleCellValue(num0(item['total_stock']).abs()),
      xls.DoubleCellValue(num0(item['sales_qty']).abs()),
      xls.DoubleCellValue(num0(item['purchase_returns']).abs()),
      xls.DoubleCellValue(num0(item['damages']).abs()),
      if (showTransfers) xls.DoubleCellValue(num0(item['transfer_qty']).abs()),
      xls.DoubleCellValue(balanceCd),
      xls.TextCellValue(carton > 0 ? carton.toStringAsFixed(2) : '-'),
      xls.DoubleCellValue(num0(item['stock_value']).abs()),
      xls.DoubleCellValue(num0(item['selling_value']).abs()),
    ]);
    final dataRowIndex = sheet.maxRows - 1;
    for (int columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      if (columnIndex == 1) continue;
      sheet
          .cell(
            xls.CellIndex.indexByColumnRow(
              columnIndex: columnIndex,
              rowIndex: dataRowIndex,
            ),
          )
          .cellStyle = xls.CellStyle(
        horizontalAlign: xls.HorizontalAlign.Center,
        numberFormat: columnIndex >= headers.length - 2
            ? xls.NumFormat.custom(formatCode: '#,##0.00')
            : xls.NumFormat.custom(formatCode: '#,##0.##'),
      );
    }
  }

  // --- Grand total row ---
  sheet.appendRow([
    xls.TextCellValue(''),
    xls.TextCellValue('GRAND TOTAL'),
    xls.DoubleCellValue(totOpening.abs()),
    xls.DoubleCellValue(totNew.abs()),
    if (showTransfers) xls.DoubleCellValue(totTransferIn.abs()),
    xls.DoubleCellValue(totSaleReturns.abs()),
    xls.DoubleCellValue(totTotal.abs()),
    xls.DoubleCellValue(totSalesQty.abs()),
    xls.DoubleCellValue(totPurchaseRet.abs()),
    xls.DoubleCellValue(totDamages.abs()),
    if (showTransfers) xls.DoubleCellValue(totTransfer.abs()),
    xls.DoubleCellValue(totBalance.abs()),
    xls.TextCellValue(''),
    xls.DoubleCellValue(totCostValue.abs()),
    xls.DoubleCellValue(totSellingValue.abs()),
  ]);
  final totalRowIdx = sheet.maxRows - 1;
  for (int c = 0; c < headers.length; c++) {
    sheet
        .cell(
          xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx),
        )
        .cellStyle = xls.CellStyle(
      bold: true,
      horizontalAlign: c == 1
          ? xls.HorizontalAlign.Left
          : xls.HorizontalAlign.Center,
      numberFormat: c >= headers.length - 2
          ? xls.NumFormat.custom(formatCode: '#,##0.00')
          : xls.NumFormat.custom(formatCode: '#,##0.##'),
    );
  }

  final bytes = excelFile.encode();
  if (bytes == null) {
    throw Exception('Failed to encode Excel file — no data to export.');
  }

  final fileName = _stockReportFileName(companyName);

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
