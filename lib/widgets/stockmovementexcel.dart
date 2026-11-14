import 'dart:typed_data';
import 'dart:convert';

import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

Future<void> exportStockMovementExcel({
  required List<Map<String, dynamic>> transactions,
  required String companyName,
  required String itemName,
  required String branchName,
  required DateTime startDate,
  required DateTime endDate,
  required double? boxPiece,
}) async {
  double number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  final excelFile = xls.Excel.createExcel();
  const sheetName = 'Stock Movement';
  final sheet = excelFile[sheetName];
  excelFile.delete('Sheet1');

  final titleStyle = xls.CellStyle(bold: true, fontSize: 16);
  final headerStyle = xls.CellStyle(
    bold: true,
    backgroundColorHex: xls.ExcelColor.fromHexString('#DDDDDD'),
  );

  sheet.appendRow([xls.TextCellValue(companyName.toUpperCase())]);
  sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .cellStyle =
      titleStyle;
  sheet.appendRow([xls.TextCellValue('STOCK MOVEMENT REPORT')]);
  sheet.appendRow([xls.TextCellValue('Item: $itemName')]);
  sheet.appendRow([xls.TextCellValue('Branch: $branchName')]);
  sheet.appendRow([
    xls.TextCellValue(
      'Period: ${DateFormat('yyyy-MM-dd').format(startDate)} - '
      '${DateFormat('yyyy-MM-dd').format(endDate)}',
    ),
  ]);
  sheet.appendRow([xls.TextCellValue('Records: ${transactions.length}')]);
  sheet.appendRow([]);

  final headers = [
    '#',
    'Date',
    'Opening',
    'New Stock',
    'Transfer In',
    'Transfer Out',
    'Sales Qty',
    'Sale Return',
    'Purchase Return',
    'Damages',
    'Pieces Balance',
    'Carton Balance',
  ];
  sheet.appendRow(headers.map(xls.TextCellValue.new).toList());
  final headerRow = sheet.maxRows - 1;
  for (var column = 0; column < headers.length; column++) {
    sheet
            .cell(
              xls.CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: headerRow,
              ),
            )
            .cellStyle =
        headerStyle;
  }

  final cartonSize = boxPiece ?? 1;
  for (var index = 0; index < transactions.length; index++) {
    final transaction = transactions[index];
    final balance = number(transaction['balance_cd']);

    sheet.appendRow([
      xls.IntCellValue(index + 1),
      xls.TextCellValue(transaction['date']?.toString() ?? ''),
      xls.DoubleCellValue(number(transaction['opening_stock'])),
      xls.DoubleCellValue(number(transaction['newstock'])),
      xls.DoubleCellValue(number(transaction['transfer_recieved_qty'])),
      xls.DoubleCellValue(
        number(transaction['transfer'] ?? transaction['transfer_qty']),
      ),
      xls.DoubleCellValue(number(transaction['sales_qty'])),
      xls.DoubleCellValue(number(transaction['sale_returns'])),
      xls.DoubleCellValue(number(transaction['purchase_returns'])),
      xls.DoubleCellValue(number(transaction['damages'])),
      xls.DoubleCellValue(balance),
      xls.DoubleCellValue(balance / (cartonSize == 0 ? 1 : cartonSize)),
    ]);
  }

  final bytes = excelFile.encode();
  if (bytes == null) {
    throw Exception('Failed to encode the stock movement Excel file.');
  }

  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final safeItemName = itemName.trim().replaceAll(
    RegExp(r'[^A-Za-z0-9_-]+'),
    '_',
  );
  final safeCompanyName = companyName.trim().replaceAll(
    RegExp(r'[^A-Za-z0-9_-]+'),
    '_',
  );
  await FileSaver.instance.saveFile(
    name: '${safeCompanyName}_stock_movement_${safeItemName}_$timestamp',
    bytes: Uint8List.fromList(bytes),
    fileExtension: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}

Future<void> exportStockMovementWord({
  required List<Map<String, dynamic>> transactions,
  required String companyName,
  required String itemName,
  required String branchName,
  required DateTime startDate,
  required DateTime endDate,
  required double? boxPiece,
}) async {
  double number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  String escape(Object? value) => (value?.toString() ?? '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  final packSize = boxPiece ?? 1;
  const headers = [
    '#',
    'Date',
    'Opening',
    'New Stock',
    'Transfer In',
    'Transfer Out',
    'Sales Qty',
    'Sale Return',
    'Purchase Return',
    'Damages',
    'Pieces Balance',
    'Carton Balance',
  ];
  final rows = transactions.asMap().entries.map((entry) {
    final transaction = entry.value;
    final balance = number(transaction['balance_cd']);
    final values = [
      entry.key + 1,
      transaction['date'] ?? '',
      transaction['opening_stock'] ?? 0,
      transaction['newstock'] ?? 0,
      transaction['transfer_recieved_qty'] ?? 0,
      transaction['transfer'] ?? transaction['transfer_qty'] ?? 0,
      transaction['sales_qty'] ?? 0,
      transaction['sale_returns'] ?? 0,
      transaction['purchase_returns'] ?? 0,
      transaction['damages'] ?? 0,
      balance,
      balance / (packSize == 0 ? 1 : packSize),
    ];
    return '<tr>${values.map((value) => '<td>${escape(value)}</td>').join()}</tr>';
  }).join();
  final html =
      '''
<!doctype html><html><head><meta charset="utf-8"><style>
body{font-family:Arial,sans-serif}h1,h2{text-align:center}
table{border-collapse:collapse;width:100%;font-size:10px}
th,td{border:1px solid #bbb;padding:6px;text-align:right}
th{background:#e5e7eb}th:nth-child(2),td:nth-child(2){text-align:left}
th:first-child,td:first-child{width:42px;text-align:center}
</style><title>${escape(companyName)} - Stock Movement Report</title></head><body>
<h1>${escape(companyName.toUpperCase())}</h1>
<h2>${escape(itemName)} - STOCK MOVEMENT REPORT</h2>
<p>Branch: ${escape(branchName)}</p>
<p>Period: ${DateFormat('yyyy-MM-dd').format(startDate)} - ${DateFormat('yyyy-MM-dd').format(endDate)}</p>
<table><thead><tr>${headers.map((header) => '<th>${escape(header)}</th>').join()}</tr></thead>
<tbody>$rows</tbody></table></body></html>
''';
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final safeItemName = itemName.trim().replaceAll(
    RegExp(r'[^A-Za-z0-9_-]+'),
    '_',
  );
  final safeCompanyName = companyName.trim().replaceAll(
    RegExp(r'[^A-Za-z0-9_-]+'),
    '_',
  );
  await FileSaver.instance.saveFile(
    name: '${safeCompanyName}_stock_movement_${safeItemName}_$timestamp',
    bytes: Uint8List.fromList(utf8.encode(html)),
    fileExtension: 'doc',
    mimeType: MimeType.custom,
    customMimeType: 'application/msword',
  );
}
