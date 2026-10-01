import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class SupplierReport extends StatefulWidget {
  const SupplierReport({super.key});

  @override
  State<SupplierReport> createState() => _SupplierReportState();
}

class _SupplierReportState extends State<SupplierReport> {
  final _searchController = TextEditingController();
  DateTimeRange? _selectedDate;
  String? _selectedBranch;
  String _search = '';
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final datafeed = context.read<Datafeed>();
      datafeed.fetchBranches();
      if (!datafeed.isAdminLevel) _selectedBranch = datafeed.branchid;
      _loadReport();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    final datafeed = context.read<Datafeed>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await datafeed.fetchSupplierBalanceReport(
        selectedDate: _selectedDate,
        selectedBranch: _selectedBranch,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load supplier report: $error')),
      );
    }
  }

  String _capitalizeFirst(String value) {
    final name = value.trim();
    if (name.isEmpty) return name;
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _openingAmount(dynamic value) => _amount(value).abs();
  double _balanceAmount(dynamic value) => _amount(value).abs();

  String _money(dynamic value) => NumberFormat('#,##0.00').format(_amount(value));

  List<Map<String, dynamic>> _filteredRows(List<Map<String, dynamic>> rows) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows.where((row) {
      return (row['supplierName'] ?? '').toString().toLowerCase().contains(
        query,
      );
    }).toList();
  }

  Future<void> _runExport(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }

  Future<void> _exportExcel(
    List<Map<String, dynamic>> rows,
    String company,
  ) async {
    final book = xls.Excel.createExcel();
    final sheet = book['Supplier Report'];
    sheet.appendRow([xls.TextCellValue(company)]);
    sheet.appendRow([
      xls.TextCellValue(
        _selectedDate == null
            ? 'Period: All dates'
            : 'Period: ${DateFormat('yyyy-MM-dd').format(_selectedDate!.start)}'
                  ' to ${DateFormat('yyyy-MM-dd').format(_selectedDate!.end)}',
      ),
    ]);
    sheet.appendRow([
      xls.TextCellValue('#'),
      xls.TextCellValue('Name'),
      xls.TextCellValue('Opening Balance'),
      xls.TextCellValue('Debit'),
      xls.TextCellValue('Credit'),
      xls.TextCellValue('Balance'),
    ]);
    var opening = 0.0;
    var debit = 0.0;
    var credit = 0.0;
    var balance = 0.0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowOpening = _openingAmount(row['openingBalance']);
      final rowDebit = _amount(row['debit']);
      final rowCredit = _amount(row['credit']);
      final rowBalance = _balanceAmount(row['balance']);
      opening += rowOpening;
      debit += rowDebit;
      credit += rowCredit;
      balance += rowBalance;
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(
          _capitalizeFirst(row['supplierName']?.toString() ?? ''),
        ),
        xls.DoubleCellValue(rowOpening),
        xls.DoubleCellValue(rowDebit),
        xls.DoubleCellValue(rowCredit),
        xls.DoubleCellValue(rowBalance),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue(''),
      xls.TextCellValue('TOTAL'),
      xls.DoubleCellValue(opening),
      xls.DoubleCellValue(debit),
      xls.DoubleCellValue(credit),
      xls.DoubleCellValue(balance),
    ]);
    final bytes = book.encode();
    if (bytes == null) throw Exception('Could not create the Excel file.');
    await FileSaver.instance.saveFile(
      name:
          'supplier_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<void> _printReport(
    List<Map<String, dynamic>> rows,
    String company,
  ) async {
    final font = await PdfGoogleFonts.openSansRegular();
    final bold = await PdfGoogleFonts.openSansBold();
    final pdf = pw.Document(title: 'Supplier Report');
    final totals = <String, double>{
      'openingBalance': 0,
      'debit': 0,
      'credit': 0,
      'balance': 0,
    };
    for (final row in rows) {
      for (final key in totals.keys) {
        final amount = switch (key) {
          'openingBalance' => _openingAmount(row[key]),
          'balance' => _balanceAmount(row[key]),
          _ => _amount(row[key]),
        };
        totals[key] = totals[key]! + amount;
      }
    }

    pw.Widget cell(String text, {bool header = false, bool right = false}) {
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 0.5),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: header ? bold : font,
            fontSize: 9,
            color: PdfColors.black,
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(26),
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        build: (_) => [
          pw.Text(company, style: pw.TextStyle(font: bold, fontSize: 14)),
          pw.SizedBox(height: 4),
          pw.Text(
            'SUPPLIER REPORT${_selectedDate == null ? '' : '  ${DateFormat('dd MMM yyyy').format(_selectedDate!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDate!.end)}'}',
            style: pw.TextStyle(font: bold, fontSize: 11),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.3),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                children: [
                  cell('#', header: true),
                  cell('Name', header: true),
                  cell('Opening Balance(GHS)', header: true, right: true),
                  cell('Debit (GHS)', header: true, right: true),
                  cell('Credit (GHS)', header: true, right: true),
                  cell('Balance (GHS)', header: true, right: true),
                ],
              ),
              ...rows.asMap().entries.map((entry) {
                final row = entry.value;
                return pw.TableRow(
                  children: [
                    cell('${entry.key + 1}'),
                    cell(
                      _capitalizeFirst(row['supplierName']?.toString() ?? ''),
                    ),
                    cell(
                      _openingAmount(row['openingBalance']).toStringAsFixed(2),
                      right: true,
                    ),
                    cell(_money(row['debit']), right: true),
                    cell(_money(row['credit']), right: true),
                    cell(
                      _balanceAmount(row['balance']).toStringAsFixed(2),
                      right: true,
                    ),
                  ],
                );
              }),
              pw.TableRow(
                children: [
                  cell('', header: true),
                  cell('TOTAL', header: true),
                  cell(
                    _money(totals['openingBalance']),
                    header: true,
                    right: true,
                  ),
                  cell(_money(totals['debit']), header: true, right: true),
                  cell(_money(totals['credit']), header: true, right: true),
                  cell(
                    _balanceAmount(totals['balance']).toStringAsFixed(2),
                    header: true,
                    right: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  Widget _reportTable(BuildContext context, List<Map<String, dynamic>> rows) {
    final theme = Theme.of(context);
    final columns = [
      ('#', 45.0),
      ('Name', 210.0),
      ('Opening Balance(GHS)', 150.0),
      ('Debit(GHS)', 130.0),
      ('Credit(GHS)', 130.0),
      ('Balance(GHS)', 140.0),
    ];
    final totals = <String, double>{
      'openingBalance': 0,
      'debit': 0,
      'credit': 0,
      'balance': 0,
    };
    for (final row in rows) {
      for (final key in totals.keys) {
        final amount = switch (key) {
          'openingBalance' => _openingAmount(row[key]),
          'balance' => _balanceAmount(row[key]),
          _ => _amount(row[key]),
        };
        totals[key] = totals[key]! + amount;
      }
    }

    Widget rowCells(List<Widget> cells, {bool bold = false}) => Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          SizedBox(
            width: columns[i].$2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
                child: cells[i],
              ),
            ),
          ),
      ],
    );

    Widget contentRow(List<Widget> cells, {bool bold = false}) => Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: .7)),
        ),
      ),
      child: rowCells(cells, bold: bold),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = columns.fold<double>(
          0,
          (width, column) => width + column.$2,
        );
        final table = SizedBox(
          width: tableWidth,
          child: Column(
            children: [
              contentRow(
                columns.map((column) => Text(column.$1)).toList(),
                bold: true,
              ),
              for (var index = 0; index < rows.length; index++)
                InkWell(
                  onTap: () => _openHistory(context, rows[index]),
                  child: contentRow([
                    Text('${index + 1}'),
                    Text(
                      _capitalizeFirst(
                        rows[index]['supplierName']?.toString() ?? '',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _openingAmount(
                        rows[index]['openingBalance'],
                      ).toStringAsFixed(2),
                    ),
                    Text(_money(rows[index]['debit'])),
                    Text(_money(rows[index]['credit'])),
                    Text(
                      _balanceAmount(rows[index]['balance']).toStringAsFixed(2),
                    ),
                  ]),
                ),
              contentRow([
                const Text(''),
                const Text('TOTAL'),
                Text(_money(totals['openingBalance'])),
                Text(_money(totals['debit'])),
                Text(_money(totals['credit'])),
                Text(_balanceAmount(totals['balance']).toStringAsFixed(2)),
              ], bold: true),
            ],
          ),
        );
        if (constraints.maxWidth >= tableWidth) {
          return Center(child: table);
        }
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: table,
          ),
        );
      },
    );
  }

  void _openHistory(BuildContext context, Map<String, dynamic> supplier) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupplierPaymentHistory(
          supplierId: supplier['supplierId'].toString(),
          supplierName: _capitalizeFirst(
            supplier['supplierName']?.toString() ?? '',
          ),
          selectedBranch: _selectedBranch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<Datafeed>(
      builder: (context, datafeed, _) {
        final rows = _filteredRows(datafeed.supplierBalanceReportRows);
        final selectedBranches = datafeed.branches.where(
          (branch) => branch.id == _selectedBranch,
        );
        final selectedBranchName = selectedBranches.isEmpty
            ? 'Selected branch'
            : selectedBranches.first.branchname;
        return Scaffold(
          appBar: AppBar(
            title: _searchExpanded
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _search = value),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search suppliers',
                      isDense: true,
                      border: InputBorder.none,
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            ),
                    ),
                  )
                : const Text('Supplier Report'),
            actions: [
              IconButton(
                tooltip: _searchExpanded ? 'Close search' : 'Search suppliers',
                onPressed: () {
                  setState(() {
                    _searchExpanded = !_searchExpanded;
                    if (!_searchExpanded) {
                      _searchController.clear();
                      _search = '';
                    }
                  });
                },
                icon: Icon(_searchExpanded ? Icons.close : Icons.search),
              ),
              if (datafeed.isAdminLevel)
                PopupMenuButton<String>(
                  tooltip: _selectedBranch == null
                      ? 'All branches'
                      : selectedBranchName,
                  icon: const Icon(Icons.store_outlined),
                  onSelected: (branchId) {
                    setState(() {
                      _selectedBranch = branchId.isEmpty ? null : branchId;
                    });
                    _loadReport();
                  },
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem<String>(
                      value: '',
                      checked: _selectedBranch == null,
                      child: const Text('All branches'),
                    ),
                    ...datafeed.branches.map(
                      (branch) => CheckedPopupMenuItem<String>(
                        value: branch.id,
                        checked: _selectedBranch == branch.id,
                        child: Text(branch.branchname),
                      ),
                    ),
                  ],
                ),
              ReusableDatePickerWidget(
                onDateSelected: (range) {
                  setState(() => _selectedDate = range);
                  _loadReport();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.calendar_today_outlined),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Export report',
                onSelected: (action) => _runExport(() async {
                  if (action == 'print') {
                    await _printReport(rows, datafeed.company);
                  } else {
                    await _exportExcel(rows, datafeed.company);
                  }
                }),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'print', child: Text('Print / PDF')),
                  PopupMenuItem(value: 'excel', child: Text('Excel')),
                ],
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Expanded(
                  child: datafeed.isLoadingSupplierBalanceReport
                      ? const Center(child: CircularProgressIndicator())
                      : rows.isEmpty
                      ? const Center(child: Text('No supplier balances found'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 680) {
                              return _reportTable(context, rows);
                            }
                            return ListView.separated(
                              itemCount: rows.length + 1,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                if (index == rows.length) {
                                  final totals = <String, double>{
                                    'openingBalance': 0,
                                    'debit': 0,
                                    'credit': 0,
                                    'balance': 0,
                                  };
                                  for (final row in rows) {
                                    for (final key in totals.keys) {
                                      final amount = switch (key) {
                                        'openingBalance' => _openingAmount(
                                          row[key],
                                        ),
                                        'balance' => _balanceAmount(row[key]),
                                        _ => _amount(row[key]),
                                      };
                                      totals[key] = totals[key]! + amount;
                                    }
                                  }
                                  return Card(
                                    color: theme.colorScheme.surface,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        children: [
                                          for (final entry in [
                                            (
                                              'Opening Balance',
                                              'openingBalance',
                                            ),
                                            ('Debit', 'debit'),
                                            ('Credit', 'credit'),
                                            ('Balance', 'balance'),
                                          ])
                                            _mobileBalanceRow(
                                              context,
                                              entry.$1,
                                              totals[entry.$2],
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                final row = rows[index];
                                return Card(
                                  color: theme.colorScheme.surface,
                                  child: InkWell(
                                    onTap: () => _openHistory(context, row),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${index + 1}. ${_capitalizeFirst(row['supplierName']?.toString() ?? '')}',
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          _mobileBalanceRow(
                                            context,
                                            'Opening Balance(GHS)',
                                            _openingAmount(
                                              row['openingBalance'],
                                            ),
                                          ),
                                          _mobileBalanceRow(
                                            context,
                                            'Debit (GHS)',
                                            row['debit'],
                                          ),
                                          _mobileBalanceRow(
                                            context,
                                            'Credit (GHS)',
                                            row['credit'],
                                          ),
                                          _mobileBalanceRow(
                                            context,
                                            'Balance(GHS)',
                                            _balanceAmount(row['balance']),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mobileBalanceRow(BuildContext context, String label, dynamic amount) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(_money(amount), style: style),
        ],
      ),
    );
  }
}

class SupplierPaymentHistory extends StatefulWidget {
  const SupplierPaymentHistory({
    super.key,
    required this.supplierId,
    required this.supplierName,
    required this.selectedBranch,
  });

  final String supplierId;
  final String supplierName;
  final String? selectedBranch;

  @override
  State<SupplierPaymentHistory> createState() => _SupplierPaymentHistoryState();
}

class _SupplierPaymentHistoryState extends State<SupplierPaymentHistory> {
  final _searchController = TextEditingController();
  DateTimeRange? _selectedDate;
  String _method = '';
  String _search = '';
  bool _searchExpanded = false;
  bool _loading = true;
  Object? _error;
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPayments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _openingAmount(dynamic value) => _amount(value).abs();

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  Future<void> _loadPayments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _payments = await context.read<Datafeed>().fetchSupplierPaymentHistory(
        supplierId: widget.supplierId,
        selectedBranch: widget.selectedBranch,
        selectedDate: _selectedDate,
      );
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visiblePayments {
    return _payments.where((payment) {
      final method = (payment['paymentMode'] ?? '').toString();
      final query = _search.trim().toLowerCase();
      return (_method.isEmpty || method == _method) &&
          (query.isEmpty ||
              method.toLowerCase().contains(query) ||
              (payment['transactionRef'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(query));
    }).toList();
  }

  Future<void> _exportExcel(
    List<Map<String, dynamic>> rows,
    String company,
  ) async {
    final book = xls.Excel.createExcel();
    final sheet = book['Supplier Payment History'];
    sheet.appendRow([xls.TextCellValue(company)]);
    sheet.appendRow([xls.TextCellValue('Supplier: ${widget.supplierName}')]);
    sheet.appendRow([
      xls.TextCellValue(
        _selectedDate == null
            ? 'Period: All dates'
            : 'Period: ${DateFormat('yyyy-MM-dd').format(_selectedDate!.start)}'
                  ' to ${DateFormat('yyyy-MM-dd').format(_selectedDate!.end)}',
      ),
    ]);
    sheet.appendRow([
      xls.TextCellValue('#'),
      xls.TextCellValue('Date'),
      xls.TextCellValue('Opening Balance'),
      xls.TextCellValue('Amount'),
      xls.TextCellValue('Payment Method'),
      xls.TextCellValue('Reference'),
      xls.TextCellValue('Staff'),
    ]);
    var total = 0.0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final amount = _amount(row['amount']);
      total += amount;
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(
          _date(row['date']) == null
              ? '-'
              : DateFormat('yyyy-MM-dd').format(_date(row['date'])!),
        ),
        xls.DoubleCellValue(_openingAmount(row['openingBalance'])),
        xls.DoubleCellValue(amount),
        xls.TextCellValue((row['paymentMode'] ?? '').toString()),
        xls.TextCellValue((row['transactionRef'] ?? '').toString()),
        xls.TextCellValue((row['staff'] ?? '').toString()),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue(''),
      xls.TextCellValue('TOTAL'),
      xls.TextCellValue(''),
      xls.DoubleCellValue(total),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
    ]);
    final bytes = book.encode();
    if (bytes == null) throw Exception('Could not create the Excel file.');
    await FileSaver.instance.saveFile(
      name:
          'supplier_payment_history_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<void> _printHistory(
    List<Map<String, dynamic>> rows,
    String company,
  ) async {
    final font = await PdfGoogleFonts.openSansRegular();
    final bold = await PdfGoogleFonts.openSansBold();
    final pdf = pw.Document(title: 'Supplier Payment History');
    pw.Widget cell(String text, {bool header = false, bool right = false}) =>
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.5),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font: header ? bold : font,
              fontSize: 8,
              color: PdfColors.black,
            ),
          ),
        );
    final total = rows.fold<double>(
      0,
      (total, row) => total + _amount(row['amount']),
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(26),
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        build: (_) => [
          pw.Text(company, style: pw.TextStyle(font: bold, fontSize: 14)),
          pw.SizedBox(height: 4),
          pw.Text(
            'SUPPLIER PAYMENT HISTORY — ${widget.supplierName}',
            style: pw.TextStyle(font: bold, fontSize: 11),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(28),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(2),
              6: const pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                children: [
                  cell('#', header: true),
                  cell('Date', header: true),
                  cell('Opening Balance (GHS)', header: true, right: true),
                  cell('Amount (GHS)', header: true, right: true),
                  cell('Payment Method', header: true),
                  cell('Reference', header: true),
                  cell('Staff', header: true),
                ],
              ),
              ...rows.asMap().entries.map((entry) {
                final row = entry.value;
                final date = _date(row['date']);
                return pw.TableRow(
                  children: [
                    cell('${entry.key + 1}'),
                    cell(
                      date == null
                          ? '-'
                          : DateFormat('yyyy-MM-dd').format(date),
                    ),
                    cell(
                      _openingAmount(row['openingBalance']).toStringAsFixed(2),
                      right: true,
                    ),
                    cell(
                      _amount(row['amount']).toStringAsFixed(2),
                      right: true,
                    ),
                    cell((row['paymentMode'] ?? '').toString()),
                    cell((row['transactionRef'] ?? '').toString()),
                    cell((row['staff'] ?? '').toString()),
                  ],
                );
              }),
              pw.TableRow(
                children: [
                  cell('', header: true),
                  cell('TOTAL (GHS)', header: true),
                  cell('', header: true),
                  cell(total.toStringAsFixed(2), header: true, right: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  Future<void> _runExport(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment history export failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _visiblePayments;
    final methods =
        _payments
            .map((payment) => (payment['paymentMode'] ?? '').toString())
            .where((method) => method.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final company = context.select<Datafeed, String>(
      (datafeed) => datafeed.company,
    );
    return Scaffold(
      appBar: AppBar(
        title: _searchExpanded
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => setState(() => _search = value),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search method or reference',
                  isDense: true,
                  border: InputBorder.none,
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        ),
                ),
              )
            : Text(
                '${widget.supplierName} Payment History',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          IconButton(
            tooltip: _searchExpanded ? 'Close search' : 'Search history',
            onPressed: () {
              setState(() {
                _searchExpanded = !_searchExpanded;
                if (!_searchExpanded) {
                  _searchController.clear();
                  _search = '';
                }
              });
            },
            icon: Icon(_searchExpanded ? Icons.close : Icons.search),
          ),
          PopupMenuButton<String>(
            tooltip: _method.isEmpty ? 'All payment methods' : _method,
            icon: const Icon(Icons.filter_list),
            onSelected: (method) => setState(() => _method = method),
            itemBuilder: (_) => [
              CheckedPopupMenuItem<String>(
                value: '',
                checked: _method.isEmpty,
                child: const Text('All methods'),
              ),
              ...methods.map(
                (method) => CheckedPopupMenuItem<String>(
                  value: method,
                  checked: _method == method,
                  child: Text(method),
                ),
              ),
            ],
          ),
          ReusableDatePickerWidget(
            onDateSelected: (range) {
              setState(() => _selectedDate = range);
              _loadPayments();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.calendar_today_outlined),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Export payment history',
            onSelected: (action) => _runExport(() async {
              if (action == 'print') {
                await _printHistory(rows, company);
              } else {
                await _exportExcel(rows, company);
              }
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'print', child: Text('Print / PDF')),
              PopupMenuItem(value: 'excel', child: Text('Excel')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text('Could not load payment history: $_error'),
                    )
                  : rows.isEmpty
                  ? const Center(child: Text('No supplier payments found'))
                  : ListView(
                      children: [
                        if (MediaQuery.sizeOf(context).width >= 700)
                          _paymentTable(context, rows)
                        else ...[
                          ...rows.asMap().entries.map((entry) {
                            final row = entry.value;
                            final date = _date(row['date']);
                            return Card(
                              color: theme.colorScheme.surface,
                              child: ListTile(
                                title: Text(
                                  NumberFormat(
                                    '#,##0.00',
                                  ).format(_amount(row['amount'])),
                                ),
                                subtitle: Text(
                                  '${date == null ? '-' : DateFormat.yMMMd().format(date)} · ${row['paymentMode'] ?? '-'}\nOpening balance: ${NumberFormat('#,##0.00').format(_openingAmount(row['openingBalance']))}\n${row['transactionRef'] ?? ''}',
                                ),
                                isThreeLine: true,
                              ),
                            );
                          }),
                          _paymentTotal(rows),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentTable(BuildContext context, List<Map<String, dynamic>> rows) {
    final theme = Theme.of(context);
    final columns = [
      ('#', 45.0),
      ('Date', 145.0),
      ('Opening Balance (GHS)', 155.0),
      ('Amount (GHS)', 145.0),
      ('Payment Method', 180.0),
      ('Reference', 210.0),
      ('Staff', 150.0),
    ];
    Widget line(List<Widget> cells, {bool bold = false}) => Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: .7)),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width: columns[i].$2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 11,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  ),
                  child: cells[i],
                ),
              ),
            ),
        ],
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: columns.fold<double>(0, (width, column) => width + column.$2),
        child: Column(
          children: [
            line(columns.map((column) => Text(column.$1)).toList(), bold: true),
            for (var i = 0; i < rows.length; i++)
              line([
                Text('${i + 1}'),
                Text(_formatPaymentDate(rows[i]['date'])),
                Text(
                  NumberFormat(
                    '#,##0.00',
                  ).format(_openingAmount(rows[i]['openingBalance'])),
                ),
                Text(
                  NumberFormat('#,##0.00').format(_amount(rows[i]['amount'])),
                ),
                Text((rows[i]['paymentMode'] ?? '').toString()),
                Text((rows[i]['transactionRef'] ?? '').toString()),
                Text((rows[i]['staff'] ?? '').toString()),
              ]),
         //   _paymentTotal(rows),
          ],
        ),
      ),
    );
  }

  String _formatPaymentDate(dynamic value) {
    final date = _date(value);
    return date == null ? '-' : DateFormat.yMMMd().format(date);
  }

  Widget _paymentTotal(List<Map<String, dynamic>> rows) {
    final total = rows.fold<double>(
      0,
      (total, row) => total + _amount(row['amount']),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Total payments: '),
          Text(
            NumberFormat('#,##0.00').format(total),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
