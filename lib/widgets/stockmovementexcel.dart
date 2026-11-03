import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

Future<void> exportStockMovementExcel({
  required List<Map<String, dynamic>> transactions,
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

  sheet.appendRow([xls.TextCellValue(itemName)]);
  sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .cellStyle =
      titleStyle;
  sheet.appendRow([xls.TextCellValue('STOCK MOVEMENT REPORT')]);
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
  await FileSaver.instance.saveFile(
    name: 'stock_movement_${safeItemName}_$timestamp',
    bytes: Uint8List.fromList(bytes),
    fileExtension: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}
