import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../models/itemhistory.dart';
import '../widgets/itemhistorypdf.dart';

class _DetailColumn {
  final String label;
  final double width;
  const _DetailColumn(this.label, this.width);
}

enum _HistoryColumn { entryDate, recordId }

class StockItemHistoryPage extends StatefulWidget {
  final String itemId;
  final String itemName;
  final String? branchId;
  final String? branchName;
  final DateTimeRange? dateRange;
  final double? boxpieces;

  const StockItemHistoryPage({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.branchId,
    required this.branchName,
    required this.dateRange,
    this.boxpieces,
  });

  @override
  State<StockItemHistoryPage> createState() => _StockItemHistoryPageState();
}

class _StockItemHistoryPageState extends State<StockItemHistoryPage> {
  late final Datafeed _provider;
  final TextEditingController _search = TextEditingController();
  final ScrollController _vc = ScrollController();
  final ScrollController _hc = ScrollController();

  static const int _rowsPerPage = 13;
  final NumberFormat _quantityFormat = NumberFormat('#,##0.########');

  int _page = 0;
  bool _loading = true;
  bool _searchExpanded = false;
  bool _showEntryDate = false;
  bool _showRecordId = false;

  ColorScheme get _colors => Theme.of(context).colorScheme;
  Color get _surfaceColor => _colors.surface;
  Color get _raisedSurfaceColor => _colors.surfaceContainerHighest;
  Color get _textColor => _colors.onSurface;
  Color get _secondaryTextColor => _colors.onSurfaceVariant;
  Color get _borderColor => _colors.outlineVariant;
  Color get _accentColor => _colors.secondary;

  String _elapsedSince(DateTime? date, [DateTime? endDate]) {
    if (date == null) return '-';

    final seconds = (endDate ?? DateTime.now())
        .difference(date)
        .inSeconds
        .clamp(0, 31536000 * 1000);
    if (seconds < 60) return '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
    if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }
    if (seconds < 86400) {
      final hours = seconds ~/ 3600;
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    if (seconds < 604800) {
      final days = seconds ~/ 86400;
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
    if (seconds < 2592000) {
      final weeks = seconds ~/ 604800;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
    }
    if (seconds < 31536000) {
      final months = seconds ~/ 2592000;
      return '$months ${months == 1 ? 'month' : 'months'}';
    }
    final years = seconds ~/ 31536000;
    return '$years ${years == 1 ? 'year' : 'years'}';
  }

  bool _isSale(ItemHistoryEntry entry) =>
      entry.type == 'Cash Sale' || entry.type == 'Credit Sale';

  bool _isStockIn(ItemHistoryEntry entry) =>
      entry.sign == '+' && entry.type != 'Sales Return';

  String _ageSinceLatestEvent(
    ItemHistoryEntry entry,
    List<ItemHistoryEntry> history,
    bool Function(ItemHistoryEntry) isRelevantEvent,
  ) {
    final date = entry.date;
    if (date == null) return '-';

    final index = history.indexOf(entry);
    if (index == -1) return '-';
    for (var i = index + 1; i < history.length; i++) {
      final event = history[i];
      final eventDate = event.date;
      if (isRelevantEvent(event) &&
          eventDate != null &&
          !eventDate.isAfter(date)) {
        return _elapsedSince(eventDate, date);
      }
    }
    return '-';
  }

  String _stockAge(
    ItemHistoryEntry entry,
    List<ItemHistoryEntry> history,
  ) => _ageSinceLatestEvent(entry, history, _isStockIn);

  String _salesAge(
    ItemHistoryEntry entry,
    List<ItemHistoryEntry> history,
  ) => _ageSinceLatestEvent(entry, history, _isSale);

  Widget _ageDetail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: TextStyle(color: _secondaryTextColor, fontSize: 10)),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          color: _textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  void _closeSearch(Datafeed datafeed) {
    _search.clear();
    datafeed.updateItemHistorySearch('');
    setState(() {
      _searchExpanded = false;
      _page = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _provider = context.read<Datafeed>();
    Future.microtask(() async {
      _provider.updateItemHistorySearch('');
      final now = DateTime.now();
      try {
        await _provider.loadItemHistory(
          itemId: widget.itemId,
          itemName: widget.itemName,
          branchId: widget.branchId,
          startDate:
              widget.dateRange?.start ?? DateTime(now.year, now.month, now.day),
          endDate: widget.dateRange?.end ?? now,
        );
      } catch (e) {
        debugPrint('$e');
      }
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _vc.dispose();
    _hc.dispose();
    Future.microtask(() => _provider.updateItemHistorySearch(''));
    super.dispose();
  }

  String get _dateLabel => widget.dateRange == null
      ? DateFormat('dd MMM yyyy').format(DateTime.now())
      : '${DateFormat('dd MMM yyyy').format(widget.dateRange!.start)} - '
            '${DateFormat('dd MMM yyyy').format(widget.dateRange!.end)}';

  Color _signColor(String s) => s == '+'
      ? (Theme.of(context).brightness == Brightness.dark
            ? Colors.greenAccent
            : Colors.green.shade800)
      : _colors.error;

  Color _typeColor(String t) {
    if (t.startsWith('Transfer In')) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.greenAccent
          : Colors.green.shade800;
    }
    if (t.startsWith('Transfer Out')) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.orangeAccent
          : Colors.orange.shade900;
    }
    switch (t) {
      case 'Sale':
        return _colors.error;
      case 'Sales Return':
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.greenAccent
            : Colors.green.shade800;
      case 'Purchase':
        return _accentColor;
      case 'Transfer Out':
        return Theme.of(context).brightness == Brightness.dark
            ? Colors.orangeAccent
            : Colors.orange.shade900;
      default:
        return _secondaryTextColor;
    }
  }

  Future<void> _run(String failLabel, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$failLabel: $e')));
      }
    }
  }

  Widget _mobileList(
    List<ItemHistoryEntry> pagedEntries,
    List<ItemHistoryEntry> allEntries,
  ) {
    return ListView.builder(
      controller: _vc,
      padding: const EdgeInsets.all(8),
      itemCount: pagedEntries.length,
      itemBuilder: (_, i) {
        final t = pagedEntries[i];
        final double qty = t.qty.toDouble();
        final box = widget.boxpieces ?? 1;
        final double cartonqty = widget.boxpieces == 0 ? 0 : qty / box;
        final dateStr = t.date != null
            ? DateFormat('dd MMM yyyy  hh:mm a').format(t.date!)
            : '-';
        return Card(
          color: _surfaceColor,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _typeColor(t.type).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _typeColor(t.type).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        t.type,
                        style: TextStyle(
                          color: _typeColor(t.type),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: _secondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${t.sign}${_quantityFormat.format(t.qty)} pcs',
                      style: TextStyle(
                        color: _signColor(t.sign),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'GHS ${t.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${t.sign}${_quantityFormat.format(cartonqty)} Carton',
                  style: TextStyle(
                    color: _signColor(t.sign),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${t.branch} - ${t.staff}',
                  style: TextStyle(color: _secondaryTextColor, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    if (_showEntryDate)
                      _ageDetail('Entry Date', t.invoiceDate ?? '-'),
                    _ageDetail(
                      'Stock Age',
                      _stockAge(t, allEntries),
                    ),
                    _ageDetail(
                      'Sales Age',
                      _salesAge(t, allEntries),
                    ),
                  ],
                ),
                if (_showRecordId && t.transactionid.isNotEmpty)
                  Text(
                    'Ref: ${t.transactionid}',
                    style: TextStyle(color: _secondaryTextColor, fontSize: 11),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _desktopTable(
    Datafeed datafeed,
    List<dynamic> pagedEntries,
    int page,
  ) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(_colors.outline),
        trackColor: WidgetStatePropertyAll(_raisedSurfaceColor),
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double gap = MediaQuery.sizeOf(context).width < 1100 ? 14 : 40;
          final isKS008 = datafeed.companyid == 'KS008';

          final detailColumns = <_DetailColumn>[
            const _DetailColumn('#', 30),
            if (_showEntryDate) const _DetailColumn('Entry Date', 130),
            const _DetailColumn('Txn Date', 90),
            const _DetailColumn('Stock Age', 90),
            const _DetailColumn('Sales Age', 90),
            const _DetailColumn('Type', 100),
            if (isKS008) const _DetailColumn('Carton', 70),
            const _DetailColumn('-Qty (pcs)', 60),
            const _DetailColumn('Unit Price', 70),
            const _DetailColumn('Total', 80),
            const _DetailColumn('Mode', 80),
            const _DetailColumn('Staff', 60),
            if (_showRecordId) const _DetailColumn('Record ID', 90),
          ];

          final double contentWidth =
              detailColumns.fold<double>(0, (s, c) => s + c.width) +
              (detailColumns.length - 1) * gap +
              32;
          final double tableWidth = constraints.maxWidth > contentWidth
              ? constraints.maxWidth
              : contentWidth;

          return Scrollbar(
            controller: _hc,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _hc,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                height: constraints.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: _raisedSurfaceColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          for (int i = 0; i < detailColumns.length; i++) ...[
                            SizedBox(
                              width: detailColumns[i].width,
                              child: Text(
                                detailColumns[i].label,
                                style: TextStyle(
                                  color: _textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (i != detailColumns.length - 1)
                              SizedBox(width: gap),
                          ],
                        ],
                      ),
                    ),
                    Divider(height: 1, color: _borderColor),
                    Expanded(
                      child: Scrollbar(
                        controller: _vc,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _vc,
                          itemCount: pagedEntries.length,
                          itemBuilder: (context, i) {
                            final t = pagedEntries[i];
                            final dateStr = t.date != null
                                ? DateFormat(
                                    'dd MMM yyyy  hh:mm a',
                                  ).format(t.date!)
                                : '-';
                            final invoiceDateStr = t.invoiceDate ?? '';
                            final double qty = t.qty.toDouble();
                            final box = widget.boxpieces ?? 1;
                            final double cartonqty = widget.boxpieces == 0
                                ? 0
                                : qty / box;

                            final detailCells = <Widget>[
                              Text(
                                '${page * _rowsPerPage + i + 1}',
                                style: TextStyle(
                                  color: _secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              if (_showEntryDate)
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: _textColor,
                                    fontSize: 12,
                                  ),
                                ),
                              Text(
                                invoiceDateStr,
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _stockAge(
                                  t,
                                  datafeed.itemHistoryEntries,
                                ),
                                style: TextStyle(
                                  color: _secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _salesAge(
                                  t,
                                  datafeed.itemHistoryEntries,
                                ),
                                style: TextStyle(
                                  color: _secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _typeColor(
                                    t.type,
                                  ).withValues(alpha: 0.12),
                                ),
                                child: Text(
                                  t.type,
                                  style: TextStyle(
                                    color: _typeColor(t.type),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isKS008)
                                Text(
                                  '${t.sign}${_quantityFormat.format(cartonqty)}',
                                  style: TextStyle(
                                    color: _signColor(t.sign),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              Text(
                                '${t.sign}${_quantityFormat.format(t.qty)}',
                                style: TextStyle(
                                  color: _signColor(t.sign),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                t.price.toStringAsFixed(2),
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                t.total.toStringAsFixed(2),
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                t.mode,
                                style: TextStyle(
                                  color: _secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                t.staff,
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 12,
                                ),
                              ),
                              if (_showRecordId)
                                Text(
                                  t.transactionid.isNotEmpty
                                      ? t.transactionid
                                      : '-',
                                  style: TextStyle(
                                    color: _secondaryTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                            ];

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      for (
                                        int c = 0;
                                        c < detailColumns.length;
                                        c++
                                      ) ...[
                                        SizedBox(
                                          width: detailColumns[c].width,
                                          child: detailCells[c],
                                        ),
                                        if (c != detailColumns.length - 1)
                                          SizedBox(width: gap),
                                      ],
                                    ],
                                  ),
                                  Divider(height: 1, color: _borderColor),
                                ],
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
          );
        },
      ),
    );
  }

  Widget _pager(int count, int page, int totalPages) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          border: Border(top: BorderSide(color: _borderColor, width: 0.7)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Records: $count',
                style: TextStyle(
                  color: _secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Previous page',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: page > 0
                  ? () => setState(() => _page = page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${page + 1}/$totalPages',
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: page < totalPages - 1
                  ? () => setState(() => _page = page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, _) {
        final entries = datafeed.filterItemHistoryEntries();
        final isSmall = MediaQuery.sizeOf(context).width < 600;
        final totalPages = entries.isEmpty
            ? 1
            : ((entries.length - 1) ~/ _rowsPerPage) + 1;
        final page = _page.clamp(0, totalPages - 1);
        final pagedEntries = entries
            .skip(page * _rowsPerPage)
            .take(_rowsPerPage)
            .toList();

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: _surfaceColor,
            foregroundColor: _textColor,
            elevation: 0,
            title: _searchExpanded
                ? TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (value) {
                      setState(() => _page = 0);
                      datafeed.updateItemHistorySearch(value);
                    },
                    style: TextStyle(color: _textColor),
                    cursorColor: _accentColor,
                    decoration: InputDecoration(
                      hintText: 'Search stock history',
                      hintStyle: TextStyle(color: _secondaryTextColor),
                      prefixIcon: Icon(
                        Icons.search,
                        color: _secondaryTextColor,
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _search.clear();
                                setState(() => _page = 0);
                                datafeed.updateItemHistorySearch('');
                              },
                              icon: Icon(
                                Icons.clear,
                                color: _secondaryTextColor,
                              ),
                            ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${widget.branchName ?? 'All Branches'} Stock History - $_dateLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _secondaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
            actions: [
              if (_searchExpanded)
                IconButton(
                  tooltip: 'Close search',
                  onPressed: () => _closeSearch(datafeed),
                  icon: const Icon(Icons.close),
                )
              else ...[
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => setState(() => _searchExpanded = true),
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: 'Print',
                  icon: const Icon(Icons.print_outlined, size: 20),
                  onPressed: () => _run(
                    'Print failed',
                    () => printItemHistory(
                      context,
                      entries: datafeed.itemHistoryEntries,
                      itemName: widget.itemName,
                      dateLabel: _dateLabel,
                      companyName: datafeed.company,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Download PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  onPressed: () => _run(
                    'PDF download failed',
                    () => downloadItemHistoryPdf(
                      entries: datafeed.itemHistoryEntries,
                      itemName: widget.itemName,
                      dateLabel: _dateLabel,
                      companyName: datafeed.company,
                    ),
                  ),
                ),
                PopupMenuButton<_HistoryColumn>(
                  tooltip: 'Show or hide columns',
                  icon: const Icon(Icons.view_column_outlined, size: 20),
                  onSelected: (column) {
                    setState(() {
                      if (column == _HistoryColumn.entryDate) {
                        _showEntryDate = !_showEntryDate;
                      } else {
                        _showRecordId = !_showRecordId;
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem<_HistoryColumn>(
                      value: _HistoryColumn.entryDate,
                      checked: _showEntryDate,
                      child: const Text('Entry Date'),
                    ),
                    CheckedPopupMenuItem<_HistoryColumn>(
                      value: _HistoryColumn.recordId,
                      checked: _showRecordId,
                      child: const Text('Record ID'),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Download Excel',
                  icon: const Icon(Icons.grid_on_outlined, size: 20),
                  onPressed: () => _run(
                    'Excel export failed',
                    () => exportItemHistoryExcel(
                      entries: datafeed.itemHistoryEntries,
                      itemName: widget.itemName,
                      dateLabel: _dateLabel,
                      companyName: datafeed.company,
                    ),
                  ),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(color: _accentColor),
                      )
                    : entries.isEmpty
                    ? Center(
                        child: Text(
                          'No transactions found.',
                          style: TextStyle(color: _secondaryTextColor),
                        ),
                      )
                    : isSmall
                    ? _mobileList(
                        pagedEntries,
                        datafeed.itemHistoryEntries,
                      )
                    : _desktopTable(datafeed, pagedEntries, page),
              ),
            ],
          ),
          bottomNavigationBar: _pager(entries.length, page, totalPages),
        );
      },
    );
  }
}
