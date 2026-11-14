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
import '../models/damageitem.dart';
import '../providers/Datafeed.dart';
import '../providers/damage_provider.dart';
import '../providers/routes.dart';
import '../utils/damagepdf.dart';
import '../widgets/datepicker.dart';
import '../widgets/offline_indicator.dart';
import '../widgets/stock_rows_per_page_menu.dart';
import 'damages.dart';

class _DamageSummaryBucket {
  double amount = 0;
  double units = 0;
  final Set<String> recordIds = {};
  int get records => recordIds.length;
}

enum _DamageInsightView {
  overview,
  reasons,
  branches,
  suppliers,
  items,
  quantities,
  costs,
}

enum _DamageSortMode { cost, quantity, name }

enum _DamageExportAction { pdf, print, word, excel, csv }

class DamagesListPage extends StatefulWidget {
  const DamagesListPage({super.key});

  @override
  State<DamagesListPage> createState() => _DamagesListPageState();
}

class _DamagesListPageState extends State<DamagesListPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _branchButtonKey = GlobalKey();

  String searchQuery = '';
  DateTimeRange? selectedDate;
  String? _selectedBranchId;
  bool _isSearching = false;

  int _sortColumnIndex = 1;
  bool _sortAscending = true;
  int _rowsPerPage = 10;
  int _currentPage = 0;

  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _secondaryTextColor =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _mutedTextColor =>
      Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8);
  Color get _cardColor => Theme.of(context).colorScheme.surfaceContainerLow;
  Color get _cardHeaderColor => Theme.of(context).colorScheme.surfaceContainer;
  Color get _cardBorderColor => Theme.of(context).colorScheme.outlineVariant;
  Color get _rowColor => Theme.of(context).colorScheme.surface;

  bool _canManagePage(Datafeed value) => value.isAdminLevel;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final value = context.read<Datafeed>();
      final damageProvider = context.read<DamageProvider>();
      await value.fetchBranches();

      if (!mounted) return;

      final branchId = _canManagePage(value) ? null : value.branchid;

      await damageProvider.fetchDamages(
        selectedDate: selectedDate,
        selectedBranch: branchId,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _itemsOf(damageitemmodel damage) {
    return Map<String, dynamic>.from(damage.item);
  }

  String _firstItemName(damageitemmodel damage) {
    for (final item in damage.item.values) {
      if (item is Map) return item['item']?.toString() ?? '';
    }
    return '';
  }

  List<damageitemmodel> filterdamages(DamageProvider damageProvider) {
    if (searchQuery.trim().isEmpty) {
      return List.of(damageProvider.damages);
    }

    final q = searchQuery.trim().toLowerCase();

    return damageProvider.damages.where((s) {
      final headerValues = <dynamic>[
        s.id,
        s.company,
        s.branchname,
        s.createdby,
        s.createdat,
        s.dateymd,
      ];

      final headerMatch = headerValues.any(
        (v) => v?.toString().toLowerCase().contains(q) ?? false,
      );

      if (headerMatch) return true;

      return s.item.values.any((item) {
        if (item is! Map) return false;

        return <dynamic>[
          item['item'],
          item['itemid'],
          item['mode'],
          item['reason'],
          item['cp'],
          item['barcode'],
          item['modeqty'],
          item['quantity'],
          item['totalpieces'],
        ].any((v) => v?.toString().toLowerCase().contains(q) ?? false);
      });
    }).toList();
  }

  void _openSearch() {
    setState(() {
      _isSearching = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();

    setState(() {
      searchQuery = '';
      _isSearching = false;
      _currentPage = 0;
    });
  }

  void _handleBack() {
    if (_isSearching) {
      _closeSearch();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(Routes.home);
    }
  }

  double _calcTotal(Map<String, dynamic> itemMap) {
    return itemMap.values.fold<double>(0, (sum, item) {
      if (item is! Map) return sum;
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final qty = double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
      return sum + (cp * qty);
    });
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2).format(amount);

  static const List<String> _damageExportHeaders = [
    'No.',
    'Date Created',
    'Transaction Date',
    'Branch',
    'Staff',
    'Item',
    'Barcode',
    'Reason',
    'Mode',
    'Quantity',
    'Total Pieces',
    'Unit Cost (GHS)',
    'Line Total (GHS)',
  ];

  List<List<String>> _damageExportRows(List<damageitemmodel> damages) {
    final rows = <List<String>>[];
    for (final damage in damages) {
      for (final item in damage.item.values.whereType<Map>()) {
        final itemData = Map<String, dynamic>.from(item);
        final totalPieces =
            double.tryParse(itemData['totalpieces']?.toString() ?? '0') ?? 0;
        final unitCost =
            double.tryParse(itemData['cp']?.toString() ?? '0') ?? 0;
        rows.add([
          '${rows.length + 1}',
          DateFormat('yyyy-MM-dd').format(damage.createdat),
          damage.dateymd ?? '',
          damage.branchname,
          damage.createdby,
          itemData['item']?.toString() ?? '',
          itemData['barcode']?.toString() ?? '',
          itemData['reason']?.toString() ?? '',
          itemData['mode']?.toString() ?? '',
          itemData['quantity']?.toString() ?? '',
          totalPieces.toString(),
          unitCost.toStringAsFixed(2),
          (unitCost * totalPieces).toStringAsFixed(2),
        ]);
      }
    }
    return rows;
  }

  String _escapeDamageCsvCell(String value) {
    if (!value.contains(',') &&
        !value.contains('"') &&
        !value.contains('\n') &&
        !value.contains('\r')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  Future<void> _exportDamages(
    _DamageExportAction action,
    List<damageitemmodel> damages,
    String companyName,
  ) async {
    if (damages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no damages to export.')),
      );
      return;
    }

    try {
      final exportDate = DateFormat('MMM-dd-yyyy').format(DateTime.now());
      final safeCompanyName = companyName.trim().isEmpty
          ? 'Company'
          : companyName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
      final fileName =
          '$safeCompanyName-damages-${damages.length}-records-$exportDate';
      final rows = _damageExportRows(damages);

      switch (action) {
        case _DamageExportAction.pdf:
        case _DamageExportAction.print:
          final document = _buildDamageExportPdf(
            damages.length,
            rows,
            companyName,
          );
          if (action == _DamageExportAction.print) {
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
        case _DamageExportAction.word:
          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: Uint8List.fromList(
              utf8.encode(
                _buildDamageExportWord(rows, damages.length, companyName),
              ),
            ),
            fileExtension: 'doc',
            mimeType: MimeType.other,
          );
        case _DamageExportAction.excel:
          await _saveDamageExportExcel(fileName, rows, companyName);
        case _DamageExportAction.csv:
          final csv = [
            _damageExportHeaders,
            ...rows,
          ].map((row) => row.map(_escapeDamageCsvCell).join(',')).join('\r\n');
          await FileSaver.instance.saveFile(
            name: fileName,
            bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
            fileExtension: 'csv',
            mimeType: MimeType.other,
          );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Damages exported successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export damages: $error')),
        );
      }
    }
  }

  pw.Document _buildDamageExportPdf(
    int recordCount,
    List<List<String>> rows,
    String companyName,
  ) {
    final document = pw.Document(title: 'Damage Report');
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            companyName.isEmpty ? 'DAMAGE REPORT' : companyName,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '$recordCount damage records - '
            '${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: _damageExportHeaders,
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF415A77),
            ),
            cellStyle: const pw.TextStyle(fontSize: 6),
            cellPadding: const pw.EdgeInsets.all(4),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          ),
        ],
      ),
    );
    return document;
  }

  String _buildDamageExportWord(
    List<List<String>> rows,
    int recordCount,
    String companyName,
  ) {
    String escapeHtml(String value) => value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    final header = _damageExportHeaders
        .map((value) => '<th>${escapeHtml(value)}</th>')
        .join();
    final body = rows
        .map(
          (row) =>
              '<tr>${row.map((value) => '<td>${escapeHtml(value)}</td>').join()}</tr>',
        )
        .join();

    return '''
<!DOCTYPE html><html><head><meta charset="utf-8"><title>Damage Report</title>
<style>body{font-family:Arial,sans-serif}table{border-collapse:collapse;width:100%}th,td{border:1px solid #999;padding:6px;text-align:left}th{background:#dce4ec}</style>
</head><body><h1>${escapeHtml(companyName.isEmpty ? 'Damage Report' : companyName)}</h1>
<p>$recordCount damage records - ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}</p>
<table><thead><tr>$header</tr></thead><tbody>$body</tbody></table></body></html>
''';
  }

  Future<void> _saveDamageExportExcel(
    String fileName,
    List<List<String>> rows,
    String companyName,
  ) async {
    final workbook = xls.Excel.createExcel();
    const sheetName = 'Damages';
    final sheet = workbook[sheetName];
    workbook.delete('Sheet1');

    if (companyName.isNotEmpty) {
      sheet.appendRow([xls.TextCellValue(companyName)]);
    }
    sheet.appendRow(_damageExportHeaders.map(xls.TextCellValue.new).toList());
    final headerRow = sheet.maxRows - 1;
    final headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#DCE4EC'),
    );
    for (var column = 0; column < _damageExportHeaders.length; column++) {
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
      sheet.appendRow([
        for (var column = 0; column < row.length; column++)
          if (column == 10 || column == 11 || column == 12)
            xls.DoubleCellValue(double.parse(row[column]))
          else
            xls.TextCellValue(row[column]),
      ]);
    }

    final bytes = workbook.encode();
    if (bytes == null) throw Exception('Could not create the Excel file.');
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  String _damageReason(damageitemmodel damage) {
    final reasons = <String>{};
    for (final value in damage.item.values) {
      if (value is! Map) continue;
      final reason = value['reason']?.toString().trim() ?? '';
      if (reason.isNotEmpty) reasons.add(reason);
    }

    if (reasons.isNotEmpty) return reasons.join(', ');
    final description = damage.description.trim();
    return description.isEmpty ? 'Unspecified' : description;
  }

  Widget _syncStatusBadge(damageitemmodel damage) {
    if (!damage.pendingSync) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Waiting to sync',
        style: TextStyle(
          color: Colors.deepOrange,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _openDamageInsight(
    List<damageitemmodel> damages,
    _DamageInsightView view,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DamageInsightsPage(damages: damages, view: view),
      ),
    );
  }

  void _openDamageRecord(damageitemmodel damage) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DamageRecordDetailsPage(damage: damage),
      ),
    );
  }

  void _editDamage(damageitemmodel damage) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Damages(damageitem: damage)),
    );
  }

  Future<void> _printDamage(damageitemmodel damage) async {
    await DamageReportPdf.generate(
      header: {
        'company': damage.company,
        'branchname': damage.branchname,
        'createdby': damage.createdby,
        'createdat': damage.createdat,
      },
      itemsMap: _itemsOf(damage),
    );
  }

  Future<void> _reloadDamages(
    Datafeed value,
    DamageProvider damageProvider,
  ) async {
    final branchId = _canManagePage(value) ? _selectedBranchId : value.branchid;

    await damageProvider.fetchDamages(
      selectedDate: selectedDate,
      selectedBranch: branchId,
    );
  }

  Future<void> _showBranchDropdown(BuildContext context, Datafeed value) async {
    if (!_canManagePage(value)) return;

    if (value.branches.isEmpty) {
      await value.fetchBranches();
    }

    if (!mounted) return;

    final renderObject = _branchButtonKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;

    final position = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final selected = await showMenu<String>(
      context: context,
      color: _cardColor,
      elevation: 8,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height + 4,
        screenWidth - position.dx - size.width,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          value: '',
          height: 44,
          child: Row(
            children: [
              Icon(Icons.apartment, color: _secondaryTextColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'All Branches',
                  style: TextStyle(color: _textColor, fontSize: 14),
                ),
              ),
              if (_selectedBranchId == null)
                Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
            ],
          ),
        ),
        ...value.branches.map((branch) {
          final id = branch.id;
          final name = branch.branchname.isNotEmpty ? branch.branchname : id;

          return PopupMenuItem<String>(
            value: id,
            height: 44,
            child: Row(
              children: [
                Icon(
                  Icons.store_outlined,
                  color: _secondaryTextColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textColor, fontSize: 14),
                  ),
                ),
                if (_selectedBranchId == id)
                  Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
              ],
            ),
          );
        }),
      ],
    );

    if (!mounted || selected == null) return;

    setState(() {
      _selectedBranchId = selected.isEmpty ? null : selected;
      _currentPage = 0;
    });

    await _reloadDamages(value, context.read<DamageProvider>());
  }

  String _selectedBranchLabel(Datafeed value) {
    if (_selectedBranchId == null) return 'All Branches';

    for (final branch in value.branches) {
      if (branch.id == _selectedBranchId) {
        return branch.branchname.isNotEmpty ? branch.branchname : 'Branch';
      }
    }

    return 'Branch';
  }

  Widget _dialogDetail(String label, String value) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _mutedTextColor, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBarIcon({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Color? color,
    double size = 19,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 40),
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      icon: Icon(icon, size: size, color: color ?? _textColor),
    );
  }

  Widget _actionsMenu(damageitemmodel damage, Datafeed value) {
    final canEdit = value.canEdit(AppModules.stock);
    final canDelete = value.canDelete(AppModules.stock);

    Widget entry(IconData icon, String label) {
      return Row(
        children: [
          Icon(icon, size: 18, color: _textColor),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: _textColor)),
        ],
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Actions',
      color: _cardColor,
      icon: Icon(Icons.more_vert, size: 20, color: _textColor),
      onSelected: (action) {
        switch (action) {
          case 'details':
            _openDamageRecord(damage);
            break;
          case 'print':
            _printDamage(damage);
            break;
          case 'edit':
            _editDamage(damage);
            break;
          case 'delete':
            _handleDelete(context, _firstItemName(damage), damage.id);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'details',
          child: entry(Icons.info_outline, 'View details'),
        ),
        PopupMenuItem(value: 'print', child: entry(Icons.print, 'Print')),
        if (canEdit)
          PopupMenuItem(
            value: 'edit',
            child: entry(Icons.edit_outlined, 'Edit'),
          ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: entry(Icons.delete_outline, 'Delete'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1050;
    final isSmall = width < 700;

    return Consumer2<Datafeed, DamageProvider>(
      builder: (context, value, damageProvider, child) {
        final filteredDamages = filterdamages(damageProvider);
        final sortedDamages = _sortedDamages(filteredDamages);
        final pageCount = sortedDamages.isEmpty
            ? 1
            : ((sortedDamages.length - 1) ~/ _rowsPerPage) + 1;
        final effectivePage = _currentPage.clamp(0, pageCount - 1);
        final pageStart = effectivePage * _rowsPerPage;
        final pageEnd = (pageStart + _rowsPerPage).clamp(
          0,
          sortedDamages.length,
        );
        final pageDamages = sortedDamages.sublist(pageStart, pageEnd);
        final canManage = _canManagePage(value);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: _textColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: isSmall ? 2 : 8,
            leading: _appBarIcon(
              icon: Icons.arrow_back,
              size: 21,
              tooltip: 'Back',
              onPressed: _handleBack,
            ),
            title: _isSearching
                ? Container(
                    height: 44,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: Theme.of(context).colorScheme.secondary,
                      cursorWidth: 2,
                      decoration: InputDecoration(
                        hintText: 'Search damages...',
                        hintStyle: TextStyle(
                          color: _secondaryTextColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: _secondaryTextColor,
                          size: 22,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                      ),
                      onChanged: (text) {
                        setState(() {
                          searchQuery = text;
                          _currentPage = 0;
                        });
                      },
                    ),
                  )
                : const Text(
                    'Damages List',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
            actions: _isSearching
                ? [
                    _appBarIcon(
                      icon: Icons.clear,
                      size: 18,
                      tooltip: 'Close search',
                      onPressed: _closeSearch,
                    ),
                  ]
                : [
                    _appBarIcon(
                      icon: Icons.search,
                      size: 19,
                      tooltip: 'Search damages',
                      onPressed: _openSearch,
                    ),
                    PopupMenuButton<_DamageExportAction>(
                      tooltip: 'Download or print damages',
                      icon: Icon(Icons.download_outlined, color: _textColor),
                      onSelected: (action) => _exportDamages(
                        action,
                        filteredDamages,
                        value.company,
                      ),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _DamageExportAction.pdf,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.picture_as_pdf_outlined),
                            title: Text('Download PDF'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _DamageExportAction.print,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.print_outlined),
                            title: Text('Print / Save as PDF'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _DamageExportAction.word,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.description_outlined),
                            title: Text('Download Word'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _DamageExportAction.excel,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.table_chart_outlined),
                            title: Text('Download Excel'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _DamageExportAction.csv,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.file_download_outlined),
                            title: Text('Download CSV'),
                          ),
                        ),
                      ],
                    ),
                    if (canManage && !damageProvider.isLoading)
                      PopupMenuButton<_DamageInsightView>(
                        tooltip: 'Damage reports',
                        icon: Icon(Icons.analytics_outlined, color: _textColor),
                        onSelected: (view) =>
                            _openDamageInsight(filteredDamages, view),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _DamageInsightView.overview,
                            child: Row(
                              children: [
                                Icon(Icons.dashboard_outlined),
                                SizedBox(width: 12),
                                Text('Damage overview'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _DamageInsightView.reasons,
                            child: Row(
                              children: [
                                Icon(Icons.report_problem_outlined),
                                SizedBox(width: 12),
                                Text('Damage by reason'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _DamageInsightView.branches,
                            child: Row(
                              children: [
                                Icon(Icons.store_outlined),
                                SizedBox(width: 12),
                                Text('Damage by branch'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _DamageInsightView.suppliers,
                            child: Row(
                              children: [
                                Icon(Icons.local_shipping_outlined),
                                SizedBox(width: 12),
                                Text('Damage by supplier'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _DamageInsightView.items,
                            child: Row(
                              children: [
                                Icon(Icons.inventory_2_outlined),
                                SizedBox(width: 12),
                                Text('Damage by item'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _DamageInsightView.quantities,
                            child: Row(
                              children: [
                                Icon(Icons.numbers_outlined),
                                SizedBox(width: 12),
                                Text('Damaged quantity'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _DamageInsightView.costs,
                            child: Row(
                              children: [
                                Icon(Icons.account_balance_wallet_outlined),
                                SizedBox(width: 12),
                                Text('Inventory cost by item'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    if (canManage)
                      KeyedSubtree(
                        key: _branchButtonKey,
                        child: _appBarIcon(
                          icon: Icons.store_outlined,
                          size: 19,
                          tooltip: _selectedBranchLabel(value),
                          color: _selectedBranchId != null
                              ? Theme.of(context).colorScheme.primary
                              : _textColor,
                          onPressed: () {
                            _showBranchDropdown(context, value);
                          },
                        ),
                      ),
                    if (!isSmall)
                      ReusableDatePickerWidget(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.calendar_today,
                            size: 19,
                            color: _textColor,
                          ),
                        ),
                        onDateSelected: (selection) async {
                          setState(() {
                            selectedDate = selection;
                            _currentPage = 0;
                          });

                          await _reloadDamages(value, damageProvider);
                        },
                      )
                    else
                      _appBarIcon(
                        icon: Icons.calendar_today,
                        size: 18,
                        tooltip: 'Date filter',
                        onPressed: () async {
                          final selection = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: selectedDate,
                          );

                          if (selection == null) return;

                          setState(() {
                            selectedDate = selection;
                            _currentPage = 0;
                          });

                          await _reloadDamages(value, damageProvider);
                        },
                      ),
                  ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            tooltip: 'Register Damage',
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Damages()),
              );
            },
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 12 : 20,
              vertical: isSmall ? 12 : 16,
            ),
            child: Column(
              children: [
                const OfflineIndicator(),
                Expanded(
                  child: damageProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredDamages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_outlined,
                                color: _mutedTextColor,
                                size: 42,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                searchQuery.isEmpty
                                    ? 'No damages found'
                                    : 'No matching damages found',
                                style: TextStyle(color: _secondaryTextColor),
                              ),
                            ],
                          ),
                        )
                      : Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isDesktop ? 1200 : 700,
                            ),
                            child: isDesktop
                                ? _desktopTable(
                                    pageDamages,
                                    value,
                                    indexOffset: pageStart,
                                  )
                                : _mobileList(pageDamages, value),
                          ),
                        ),
                ),
                if (!damageProvider.isLoading && filteredDamages.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 1200 : 700,
                      ),
                      child: _paginationControls(
                        totalRecords: sortedDamages.length,
                        page: effectivePage,
                        totalPages: pageCount,
                        compact: isSmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<damageitemmodel> _sortedDamages(List<damageitemmodel> items) {
    final sorted = List<damageitemmodel>.of(items);

    sorted.sort((a, b) {
      final result = switch (_sortColumnIndex) {
        1 => a.createdat.compareTo(b.createdat),
        2 => (a.dateymd ?? '').compareTo(b.dateymd ?? ''),
        3 => _firstItemName(
          a,
        ).toLowerCase().compareTo(_firstItemName(b).toLowerCase()),
        4 => a.branchname.toLowerCase().compareTo(b.branchname.toLowerCase()),
        5 => _damageReason(
          a,
        ).toLowerCase().compareTo(_damageReason(b).toLowerCase()),
        6 => _calcTotal(_itemsOf(a)).compareTo(_calcTotal(_itemsOf(b))),
        _ => 0,
      };

      return _sortAscending ? result : -result;
    });

    return sorted;
  }

  Widget _paginationControls({
    required int totalRecords,
    required int page,
    required int totalPages,
    required bool compact,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$totalRecords damage records',
              style: TextStyle(
                color: _secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          StockRowsPerPageMenu(
            compact: compact,
            value: _rowsPerPage,
            onChanged: (value) => setState(() {
              _rowsPerPage = value;
              _currentPage = 0;
            }),
          ),
          IconButton(
            tooltip: 'Previous page',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: page > 0
                ? () => setState(() => _currentPage = page - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${page + 1}/$totalPages',
            style: TextStyle(
              color: _textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: page < totalPages - 1
                ? () => setState(() => _currentPage = page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  List<Widget> _desktopCells(int index, damageitemmodel d, Datafeed value) {
    final itemMap = _itemsOf(d);
    final itemName = _firstItemName(d);
    final total = _calcTotal(itemMap);
    final colors = Theme.of(context).colorScheme;

    return [
      Text('${index + 1}', style: TextStyle(color: colors.onSurfaceVariant)),
      Text(
        DateFormat('dd MMM yyyy').format(d.createdat),
        style: TextStyle(color: colors.onSurface),
      ),
      Text(
        d.dateymd?.isNotEmpty == true ? d.dateymd! : '-',
        style: TextStyle(color: colors.onSurface),
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            itemName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${itemMap.length} item(s)',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
          _syncStatusBadge(d),
        ],
      ),
      Text(
        d.branchname.isEmpty ? 'Unassigned' : d.branchname,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onSurface),
      ),
      Text(
        _damageReason(d),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
      Text(
        NumberFormat('#,##0.00').format(total),
        style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
      ),
      _actionsMenu(d, value),
    ];
  }

  Widget _desktopTable(
    List<damageitemmodel> items,
    Datafeed value, {
    required int indexOffset,
  }) {
    const cols = <_DamageCol>[
      _DamageCol('#', 1),
      _DamageCol('Date', 3, sortable: true),
      _DamageCol('Trx Date', 3, sortable: true),
      _DamageCol('Item', 5, sortable: true),
      _DamageCol('Branch / Warehouse', 4, sortable: true),
      _DamageCol('Reason', 4, sortable: true),
      _DamageCol(
        'Total (GHS)',
        3,
        sortable: true,
        alignment: Alignment.centerRight,
      ),
      _DamageCol('Actions', 2, alignment: Alignment.center),
    ];

    final rows = items;

    Widget tableRow(List<Widget> cells, double height, Color color) {
      return Container(
        height: height,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (var i = 0; i < cols.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                flex: cols[i].flex,
                child: Align(alignment: cols[i].alignment, child: cells[i]),
              ),
            ],
          ],
        ),
      );
    }

    Widget headerCell(int i) {
      final col = cols[i];
      final active = _sortColumnIndex == i;

      final label = Text(
        col.label,
        style: TextStyle(
          color: _secondaryTextColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      );

      if (!col.sortable) return label;

      return InkWell(
        onTap: () {
          setState(() {
            if (active) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumnIndex = i;
              _sortAscending = true;
            }
            _currentPage = 0;
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            label,
            if (active) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: _secondaryTextColor,
                size: 14,
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 900
            ? 900.0
            : constraints.maxWidth;

        return Scrollbar(
          controller: horizontalController,
          thumbVisibility: true,
          notificationPredicate: (notif) => notif.depth == 1,
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  tableRow(
                    List.generate(cols.length, headerCell),
                    44,
                    _cardColor,
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: verticalController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: verticalController,
                        itemCount: rows.length,
                        itemBuilder: (context, index) => tableRow(
                          _desktopCells(
                            indexOffset + index,
                            rows[index],
                            value,
                          ),
                          52,
                          _rowColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileList(List<damageitemmodel> filteredDamages, Datafeed value) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      itemCount: filteredDamages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final damage = filteredDamages[index];
        final itemMap = _itemsOf(damage);
        final itemName = _firstItemName(damage);
        final totalAmount = _calcTotal(itemMap);

        return Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 4,
                    top: 6,
                    bottom: 6,
                  ),
                  color: _cardHeaderColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          itemName.isEmpty ? 'Damage record' : itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _syncStatusBadge(damage),
                      _actionsMenu(damage, value),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reason: ${_damageReason(damage)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...itemMap.values.map((rawItem) {
                        if (rawItem is! Map) return const SizedBox();

                        final item = Map<String, dynamic>.from(rawItem);
                        final cp =
                            double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
                        final qty =
                            double.tryParse(
                              item['totalpieces']?.toString() ?? '0',
                            ) ??
                            0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _cardBorderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['item']?.toString().toUpperCase() ??
                                          '',
                                      style: TextStyle(
                                        color: _textColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatCurrency(cp * qty),
                                    style: TextStyle(
                                      color: _textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  _dialogDetail(
                                    'Quantity',
                                    '${item['quantity'] ?? '-'} ${item['mode'] ?? ''}',
                                  ),
                                  _dialogDetail(
                                    'Pieces',
                                    '${item['totalpieces'] ?? '-'}',
                                  ),
                                ],
                              ),
                              if (item['reason'] != null &&
                                  item['reason']
                                      .toString()
                                      .trim()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Reason: ${item['reason']}',
                                  style: TextStyle(
                                    color: _secondaryTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      Divider(color: _cardBorderColor),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final details = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFooterLabel(
                                Icons.person_outline,
                                'Staff: ${damage.createdby}',
                              ),
                              const SizedBox(height: 6),
                              _buildFooterLabel(
                                Icons.calendar_today_outlined,
                                'Date: ${DateFormat('dd MMM yyyy').format(damage.createdat)}',
                              ),
                              const SizedBox(height: 6),
                              _buildFooterLabel(
                                Icons.store_outlined,
                                'Branch: ${damage.branchname.isEmpty ? 'Unassigned' : damage.branchname}',
                              ),
                            ],
                          );

                          final amount = Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'INVENTORY COST',
                                style: TextStyle(
                                  color: _mutedTextColor,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                _formatCurrency(totalAmount),
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          );

                          if (constraints.maxWidth < 420) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                details,
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: amount,
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: details),
                              const SizedBox(width: 12),
                              amount,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooterLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _secondaryTextColor, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _textColor, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _handleDelete(
    BuildContext context,
    String itemName,
    String id,
  ) async {
    final name = itemName.isEmpty ? 'this damage' : itemName;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: Text('Delete $name?', style: TextStyle(color: _textColor)),
          content: Text(
            'This action cannot be undone. Are you sure?',
            style: TextStyle(color: _secondaryTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(innerContext, false),
              child: Text('Cancel', style: TextStyle(color: _mutedTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(innerContext, true),
              child: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.onError),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      await context.read<DamageProvider>().deleteDamage(id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name deleted successfully',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete item',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _DamageInsightsPage extends StatefulWidget {
  const _DamageInsightsPage({required this.damages, required this.view});

  final List<damageitemmodel> damages;
  final _DamageInsightView view;

  @override
  State<_DamageInsightsPage> createState() => _DamageInsightsPageState();
}

class _DamageInsightsPageState extends State<_DamageInsightsPage> {
  List<damageitemmodel> get damages => widget.damages;
  _DamageInsightView get view => widget.view;

  late _DamageSortMode _sortMode;

  @override
  void initState() {
    super.initState();
    _sortMode = switch (view) {
      _DamageInsightView.quantities => _DamageSortMode.quantity,
      _DamageInsightView.items => _DamageSortMode.name,
      _ => _DamageSortMode.cost,
    };
  }

  double _number(dynamic value) =>
      double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;

  double _units(damageitemmodel damage) {
    return damage.item.values.fold<double>(0, (sum, rawItem) {
      if (rawItem is! Map) return sum;
      return sum + _number(rawItem['totalpieces']);
    });
  }

  double _cost(damageitemmodel damage) {
    return damage.item.values.fold<double>(0, (sum, rawItem) {
      if (rawItem is! Map) return sum;
      return sum + _number(rawItem['cp']) * _number(rawItem['totalpieces']);
    });
  }

  String _groupKey(damageitemmodel damage, Map item) {
    String value(String key, {String fallback = 'Unspecified'}) {
      final text = item[key]?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }

    return switch (view) {
      _DamageInsightView.reasons => value(
        'reason',
        fallback: damage.description.trim().isEmpty
            ? 'Unspecified'
            : damage.description.trim(),
      ),
      _DamageInsightView.suppliers => value('supplier'),
      _DamageInsightView.items ||
      _DamageInsightView.quantities ||
      _DamageInsightView.costs => value('item', fallback: 'Unknown item'),
      _ => '',
    };
  }

  Map<String, _DamageSummaryBucket> _groupByItemField() {
    final groups = <String, _DamageSummaryBucket>{};
    for (final damage in damages) {
      for (final rawItem in damage.item.values.whereType<Map>()) {
        final key = _groupKey(damage, rawItem);
        final bucket = groups.putIfAbsent(key, _DamageSummaryBucket.new);
        final units = _number(rawItem['totalpieces']);
        bucket
          ..amount += _number(rawItem['cp']) * units
          ..units += units
          ..recordIds.add(damage.id);
      }
    }
    return groups;
  }

  Map<String, _DamageSummaryBucket> _groupByBranch() {
    final groups = <String, _DamageSummaryBucket>{};
    for (final damage in damages) {
      final key = damage.branchname.trim().isEmpty
          ? 'Unassigned'
          : damage.branchname.trim();
      final bucket = groups.putIfAbsent(key, _DamageSummaryBucket.new);
      bucket
        ..amount += _cost(damage)
        ..units += _units(damage)
        ..recordIds.add(damage.id);
    }
    return groups;
  }

  bool _matchesGroup(damageitemmodel damage, String key) {
    if (view == _DamageInsightView.branches) {
      final branch = damage.branchname.trim().isEmpty
          ? 'Unassigned'
          : damage.branchname.trim();
      return branch == key;
    }
    return damage.item.values.whereType<Map>().any(
      (item) => _groupKey(damage, item) == key,
    );
  }

  void _openGroup(BuildContext context, String key) {
    final records = damages
        .where((damage) => _matchesGroup(damage, key))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DamageGroupItemsPage(
          damages: records,
          view: view,
          groupLabel: key,
        ),
      ),
    );
  }

  String get _title => switch (view) {
    _DamageInsightView.overview => 'Damage overview',
    _DamageInsightView.reasons => 'Damage by reason',
    _DamageInsightView.branches => 'Damage by branch',
    _DamageInsightView.suppliers => 'Damage by supplier',
    _DamageInsightView.items => 'Damage by item',
    _DamageInsightView.quantities => 'Damaged quantity',
    _DamageInsightView.costs => 'Inventory cost by item',
  };

  IconData get _iconForView => switch (view) {
    _DamageInsightView.reasons => Icons.report_problem_outlined,
    _DamageInsightView.branches => Icons.store_outlined,
    _DamageInsightView.suppliers => Icons.local_shipping_outlined,
    _DamageInsightView.items => Icons.inventory_2_outlined,
    _DamageInsightView.quantities => Icons.numbers_outlined,
    _DamageInsightView.costs => Icons.account_balance_wallet_outlined,
    _DamageInsightView.overview => Icons.dashboard_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currency = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    final totalUnits = damages.fold<double>(0, (sum, d) => sum + _units(d));
    final totalCost = damages.fold<double>(0, (sum, d) => sum + _cost(d));
    final groups = view == _DamageInsightView.branches
        ? _groupByBranch()
        : _groupByItemField();
    final orderedGroups = groups.entries.toList()
      ..sort((a, b) {
        if (_sortMode == _DamageSortMode.quantity) {
          return b.value.units.compareTo(a.value.units);
        }
        if (_sortMode == _DamageSortMode.name) {
          return a.key.toLowerCase().compareTo(b.key.toLowerCase());
        }
        return b.value.amount.compareTo(a.value.amount);
      });

    Widget metric(IconData icon, String label, String value) => Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (view != _DamageInsightView.overview)
            PopupMenuButton<_DamageSortMode>(
              tooltip: 'Sort results',
              initialValue: _sortMode,
              onSelected: (mode) => setState(() => _sortMode = mode),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _DamageSortMode.cost,
                  child: Text('Highest inventory cost'),
                ),
                PopupMenuItem(
                  value: _DamageSortMode.quantity,
                  child: Text('Highest quantity'),
                ),
                PopupMenuItem(
                  value: _DamageSortMode.name,
                  child: Text('Name A - Z'),
                ),
              ],
              icon: const Icon(Icons.sort),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (view == _DamageInsightView.overview) ...[
                Text(
                  'Based on the damage records currently loaded for this date and branch selection.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 680
                        ? 3
                        : constraints.maxWidth >= 420
                        ? 2
                        : 1;
                    const gap = 10.0;
                    final width =
                        (constraints.maxWidth - (columns - 1) * gap) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: width,
                          child: metric(
                            Icons.receipt_long_outlined,
                            'Damage records',
                            '${damages.length}',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: metric(
                            Icons.inventory_2_outlined,
                            'Units damaged',
                            NumberFormat('#,##0.##').format(totalUnits),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: metric(
                            Icons.account_balance_wallet_outlined,
                            'Inventory cost',
                            currency.format(totalCost),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                Text(
                  'Recent damage records',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...damages.take(20).map((damage) {
                  final itemNames = damage.item.values
                      .whereType<Map>()
                      .map((item) => item['item']?.toString() ?? '')
                      .where((name) => name.isNotEmpty)
                      .take(2)
                      .join(', ');
                  return Card(
                    color: colors.surface,
                    child: ListTile(
                      leading: Icon(
                        Icons.warning_amber_outlined,
                        color: colors.primary,
                      ),
                      title: Text(
                        itemNames.isEmpty ? 'Damage record' : itemNames,
                      ),
                      subtitle: Text(
                        '${damage.branchname.isEmpty ? 'Unassigned' : damage.branchname} - ${DateFormat('dd MMM yyyy').format(damage.createdat)}',
                      ),
                      trailing: Text(currency.format(_cost(damage))),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              _DamageRecordDetailsPage(damage: damage),
                        ),
                      ),
                    ),
                  );
                }),
              ] else ...[
                Text(
                  switch (view) {
                    _DamageInsightView.reasons =>
                      'Select a reason to see the matching item, supplier, quantity, cost, and staff.',
                    _DamageInsightView.branches =>
                      'Select a branch to see its damage records and item details.',
                    _DamageInsightView.suppliers =>
                      'Select a supplier to see the damaged items linked to that supplier.',
                    _DamageInsightView.items =>
                      'Select an item to see its damage history, reasons, and suppliers.',
                    _DamageInsightView.quantities =>
                      'Items ranked by total damaged quantity. Select one to inspect its records.',
                    _DamageInsightView.costs =>
                      'Items ranked by inventory cost. Select one to inspect its records.',
                    _DamageInsightView.overview => '',
                  },
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (orderedGroups.isEmpty)
                  const Center(child: Text('No damage records available.'))
                else
                  ...orderedGroups.map(
                    (entry) => Card(
                      color: colors.surface,
                      child: ListTile(
                        leading: Icon(_iconForView, color: colors.primary),
                        title: Text(entry.key),
                        subtitle: Text(
                          '${NumberFormat('#,##0.##').format(entry.value.units)} units - ${entry.value.records} records',
                        ),
                        trailing: Text(currency.format(entry.value.amount)),
                        onTap: () => _openGroup(context, entry.key),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DamageGroupItemsPage extends StatelessWidget {
  const _DamageGroupItemsPage({
    required this.damages,
    required this.view,
    required this.groupLabel,
  });

  final List<damageitemmodel> damages;
  final _DamageInsightView view;
  final String groupLabel;

  double _number(dynamic value) =>
      double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;

  bool _matches(damageitemmodel damage, Map item) {
    final key = switch (view) {
      _DamageInsightView.branches =>
        damage.branchname.trim().isEmpty
            ? 'Unassigned'
            : damage.branchname.trim(),
      _DamageInsightView.reasons =>
        (item['reason']?.toString().trim().isNotEmpty ?? false)
            ? item['reason'].toString().trim()
            : (damage.description.trim().isEmpty
                  ? 'Unspecified'
                  : damage.description.trim()),
      _DamageInsightView.suppliers =>
        item['supplier']?.toString().trim().isNotEmpty == true
            ? item['supplier'].toString().trim()
            : 'Unspecified',
      _ =>
        item['item']?.toString().trim().isNotEmpty == true
            ? item['item'].toString().trim()
            : 'Unknown item',
    };
    return key.toLowerCase() == groupLabel.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currency = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    final itemLevel = view != _DamageInsightView.branches;

    return Scaffold(
      appBar: AppBar(title: Text(groupLabel)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                itemLevel
                    ? 'Matching damaged items - supplier, reason, quantity, cost, and staff are shown for each record.'
                    : 'Damage items recorded for this branch.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final damage in damages)
                for (final entry in damage.item.entries)
                  if (entry.value is Map &&
                      _matches(damage, entry.value as Map))
                    Builder(
                      builder: (context) {
                        final item = entry.value as Map;
                        final pieces = _number(item['totalpieces']);
                        final cost = _number(item['cp']) * pieces;
                        final branch = damage.branchname.isEmpty
                            ? 'Unassigned'
                            : damage.branchname;
                        final reason = item['reason']?.toString().trim();
                        final supplier = item['supplier']?.toString().trim();
                        final itemName =
                            item['item']?.toString().trim().isNotEmpty == true
                            ? item['item'].toString().trim()
                            : 'Unknown item';
                        final info = [
                          if (reason != null && reason.isNotEmpty)
                            'Reason: $reason',
                          'Supplier: ${supplier == null || supplier.isEmpty ? 'Unspecified' : supplier}',
                          'Staff: ${damage.createdby}',
                          'Branch: $branch',
                          'Qty: ${item['quantity'] ?? '-'} ${item['mode'] ?? ''} (${NumberFormat('#,##0.##').format(pieces)} pcs)',
                        ].join(' - ');
                        return Card(
                          color: colors.surface,
                          child: ListTile(
                            leading: Icon(
                              Icons.inventory_2_outlined,
                              color: colors.primary,
                            ),
                            title: Text(itemName),
                            subtitle: Text(
                              '$info\n${DateFormat('dd MMM yyyy, hh:mm a').format(damage.createdat)}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currency.format(cost),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  itemLevel
                                      ? '${NumberFormat('#,##0.##').format(pieces)} pcs'
                                      : currency.format(cost),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => _DamageRecordDetailsPage(
                                  damage: damage,
                                  itemKeys: {entry.key},
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DamageRecordDetailsPage extends StatelessWidget {
  const _DamageRecordDetailsPage({required this.damage, this.itemKeys});

  final damageitemmodel damage;
  final Set<String>? itemKeys;

  double _number(dynamic value) =>
      double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;

  Widget _detail(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '-' : value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currency = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    final itemEntries = damage.item.entries
        .where(
          (entry) =>
              entry.value is Map &&
              (itemKeys == null || itemKeys!.contains(entry.key)),
        )
        .toList();
    final totalCost = itemEntries.fold<double>(0, (sum, entry) {
      final item = entry.value as Map;
      return sum + _number(item['cp']) * _number(item['totalpieces']);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Damage record details')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Damaged items', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...itemEntries.map((entry) {
                final item = entry.value as Map;
                final unitCost = _number(item['cp']);
                final quantity = _number(item['totalpieces']);
                final total = unitCost * quantity;
                return Card(
                  color: colors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['item']?.toString() ?? 'Unknown item',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              currency.format(total),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 24,
                          runSpacing: 12,
                          children: [
                            _detail( context, 'Quantity',
                              '${item['quantity'] ?? '-'} ${item['mode'] ?? ''}', ),
                            _detail( context, 'Total pieces',
                              NumberFormat('#,##0.##').format(quantity), ),
                            _detail( context, 'Unit cost',
                              currency.format(unitCost), ),
                            _detail(context,  'Reason',
                              item['reason']?.toString() ?? '', ),
                            _detail(context,'Supplier',
                              item['supplier']?.toString() ?? '',),
                            if (item['barcode'] != null)
                              _detail(context, 'Barcode', '${item['barcode']}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _DamageCol {
  final String label;
  final int flex;
  final bool sortable;
  final Alignment alignment;

  const _DamageCol(
    this.label,
    this.flex, {
    this.sortable = false,
    this.alignment = Alignment.centerLeft,
  });
}
