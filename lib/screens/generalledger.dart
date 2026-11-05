import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
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
  Color get _fieldColor => _isLightTheme
      ? Colors.white
      : Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _borderColor =>
      _isLightTheme ? Colors.grey.shade300 : Colors.white.withOpacity(0.1);

  late final ScrollController verticalController;
  late final ScrollController horizontalController;
  final GlobalKey _branchButtonKey = GlobalKey();
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

    Future.microtask(() {
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchgeneralledgerreport(
        selectedDate: selectedDate,
      );
    });
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch(Datafeed datafeed) {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    datafeed.updateSearch('');
  }

  Widget _datePickerIcon() {
    return ReusableDatePickerWidget(
      onDateSelected: (selection) {
        setState(() => selectedDate = selection);
        context.read<Datafeed>().fetchgeneralledgerreport(
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

  Widget _pdfIcon() {
    return IconButton(
      tooltip: 'Download / Print',
      onPressed: () => _printLedgerPdf(context),
      icon: const Icon(Icons.picture_as_pdf_outlined),
      color: _textColor,
    );
  }

  Widget _searchTitle(Datafeed datafeed) {
    if (!_isSearching) {
      return Row(
        children: [
          const Expanded(
            child: Text(
              'General Ledger',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
            color: _textColor,
          ),
        ],
      );
    }

    return Row(
      children: [
        IconButton(
          tooltip: 'Close search',
          onPressed: () => _closeSearch(datafeed),
          icon: const Icon(Icons.arrow_back),
          color: _textColor,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            onChanged: (query) {
              setState(() {});
              datafeed.updateSearch(query);
            },
            style: TextStyle(color: _textColor, fontSize: 15),
            cursorColor: Theme.of(context).colorScheme.primary,
            decoration: InputDecoration(
              hintText: 'Search ledger...',
              hintStyle: TextStyle(color: _mutedTextColor),
              border: InputBorder.none,
              isCollapsed: true,
            ),
          ),
        ),
        if (_searchController.text.isNotEmpty)
          IconButton(
            tooltip: 'Clear search',
            onPressed: () {
              setState(_searchController.clear);
              datafeed.updateSearch('');
              _searchFocusNode.requestFocus();
            },
            icon: const Icon(Icons.clear),
            color: _textColor,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36),
          ),
      ],
    );
  }

  String _branchLabel(Datafeed datafeed) {
    if (_selectedBranch == null) return 'All Branches';
    for (final branch in datafeed.branches) {
      if (branch.id == _selectedBranch) return branch.branchname;
    }
    return 'All Branches';
  }

  Widget _branchMenu(Datafeed datafeed) {
    return PopupMenuButton<String>(
      key: _branchButtonKey,
      tooltip: 'Branch: ${_branchLabel(datafeed)}',
      color: _cardColor,
      icon: Icon(
        Icons.store_outlined,
        color: _selectedBranch == null
            ? _textColor
            : Theme.of(context).colorScheme.primary,
      ),
      onSelected: (selection) {
        final branchId = selection == '__all_branches__'
            ? null
            : selection.substring('branch:'.length);
        setState(() => _selectedBranch = branchId);
        datafeed.fetchgeneralledgerreport(
          selectedDate: selectedDate,
          selectedBranch: branchId,
        );
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: '__all_branches__',
          child: Text(
            'All Branches',
            style: TextStyle(
              color: _selectedBranch == null
                  ? Theme.of(context).colorScheme.primary
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
                    ? Theme.of(context).colorScheme.primary
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
        final resultList = value.filtergeneralledgerreport();

        return Scaffold(
          backgroundColor: _backgroundColor,

          appBar: AppBar(
            backgroundColor: _cardColor,
            foregroundColor: _textColor,
            titleSpacing: 8,
            title: _searchTitle(value),
            centerTitle: false,
            toolbarHeight: 56,
            actions: _isSearching
                ? null
                : [
                    _branchMenu(value),
                    _datePickerIcon(),
                    _pdfIcon(),
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
                        child: value.isloadingledgerreport
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
                                        const widths = [
                                          30,
                                          180,
                                          130,
                                          100,
                                          100,
                                          100,
                                        ];
                                        const gap = 24.0;
                                        final double contentWidth =
                                            widths.reduce((a, b) => a + b) +
                                            (widths.length - 1) * gap +
                                            32;
                                        final double tableWidth =
                                            constraints.maxWidth > contentWidth
                                            ? constraints.maxWidth
                                            : contentWidth;

                                        Widget rowOf(List<Widget> cells) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: _rowColor,
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
                                              maxHeight: 60,
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
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Account/Name",
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Opening Balance (GHS)",
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Debit (GHS)",
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Credit(GHS)",
                                                          style: TextStyle(
                                                            color: _textColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Balance(GHS)",
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
                                                              resultList.length,
                                                          itemBuilder: (context, index) {
                                                            final ledger =
                                                                resultList[index];
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
                                                              child: rowOf([
                                                                Text(
                                                                  "${index + 1}",
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
                                                              ]),
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
                                          itemCount: resultList.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final ledger = resultList[index];
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

    final provider = Provider.of<Datafeed>(context, listen: false);
    final previousSearch = provider.searchQuery;
    provider.updateSearch('');

    try {
      final now = DateTime.now();
      await provider.showLedgerDetailsDialog(
        startDate: selectedDate?.start ?? now,
        endDate: selectedDate?.end ?? now,
        Id: itemId,
        Name: itemName,
        branchId: branchId,
      );
    } catch (error) {
      debugPrint('Error loading ledger details: $error');
      provider.updateSearch(previousSearch);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load ledger details: $error')),
      );
      return;
    }

    if (!context.mounted) return;
    final transactions = provider.filteredshowLedgerDetailsDialog();
    provider.updateSearch(previousSearch);
    Navigator.of(context, rootNavigator: true).pop();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => GeneralLedgerDetailScreen(
          title: 'General Ledger - $itemName',
          subtitle: 'Account activity',
          transactions: transactions,
          accountStatement: false,
          onPrint: () => printTransactions(transactions, itemName),
          onTransactionTap: (transaction) {
            final account =
                transaction['account']?.toString().isNotEmpty == true
                ? transaction['account'].toString()
                : transaction['customerName']?.toString() ?? '';
            _openLedgerAccountStatementScreen(
              routeContext,
              itemId: account,
              itemName: account,
              branchId: branchId,
            );
          },
        ),
      ),
    );
  }

  Future<void> _openLedgerAccountStatementScreen(
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

    final provider = Provider.of<Datafeed>(context, listen: false);
    final previousSearch = provider.searchQuery;
    provider.updateSearch('');

    try {
      final now = DateTime.now();
      await provider.showLedgerAccountDetailsDialog(
        startDate: selectedDate?.start ?? now,
        endDate: selectedDate?.end ?? now,
        itemId: itemId,
        itemName: itemName,
        branchId: branchId,
      );
    } catch (error) {
      debugPrint('Error loading ledger account statement: $error');
      provider.updateSearch(previousSearch);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load account statement: $error')),
      );
      return;
    }

    if (!context.mounted) return;
    final transactions = provider.filteredshowLedgerAccountDetailsDialog();
    provider.updateSearch(previousSearch);
    Navigator.of(context, rootNavigator: true).pop();

    final startLabel = DateFormat(
      'yyyy MMMM EEEE dd',
    ).format(selectedDate?.start ?? DateTime.now());
    final endLabel = DateFormat(
      'yyyy MMMM EEEE dd',
    ).format(selectedDate?.end ?? DateTime.now());

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => GeneralLedgerDetailScreen(
          title: itemName,
          subtitle:
              'Address: ${provider.branchaddress} · '
              'ACCOUNT STATEMENT FROM $startLabel TO $endLabel',
          transactions: transactions,
          accountStatement: true,
          onPrint: () => printItemTransactions(transactions, itemName),
          onTransactionTap: (transaction) {
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
            );
          },
        ),
      ),
    );
  }

  Future<void> printTransactions(List transactions, String itemName) async {
    final pdf = pw.Document(title: "General Ledger - $itemName");
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final provider = context.read<Datafeed>();

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
      PdfColor? color,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          font: (header || bold) ? boldFont : baseFont,
          fontSize: 8,
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

    final period = selectedDate != null
        ? '${DateFormat('d MMM y').format(selectedDate!.start)}'
              ' - ${DateFormat('d MMM y').format(selectedDate!.end)}'
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
                  0: const pw.FixedColumnWidth(22), // #
                  1: const pw.FixedColumnWidth(65), // Date
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
                      _cell('#', header: true),
                      _cell('DATE', header: true),
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
                        _cell('${pg * rpp + i + 1}'),
                        _cell(_fmtDate(t['date'])),
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

  Future<void> _printLedgerPdf(BuildContext context) async {
    final provider = context.read<Datafeed>();
    final resultList = provider.ledgerreport;
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

  Future<void> printItemTransactions(List transactions, String itemName) async {
    final pdf = pw.Document(title: "Item Transactions - $itemName");
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final provider = context.read<Datafeed>();

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
      PdfColor? color,
    }) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          font: (header || bold) ? boldFont : baseFont,
          fontSize: 8,
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

    final period = selectedDate != null
        ? '${DateFormat('d MMM y').format(selectedDate!.start)}'
              ' - ${DateFormat('d MMM y').format(selectedDate!.end)}'
        : 'All Dates';

    // account statement period label (mirrors the dialog's startLabel/endLabel)
    final statementStart = DateFormat(
      'yyyy MMMM EEEE dd',
    ).format(selectedDate?.start ?? DateTime.now());
    final statementEnd = DateFormat(
      'yyyy MMMM EEEE dd',
    ).format(selectedDate?.end ?? DateTime.now());

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
              // header band
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
                    pw.Expanded(
                      child: pw.Column(
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
                            'Address: ${provider.branchaddress}',
                            style: pw.TextStyle(
                              font: baseFont,
                              fontSize: 8,
                              color: PdfColors.blueGrey200,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Account Name: $itemName',
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
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'ACCOUNT STATEMENT FROM $statementStart TO $statementEnd',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
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
                  0: const pw.FixedColumnWidth(22), // #
                  1: const pw.FixedColumnWidth(65), // Date
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
                      _cell('#', header: true),
                      _cell('DATE', header: true),
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
                        _cell('${pg * rpp + i + 1}'),
                        _cell(_fmtDate(t['date'])),
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
