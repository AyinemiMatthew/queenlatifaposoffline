import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

import '../models/appModuls.dart';
import '../models/itemregmodel.dart';
import '../providers/Datafeed.dart';
import '../providers/item_provider.dart';
import '../widgets/itemmodal.dart';
import 'itemreg.dart';

class ItemListPage extends StatefulWidget {
  const ItemListPage({super.key});

  @override
  State<ItemListPage> createState() => _ItemListPageState();
}

enum _ItemExportAction { pdf, print, word, excel, csv }

class _ItemListPageState extends State<ItemListPage> {
  String searchQuery = "";
  bool _isSearching = false;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  static const List<double> _columnWidths = [
    50,
    180,
    140,
    100,
    90,
    100,
    100,
    140,
    110,
  ];
  static const double _horizontalPadding = 24;
  static const double _mobileInset = 16;

  double get _totalWidth =>
      _columnWidths.reduce((a, b) => a + b) + _horizontalPadding;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1000;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final filteredItems = context.read<ItemProvider>().filterItems(
          value.items,
          searchQuery,
        );
        final pageCount = (filteredItems.length / _itemsPerPage).ceil();
        final currentPage = pageCount == 0
            ? 0
            : _currentPage.clamp(0, pageCount - 1);
        final startIndex = currentPage * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage).clamp(
          0,
          filteredItems.length,
        );
        final pageItems = filteredItems.sublist(startIndex, endIndex);
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isSearching
                  ? SizedBox(
                      key: const ValueKey('search'),
                      child: _buildAppBarSearchField(),
                    )
                  : const Text("Registered Items", key: ValueKey('title')),
            ),
            actions: [
              PopupMenuButton<_ItemExportAction>(
                tooltip: 'Export items',
                onSelected: (action) =>
                    _exportItems(action, filteredItems, value.company),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ItemExportAction.pdf,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Download PDF'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ItemExportAction.print,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.print_outlined),
                      title: Text('Print / Save as PDF'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ItemExportAction.word,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.description_outlined),
                      title: Text('Download Word (.doc)'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ItemExportAction.excel,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.table_view_outlined),
                      title: Text('Download Excel'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _ItemExportAction.csv,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.subject_outlined),
                      title: Text('Download CSV'),
                    ),
                  ),
                ],
                icon: const Icon(Icons.file_download_outlined),
              ),
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  backgroundColor: Colors.transparent,
                  overlayColor: Colors.transparent,
                  side: BorderSide.none,
                  shape: const CircleBorder(),
                ),
                onPressed: () {
                  setState(() {
                    if (_isSearching) {
                      _searchController.clear();
                      searchQuery = "";
                      _currentPage = 0;
                    }
                    _isSearching = !_isSearching;
                  });
                },
              ),
            ],
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 56),
            child: FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ItemRegPage()),
                );
              },
            ),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                Expanded(
                  child: value.loading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            "No items registered yet",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : isDesktop
                      ? _desktopTable(pageItems, value, startIndex)
                      : _mobileCards(pageItems, value, startIndex),
                ),
                _paginationFooter(
                  totalItems: filteredItems.length,
                  currentPage: currentPage,
                  pageCount: pageCount,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const List<String> _exportHeaders = [
    '#',
    'Name',
    'Barcode',
    'Category',
    'Type',
    'Cost Price',
    'Retail Price',
    'Wholesale Price',
    'Supplier Price',
    'Status',
  ];

  List<String> _exportItemRow(ItemModel item, int index) {
    final single = item.modes?.where((mode) => mode.id == 'single').firstOrNull;
    final carton = item.modes?.where((mode) => mode.id == 'carton').firstOrNull;
    return [
      '${index + 1}',
      item.name,
      item.barcode,
      item.pcategory,
      item.producttype,
      item.cp,
      single?.rp ?? '',
      carton?.wp ?? '',
      carton?.sp ?? '',
      item.isActive ? 'Active' : 'Inactive',
    ];
  }

  Future<void> _exportItems(
    _ItemExportAction action,
    List<ItemModel> items,
    String companyName,
  ) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no items to export.')),
      );
      return;
    }

    try {
      final exportDate = DateFormat('MMM-dd-yyyy').format(DateTime.now());
      final safeCompanyName = companyName.trim().isEmpty
          ? 'Company'
          : companyName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
      final fileName =
          '$safeCompanyName-registered-items-${items.length}-records-$exportDate';
      final rows = items
          .asMap()
          .entries
          .map((entry) => _exportItemRow(entry.value, entry.key))
          .toList();

      switch (action) {
        case _ItemExportAction.pdf:
        case _ItemExportAction.print:
          final document = _buildItemsPdf(items, rows, companyName);
          if (action == _ItemExportAction.print) {
            await Printing.layoutPdf(
              onLayout: (_) => document.save(),
              name: fileName,
            );
          } else {
            await FileSaver.instance.saveFile(
              name: fileName,
              bytes: Uint8List.fromList(await document.save()),
              fileExtension: 'pdf',
              mimeType: MimeType.pdf,
            );
          }
        case _ItemExportAction.word:
          final html = _buildItemsWordHtml(items, rows, companyName);
          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: Uint8List.fromList(utf8.encode(html)),
            fileExtension: 'doc',
            mimeType: MimeType.other,
          );
        case _ItemExportAction.excel:
          await _saveItemsExcel(fileName, rows, companyName);
        case _ItemExportAction.csv:
          final csv = [
            _exportHeaders,
            ...rows,
          ].map((row) => row.map(_escapeCsvCell).join(',')).join('\r\n');
          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
            fileExtension: 'csv',
            mimeType: MimeType.other,
          );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items exported successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export items: $error')),
        );
      }
    }
  }

  String _escapeCsvCell(String value) {
    if (!value.contains(',') &&
        !value.contains('"') &&
        !value.contains('\n') &&
        !value.contains('\r')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  pw.Document _buildItemsPdf(
    List<ItemModel> items,
    List<List<String>> rows,
    String companyName,
  ) {
    final document = pw.Document(title: 'Registered Items');
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            companyName.isEmpty ? 'REGISTERED ITEMS' : companyName,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Registered items - ${items.length} records - '
            '${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: _exportHeaders,
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF415A77),
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.all(5),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
        ],
      ),
    );
    return document;
  }

  String _buildItemsWordHtml(
    List<ItemModel> items,
    List<List<String>> rows,
    String companyName,
  ) {
    String escapeHtml(String value) => value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    final header = _exportHeaders
        .map((value) => '<th>${escapeHtml(value)}</th>')
        .join();
    final body = rows
        .map(
          (row) =>
              '<tr>${row.map((value) => '<td>${escapeHtml(value)}</td>').join()}</tr>',
        )
        .join();

    return '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Registered Items</title>
<style>
body { font-family: Arial, sans-serif; }
h1 { color: #415a77; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #999; padding: 6px; text-align: left; }
th { background: #dce4ec; }
</style></head>
<body>
<h1>${escapeHtml(companyName.isEmpty ? 'Registered Items' : companyName)}</h1>
<p>Registered items - ${items.length} records - ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}</p>
<table><thead><tr>$header</tr></thead><tbody>$body</tbody></table>
</body></html>
''';
  }

  Future<void> _saveItemsExcel(
    String fileName,
    List<List<String>> rows,
    String companyName,
  ) async {
    final workbook = xls.Excel.createExcel();
    const sheetName = 'Registered Items';
    final sheet = workbook[sheetName];
    workbook.delete('Sheet1');

    if (companyName.isNotEmpty) {
      sheet.appendRow([xls.TextCellValue(companyName)]);
    }
    sheet.appendRow(_exportHeaders.map(xls.TextCellValue.new).toList());
    final headerRow = sheet.maxRows - 1;
    final headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#DCE4EC'),
    );
    for (var column = 0; column < _exportHeaders.length; column++) {
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
    for (final row in rows) {
      sheet.appendRow(row.map(xls.TextCellValue.new).toList());
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw Exception('Could not create the Excel file.');
    }
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Widget _buildAppBarSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      cursorColor: Theme.of(context).colorScheme.secondary,
      onChanged: (v) => setState(() {
        searchQuery = v.toLowerCase();
        _currentPage = 0;
      }),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: "Search name, barcode, company...",
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
  }

  Widget _paginationFooter({
    required int totalItems,
    required int currentPage,
    required int pageCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstItem = totalItems == 0 ? 0 : currentPage * _itemsPerPage + 1;
    final lastItem = ((currentPage + 1) * _itemsPerPage).clamp(0, totalItems);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$firstItem-$lastItem of $totalItems',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Previous page',
              onPressed: currentPage > 0
                  ? () => setState(() => _currentPage = currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              pageCount == 0 ? '0 / 0' : '${currentPage + 1} / $pageCount',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: currentPage + 1 < pageCount
                  ? () => setState(() => _currentPage = currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileCards(List<ItemModel> items, Datafeed value, int startIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return ListView.builder(
      padding: const EdgeInsets.all(_mobileInset),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        try {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                ItemDetailsModal(context: context, item: item).show();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF415A77),
                      foregroundColor: Colors.white,
                      child: Text("${startIndex + index + 1}"),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              color: isLightTheme
                                  ? colorScheme.onSurface
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Barcode: ${item.barcode}",
                            style: TextStyle(
                              color: isLightTheme
                                  ? colorScheme.onSurfaceVariant
                                  : Colors.white70,
                            ),
                          ),
                          if (item.shelfnumber != null &&
                              item.shelfnumber!.isNotEmpty)
                            Text(
                              "Shell Number: ${item.shelfnumber}",
                              style: TextStyle(
                                color: isLightTheme
                                    ? colorScheme.onSurfaceVariant
                                    : Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: isLightTheme
                          ? colorScheme.onSurfaceVariant
                          : Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
          );
        } catch (e) {
          print("Error building item card for item ${items[index].id}: $e");
          return Container();
        }
      },
    );
  }

  Widget _desktopTable(List<ItemModel> items, Datafeed value, int startIndex) {
    final columnWidths = _columnWidths;
    final totalWidth = _totalWidth;
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    Widget headerCell(String text, double width) {
      return SizedBox(
        width: width,
        child: Text(
          text,
          style: TextStyle(
            color: isLightTheme ? colorScheme.onSurface : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    Widget bodyCell(Widget child, double width) {
      return SizedBox(width: width, child: child);
    }

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(
          isLightTheme ? colorScheme.primary : const Color(0xFF415A77),
        ),
        trackColor: MaterialStateProperty.all(
          isLightTheme
              ? colorScheme.surfaceContainerHighest
              : const Color(0xFF22304A),
        ),
        trackBorderColor: MaterialStateProperty.all(
          isLightTheme ? colorScheme.outlineVariant : const Color(0xFF1B263B),
        ),
        thickness: MaterialStateProperty.all(10),
        radius: const Radius.circular(8),
      ),
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (notif) => notif.depth == 1,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                Container(
                  height: 48,
                  color: isLightTheme
                      ? colorScheme.surface
                      : colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      headerCell("#", columnWidths[0]),
                      headerCell("Name", columnWidths[1]),
                      headerCell("Barcode", columnWidths[2]),
                      headerCell("Cost Price", columnWidths[3]),
                      headerCell("Retail", columnWidths[4]),
                      headerCell("Wholesale", columnWidths[5]),
                      headerCell("Supplier", columnWidths[6]),
                      headerCell("Inactive/Active", columnWidths[7]),
                      headerCell("Actions", columnWidths[8]),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: ListView.builder(
                      controller: _verticalController,
                      itemCount: items.length,
                      itemExtent: 64,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final supplierPrices =
                            item.modes
                                ?.where((d) => d.name.toLowerCase() == 'carton')
                                .map((m) => " ${m.sp}")
                                .join("\n") ??
                            "";
                        final wholesalePrices =
                            item.modes
                                ?.where((d) => d.name.toLowerCase() == 'carton')
                                .map((m) => " ${m.wp}")
                                .join("\n") ??
                            "";
                        final singlePrices =
                            item.modes
                                ?.where((d) => d.name.toLowerCase() == 'single')
                                .map((m) => "${m.rp}")
                                .join("\n") ??
                            "";

                        try {
                          return InkWell(
                            onTap: () => ItemDetailsModal(
                              context: context,
                              item: item,
                            ).show(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isLightTheme
                                    ? colorScheme.surface
                                    : colorScheme.surfaceContainerHighest,
                                border: Border(
                                  bottom: BorderSide(
                                    color: isLightTheme
                                        ? colorScheme.outlineVariant
                                        : colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  bodyCell(
                                    Text(
                                      "${startIndex + index + 1}",
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    columnWidths[0],
                                  ),
                                  bodyCell(
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    columnWidths[1],
                                  ),
                                  bodyCell(
                                    Text(
                                      item.barcode,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    columnWidths[2],
                                  ),
                                  bodyCell(
                                    Text(
                                      item.cp,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    columnWidths[3],
                                  ),
                                  bodyCell(
                                    Tooltip(
                                      message: singlePrices,
                                      child: Text(
                                        singlePrices,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    columnWidths[4],
                                  ),
                                  bodyCell(
                                    Tooltip(
                                      message: wholesalePrices,
                                      child: Text(
                                        wholesalePrices,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    columnWidths[5],
                                  ),
                                  bodyCell(
                                    Tooltip(
                                      message: supplierPrices,
                                      child: Text(
                                        supplierPrices,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    columnWidths[6],
                                  ),
                                  bodyCell(
                                    Center(
                                      child: Switch(
                                        value: item.isActive == true,
                                        activeColor: Colors.green,
                                        onChanged: (val) {
                                          if (!mounted) return;
                                          context
                                              .read<ItemProvider>()
                                              .setItemActive(
                                                datafeed: value,
                                                docId: item.id,
                                                newStatus: val,
                                              )
                                              .catchError((Object error) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context)
                                                  ..hideCurrentSnackBar()
                                                  ..showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Could not update item status: $error',
                                                      ),
                                                    ),
                                                  );
                                              });
                                        },
                                      ),
                                    ),
                                    columnWidths[7],
                                  ),
                                  bodyCell(
                                    Row(
                                      children: [
                                        Visibility(
                                          visible: value.canEdit(
                                            AppModules.stock,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.amber,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ItemRegPage(
                                                    docId: item.id,
                                                    item: item,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        Visibility(
                                          visible: value.canDelete(
                                            AppModules.stock,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () =>
                                                _deleteItem(item.id),
                                          ),
                                        ),
                                      ],
                                    ),
                                    columnWidths[8],
                                  ),
                                ],
                              ),
                            ),
                          );
                        } catch (e) {
                          print(
                            "Error building table row for item ${item.id}: $e",
                          );
                          return SizedBox(height: 64, width: totalWidth);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteItem(String id) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Confirm Delete",
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Text(
          "Are you sure you want to delete this item?\nThis action cannot be undone.",
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: colorScheme.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Delete",
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await context.read<ItemProvider>().deleteItem(
        datafeed: context.read<Datafeed>(),
        id: id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Item deleted successfully",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to delete item: $e",
              style: TextStyle(color: Theme.of(context).colorScheme.surface),
            ),
          ),
        );
      }
    }
  }
}
