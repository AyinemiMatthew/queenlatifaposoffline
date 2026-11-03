import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import 'stock_item_history_page.dart';
import '../widgets/stockmovementexcel.dart';

class _MovementColumn {
  final String label;
  final double width;
  const _MovementColumn(this.label, this.width);
}

class StockMovementPage extends StatefulWidget {
  final String itemId;
  final String itemName;
  final double? boxpiece;
  final String? branchId;
  final String? branchName;
  final DateTimeRange? dateRange;
  final Future<void> Function(List<Map<String, dynamic>> transactions) onPrint;

  const StockMovementPage({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.boxpiece,
    required this.branchId,
    required this.branchName,
    required this.dateRange,
    required this.onPrint,
  });

  @override
  State<StockMovementPage> createState() => _StockMovementPageState();
}

class _StockMovementPageState extends State<StockMovementPage> {
  late final Datafeed _provider;
  final TextEditingController _search = TextEditingController();
  final ScrollController _vc = ScrollController();
  final ScrollController _hc = ScrollController();

  static const int _rowsPerPage = 16;
  static const double _colGap = 10;

  static const List<_MovementColumn> _columns = [
    _MovementColumn('#', 40),
    _MovementColumn('Date', 100),
    _MovementColumn('Opening', 90),
    _MovementColumn('New Stock', 90),
    _MovementColumn('Transfer In', 90),
    _MovementColumn('Transfer Out', 90),
    _MovementColumn('Sales Qty', 90),
    _MovementColumn('Sale Return', 90),
    _MovementColumn('Purchase Return', 80),
    _MovementColumn('Damages', 70),
    _MovementColumn('Pieces Balance', 90),
    _MovementColumn('Carton Balance', 80),
  ];

  int _page = 0;
  bool _loading = true;
  bool _searchExpanded = false;

  ColorScheme get _colors => Theme.of(context).colorScheme;
  Color get _surfaceColor => _colors.surface;
  Color get _raisedSurfaceColor => _colors.surfaceContainerHighest;
  Color get _textColor => _colors.onSurface;
  Color get _secondaryTextColor => _colors.onSurfaceVariant;
  Color get _borderColor => _colors.outlineVariant;
  Color get _accentColor => _colors.secondary;

  void _closeSearch(Datafeed provider) {
    _search.clear();
    provider.updateStockDialogSearch('');
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
      _provider.updateStockDialogSearch('');
      final now = DateTime.now();
      try {
        await _provider.loadStockTransactions(
          startDate:
              widget.dateRange?.start ?? DateTime(now.year, now.month, now.day),
          endDate:
              widget.dateRange?.end ?? DateTime(now.year, now.month, now.day),
          itemId: widget.itemId,
          itemName: widget.itemName,
          selectedBranch: widget.branchId,
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
    Future.microtask(() => _provider.updateStockDialogSearch(''));
    super.dispose();
  }

  void _openHistory(String itemId, String item, double boxPiece) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockItemHistoryPage(
          itemId: itemId,
          itemName: item,
          branchId: widget.branchId,
          branchName: widget.branchName,
          dateRange: widget.dateRange,
          boxpieces: boxPiece,
        ),
      ),
    );
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> transactions) async {
    final now = DateTime.now();
    try {
      await exportStockMovementExcel(
        transactions: transactions,
        itemName: widget.itemName,
        branchName: widget.branchName ?? 'All Branches',
        startDate:
            widget.dateRange?.start ?? DateTime(now.year, now.month, now.day),
        endDate:
            widget.dateRange?.end ?? DateTime(now.year, now.month, now.day),
        boxPiece: widget.boxpiece,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Excel export failed: $error')));
    }
  }

  Widget _miniStatstring(String title, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _raisedSurfaceColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: _secondaryTextColor, fontSize: 10),
          ),
          Text(
            textAlign: TextAlign.right,
            value.toString(),
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _mobileCards(List<Map<String, dynamic>> transactions, int startIndex) {
    return Scrollbar(
      controller: _vc,
      child: ListView.builder(
        controller: _vc,
        padding: const EdgeInsets.all(8),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final t = transactions[index];

          final no = startIndex + index + 1;
          final item = t['item'] ?? '';
          final itemid = t['itemId'] ?? '';
          final transferIn = t['transfer_recieved_qty'] ?? 0;
          final openingStock = t['opening_stock'] ?? 0;
          final newStock = t['newstock'] ?? 0;
          final salesQty = t['sales_qty'] ?? 0;
          final saleReturns = t['sale_returns'] ?? 0;
          final purchaseReturns = t['purchase_returns'] ?? 0;
          final damages = t['damages'] ?? 0;
          final transfer = t['transfer_qty'] ?? 0;
          final balance = t['balance_cd'] ?? 0;

          final boxPiece = double.tryParse(widget.boxpiece.toString()) ?? 1;
          final cartonQtyBal = balance / (boxPiece == 0 ? 1 : boxPiece);
          final datte = t['date'] ?? '';

          String formattedDate = '-';
          if (datte is DateTime) {
            formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(datte);
          } else if (datte is Timestamp) {
            formattedDate = DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format(datte.toDate());
          }

          return InkWell(
            onTap: () => _openHistory(itemid, item, boxPiece),
            child: Card(
              color: _surfaceColor,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$no',
                      style: TextStyle(
                        color: _secondaryTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.toString(),
                      style: TextStyle(
                        color: _accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: _secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _miniStatstring(
                          'Opening Stock',
                          openingStock.toString(),
                        ),
                        _miniStatstring('New Stock', newStock.toString()),
                        _miniStatstring('Sales Qty', salesQty.toString()),
                        _miniStatstring('Sale Return', saleReturns.toString()),
                        _miniStatstring(
                          'Transfer In',
                          transferIn?.toString() ?? '0',
                        ),
                        _miniStatstring(
                          'Transfer Out',
                          t['transfer']?.toString() ?? '0',
                        ),
                        _miniStatstring(
                          'Purchase Return',
                          purchaseReturns.toString(),
                        ),
                        _miniStatstring('Damages', damages.toString()),
                        _miniStatstring('Transfer', transfer.toString()),
                        _miniStatstring('Pcs Bal', balance.toString()),
                        _miniStatstring(
                          'Ctn Bal',
                          cartonQtyBal.toStringAsFixed(1),
                        ),
                      ],
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

  Widget _desktopRow(Map<String, dynamic> t, int index) {
    final summarydate = t['date'] ?? '';
    final openingStock = t['opening_stock'] ?? 0;
    final newstock = t['newstock'] ?? 0;
    final salesQty = t['sales_qty'] ?? 0;
    final saleReturns = t['sale_returns'] ?? 0;
    final purchaseReturns = t['purchase_returns'] ?? 0;
    final damages = t['damages'] ?? 0;
    final balanceCd = t['balance_cd'] ?? 0;
    final transferIn = t['transfer_recieved_qty'] ?? 0;
    final transferOut = t['transfer_qty'] ?? 0;
    final item = t['item'] ?? '';
    final itemid = t['itemId'] ?? '';
    final boxPiece = double.tryParse(widget.boxpiece.toString()) ?? 1;
    final cartonQtyBal = balanceCd / (boxPiece == 0 ? 1 : boxPiece);

    final style = TextStyle(color: _textColor);

    final cells = <Widget>[
      Text('${index + 1}', style: style),
      Text(summarydate.toString(), style: style),
      Text(openingStock.toString(), style: style),
      Text(newstock.toString(), style: style),
      Text(transferIn.toString(), style: style),
      Text(transferOut.toString(), style: style),
      Text(salesQty.toString(), style: style),
      Text(saleReturns.toString(), style: style),
      Text(purchaseReturns.toString(), style: style),
      Text(damages.toString(), style: style),
      Text(balanceCd.toString(), style: style),
      Text(cartonQtyBal.toStringAsFixed(1), style: style),
    ];

    return InkWell(
      onTap: () => _openHistory(itemid, item, boxPiece),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          border: Border(bottom: BorderSide(color: _borderColor)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < _columns.length; i++) ...[
              SizedBox(width: _columns[i].width, child: cells[i]),
              if (i != _columns.length - 1) const SizedBox(width: _colGap),
            ],
          ],
        ),
      ),
    );
  }

  Widget _desktopTable(
    List<Map<String, dynamic>> transactions,
    int startIndex,
  ) {
    final double totalColsWidth =
        _columns.fold<double>(0, (s, c) => s + c.width) +
        (_columns.length - 1) * _colGap +
        40;

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(_colors.outline),
        trackColor: WidgetStatePropertyAll(_raisedSurfaceColor),
        trackBorderColor: WidgetStatePropertyAll(_borderColor),
        thickness: const WidgetStatePropertyAll(10),
        radius: const Radius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double contentWidth = constraints.maxWidth > totalColsWidth
              ? constraints.maxWidth
              : totalColsWidth;

          return Scrollbar(
            controller: _hc,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _hc,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 40,
                      color: _raisedSurfaceColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          for (int i = 0; i < _columns.length; i++) ...[
                            SizedBox(
                              width: _columns[i].width,
                              child: Text(
                                _columns[i].label,
                                style: TextStyle(
                                  color: _textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (i != _columns.length - 1)
                              const SizedBox(width: _colGap),
                          ],
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: _borderColor),
                    Expanded(
                      child: Scrollbar(
                        controller: _vc,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: ListView.builder(
                          controller: _vc,
                          itemCount: transactions.length,
                          itemBuilder: (context, index) => Column(
                            children: [
                              _desktopRow(
                                transactions[index],
                                startIndex + index,
                              ),
                              Divider(height: 1, color: _borderColor),
                            ],
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
                'Transactions: $count',
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
      builder: (context, provider, _) {
        final transactions = provider.filterstockTransactions();
        final isSmall = MediaQuery.sizeOf(context).width < 600;
        final totalPages = transactions.isEmpty
            ? 1
            : ((transactions.length - 1) ~/ _rowsPerPage) + 1;
        final page = _page.clamp(0, totalPages - 1);
        final paged = transactions
            .skip(page * _rowsPerPage)
            .take(_rowsPerPage)
            .toList();
        final startIndex = page * _rowsPerPage;

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
                    onChanged: (val) {
                      setState(() => _page = 0);
                      provider.updateStockDialogSearch(val);
                    },
                    style: TextStyle(color: _textColor),
                    cursorColor: _accentColor,
                    decoration: InputDecoration(
                      hintText: 'Search stock movements',
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
                                provider.updateStockDialogSearch('');
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
                        widget.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Stock Movement for ${widget.branchName ?? 'All Branches'}',
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
                  onPressed: () => _closeSearch(provider),
                  icon: const Icon(Icons.close),
                )
              else ...[
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => setState(() => _searchExpanded = true),
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: 'Download Excel',
                  icon: const Icon(Icons.grid_on_outlined, size: 21),
                  onPressed: transactions.isEmpty
                      ? null
                      : () => _exportExcel(transactions),
                ),
                IconButton(
                  tooltip: 'Print',
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 21),
                  onPressed: transactions.isEmpty
                      ? null
                      : () =>
                            widget.onPrint(provider.filterstockTransactions()),
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
                    : transactions.isEmpty
                    ? Center(
                        child: Text(
                          'No transactions found',
                          style: TextStyle(color: _secondaryTextColor),
                        ),
                      )
                    : isSmall
                    ? _mobileCards(paged, startIndex)
                    : _desktopTable(paged, startIndex),
              ),
            ],
          ),
          bottomNavigationBar: _pager(transactions.length, page, totalPages),
        );
      },
    );
  }
}
