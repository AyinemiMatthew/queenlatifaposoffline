import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../providers/ReportProvider.dart';
import '../widgets/datepicker.dart';
import '../widgets/general_ledger_export.dart';
import '../widgets/printreportpdf.dart';
import 'general_ledger_detail_screen.dart';

class generalLedger extends StatefulWidget {
  const generalLedger({super.key});

  @override
  State<generalLedger> createState() => _generalLedgerState();
}

class _ScrollScope extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    ScrollController horizontal,
    ScrollController vertical,
  )
  builder;

  const _ScrollScope({required this.builder});

  @override
  State<_ScrollScope> createState() => _ScrollScopeState();
}

class _ScrollScopeState extends State<_ScrollScope> {
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _horizontal, _vertical);
}

class _generalLedgerState extends State<generalLedger> {
  String searchQuery = '';
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  bool _isSearching = false;
  int _currentLedgerPage = 0;
  int _ledgerRowsPerPage = 13;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _textColor =>
      _isLightTheme ? Theme.of(context).colorScheme.onSurface : Colors.white;
  Color get _mutedTextColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : Colors.white70;
  Color get _backgroundColor =>
      _isLightTheme ? Colors.white : Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor =>
      _isLightTheme ? Colors.white : const Color(0xFF1A2235);
  Color get _headerColor =>
      _isLightTheme ? Colors.white : const Color(0xFF1E2A3D);
  Color get _rowColor => _isLightTheme ? Colors.white : const Color(0xFF0D1B2A);
  Color get _alternateRowColor =>
      _isLightTheme ? const Color(0xFFF3F6FA) : const Color(0xFF13243A);
  Color get _fieldColor => _isLightTheme
      ? Colors.white
      : Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _borderColor =>
      _isLightTheme ? Colors.grey.shade300 : Colors.white.withOpacity(0.1);

  late final ScrollController verticalController;
  late final ScrollController horizontalController;
  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void dispose() {
    selectedDate = null;
    _selectedBranch = null;
    verticalController.dispose();
    horizontalController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    verticalController = ScrollController();
    horizontalController = ScrollController();

    final datafeed = context.read<Datafeed>();
    final reportProvider = context.read<ReportProvider>();
    Future.microtask(() {
      datafeed.fetchBranches();
      reportProvider.fetchgeneralledgerreport(selectedDate: selectedDate);
    });
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch(ReportProvider reportProvider) {
    setState(() {
      _isSearching = false;
      _currentLedgerPage = 0;
      _searchController.clear();
    });
    reportProvider.updateGeneralLedgerSearch('');
  }

  Widget _datePickerIcon() {
    return ReusableDatePickerWidget(
      onDateSelected: (selection) {
        setState(() {
          selectedDate = selection;
          _currentLedgerPage = 0;
        });
        context.read<ReportProvider>().fetchgeneralledgerreport(
          selectedDate: selection,
          selectedBranch: _selectedBranch,
        );
      },
      child: Tooltip(
        message: selectedDate == null
            ? 'Select date range'
            : 'Date range: ${DateFormat.MMMd().format(selectedDate!.start)} - '
                  '${DateFormat.MMMd().format(selectedDate!.end)}',
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.calendar_today_outlined,
            color: _textColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _exportMenu(List<Map<String, dynamic>> rows) {
    final formatter = NumberFormat('#,##0.00');
    final provider = context.read<ReportProvider>();
    final period = selectedDate == null
        ? 'All Dates'
        : _dateRangeLabel(selectedDate!);
    return GeneralLedgerExportMenu(
      title: 'General Ledger Report',
      metadata: [
        'Company: ${provider.company}',
        'Branch: ${_branchLabel(context.read<Datafeed>())}',
        'Period: $period',
      ],
      headers: const [
        '#',
        'Account/Name',
        'Opening Balance (GHS)',
        'Debit (GHS)',
        'Credit (GHS)',
        'Balance (GHS)',
      ],
      rows: rows.asMap().entries.map((entry) {
        final ledger = entry.value;
        return [
          '${entry.key + 1}',
          capitalize(ledger['account']?.toString()),
          formatter.format((ledger['openingBalance'] ?? 0).toDouble().abs()),
          formatter.format((ledger['debit'] ?? 0).toDouble().abs()),
          formatter.format((ledger['credit'] ?? 0).toDouble().abs()),
          formatter.format((ledger['balance'] ?? 0).toDouble().abs()),
        ];
      }).toList(),
      onPrint: () => _printLedgerPdf(context, ledgerRows: rows),
    );
  }

  String _dateRangeLabel(DateTimeRange range) =>
      '${DateFormat('d MMM yyyy').format(range.start)}'
      ' to ${DateFormat('d MMM yyyy').format(range.end)}';

  Widget _searchTitle(ReportProvider reportProvider) {
    if (!_isSearching) {
      return const Text(
        'General Ledger',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      onChanged: (query) {
        setState(() => _currentLedgerPage = 0);
        reportProvider.updateGeneralLedgerSearch(query);
      },
      style: TextStyle(color: _textColor, fontSize: 15),
      cursorColor: _isLightTheme
          ? Theme.of(context).colorScheme.primary
          : Colors.white,
      decoration: InputDecoration(
        hintText: 'Search ledger...',
        hintStyle: TextStyle(color: _mutedTextColor),
        prefixIcon: Icon(Icons.search, color: _mutedTextColor, size: 20),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  reportProvider.updateGeneralLedgerSearch('');
                  setState(() => _currentLedgerPage = 0);
                  _searchFocusNode.requestFocus();
                },
                icon: Icon(Icons.clear, color: _textColor),
              ),
        filled: true,
        fillColor: _fieldColor,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  String _branchLabel(Datafeed datafeed) {
    if (_selectedBranch == null) return 'All Branches';
    for (final branch in datafeed.branches) {
      if (branch.id == _selectedBranch) return branch.branchname;
    }
    return 'All Branches';
  }

  void _selectBranch(String selection) {
    final branchId = selection == '__all_branches__'
        ? null
        : selection.substring('branch:'.length);
    setState(() {
      _selectedBranch = branchId;
      _currentLedgerPage = 0;
    });
    context.read<ReportProvider>().fetchgeneralledgerreport(
      selectedDate: selectedDate,
      selectedBranch: branchId,
    );
  }

  Future<void> _showMobileBranchSelector(Datafeed datafeed) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Select Branch',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    color: _textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.store_outlined, color: _textColor),
                title: Text(
                  'All Branches',
                  style: TextStyle(color: _textColor),
                ),
                trailing: _selectedBranch == null
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.secondary,
                      )
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _selectBranch('__all_branches__');
                },
              ),
              ...datafeed.branches.map(
                (branch) => ListTile(
                  leading: Icon(Icons.store_outlined, color: _textColor),
                  title: Text(
                    branch.branchname,
                    style: TextStyle(color: _textColor),
                  ),
                  trailing: branch.id == _selectedBranch
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.secondary,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _selectBranch('branch:${branch.id}');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _branchMenu(Datafeed datafeed) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return IconButton(
        tooltip: 'Select branch: ${_branchLabel(datafeed)}',
        onPressed: () => _showMobileBranchSelector(datafeed),
        icon: Icon(
          Icons.store_outlined,
          color: _selectedBranch == null
              ? _textColor
              : Theme.of(context).colorScheme.secondary,
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Branch: ${_branchLabel(datafeed)}',
      color: _cardColor,
      icon: Icon(
        Icons.store_outlined,
        color: _selectedBranch == null
            ? _textColor
            : Theme.of(context).colorScheme.primary,
      ),
      onSelected: _selectBranch,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '__all_branches__',
          child: Text(
            'All Branches',
            style: TextStyle(
              color: _selectedBranch == null
                  ? Theme.of(context).colorScheme.secondary
                  : _textColor,
              fontWeight: _selectedBranch == null
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ),
        ...datafeed.branches.map(
          (branch) => PopupMenuItem<String>(
            value: 'branch:${branch.id}',
            child: Text(
              branch.branchname,
              style: TextStyle(
                color: branch.id == _selectedBranch
                    ? Theme.of(context).colorScheme.secondary
                    : _textColor,
                fontWeight: branch.id == _selectedBranch
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final reportProvider = context.watch<ReportProvider>();
        final resultList = reportProvider.filtergeneralledgerreport();
        final pageSize = _ledgerRowsPerPage;
        final pageCount = (resultList.length / pageSize).ceil().clamp(
          1,
          1 << 30,
        );
        final pageIndex = _currentLedgerPage.clamp(0, pageCount - 1);
        final pageStart = pageIndex * pageSize;
        final pageRows = resultList.skip(pageStart).take(pageSize).toList();

        return Scaffold(
          backgroundColor: _backgroundColor,
          bottomNavigationBar:
              !reportProvider.isloadingledgerreport && resultList.isNotEmpty
              ? GeneralLedgerPagination(
                  totalRows: resultList.length,
                  pageIndex: pageIndex,
                  pageSize: pageSize,
                  onPageChanged: (page) =>
                      setState(() => _currentLedgerPage = page),
                  onPageSizeChanged: (pageSize) => setState(() {
                    _ledgerRowsPerPage = pageSize;
                    _currentLedgerPage = 0;
                  }),
                )
              : null,
          appBar: AppBar(
            backgroundColor: _cardColor,
            foregroundColor: _textColor,
            titleSpacing: 8,
            title: _searchTitle(reportProvider),
            centerTitle: false,
            toolbarHeight: 56,
            actions: [
              if (_isSearching)
                IconButton(
                  tooltip: 'Close search',
                  onPressed: () => _closeSearch(reportProvider),
                  icon: const Icon(Icons.close),
                  color: _textColor,
                )
              else
                IconButton(
                  tooltip: 'Search ledger',
                  onPressed: _openSearch,
                  icon: const Icon(Icons.search),
                  color: _textColor,
                ),
              if (!_isSearching) ...[
                _branchMenu(value),
                _datePickerIcon(),
                _exportMenu(resultList),
              ] else
                _exportMenu(resultList),
              const SizedBox(width: 4),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: screenWidth),
                  child: Column(
                    children: [
                      SizedBox(height: 5),
                      Expanded(
                        child: reportProvider.isloadingledgerreport
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: _textColor,
                                ),
                              )
                            : resultList.isEmpty
                            ? Center(
                                child: Text(
                                  'No Sales found',
                                  style: TextStyle(color: _mutedTextColor),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final isDesktop = constraints.maxWidth > 600;

                                  if (isDesktop) {
                                    return LayoutBuilder(
                                      builder: (context, constraints) {
                                        const baseWidths = [
                                          30,
                                          180,
                                          130,
                                          100,
                                          100,
                                          100,
                                        ];
                                        const gap = 24.0;
                                        final availableColumnWidth =
                                            constraints.maxWidth -
                                            32 -
                                            (baseWidths.length - 1) * gap;
                                        final baseColumnWidth = baseWidths
                                            .reduce((a, b) => a + b)
                                            .toDouble();
                                        final scale =
                                            availableColumnWidth <
                                                baseColumnWidth
                                            ? availableColumnWidth /
                                                  baseColumnWidth
                                            : 1.0;
                                        final widths = baseWidths
                                            .map((width) => width * scale)
                                            .toList();
                                        if (availableColumnWidth >
                                            baseColumnWidth) {
                                          widths[1] +=
                                              availableColumnWidth -
                                              baseColumnWidth;
                                        }
                                        final tableWidth = constraints.maxWidth;

                                        Widget rowOf(
                                          List<Widget> cells, {
                                          Color? backgroundColor,
                                        }) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  backgroundColor ?? _rowColor,
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: _borderColor,
                                                  width: 0.5,
                                                ),
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            constraints: const BoxConstraints(
                                              minHeight: 44,
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              children: [
                                                for (
                                                  int i = 0;
                                                  i < cells.length;
                                                  i++
                                                ) ...[
                                                  SizedBox(
                                                    width: widths[i].toDouble(),
                                                    child: cells[i],
                                                  ),
                                                  if (i != cells.length - 1)
                                                    const SizedBox(width: gap),
                                                ],
                                              ],
                                            ),
                                          );
                                        }

                                        return ScrollbarTheme(
                                          data: ScrollbarThemeData(
                                            thumbColor:
                                                MaterialStateProperty.all(
                                                  _isLightTheme
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : const Color(0xFF415A77),
                                                ),
                                            trackColor:
                                                MaterialStateProperty.all(
                                                  _fieldColor,
                                                ),
                                            trackBorderColor:
                                                MaterialStateProperty.all(
                                                  _cardColor,
                                                ),
                                            thickness:
                                                MaterialStateProperty.all(10),
                                            radius: const Radius.circular(8),
                                          ),
                                          child: Scrollbar(
                                            controller: horizontalController,
                                            thumbVisibility: true,
                                            trackVisibility: true,
                                            child: SingleChildScrollView(
                                              controller: horizontalController,
                                              scrollDirection: Axis.horizontal,
                                              child: SizedBox(
                                                width: tableWidth,
                                                height:
                                                    constraints
                                                        .maxHeight
                                                        .isFinite
                                                    ? constraints.maxHeight
                                                    : null,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: _headerColor,
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color: _borderColor,
                                                            width: 0.7,
                                                          ),
                                                        ),
                                                      ),
                                                      child: rowOf([
                                                        Text(
                                                          "#",
                                                          softWrap: true,
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Account/Name",
                                                          softWrap: true,
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Opening Balance (GHS)",
                                                          softWrap: true,
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Debit (GHS)",
                                                          softWrap: true,
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Credit(GHS)",
                                                          softWrap: true,
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Balance(GHS)",
                                                          softWrap: true,
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ]),
                                                    ),
                                                    Expanded(
                                                      child: Scrollbar(
                                                        controller:
                                                            verticalController,
                                                        thumbVisibility: true,
                                                        trackVisibility: true,
                                                        child: ListView.builder(
                                                          controller:
                                                              verticalController,
                                                          itemCount:
                                                              pageRows.length,
                                                          itemBuilder: (context, index) {
                                                            final ledger =
                                                                pageRows[index];
                                                            final formatter =
                                                                NumberFormat(
                                                                  '#,##0.00',
                                                                );
                                                            final openingBalance =
                                                                formatter.format(
                                                                  (ledger['openingBalance'] ??
                                                                          0.0)
                                                                      .toDouble()
                                                                      .abs(),
                                                                );
                                                            final debit =
                                                                formatter.format(
                                                                  (ledger['debit'] ??
                                                                          0.0)
                                                                      .toDouble(),
                                                                );
                                                            final credit =
                                                                formatter.format(
                                                                  (ledger['credit'] ??
                                                                          0.0)
                                                                      .toDouble(),
                                                                );
                                                            final balance =
                                                                formatter.format(
                                                                  (ledger['balance'] ??
                                                                          0.0)
                                                                      .toDouble()
                                                                      .abs(),
                                                                );

                                                            return InkWell(
                                                              onTap: () {
                                                                _openLedgerDetailsScreen(
                                                                  context,
                                                                  itemId: ledger['account']
                                                                      .toString()
                                                                      .toLowerCase(),
                                                                  itemName:
                                                                      ledger['account'] ??
                                                                      '',
                                                                  branchId:
                                                                      _selectedBranch,
                                                                );
                                                              },
                                                              child: rowOf(
                                                                [
                                                                  Text(
                                                                    "${pageStart + index + 1}",
                                                                    style: TextStyle(
                                                                      color:
                                                                          _textColor,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    capitalize(
                                                                      ledger['account'] ??
                                                                          '',
                                                                    ),
                                                                    style: TextStyle(
                                                                      color:
                                                                          _textColor,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    openingBalance,
                                                                    style: TextStyle(
                                                                      color:
                                                                          _textColor,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    debit,
                                                                    style: TextStyle(
                                                                      color:
                                                                          _textColor,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    credit,
                                                                    style: TextStyle(
                                                                      color:
                                                                          _textColor,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    balance,
                                                                    style: TextStyle(
                                                                      color:
                                                                          _textColor,
                                                                    ),
                                                                  ),
                                                                ],
                                                                backgroundColor:
                                                                    index.isEven
                                                                    ? _rowColor
                                                                    : _alternateRowColor,
                                                              ),
                                                            );
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
                                      },
                                    );
                                  }

                                  // MOBILE
                                  final totalBalance = resultList.fold<double>(
                                    0.0,
                                    (sum, item) =>
                                        sum +
                                        (item['balance'] ?? 0.0).toDouble(),
                                  );

                                  return Column(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "TOTAL BALANCE",
                                              style: TextStyle(
                                                color: _textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "GHS ${totalBalance.toStringAsFixed(2)}",
                                              style: TextStyle(
                                                color: _textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      Expanded(
                                        child: ListView.separated(
                                          itemCount: pageRows.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final ledger = pageRows[index];
                                            final number =
                                                ledger['number'] ?? index + 1;
                                            final account =
                                                ledger['account'] ?? '';
                                            final openingBalance =
                                                (ledger['openingBalance'] ??
                                                        0.0)
                                                    .toDouble();
                                            final debit =
                                                (ledger['debit'] ?? 0.0)
                                                    .toDouble();
                                            final credit =
                                                (ledger['credit'] ?? 0.0)
                                                    .toDouble();
                                            final balance =
                                                (ledger['balance'] ?? 0.0)
                                                    .toDouble();

                                            return Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: _textColor.withOpacity(
                                                    0.05,
                                                  ),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  /// Header row
                                                  Wrap(
                                                    // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Container(
                                                            width: 28,
                                                            height: 28,
                                                            decoration: BoxDecoration(
                                                              color: Colors.blue
                                                                  .withOpacity(
                                                                    0.15,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    6,
                                                                  ),
                                                            ),
                                                            child: Center(
                                                              child: Text(
                                                                "$number",
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .blue,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Text(
                                                            capitalize(account),
                                                            style: TextStyle(
                                                              color: _textColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Text(
                                                        "GHS ${balance.toStringAsFixed(2)}",
                                                        style: TextStyle(
                                                          color: _textColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  const SizedBox(height: 12),
                                                  Divider(
                                                    color: _borderColor,
                                                    height: 1,
                                                  ),
                                                  const SizedBox(height: 12),

                                                  /// Stats row
                                                  Wrap(
                                                    spacing: 12,
                                                    runSpacing: 8,
                                                    children: [
                                                      _miniStat(
                                                        "Opening Bal",
                                                        openingBalance,
                                                      ),
                                                      _miniStat("Debit", debit),
                                                      _miniStat(
                                                        "Credit",
                                                        credit,
                                                      ),
                                                    ],
                                                  ),

                                                  const SizedBox(height: 12),
                                                  Divider(
                                                    color: _borderColor,
                                                    height: 1,
                                                  ),
                                                  const SizedBox(height: 8),

                                                  _summaryTile(
                                                    "Balance",
                                                    balance,
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniStat(String title, double value) {
    final formatter = NumberFormat('#,##0.00');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: _mutedTextColor, fontSize: 10)),
          Text(
            formatter.format(value),
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String title, double value) {
    final formatter = NumberFormat('#,##0.00');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(color: _mutedTextColor, fontWeight: FontWeight.bold),
        ),
        Text(
          "GHS ${formatter.format(value)}",
          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _openLedgerDetailsScreen(
    BuildContext context, {
    required String itemId,
    required String itemName,
    required String? branchId,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final provider = Provider.of<ReportProvider>(context, listen: false);
    final previousSearch = provider.generalLedgerSearchQuery;
    provider.updateGeneralLedgerSearch('');

    try {
      final now = DateTime.now();
      await provider.showLedgerDetailsDialog(
        startDate: selectedDate?.start ?? now,
        endDate: selectedDate?.end ?? now,
        id: itemId,
        name: itemName,
        branchId: branchId,
      );
    } catch (error) {
      debugPrint('Error loading ledger details: $error');
      provider.updateGeneralLedgerSearch(previousSearch);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load ledger details: $error')),
      );
      return;
    }

    if (!context.mounted) return;
    final transactions = provider.filteredshowLedgerDetailsDialog();
    provider.updateGeneralLedgerSearch(previousSearch);
    Navigator.of(context, rootNavigator: true).pop();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => GeneralLedgerDetailScreen(
          title: 'General Ledger - $itemName',
          subtitle: 'Account activity',
          transactions: transactions,
          accountStatement: false,
          dateRange: selectedDate,
          activityCompany: context.read<ReportProvider>().company,
          activityBranch: _branchLabel(context.read<Datafeed>()),
          onPrint: (rows, range) =>
              printTransactions(rows, itemName, dateRange: range),
          onTransactionTap: (transaction, range) {
            final account =
                transaction['account']?.toString().isNotEmpty == true
                ? transaction['account'].toString()
                : transaction['customerName']?.toString() ?? '';
            _openLedgerAccountStatementScreen(
              routeContext,
              itemId: account,
              itemName: account,
              branchId: branchId,
              dateRange: range,
            );
          },
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadLedgerAccountTransactions({
    required DateTimeRange dateRange,
    required String itemId,
    required String itemName,
    required String? branchId,
  }) async {
    final provider = Provider.of<ReportProvider>(context, listen: false);
    final previousSearch = provider.generalLedgerSearchQuery;
    provider.updateGeneralLedgerSearch('');
    try {
      await provider.showLedgerAccountDetailsDialog(
        startDate: dateRange.start,
        endDate: dateRange.end,
        itemId: itemId,
        itemName: itemName,
        branchId: branchId,
      );
      return provider.filteredshowLedgerAccountDetailsDialog();
    } finally {
      provider.updateGeneralLedgerSearch(previousSearch);
    }
  }

  Future<void> _openLedgerAccountStatementScreen(
    BuildContext context, {
    required String itemId,
    required String itemName,
    required String? branchId,
    DateTimeRange? dateRange,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final now = DateTime.now();
    final statementDateRange =
        dateRange ?? selectedDate ?? DateTimeRange(start: now, end: now);
    late final List<Map<String, dynamic>> transactions;

    try {
      transactions = await _loadLedgerAccountTransactions(
        dateRange: statementDateRange,
        itemId: itemId,
        itemName: itemName,
        branchId: branchId,
      );
    } catch (error) {
      debugPrint('Error loading ledger account statement: $error');
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load account statement: $error')),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final datafeed = context.read<Datafeed>();
    final companyName = context.read<ReportProvider>().company;
    final branchAddress = datafeed.branchaddress;
    var statementBranch = 'All Branches';
    for (final branch in datafeed.branches) {
      if (branch.id == branchId) {
        statementBranch = branch.branchname;
        break;
      }
    }
    if (branchId == null || branchId.isEmpty) {
      statementBranch = _branchLabel(datafeed);
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => GeneralLedgerDetailScreen(
          title: 'General Ledger - $itemName',
          subtitle: '',
          transactions: transactions,
          accountStatement: true,
          dateRange: statementDateRange,
          onDateRangeChanged: (range) => _loadLedgerAccountTransactions(
            dateRange: range,
            itemId: itemId,
            itemName: itemName,
            branchId: branchId,
          ),
          statementAccountName: itemName,
          statementCompany: companyName,
          statementBranch: statementBranch,
          statementAddress: branchAddress,
          onPrint: (rows, range) => printItemTransactions(
            rows,
            itemName,
            dateRange: range,
            branchName: statementBranch,
            branchAddress: branchAddress,
          ),
          onTransactionTap: (transaction, range) {
            final accountId =
                transaction['accountId']?.toString() ??
                transaction['account']?.toString() ??
                '';
            final accountName =
                transaction['customerName']?.toString().isNotEmpty == true
                ? transaction['customerName'].toString()
                : transaction['account']?.toString() ?? '';
            _openLedgerAccountStatementScreen(
              routeContext,
              itemId: accountId,
              itemName: accountName,
              branchId:
                  transaction['branchId']?.toString() ??
                  transaction['branch']?.toString() ??
                  branchId,
              dateRange: range,
            );
          },
        ),
      ),
    );
  }

  Future<void> printTransactions(
    List transactions,
    String itemName, {
    DateTimeRange? dateRange,
  }) async {
    final pdf = pw.Document(title: "General Ledger - $itemName");
    final provider = context.read<ReportProvider>();
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    DateTime _parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    String _fmtDate(dynamic v) {
      try {
        return DateFormat('dd MMM yyyy').format(_parseDate(v));
      } catch (_) {
        return v?.toString() ?? '-';
      }
    }

    // -- number helper
    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return (v as num).toDouble();
    }

    final fmt = NumberFormat('#,##0.00');
    String _fmt(dynamic v) => fmt.format(_d(v));

    // -- totals
    double totOpening = 0, totDebit = 0, totCredit = 0, totBalance = 0;
    for (final t in transactions) {
      totOpening += _d(t['openingBalance']).abs();
      totDebit += _d(t['debit']).abs();
      totCredit += _d(t['credit']).abs();
      totBalance += _d(t['balance']).abs();
    }
    final netBalance = (totDebit - totCredit).abs();

    // -- colours
    const headerBg = PdfColor.fromInt(0xFF1B263B);
    const totalBg = PdfColor.fromInt(0xFF0D1B2A);
    const rowEven = PdfColor.fromInt(0xFFF4F6FA);
    const accent = PdfColor.fromInt(0xFF415A77);

    // -- cell helpers
    pw.Widget _cell(
      String text, {
      bool header = false,
      bool bold = false,
      bool right = false,
      double fontSize = 8,
      PdfColor? color,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          font: (header || bold) ? boldFont : baseFont,
          fontSize: fontSize,
          color: header
              ? PdfColors.white
              : (color ?? const PdfColor.fromInt(0xFF1A1A2E)),
        ),
      ),
    );

    pw.Widget _summaryLine(
      String label,
      String value, {
      bool highlight = false,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: highlight ? boldFont : baseFont,
              fontSize: highlight ? 10 : 9,
              color: highlight ? accent : PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: highlight ? 11 : 9,
              color: highlight ? accent : PdfColors.grey800,
            ),
          ),
        ],
      ),
    );

    const rpp = 30;
    final pages = (transactions.length / rpp).ceil().clamp(1, 9999);

    final printDateRange = dateRange ?? selectedDate;
    final period = printDateRange != null
        ? _dateRangeLabel(printDateRange)
        : 'All Dates';

    for (int pg = 0; pg < pages; pg++) {
      final pageRows = transactions.skip(pg * rpp).take(rpp).toList();
      final isLast = pg == pages - 1;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // -- header band
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: headerBg,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          provider.company.toUpperCase(),
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 14,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'GENERAL LEDGER',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: PdfColors.blueGrey200,
                          ),
                        ),
                        pw.Text(
                          'Account: $itemName',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 10,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          'Branch: ${_selectedBranch ?? "All Branches"}',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8,
                            color: PdfColors.blueGrey200,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Period: $period',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 9,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Generated: ${DateFormat('d MMMM y, hh:mm a').format(DateTime.now())}',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8,
                            color: PdfColors.blueGrey200,
                          ),
                        ),
                        pw.Text(
                          'Page ${pg + 1} of $pages',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8,
                            color: PdfColors.blueGrey200,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // -- summary strip
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Wrap(
                  spacing: 18,
                  children: [
                    pw.Text(
                      'Entries: ${transactions.length}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Total Debit: ${fmt.format(totDebit)}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Total Credit: ${fmt.format(totCredit)}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Net Balance: ${fmt.format(netBalance)}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.greenAccent700,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // -- data table
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(34), // #
                  1: const pw.FixedColumnWidth(90), // Date
                  2: const pw.FlexColumnWidth(3.0), // Description
                  3: const pw.FlexColumnWidth(1.4), // Opening Balance
                  4: const pw.FlexColumnWidth(1.4), // Debit
                  5: const pw.FlexColumnWidth(1.4), // Credit
                  6: const pw.FlexColumnWidth(1.4), // Balance
                },
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                    color: PdfColors.blueGrey100,
                    width: 0.4,
                  ),
                  bottom: pw.BorderSide(
                    color: PdfColors.blueGrey300,
                    width: 0.5,
                  ),
                ),
                children: [
                  // header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBg),
                    children: [
                      _cell('#', header: true, fontSize: 10),
                      _cell('DATE', header: true, fontSize: 10),
                      _cell('DESCRIPTION', header: true),
                      _cell('OPENING BAL.', header: true, right: true),
                      _cell('DEBIT', header: true, right: true),
                      _cell('CREDIT', header: true, right: true),
                      _cell('BALANCE', header: true, right: true),
                    ],
                  ),

                  // data rows
                  ...pageRows.asMap().entries.map((e) {
                    final i = e.key;
                    final t = e.value;
                    final bg = i.isOdd ? rowEven : PdfColors.white;

                    final desc = (t['description'] ?? '').toString();
                    final opening = _d(t['openingBalance']);
                    final debit = _d(t['debit']);
                    final credit = _d(t['credit']);
                    final balance = _d(t['balance']).abs();

                    final balColor = balance < 0
                        ? PdfColors.red700
                        : const PdfColor.fromInt(0xFF1A1A2E);

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: bg),
                      children: [
                        _cell('${pg * rpp + i + 1}', bold: true, fontSize: 10),
                        _cell(_fmtDate(t['date']), bold: true, fontSize: 10),
                        _cell(desc),
                        _cell(fmt.format(opening), right: true),
                        _cell(
                          fmt.format(debit),
                          right: true,
                          color: debit > 0
                              ? const PdfColor.fromInt(0xFF1565C0)
                              : null,
                        ),
                        _cell(
                          fmt.format(credit),
                          right: true,
                          color: credit > 0 ? PdfColors.red700 : null,
                        ),
                        _cell(
                          fmt.format(balance),
                          right: true,
                          bold: true,
                          color: balColor,
                        ),
                      ],
                    );
                  }),

                  // totals row
                  // if (isLast)
                  //   pw.TableRow(
                  //     decoration: const pw.BoxDecoration(color: totalBg),
                  //     children: [
                  //       _cell('',                         header: true),
                  //       _cell('',                         header: true),
                  //       _cell('TOTAL',                    header: true),
                  //       _cell(fmt.format(totOpening),     header: true, right: true),
                  //       _cell(fmt.format(totDebit),       header: true, right: true),
                  //       _cell(fmt.format(totCredit),      header: true, right: true),
                  //       _cell(fmt.format(netBalance),     header: true, right: true),
                  //     ],
                  //   ),
                ],
              ),

              pw.Spacer(),

              // -- summary box (last page only)
              if (isLast)
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 260,
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: rowEven,
                      border: pw.Border.all(color: accent, width: 0.8),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          'LEDGER SUMMARY',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 10,
                            color: accent,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        _summaryLine('Opening Balance', fmt.format(totOpening)),
                        _summaryLine('Total Debit', fmt.format(totDebit)),
                        _summaryLine('Total Credit', fmt.format(totCredit)),
                        pw.Divider(thickness: 0.8, color: accent),
                        _summaryLine(
                          'Net Balance',
                          fmt.format(netBalance),
                          highlight: true,
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Total Entries: ${transactions.length}',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8,
                            color: PdfColors.grey500,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              pw.SizedBox(height: 6),

              // -- footer -------------------------------------------------------
              pw.Divider(color: PdfColors.blueGrey200, thickness: 0.4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Confidential - ${provider.company}',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 7,
                      color: PdfColors.blueGrey400,
                    ),
                  ),
                  pw.Text(
                    'General Ledger | $itemName | $period',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 7,
                      color: PdfColors.blueGrey400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
          'ledger_${itemName.replaceAll(' ', '_')}'
          '_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _printLedgerPdf(
    BuildContext context, {
    List<Map<String, dynamic>>? ledgerRows,
  }) async {
    final provider = context.read<ReportProvider>();
    final resultList = ledgerRows ?? provider.ledgerreport;
    final formatter = NumberFormat('#,##0.00');

    final totalOpening = resultList.fold<double>(
      0.0,
      (s, e) => s + (e['openingBalance'] ?? 0.0).toDouble().abs(),
    );
    final totalDebit = resultList.fold<double>(
      0.0,
      (s, e) => s + (e['debit'] ?? 0.0).toDouble().abs(),
    );
    final totalCredit = resultList.fold<double>(
      0.0,
      (s, e) => s + (e['credit'] ?? 0.0).toDouble().abs(),
    );
    final totalBalance = resultList.fold<double>(
      0.0,
      (s, e) => s + (e['balance'] ?? 0.0).toDouble().abs(),
    );

    final rows = resultList.asMap().entries.map((entry) {
      final i = entry.key;
      final ledger = entry.value;
      return [
        '${i + 1}',
        ledger['account']?.toString() ?? '',
        formatter.format((ledger['openingBalance'] ?? 0.0).toDouble().abs()),
        formatter.format((ledger['debit'] ?? 0.0).toDouble().abs()),
        formatter.format((ledger['credit'] ?? 0.0).toDouble().abs()),
        formatter.format((ledger['balance'] ?? 0.0).toDouble().abs()),
      ];
    }).toList();

    await printReportPdf(
      context: context,
      reportTitle: 'General Ledger Report',
      companyName: provider.company,
      branchName: _selectedBranch?.isEmpty ?? true
          ? 'All Branches'
          : _selectedBranch!,
      dateRange: selectedDate,
      columns: const [
        PdfColumn('#', width: 22),
        PdfColumn('Account/Name', width: 120),
        PdfColumn('Opening Balance', width: 70),
        PdfColumn('Debit', width: 70),
        PdfColumn('Credit', width: 70),
        PdfColumn('Balance', width: 70),
      ],
      rows: rows,

      landscape: true,
      rowsPerPage: 30,
    );
  }

  Future<void> printItemTransactions(
    List transactions,
    String itemName, {
    DateTimeRange? dateRange,
    String? branchName,
    String? branchAddress,
  }) async {
    final pdf = pw.Document(title: "Item Transactions - $itemName");
    final provider = context.read<Datafeed>();
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    DateTime _parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    String _fmtDate(dynamic v) {
      try {
        return DateFormat('dd MMM yyyy').format(_parseDate(v));
      } catch (_) {
        return v?.toString() ?? '-';
      }
    }

    // number helper
    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return (v as num).toDouble();
    }

    final fmt = NumberFormat('#,##0.00');
    String _fmt(dynamic v) => fmt.format(_d(v));

    // totals
    double totOpening = 0, totDebit = 0, totCredit = 0, totBalance = 0;
    for (final t in transactions) {
      totOpening += _d(t['openingBalance']).abs();
      totDebit += _d(t['debit']).abs();
      totCredit += _d(t['credit']).abs();
      totBalance += _d(t['balance']).abs();
    }
    final netBalance = (totDebit - totCredit).abs();

    // colours
    const headerBg = PdfColor.fromInt(0xFF1B263B);
    const totalBg = PdfColor.fromInt(0xFF0D1B2A);
    const rowEven = PdfColor.fromInt(0xFFF4F6FA);
    const accent = PdfColor.fromInt(0xFF415A77);

    // cell helpers
    pw.Widget _cell(
      String text, {
      bool header = false,
      bool bold = false,
      bool right = false,
      double fontSize = 8,
      PdfColor? color,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          font: (header || bold) ? boldFont : baseFont,
          fontSize: fontSize,
          color: header
              ? PdfColors.white
              : (color ?? const PdfColor.fromInt(0xFF1A1A2E)),
        ),
      ),
    );

    pw.Widget _summaryLine(
      String label,
      String value, {
      bool highlight = false,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: highlight ? boldFont : baseFont,
              fontSize: highlight ? 10 : 9,
              color: highlight ? accent : PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: highlight ? 11 : 9,
              color: highlight ? accent : PdfColors.grey800,
            ),
          ),
        ],
      ),
    );

    const rpp = 30;
    final pages = (transactions.length / rpp).ceil().clamp(1, 9999);

    final statementDateRange =
        dateRange ??
        selectedDate ??
        DateTimeRange(start: DateTime.now(), end: DateTime.now());
    final period = _dateRangeLabel(statementDateRange);

    final statementBranch = branchName ?? _branchLabel(provider);
    final address = branchAddress ?? provider.branchaddress;
    pw.Widget headerDetail(
      String label,
      String value, {
      bool alignRight = false,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(font: boldFont),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(font: baseFont),
            ),
          ],
        ),
      ),
    );

    for (int pg = 0; pg < pages; pg++) {
      final pageRows = transactions.skip(pg * rpp).take(rpp).toList();
      final isLast = pg == pages - 1;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(bottom: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.black),
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      provider.company,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 20,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'ACCOUNT STATEMENT',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              headerDetail('Account Name', itemName),
                              if (address.isNotEmpty)
                                headerDetail('Address', address),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 24),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              headerDetail(
                                'Branch',
                                statementBranch,
                                alignRight: true,
                              ),
                              headerDetail('Period', period, alignRight: true),
                              pw.Text(
                                'Generated: ${DateFormat('d MMM y, hh:mm a').format(DateTime.now())}'
                                '  |  Page ${pg + 1} of $pages',
                                style: pw.TextStyle(
                                  font: baseFont,
                                  fontSize: 8,
                                  color: PdfColors.grey600,
                                ),
                                textAlign: pw.TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // summary strip
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: pw.BoxDecoration(
                  color: accent,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Wrap(
                  spacing: 18,
                  children: [
                    pw.Text(
                      'Entries: ${transactions.length}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Total Debit: ${fmt.format(totDebit)}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Total Credit: ${fmt.format(totCredit)}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Net Balance: ${fmt.format(netBalance)}',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 8,
                        color: PdfColors.greenAccent700,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // data table
              pw.Table(
                columnWidths: {
                  0: const pw.FixedColumnWidth(34), // #
                  1: const pw.FixedColumnWidth(90), // Date
                  2: const pw.FlexColumnWidth(3.0), // Description
                  3: const pw.FlexColumnWidth(1.4), // Opening Balance
                  4: const pw.FlexColumnWidth(1.4), // Debit
                  5: const pw.FlexColumnWidth(1.4), // Credit
                  6: const pw.FlexColumnWidth(1.4), // Balance
                },
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                    color: PdfColors.blueGrey100,
                    width: 0.4,
                  ),
                  bottom: pw.BorderSide(
                    color: PdfColors.blueGrey300,
                    width: 0.5,
                  ),
                ),
                children: [
                  // header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBg),
                    children: [
                      _cell('#', header: true, fontSize: 10),
                      _cell('DATE', header: true, fontSize: 10),
                      _cell('DESCRIPTION', header: true),
                      _cell('OPENING BAL.', header: true, right: true),
                      _cell('DEBIT', header: true, right: true),
                      _cell('CREDIT', header: true, right: true),
                      _cell('BALANCE', header: true, right: true),
                    ],
                  ),

                  // data rows
                  ...pageRows.asMap().entries.map((e) {
                    final i = e.key;
                    final t = e.value;
                    final bg = i.isOdd ? rowEven : PdfColors.white;

                    final desc = (t['description'] ?? '').toString();
                    final opening = _d(t['openingBalance']);
                    final debit = _d(t['debit']);
                    final credit = _d(t['credit']);
                    final balance = _d(t['balance']).abs();

                    final balColor = balance < 0
                        ? PdfColors.red700
                        : const PdfColor.fromInt(0xFF1A1A2E);

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: bg),
                      children: [
                        _cell('${pg * rpp + i + 1}', bold: true, fontSize: 10),
                        _cell(
                          _fmtDate(t['transactionDate'] ?? t['date']),
                          bold: true,
                          fontSize: 10,
                        ),
                        _cell(desc),
                        _cell(fmt.format(opening), right: true),
                        _cell(
                          fmt.format(debit),
                          right: true,
                          color: debit > 0
                              ? const PdfColor.fromInt(0xFF1565C0)
                              : null,
                        ),
                        _cell(
                          fmt.format(credit),
                          right: true,
                          color: credit > 0 ? PdfColors.red700 : null,
                        ),
                        _cell(
                          fmt.format(balance),
                          right: true,
                          bold: true,
                          color: balColor,
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.Spacer(),

              // summary box (last page only)
              if (isLast)
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 260,
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: rowEven,
                      border: pw.Border.all(color: accent, width: 0.8),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        pw.Text(
                          'LEDGER SUMMARY',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 10,
                            color: accent,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        _summaryLine('Opening Balance', fmt.format(totOpening)),
                        _summaryLine('Total Debit', fmt.format(totDebit)),
                        _summaryLine('Total Credit', fmt.format(totCredit)),
                        pw.Divider(thickness: 0.8, color: accent),
                        _summaryLine(
                          'Net Balance',
                          fmt.format(netBalance),
                          highlight: true,
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Total Entries: ${transactions.length}',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 8,
                            color: PdfColors.grey500,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              pw.SizedBox(height: 6),

              // footer
              pw.Divider(color: PdfColors.blueGrey200, thickness: 0.4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Confidential - ${provider.company}',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 7,
                      color: PdfColors.blueGrey400,
                    ),
                  ),
                  pw.Text(
                    'General Ledger | $itemName | $period',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 7,
                      color: PdfColors.blueGrey400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
          'ledger_${itemName.replaceAll(' ', '_')}'
          '_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
