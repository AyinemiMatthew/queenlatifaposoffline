import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import 'sales_report_shared.dart';

class SalesItemTransactionsPage extends StatefulWidget {
  final String itemId;
  final String itemName;
  final String? branchId;
  final String branchLabel;
  final DateTimeRange? dateRange;
  final String? producttype;
  final String? pcategory;
  final ItemTxnExport onExport;

  const SalesItemTransactionsPage({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.branchId,
    required this.branchLabel,
    required this.dateRange,
    required this.onExport,
    this.producttype,
    this.pcategory,
  });

  @override
  State<SalesItemTransactionsPage> createState() =>
      _SalesItemTransactionsPageState();
}

class _SalesItemTransactionsPageState extends State<SalesItemTransactionsPage> {
  bool get _isLightTheme => srIsLightTheme(context);
  Color get _backgroundColor => srBackgroundColor(context);
  Color get _cardColor => srCardColor(context);
  Color get _totalColor => srTotalColor(context);
  Color get _borderColor => srBorderColor(context);
  Color get _textColor => srTextColor(context);
  Color get _mutedTextColor => srMutedTextColor(context);
  Color get _accentColor => srAccentColor(context);
  Color get _errorColor =>
      _isLightTheme ? Colors.red.shade700 : Colors.redAccent;
  Color get _warningColor =>
      _isLightTheme ? Colors.orange.shade800 : Colors.orange;
  Color get _successColor =>
      _isLightTheme ? Colors.green.shade700 : Colors.greenAccent;

  late final Datafeed _provider;
  late final String _previousSearch;
  final TextEditingController _search = TextEditingController();
  final ScrollController _listCtrl = ScrollController();

  static const int _rowsPerPage = 10;
  static final DateFormat _txnDateFmt = DateFormat('dd MMM yy, hh:mm a');

  static const List<TxnCol> _txnCols = [
    TxnCol('#', 1),
    TxnCol('Date', 4),
    TxnCol('Qty', 1, right: true),
    TxnCol('Price', 2, right: true),
    TxnCol('Disc', 2, right: true),
    TxnCol('Total', 2, right: true),
    TxnCol('Profit', 2, right: true),
    TxnCol('Type', 3),
    TxnCol('Customer', 3, minWidth: 820),
    TxnCol('Staff', 3),
    TxnCol('Sales Mode', 2, minWidth: 940),
    TxnCol('Price Mode', 2, minWidth: 1040),
  ];

  String? _staff;
  String? _kind;
  int _page = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _provider = context.read<Datafeed>();
    _previousSearch = _provider.searchQuery;
    Future.microtask(() async {
      _provider.updateSearch('');
      try {
        await _provider.loadItemSalesTransactions(
          startDate: widget.dateRange?.start ?? DateTime.now(),
          endDate: widget.dateRange?.end ?? DateTime.now(),
          itemId: widget.itemId,
          itemName: widget.itemName,
          branchId: widget.branchId,
        );
      } catch (e) {
        debugPrint('Error from individual sales $e');
      }
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _listCtrl.dispose();
    Future.microtask(() => _provider.updateSearch(_previousSearch));
    super.dispose();
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

  String _q(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  String _txnDate(dynamic d) {
    if (d is Timestamp) return _txnDateFmt.format(d.toDate());
    if (d is DateTime) return _txnDateFmt.format(d);
    return '-';
  }

  bool _isRet(Map<String, dynamic> t) => t['isReturned'] == true;

  String _txnType(Map<String, dynamic> t) {
    if (_isRet(t)) {
      return t['returnedTransMode'] == 'credit'
          ? 'Credit Return'
          : 'Cash Return';
    }
    final m = (t['transMode'] ?? '').toString();
    return m.isEmpty ? 'Sale' : 'Sale · $m';
  }

  Color _txnColor(Map<String, dynamic> t) {
    if (_isRet(t)) {
      return t['returnedTransMode'] == 'credit' ? _warningColor : _errorColor;
    }
    return _successColor;
  }

  List<Map<String, dynamic>> _filterByKind(
    List<Map<String, dynamic>> transactions,
    String category,
  ) {
    switch (category) {
      case 'cashSales':
        return transactions
            .where((t) => t['isReturned'] != true && t['isCredit'] != true)
            .toList();
      case 'creditSales':
        return transactions
            .where((t) => t['isReturned'] != true && t['isCredit'] == true)
            .toList();
      case 'cashReturns':
        return transactions
            .where((t) => t['isReturned'] == true && t['isCashReturn'] == true)
            .toList();
      case 'creditReturns':
        return transactions
            .where(
              (t) => t['isReturned'] == true && t['isCreditReturn'] == true,
            )
            .toList();
      case 'totalReturns':
        return transactions.where((t) => t['isReturned'] == true).toList();
      case 'discount':
        return transactions.where((t) {
          final d = (t['discount'] as num?) ?? 0;
          return d > 0;
        }).toList();
      default:
        return transactions;
    }
  }

  Map<String, double> _txnSummary(List<Map<String, dynamic>> list) {
    double cash = 0, credit = 0, cashRet = 0, creditRet = 0, returns = 0;
    double saleDisc = 0, retDisc = 0, saleQty = 0, retQty = 0;
    double saleProfit = 0, retProfit = 0;

    for (final t in list) {
      final total = _num(t['total']);
      final disc = _num(t['discount']);
      final qty = _num(t['qty']);
      final profit = _num(t['profit']);

      if (_isRet(t)) {
        returns += total;
        if (t['isCashReturn'] == true) cashRet += total;
        if (t['isCreditReturn'] == true) creditRet += total;
        retDisc += disc;
        retQty += qty;
        retProfit += profit;
      } else {
        if (t['isCredit'] == true) {
          credit += total;
        } else {
          cash += total;
        }
        saleDisc += disc;
        saleQty += qty;
        saleProfit += profit;
      }
    }

    return {
      'cash': cash,
      'credit': credit,
      'cashRet': cashRet,
      'creditRet': creditRet,
      'returns': returns,
      'saleDisc': saleDisc,
      'retDisc': retDisc,
      'discount': saleDisc - retDisc,
      'saleQty': saleQty,
      'retQty': retQty,
      'qty': saleQty - retQty,
      'saleProfit': saleProfit,
      'retProfit': retProfit,
      'profit': saleProfit - retProfit,
      'net': cash + credit - returns,
      'cashAtHand': cash - cashRet,
    };
  }

  Widget _txnStat({
    required String label,
    required String value,
    String? tip,
    bool active = false,
    VoidCallback? onTap,
  }) {
    final narrow = MediaQuery.sizeOf(context).width < 600;

    Widget w = InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      onLongPress: (narrow && tip != null)
          ? () => srShowBreakdown(context, label, tip)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? _accentColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? _accentColor : _mutedTextColor,
                fontSize: 10,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: active ? _accentColor : _textColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );

    if (!narrow && tip != null) w = srTip(context, tip, w, title: label);
    return w;
  }

  Widget _txnStats(Map<String, double> s) {
    void toggle(String k) => setState(() {
      _kind = _kind == k ? null : k;
      _page = 0;
    });
    double v(String k) => s[k] ?? 0;

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _txnStat(
          label: 'Cash Sales',
          value: srN(v('cash')),
          tip:
              'Cash sales: ${srN(v('cash'))}\n'
              'Less cash returns: ${srN(v('cashRet'))}\n'
              'Cash @ Hand: ${srN(v('cashAtHand'))}',
          active: _kind == 'cashSales',
          onTap: () => toggle('cashSales'),
        ),
        _txnStat(
          label: 'Credit Sales',
          value: srN(v('credit')),
          tip:
              'Credit sales: ${srN(v('credit'))}\n'
              'Less credit returns: ${srN(v('creditRet'))}\n'
              'Net credit: ${srN(v('credit') - v('creditRet'))}',
          active: _kind == 'creditSales',
          onTap: () => toggle('creditSales'),
        ),
        _txnStat(
          label: 'Returns',
          value: srN(v('returns')),
          tip:
              'Cash returns: ${srN(v('cashRet'))}\n'
              'Credit returns: ${srN(v('creditRet'))}\n'
              'Total returns: ${srN(v('returns'))}',
          active: _kind == 'totalReturns',
          onTap: () => toggle('totalReturns'),
        ),
        _txnStat(
          label: 'Discount',
          value: srN(v('discount')),
          tip:
              'Discount given: ${srN(v('saleDisc'))}\n'
              'Less discount on returns: ${srN(v('retDisc'))}\n'
              'Net discount: ${srN(v('discount'))}',
          active: _kind == 'discount',
          onTap: () => toggle('discount'),
        ),
        _txnStat(
          label: 'Qty Sold',
          value: _q(v('qty')),
          tip:
              'Qty sold: ${_q(v('saleQty'))}\n'
              'Less qty returned: ${_q(v('retQty'))}\n'
              'Net qty: ${_q(v('qty'))}',
        ),
        _txnStat(
          label: 'Net Revenue',
          value: srN(v('net')),
          tip:
              'Cash + credit sales: ${srN(v('cash') + v('credit'))}\n'
              'Less returns: ${srN(v('returns'))}\n'
              'Net revenue: ${srN(v('net'))}',
        ),
        _txnStat(
          label: 'Profit',
          value: srN(v('profit')),
          tip:
              'Profit on sales: ${srN(v('saleProfit'))}\n'
              'Less profit on returns: ${srN(v('retProfit'))}\n'
              'Net profit: ${srN(v('profit'))}',
        ),
      ],
    );
  }

  Widget _typeBadge(Map<String, dynamic> t) {
    final c = _txnColor(t);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        border: Border.all(color: c.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _txnType(t),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _txnCell(String label, Map<String, dynamic> t, int i) {
    final ret = _isRet(t);
    String sg(double v) => ret && v != 0 ? '-${srN(v)}' : srN(v);

    switch (label) {
      case '#':
        return '${i + 1}';
      case 'Date':
        return _txnDate(t['date']);
      case 'Qty':
        {
          final q = _num(t['qty']);
          return ret && q != 0 ? '-${_q(q)}' : _q(q);
        }
      case 'Price':
        return srN(_num(t['price']));
      case 'Disc':
        return sg(_num(t['discount']));
      case 'Total':
        return sg(_num(t['total']));
      case 'Profit':
        return sg(_num(t['profit']));
      case 'Customer':
        return (t['customer'] ?? '').toString();
      case 'Staff':
        return (t['staff'] ?? '').toString();
      case 'Sales Mode':
        return (t['salesMode'] ?? '').toString();
      case 'Price Mode':
        return (t['pricingMode'] ?? '').toString();
      default:
        return '';
    }
  }

  Widget _txnRowShell(
    List<TxnCol> cols,
    Widget Function(TxnCol col, int c) cellBuilder, {
    required Color color,
    double vertical = 8,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: vertical),
      decoration: BoxDecoration(
        color: color,
        border: Border(bottom: BorderSide(color: _borderColor, width: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int c = 0; c < cols.length; c++) ...[
            if (c > 0) const SizedBox(width: 8),
            Expanded(flex: cols[c].flex, child: cellBuilder(cols[c], c)),
          ],
        ],
      ),
    );
  }

  Widget _txnTableRow(List<TxnCol> cols, Map<String, dynamic> t, int i) {
    final ret = _isRet(t);
    return _txnRowShell(
      cols,
      (col, _) {
        if (col.label == 'Type') {
          return Align(alignment: Alignment.centerLeft, child: _typeBadge(t));
        }
        final numeric = col.right && col.label != 'Price';
        return Text(
          _txnCell(col.label, t, i),
          textAlign: col.right ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ret && numeric ? _errorColor : _textColor,
            fontSize: 12,
          ),
        );
      },
      color: ret
          ? Colors.red.withOpacity(_isLightTheme ? 0.04 : 0.05)
          : _cardColor,
    );
  }

  Widget _txnCard(Map<String, dynamic> t, int i) {
    final ret = _isRet(t);
    String sg(double v) => ret && v != 0 ? '-${srN(v)}' : srN(v);
    final q = _num(t['qty']);
    final qtyStr = ret && q != 0 ? '-${_q(q)}' : _q(q);

    Widget kv(String k, String v) {
      if (v.trim().isEmpty) return const SizedBox.shrink();
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$k: ',
              style: TextStyle(color: _mutedTextColor, fontSize: 11),
            ),
            TextSpan(
              text: v,
              style: TextStyle(color: _textColor, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ret
            ? Colors.red.withOpacity(_isLightTheme ? 0.04 : 0.08)
            : _cardColor,
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${i + 1}',
                style: TextStyle(color: _mutedTextColor, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Flexible(child: _typeBadge(t)),
              const Spacer(),
              Text(
                _txnDate(t['date']),
                style: TextStyle(color: _mutedTextColor, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$qtyStr × ${srN(_num(t['price']))}',
                style: TextStyle(color: _textColor, fontSize: 13),
              ),
              const Spacer(),
              Text(
                sg(_num(t['total'])),
                style: TextStyle(
                  color: ret ? _errorColor : _textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              kv('Disc', sg(_num(t['discount']))),
              kv('Profit', sg(_num(t['profit']))),
              kv('Customer', (t['customer'] ?? '').toString()),
              kv('Staff', (t['staff'] ?? '').toString()),
              kv('Sales mode', (t['salesMode'] ?? '').toString()),
              kv('Price mode', (t['pricingMode'] ?? '').toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _txnTotalCard(int count, Map<String, double> s) {
    Widget kv(String k, String v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(k, style: TextStyle(color: _mutedTextColor, fontSize: 10)),
        Text(
          v,
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _totalColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL ($count)',
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              kv('Qty', _q(s['qty'] ?? 0)),
              kv('Disc', srN(s['discount'] ?? 0)),
              kv('Net Total', srN(s['net'] ?? 0)),
              kv('Profit', srN(s['profit'] ?? 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _txnBody(
    List<Map<String, dynamic>> list,
    Map<String, double> s,
    ScrollController sc,
    int page,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No transactions found',
          style: TextStyle(color: _mutedTextColor),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final visible = list
            .skip(page * _rowsPerPage)
            .take(_rowsPerPage)
            .toList();

        if (c.maxWidth < 600) {
          return Column(
            children: [
              Expanded(
                child: Scrollbar(
                  controller: sc,
                  child: ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                    itemCount: visible.length,
                    itemBuilder: (_, i) =>
                        _txnCard(visible[i], page * _rowsPerPage + i),
                  ),
                ),
              ),
              _txnTotalCard(list.length, s),
            ],
          );
        }

        final cols = _txnCols.where((x) => c.maxWidth >= x.minWidth).toList();

        Widget total(TxnCol col, int _) {
          String text = '';
          switch (col.label) {
            case 'Date':
              text = 'TOTAL (${list.length})';
              break;
            case 'Qty':
              text = _q(s['qty'] ?? 0);
              break;
            case 'Disc':
              text = srN(s['discount'] ?? 0);
              break;
            case 'Total':
              text = srN(s['net'] ?? 0);
              break;
            case 'Profit':
              text = srN(s['profit'] ?? 0);
              break;
          }
          return Text(
            text,
            textAlign: col.right ? TextAlign.right : TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _txnRowShell(
              cols,
              (col, _) => Text(
                col.label,
                textAlign: col.right ? TextAlign.right : TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              color: _cardColor,
              vertical: 12,
            ),
            Expanded(
              child: Scrollbar(
                controller: sc,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: sc,
                  padding: EdgeInsets.zero,
                  itemCount: visible.length,
                  itemBuilder: (_, i) =>
                      _txnTableRow(cols, visible[i], page * _rowsPerPage + i),
                ),
              ),
            ),
            _txnRowShell(cols, total, color: _totalColor),
          ],
        );
      },
    );
  }

  Future<void> _export(String action, List<Map<String, dynamic>> list) async {
    try {
      await widget.onExport(
        action: action,
        itemName: widget.itemName,
        branchLabel: widget.branchLabel,
        rows: list,
        summary: _txnSummary(list),
        staff: _staff,
        type: widget.producttype,
        category: widget.pcategory,
        kind: _kind,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.sizeOf(context).width < 600;
    final base = _provider.filteredItemTransactions(staff: _staff);
    final list = _kind == null ? base : _filterByKind(base, _kind!);
    final s = _txnSummary(base);
    final hasFilter = _staff != null || _kind != null;
    final totalPages = list.isEmpty
        ? 1
        : ((list.length - 1) ~/ _rowsPerPage) + 1;
    final page = _page.clamp(0, totalPages - 1);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        title: Column(
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
              '${widget.branchLabel} • Sales transactions • ${list.length} record${list.length == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _mutedTextColor, fontSize: 11),
            ),
          ],
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
            enabled: list.isNotEmpty,
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
            onSelected: (selected) => _export(selected, list),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _search,
                          onChanged: (val) {
                            _provider.updateSearch(val);
                            setState(() => _page = 0);
                          },
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search receipt, customer, staff...',
                            hintStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            suffixIcon: _search.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _search.clear();
                                      _provider.updateSearch('');
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    srFilterButton(
                      context: context,
                      icon: Icons.people_alt_outlined,
                      tooltip: 'Staff: ${_staff ?? 'All'}',
                      allLabel: 'All Staff',
                      options: _provider.itemTxnStaff,
                      current: _staff,
                      onPicked: (v) => setState(() {
                        _staff = v;
                        _page = 0;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _txnStats(s),
                if (isSmall)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Tap a total to filter • long-press for breakdown',
                      style: TextStyle(color: _mutedTextColor, fontSize: 10),
                    ),
                  ),
                if (hasFilter)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        Icons.filter_alt_off,
                        size: 15,
                        color: _accentColor,
                      ),
                      label: Text(
                        'Clear filters',
                        style: TextStyle(color: _accentColor, fontSize: 12),
                      ),
                      onPressed: () => setState(() {
                        _staff = null;
                        _kind = null;
                        _page = 0;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: _borderColor),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _textColor))
                : Padding(
                    padding: EdgeInsets.all(isSmall ? 0 : 12),
                    child: _txnBody(list, _txnSummary(list), _listCtrl, page),
                  ),
          ),
        ],
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
