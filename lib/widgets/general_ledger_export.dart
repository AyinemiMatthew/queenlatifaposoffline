import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum _GeneralLedgerExportFormat { pdf, csv, excel, word, print }

int generalLedgerPageSizeForWidth(double width) {
  if (width >= 1600) return 30;
  if (width >= 1200) return 25;
  if (width >= 900) return 20;
  if (width >= 700) return 15;
  return 10;
}

class GeneralLedgerExportDetail {
  const GeneralLedgerExportDetail(this.label, this.value);

  final String label;
  final String value;
}

class GeneralLedgerExportHeader {
  const GeneralLedgerExportHeader({
    required this.companyName,
    required this.heading,
    required this.leftDetails,
    required this.rightDetails,
  });

  final String companyName;
  final String heading;
  final List<GeneralLedgerExportDetail> leftDetails;
  final List<GeneralLedgerExportDetail> rightDetails;
}

class GeneralLedgerExportMenu extends StatelessWidget {
  const GeneralLedgerExportMenu({
    super.key,
    required this.title,
    required this.headers,
    required this.rows,
    this.onPrint,
    this.metadata = const [],
    this.exportHeader,
  });

  final String title;
  final List<String> headers;
  final List<List<Object?>> rows;
  final Future<void> Function()? onPrint;
  final List<String> metadata;
  final GeneralLedgerExportHeader? exportHeader;

  Future<void> _export(
    BuildContext context,
    _GeneralLedgerExportFormat format,
  ) async {
    try {
      switch (format) {
        case _GeneralLedgerExportFormat.pdf:
          await _savePdf(
            title: title,
            metadata: metadata,
            exportHeader: exportHeader,
            headers: headers,
            rows: rows,
          );
        case _GeneralLedgerExportFormat.csv:
          await _saveCsv(title: title, headers: headers, rows: rows);
        case _GeneralLedgerExportFormat.excel:
          await _saveExcel(
            title: title,
            exportHeader: exportHeader,
            headers: headers,
            rows: rows,
          );
        case _GeneralLedgerExportFormat.word:
          await _saveWord(
            title: title,
            metadata: metadata,
            exportHeader: exportHeader,
            headers: headers,
            rows: rows,
          );
        case _GeneralLedgerExportFormat.print:
          await Printing.layoutPdf(
            name: '${_fileSafeTitle(title)}.pdf',
            onLayout: (_) => _buildPdf(
              title: title,
              metadata: metadata,
              exportHeader: exportHeader,
              headers: headers,
              rows: rows,
            ),
          );
      }
    } catch (error, stackTrace) {
      debugPrint('General ledger export failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export $title: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      PopupMenuButton<_GeneralLedgerExportFormat>(
        tooltip: 'Export general ledger',
        onSelected: (format) => _export(context, format),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _GeneralLedgerExportFormat.pdf,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.picture_as_pdf_outlined),
              title: Text('Download PDF'),
            ),
          ),
          const PopupMenuItem(
            value: _GeneralLedgerExportFormat.csv,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.table_chart_outlined),
              title: Text('Download CSV'),
            ),
          ),
          const PopupMenuItem(
            value: _GeneralLedgerExportFormat.excel,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.grid_on_outlined),
              title: Text('Download Excel'),
            ),
          ),
          const PopupMenuItem(
            value: _GeneralLedgerExportFormat.word,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.description_outlined),
              title: Text('Download Word'),
            ),
          ),
          if (onPrint != null)
            const PopupMenuItem(
              value: _GeneralLedgerExportFormat.print,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.print_outlined),
                title: Text('Print'),
              ),
            ),
        ],
        icon: const Icon(Icons.download_outlined),
      );
}

class GeneralLedgerPagination extends StatelessWidget {
  const GeneralLedgerPagination({
    super.key,
    required this.totalRows,
    required this.pageIndex,
    required this.onPageChanged,
    this.pageSize = 10,
    this.onPageSizeChanged,
  });

  final int totalRows;
  final int pageIndex;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final pageCount = (totalRows / pageSize).ceil().clamp(1, 1 << 30);
      final safePage = pageIndex.clamp(0, pageCount - 1);
      final compact = constraints.maxWidth < 520;
      final firstRow = totalRows == 0 ? 0 : safePage * pageSize + 1;
      final lastRow = (safePage + 1) * pageSize < totalRows
          ? (safePage + 1) * pageSize
          : totalRows;
      final pageLinks = Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          pageCount,
          (page) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(36, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: page == safePage
                    ? theme.colorScheme.primary
                    : null,
                foregroundColor: page == safePage
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
              onPressed: () {
                if (page != safePage) onPageChanged(page);
              },
              child: Text('${page + 1}'),
            ),
          ),
        ),
      );
      final pageNavigation = Row(
        children: [
          IconButton(
            tooltip: 'First page',
            visualDensity: VisualDensity.compact,
            onPressed: safePage == 0 ? null : () => onPageChanged(0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: 'Previous page',
            visualDensity: VisualDensity.compact,
            onPressed: safePage == 0 ? null : () => onPageChanged(safePage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: pageLinks,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            visualDensity: VisualDensity.compact,
            onPressed: safePage >= pageCount - 1
                ? null
                : () => onPageChanged(safePage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Last page',
            visualDensity: VisualDensity.compact,
            onPressed: safePage >= pageCount - 1
                ? null
                : () => onPageChanged(pageCount - 1),
            icon: const Icon(Icons.last_page),
          ),
        ],
      );
      final rowsPerPageSelector = onPageSizeChanged == null
          ? const SizedBox.shrink()
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rows per page', style: theme.textTheme.bodySmall),
                const SizedBox(width: 6),
                MenuAnchor(
                  style: MenuStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      theme.colorScheme.surfaceContainerHighest,
                    ),
                    surfaceTintColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                  ),
                  menuChildren: [
                    for (final option in const [10, 13, 15, 50, 100])
                      MenuItemButton(
                        style: ButtonStyle(
                          foregroundColor: WidgetStatePropertyAll(
                            theme.colorScheme.onSurface,
                          ),
                        ),
                        onPressed: () => onPageSizeChanged!(option),
                        child: Text('$option'),
                      ),
                  ],
                  builder: (context, controller, child) => TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$pageSize'),
                        Icon(
                          Icons.arrow_drop_down,
                          color: theme.colorScheme.onSurface,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$firstRow–$lastRow of $totalRows',
                        style: theme.textTheme.bodySmall,
                      ),
                      rowsPerPageSelector,
                    ],
                  ),
                  pageNavigation,
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing $firstRow–$lastRow of $totalRows',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  rowsPerPageSelector,
                  const SizedBox(width: 12),
                  Expanded(child: pageNavigation),
                ],
              ),
      );
    },
  );
}

String _fileSafeTitle(String title) => title
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _cellString(Object? value) => value?.toString() ?? '';

bool _isNumberOrDateColumn(String header) {
  final normalized = header.trim().toLowerCase();
  return normalized == '#' || normalized == 'date';
}

Future<Uint8List> _buildPdf({
  required String title,
  required List<String> metadata,
  required GeneralLedgerExportHeader? exportHeader,
  required List<String> headers,
  required List<List<Object?>> rows,
}) async {
  pw.Widget detailColumn(List<GeneralLedgerExportDetail> details) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: details
        .map(
          (detail) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '${detail.label}: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.TextSpan(text: detail.value),
                ],
              ),
              textAlign: pw.TextAlign.left,
            ),
          ),
        )
        .toList(),
  );

  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        if (exportHeader == null) ...[
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          ...metadata.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text(line, style: const pw.TextStyle(fontSize: 9)),
            ),
          ),
        ] else ...[
          pw.Center(
            child: pw.Text(
              exportHeader.companyName,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              exportHeader.heading.toUpperCase(),
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: detailColumn(exportHeader.leftDetails)),
                pw.SizedBox(width: 24),
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.topRight,
                    child: detailColumn(exportHeader.rightDetails),
                  ),
                ),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 12),
        pw.Table(
          columnWidths: {
            for (var index = 0; index < headers.length; index++)
              index: headers[index].trim() == '#'
                  ? const pw.FixedColumnWidth(28)
                  : headers[index].trim().toLowerCase() == 'date'
                  ? const pw.FixedColumnWidth(100)
                  : const pw.FlexColumnWidth(),
          },
          border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              children: [
                for (var index = 0; index < headers.length; index++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 6,
                    ),
                    child: pw.Text(
                      headers[index],
                      textAlign: headers[index].trim() == '#'
                          ? pw.TextAlign.center
                          : pw.TextAlign.left,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: _isNumberOrDateColumn(headers[index])
                            ? 10
                            : 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            for (final row in rows)
              pw.TableRow(
                children: [
                  for (var index = 0; index < headers.length; index++)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 6,
                      ),
                      child: pw.Text(
                        _cellString(index < row.length ? row[index] : null),
                        textAlign: headers[index].trim() == '#'
                            ? pw.TextAlign.center
                            : pw.TextAlign.left,
                        style: pw.TextStyle(
                          fontSize: _isNumberOrDateColumn(headers[index])
                              ? 10
                              : 8,
                          fontWeight: _isNumberOrDateColumn(headers[index])
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    ),
  );

  return Uint8List.fromList(await document.save());
}

Future<void> _savePdf({
  required String title,
  required List<String> metadata,
  required GeneralLedgerExportHeader? exportHeader,
  required List<String> headers,
  required List<List<Object?>> rows,
}) async {
  final bytes = await _buildPdf(
    title: title,
    metadata: metadata,
    exportHeader: exportHeader,
    headers: headers,
    rows: rows,
  );
  await FileSaver.instance.saveFile(
    name: '${_fileSafeTitle(title)}_${DateTime.now().millisecondsSinceEpoch}',
    bytes: bytes,
    fileExtension: 'pdf',
    mimeType: MimeType.pdf,
  );
}

Future<void> _saveCsv({
  required String title,
  required List<String> headers,
  required List<List<Object?>> rows,
}) async {
  String csvCell(Object? value) {
    final text = _cellString(value);
    return '"${text.replaceAll('"', '""')}"';
  }

  final lines = [
    headers.map(csvCell).join(','),
    ...rows.map((row) => row.map(csvCell).join(',')),
  ];
  await FileSaver.instance.saveFile(
    name: '${_fileSafeTitle(title)}_${DateTime.now().millisecondsSinceEpoch}',
    bytes: Uint8List.fromList(utf8.encode('\uFEFF${lines.join('\r\n')}')),
    fileExtension: 'csv',
    mimeType: MimeType.csv,
  );
}

Future<void> _saveExcel({
  required String title,
  required GeneralLedgerExportHeader? exportHeader,
  required List<String> headers,
  required List<List<Object?>> rows,
}) async {
  final workbook = xls.Excel.createExcel();
  final sheet = workbook['General Ledger'];
  workbook.delete('Sheet1');
  var headerRowIndex = 0;
  if (exportHeader != null) {
    sheet.appendRow([xls.TextCellValue(exportHeader.companyName)]);
    sheet.appendRow([xls.TextCellValue(exportHeader.heading)]);
    final detailsRowCount =
        exportHeader.leftDetails.length > exportHeader.rightDetails.length
        ? exportHeader.leftDetails.length
        : exportHeader.rightDetails.length;
    for (var index = 0; index < detailsRowCount; index++) {
      final left = index < exportHeader.leftDetails.length
          ? exportHeader.leftDetails[index]
          : null;
      final right = index < exportHeader.rightDetails.length
          ? exportHeader.rightDetails[index]
          : null;
      sheet.appendRow([
        xls.TextCellValue(left == null ? '' : '${left.label}: ${left.value}'),
        xls.TextCellValue(
          right == null ? '' : '${right.label}: ${right.value}',
        ),
      ]);
    }
    sheet.appendRow([xls.TextCellValue('')]);
    headerRowIndex = detailsRowCount + 3;
  }
  sheet.appendRow(headers.map(xls.TextCellValue.new).toList());
  for (var index = 0; index < headers.length; index++) {
    final emphasize = _isNumberOrDateColumn(headers[index]);
    sheet
        .cell(
          xls.CellIndex.indexByColumnRow(
            columnIndex: index,
            rowIndex: headerRowIndex,
          ),
        )
        .cellStyle = xls.CellStyle(
      bold: true,
      fontSize: emphasize ? 12 : 11,
      backgroundColorHex: xls.ExcelColor.fromHexString('#DCE6F1'),
      horizontalAlign: headers[index].trim() == '#'
          ? xls.HorizontalAlign.Center
          : xls.HorizontalAlign.Left,
    );
    if (emphasize) {
      sheet.setColumnWidth(index, headers[index].trim() == '#' ? 6 : 20);
    }
  }

  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    sheet.appendRow([
      for (var index = 0; index < headers.length; index++)
        _excelCell(headers[index], index < row.length ? row[index] : null),
    ]);
    for (var index = 0; index < headers.length; index++) {
      if (_isNumberOrDateColumn(headers[index])) {
        sheet
            .cell(
              xls.CellIndex.indexByColumnRow(
                columnIndex: index,
                rowIndex: headerRowIndex + rowIndex + 1,
              ),
            )
            .cellStyle = xls.CellStyle(
          fontSize: 12,
          bold: true,
          horizontalAlign: headers[index].trim() == '#'
              ? xls.HorizontalAlign.Center
              : xls.HorizontalAlign.Left,
        );
      }
    }
  }

  final bytes = workbook.encode();
  if (bytes == null) {
    throw StateError('Excel workbook could not be encoded.');
  }
  await FileSaver.instance.saveFile(
    name: '${_fileSafeTitle(title)}_${DateTime.now().millisecondsSinceEpoch}',
    bytes: Uint8List.fromList(bytes),
    fileExtension: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}

xls.CellValue _excelCell(String header, Object? value) {
  final text = _cellString(value);
  if (header.trim() == '#') {
    final integer = int.tryParse(text);
    if (integer != null) return xls.IntCellValue(integer);
  }
  if (header.toLowerCase().contains('(ghs)')) {
    final number = double.tryParse(text.replaceAll(',', ''));
    if (number != null) return xls.DoubleCellValue(number);
  }
  return xls.TextCellValue(text);
}

Future<void> _saveWord({
  required String title,
  required List<String> metadata,
  required GeneralLedgerExportHeader? exportHeader,
  required List<String> headers,
  required List<List<Object?>> rows,
}) async {
  String escapeHtml(Object? value) => _cellString(value)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  final headerHtml = headers.asMap().entries.map((entry) {
    final classes = [
      if (_isNumberOrDateColumn(entry.value)) 'key',
      if (entry.value.trim() == '#') 'number',
    ];
    final classAttribute = classes.isEmpty
        ? ''
        : ' class="${classes.join(' ')}"';
    return '<th$classAttribute>${escapeHtml(entry.value)}</th>';
  }).join();
  final rowsHtml = rows
      .map(
        (row) =>
            '<tr>${List.generate(headers.length, (index) {
              final classes = [if (_isNumberOrDateColumn(headers[index])) 'key', if (headers[index].trim() == '#') 'number'];
              final classAttribute = classes.isEmpty ? '' : ' class="${classes.join(' ')}"';
              return '<td$classAttribute>${escapeHtml(index < row.length ? row[index] : '')}</td>';
            }).join()}</tr>',
      )
      .join();
  final metadataHtml = metadata
      .map((line) => '<p>${escapeHtml(line)}</p>')
      .join();
  final exportHeaderHtml = exportHeader == null
      ? '<h1>${escapeHtml(title)}</h1>$metadataHtml'
      : '''
<div class="report-heading">
  <h1>${escapeHtml(exportHeader.companyName)}</h1>
  <h2>${escapeHtml(exportHeader.heading.toUpperCase())}</h2>
</div>
<table class="details"><tbody><tr>
  <td>${_wordDetailsHtml(exportHeader.leftDetails, escapeHtml)}</td>
  <td class="right">${_wordDetailsHtml(exportHeader.rightDetails, escapeHtml)}</td>
</tr></tbody></table>
''';
  final html =
      '''
<!doctype html>
<html>
<head><meta charset="utf-8"><title>${escapeHtml(title)}</title>
<style>
body { font-family: Arial, sans-serif; margin: 24px; }
h1 { font-size: 20px; }
h2 { font-size: 16px; font-weight: normal; color: #666; margin: 4px 0 14px; }
p { margin: 3px 0; font-size: 11px; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #b8c2cc; padding: 7px; text-align: left; }
.data-table { table-layout: auto; }
.data-table th.key, .data-table td.key { font-size: 13px; font-weight: bold; }
.data-table th.number, .data-table td.number { width: 30px; min-width: 30px; text-align: center; padding-left: 3px; padding-right: 3px; }
.data-table th:nth-child(2), .data-table td:nth-child(2) { min-width: 110px; }
.report-heading { text-align: center; border-bottom: 1px solid #222; padding-bottom: 12px; }
.report-heading h1 { color: #174ea6; margin: 0; }
.details { margin: 12px 0; }
.details td { border: 0; padding: 3px 0; vertical-align: top; }
.details .right { text-align: right; }
th { background: #dce6f1; }
tr:nth-child(even) { background: #f3f6fa; }
</style></head>
<body>$exportHeaderHtml
<table class="data-table"><thead><tr>$headerHtml</tr></thead><tbody>$rowsHtml</tbody></table>
</body></html>
''';

  await FileSaver.instance.saveFile(
    name: '${_fileSafeTitle(title)}_${DateTime.now().millisecondsSinceEpoch}',
    bytes: Uint8List.fromList(utf8.encode(html)),
    fileExtension: 'doc',
    mimeType: MimeType.custom,
    customMimeType: 'application/msword',
  );
}

String _wordDetailsHtml(
  List<GeneralLedgerExportDetail> details,
  String Function(Object?) escapeHtml,
) => details
    .map(
      (detail) =>
          '<p><strong>${escapeHtml(detail.label)}:</strong> ${escapeHtml(detail.value)}</p>',
    )
    .join();
