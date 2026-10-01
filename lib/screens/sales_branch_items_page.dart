import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import 'sales_item_transactions_page.dart';
import 'sales_report_shared.dart';

class SalesBranchItemsPage extends StatefulWidget {
  final String branchId;
  final String branchName;
  final String branchLabel;
  final DateTimeRange? dateRange;
  final ValueChanged<DateTimeRange> onDateChanged;
  final ReportExport onExportReport;
  final ItemTxnExport onExportTxn;

  const SalesBranchItemsPage({
    super.key,
    required this.branchId,
    required this.branchName,
    required this.branchLabel,
    required this.dateRange,
    required this.onDateChanged,
    required this.onExportReport,
    required this.onExportTxn,
  });

  @override
  State<SalesBranchItemsPage> createState() => _SalesBranchItemsPageState();
}

class _SalesBranchItemsPageState extends State<SalesBranchItemsPage> {
  bool get _isLightTheme => srIsLightTheme(context);
  Color get _backgroundColor => srBackgroundColor(context);
  Color get _cardColor => srCardColor(context);
  Color get _headerColor => srHeaderColor(context);
  Color get _totalColor => srTotalColor(context);
  Color get _borderColor => srBorderColor(context);
  Color get _textColor => srTextColor(context);
  Color get _mutedTextColor => srMutedTextColor(context);

  late final Datafeed _provider;
  late final String _previousSearch;
  final TextEditingController _search = TextEditingController();
  final ScrollController _vc = ScrollController();

  static const int _rowsPerPage = 10;

  static const List<int> _colFlexes = [
    1,
    4,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
    3,
  ];
  static const List<String> _headers = [
    '#',
    'Item',
    'Cash Sales',
    'MoMo',
    'Hubtel',
    'Card',
    'Bank',
    'Cheque',
    'Credit Sales',
    'Total Sales',
    'Returns',
    'Discount',
    'Profit',
    'Cash@Hand',
  ];

  DateTimeRange? _range;
  String? _type;
  String? _category;
  bool _loading = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _provider = context.read<Datafeed>();
    _previousSearch = _provider.searchQuery;
    _range = widget.dateRange;
    Future.microtask(() {
      _provider.updateSearch('');
      _load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _vc.dispose();
    Future.microtask(() => _provider.updateSearch(_previousSearch));
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      await _provider.loadBranchItemsReport(
        startDate: _range?.start ?? DateTime.now(),
        endDate: _range?.end ?? DateTime.now(),
        branchId: widget.branchId,
      );
    } catch (e) {
      debugPrint('SalesBranchItemsPage load error: $e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Theme.of(context).colorScheme.primary,
            surface: Theme.of(context).colorScheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      _page = 0;
    });
    widget.onDateChanged(picked);
    await _load();
  }

  void _openItem(Map<String, dynamic> m) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalesItemTransactionsPage(
          itemId: (m['itemid'] ?? '').toString(),
          itemName: (m['item'] ?? '').toString(),
          branchId: (m['branchId'] ?? widget.branchId)?.toString(),
          branchLabel: widget.branchLabel,
          dateRange: _range,
          producttype: (m['producttype'] ?? '').toString(),
          pcategory: (m['pcategory'] ?? '').toString(),
          onExport: widget.onExportTxn,
        ),
      ),
    );
  }

  Future<void> _export(
    String action,
    List<BranchRow> rows,
    BranchRow totals,
  ) async {
    try {
      await widget.onExportReport(
        action: action,
        title: 'ITEM SALES REPORT',
        branchLabel: widget.branchName,
        countLabel: 'Items',
        firstColumn: 'ITEM',
        start: _range?.start ?? DateTime.now(),
        end: _range?.end ?? DateTime.now(),
        type: _type,
        category: _category,
        rows: rows,
        t: totals,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    }
  }

  Widget _miniStat(String title, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _isLightTheme
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: _isLightTheme ? Border.all(color: _borderColor) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: _mutedTextColor, fontSize: 10)),
          Text(
            srN(value),
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _tipStat(String title, double value, String tip) {
    return srTip(context, tip, _miniStat(title, value), title: title);
  }

  Widget _mobileTotalsCard(BranchRow totals) {
    final tips = srTips(totals);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          srTip(
            context,
            tips[11],
            Column(
              children: [
                Text(
                  'TOTAL CASH@HAND (GHS)',
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'GHS ${srN(totals.cashAtHand)}',
                  style: TextStyle(
                    color: _isLightTheme
                        ? Colors.green.shade800
                        : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            title: 'Cash @ Hand',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _tipStat('Cash Sales', totals.cashSales, tips[0]),
              _tipStat('Credit Sales', totals.credit, tips[1]),
              _tipStat('Total Sales', totals.totalSales, tips[2]),
              _tipStat('Returns', totals.returns, tips[3]),
              _tipStat('Discount', totals.discount, tips[4]),
              _tipStat('Profit', totals.profit, tips[5]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataRow(BranchRow r, int index, {bool total = false}) {
    final tips = srTips(r);
    final values = srValues(r);

    return Container(
      decoration: BoxDecoration(
        color: total ? _totalColor : srRowColor(context, index),
        border: Border(bottom: BorderSide(color: _borderColor, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: _colFlexes[0],
            child: Text(
              total ? '' : '${index + 1}',
              style: TextStyle(color: _textColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: _colFlexes[1],
            child: Text(
              r.branchName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textColor,
                fontSize: 13,
                fontWeight: total ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
          for (int i = 0; i < values.length; i++) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: _colFlexes[i + 2],
              child: srTip(
                context,
                tips[i],
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    srN(values[i]),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: i == values.length - 1 && !_isLightTheme
                          ? Colors.white
                          : _textColor,
                      fontSize: 13,
                      fontWeight: total || i == values.length - 1
                          ? FontWeight.w800
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemTable(
    List<Map<String, dynamic>> maps,
    List<BranchRow> rows,
    BranchRow totals,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: _headerColor,
                border: Border(
                  bottom: BorderSide(color: _borderColor, width: 0.7),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  for (int i = 0; i < _headers.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: _colFlexes[i],
                      child: Text(
                        _headers[i],
                        textAlign: i >= 2 ? TextAlign.right : TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _vc,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _vc,
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    return InkWell(
                      onTap: () => _openItem(maps[index]),
                      child: _dataRow(rows[index], index),
                    );
                  },
                ),
              ),
            ),
            _dataRow(totals, rows.length, total: true),
          ],
        ),
      ),
    );
  }

  Widget _itemMobileList(
    List<Map<String, dynamic>> maps,
    List<BranchRow> rows,
    BranchRow totals,
  ) {
    return Column(
      children: [
        _mobileTotalsCard(totals),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final r = rows[index];
              final tips = srTips(r);
              return InkWell(
                onTap: () => _openItem(maps[index]),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${index + 1}',
                            style: TextStyle(
                              color: _mutedTextColor,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.branchName,
                              style: TextStyle(
                                color: _isLightTheme
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _tipStat('Cash', r.cash, tips[0]),
                          _tipStat('MoMo', r.momo, tips[1]),
                          _tipStat('Hubtel', r.hubtel, tips[2]),
                          _tipStat('Card', r.card, tips[3]),
                          _tipStat('Bank', r.bank, tips[4]),
                          _tipStat('Cheque', r.cheque, tips[5]),
                          _tipStat('Credit', r.credit, tips[6]),
                          _tipStat('Total Sales', r.totalSales, tips[7]),
                          _tipStat('Returns', r.returns, tips[8]),
                          _tipStat('Discount', r.discount, tips[9]),
                          _tipStat('Profit', r.profit, tips[10]),
                          _tipStat('Cash@Hand', r.cashAtHand, tips[11]),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.sizeOf(context).width < 600;
    final maps = _provider.filterBranchItems(
      productType: _type,
      category: _category,
    );
    final rows = maps.map(BranchRow.fromItem).toList();
    final totals = BranchRow.sum(rows);
    final totalPages = rows.isEmpty
        ? 1
        : ((rows.length - 1) ~/ _rowsPerPage) + 1;
    final page = _page.clamp(0, totalPages - 1);
    final visibleMaps = maps
        .skip(page * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();
    final visibleRows = rows
        .skip(page * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        title: Text(
          '${widget.branchName} — Branch Sales Report',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _textColor,
            fontSize: 15,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Print / Download',
            color: _cardColor,
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              color: _textColor,
              size: 20,
            ),
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'print',
                child: Row(
                  children: [
                    Icon(
                      Icons.print_outlined,
                      size: 18,
                      color: _mutedTextColor,
                    ),
                    SizedBox(width: 10),
                    Text('Print'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 18,
                      color: _mutedTextColor,
                    ),
                    SizedBox(width: 10),
                    Text('Download PDF'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(
                      Icons.grid_on_outlined,
                      size: 18,
                      color: _mutedTextColor,
                    ),
                    SizedBox(width: 10),
                    Text('Download Excel'),
                  ],
                ),
              ),
            ],
            onSelected: (selected) => _export(selected, rows, totals),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (val) {
                      _provider.updateSearch(val);
                      setState(() => _page = 0);
                    },
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search item...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                srFilterButton(
                  context: context,
                  icon: Icons.inventory_2_outlined,
                  tooltip: 'Product type: ${_type ?? 'All'}',
                  allLabel: 'All Product Types',
                  options: _provider.branchItemProductTypes,
                  current: _type,
                  onPicked: (v) => setState(() {
                    _type = v;
                    _page = 0;
                  }),
                ),
                srFilterButton(
                  context: context,
                  icon: Icons.category_outlined,
                  tooltip: 'Category: ${_category ?? 'All'}',
                  allLabel: 'All Categories',
                  options: _provider.branchItemCategories,
                  current: _category,
                  onPicked: (v) => setState(() {
                    _category = v;
                    _page = 0;
                  }),
                ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _pickRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          color: _mutedTextColor,
                          size: 18,
                        ),
                        if (!isSmall) ...[
                          const SizedBox(width: 6),
                          Text(
                            _range != null
                                ? '${DateFormat('dd MMM').format(_range!.start)} - '
                                      '${DateFormat('dd MMM yyyy').format(_range!.end)}'
                                : 'Pick dates',
                            style: TextStyle(
                              color: _mutedTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: _textColor))
                  : rows.isEmpty
                  ? Center(
                      child: Text(
                        'No Sales found',
                        style: TextStyle(color: _mutedTextColor),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return _itemTable(visibleMaps, visibleRows, totals);
                        }
                        return _itemMobileList(
                          visibleMaps,
                          visibleRows,
                          totals,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: _cardColor,
            border: Border(top: BorderSide(color: _borderColor, width: 0.7)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                onPressed: page > 0
                    ? () => setState(() => _page = page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${page + 1}/$totalPages',
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                onPressed: page < totalPages - 1
                    ? () => setState(() => _page = page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
