import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class _BranchRow {
  final String branchId;
  final String branchName;
  final double cash;
  final double momo;
  final double card;
  final double bank;
  final double hubtel;
  final double cheque;
  final double credit;
  final double cashReturns;
  final double creditReturns;
  final double discount;
  final double returnDiscount;
  final double profit;
  final double returnProfit;
  final double debt;
  final String? category;
  final String? producttype;

  const _BranchRow({
    required this.branchId,
    required this.branchName,
    required this.cash,
    required this.momo,
    required this.card,
    required this.bank,
    required this.hubtel,
    required this.cheque,
    required this.credit,
    required this.cashReturns,
    required this.creditReturns,
    required this.discount,
    required this.returnDiscount,
    required this.profit,
    required this.returnProfit,
    required this.debt,
     this.category,
     this.producttype,

  });

  factory _BranchRow.fromMap(Map<String, dynamic> m) {
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0.0;
    return _BranchRow(
      branchId: (m['branchId'] ?? '').toString(),
      branchName: (m['branchName'] ?? '').toString(),
      cash: d('cashSales'),
      momo: d('merchantmomo'),
      card: d('card'),
      bank: d('bank'),
      hubtel: d('hubtel'),
      cheque: d('cheque'),
      credit: d('creditSales'),
      cashReturns: d('cashReturns'),
      creditReturns: d('creditReturns'),
      discount: d('discount'),
      returnDiscount: d('returnDiscount'),
      profit: d('profit'),
      returnProfit: d('returnProfit'),
      debt: d('branchdebt'),
      category: '',
      producttype: '',

    );
  }
  factory _BranchRow.fromItem(Map<String, dynamic> m) {
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0.0;
    return _BranchRow(
      branchId: (m['itemid'] ?? '').toString(),
      branchName: (m['item'] ?? '').toString(),
      cash: d('cashSales'),
      momo: d('momo'),
      card: 0,
      bank: 0,
      hubtel: 0,
      cheque: 0,
      credit: d('creditSales'),
      cashReturns: d('cashReturns'),
      creditReturns: d('creditReturns'),
      discount: d('discount'),
      returnDiscount: d('return_discount'),
      profit: d('profit'),
      returnProfit: d('return_profit'),
      debt: 0,
      category: (m['pcategory'] ?? m['category'] ?? '').toString(),
      producttype: (m['producttype'] ?? '').toString(),

    );
  }
  factory _BranchRow.sum(List<_BranchRow> rows) {
    double cash = 0, momo = 0, card = 0, bank = 0, hubtel = 0, cheque = 0;
    double credit = 0, cashReturns = 0, creditReturns = 0, discount = 0;
    double returnDiscount = 0, profit = 0, returnProfit = 0, debt = 0;

    for (final r in rows) {
      cash += r.cash;
      momo += r.momo;
      card += r.card;
      bank += r.bank;
      hubtel += r.hubtel;
      cheque += r.cheque;
      credit += r.credit;
      cashReturns += r.cashReturns;
      creditReturns += r.creditReturns;
      discount += r.discount;
      returnDiscount += r.returnDiscount;
      profit += r.profit;
      returnProfit += r.returnProfit;
      debt += r.debt;
    }
    return _BranchRow(
      branchId: '',
      branchName: 'Grand Total',
      cash: cash,
      momo: momo,
      card: card,
      bank: bank,
      hubtel: hubtel,
      cheque: cheque,
      credit: credit,
      cashReturns: cashReturns,
      creditReturns: creditReturns,
      discount: discount,
      returnDiscount: returnDiscount,
      profit: profit,
      returnProfit: returnProfit,
      debt: debt,
      category: '',
      producttype: '',

    );
  }

  double get cashSales => cash + momo + card + bank + hubtel + cheque;
  double get totalSales => cashSales + credit;
  double get returns => cashReturns + creditReturns;
  double get grossDiscount => discount + returnDiscount;
  double get grossProfit => profit + returnProfit;
  double get cashAtHand => cash - cashReturns;
}

class _TxnCol {
  final String label;
  final int flex;
  final double minWidth;
  final bool right;
  const _TxnCol(this.label, this.flex, {this.minWidth = 0, this.right = false});
}

class SalesReport extends StatefulWidget {
  const SalesReport({super.key});

  @override
  State<SalesReport> createState() => _SalesReportState();
}

class _SalesReportState extends State<SalesReport> {
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  final GlobalKey _branchKey = GlobalKey();

  static final DateFormat _txnDateFmt = DateFormat('dd MMM yy, hh:mm a');
  bool _isSearching = false;
  int? _sortColumn;
  bool _sortAscending = true;

  String? _selectedType;
  String? _selectedCategory;
  final GlobalKey _typeKey = GlobalKey();
  final GlobalKey _categoryKey = GlobalKey();
  static const Color _accent = Color(0xFF6366F1);

  late final ScrollController verticalController;
  late final ScrollController horizontalController;
  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;
  late final ScrollController _listController;
  final TextEditingController _mainSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  static const int _rowsPerPage = 10;
  int _mainPage = 0;

  static const Color _backgroundColor = Color(0xFF101624);
  static const Color _cardColor = Color(0xFF1B263B);
  static const Color _headerColor = Color(0xFF0D1B2A);
  static const Color _totalColor = Color(0xFF16213E);
  static const Color _borderColor = Colors.white12;
  static const Color _textColor = Colors.white;

  static const List<int> _colFlexes = [
    1, 4, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
  ];
  static const List<String> _headers = [
    '#',
    'Branch',
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

  static final NumberFormat _nf = NumberFormat('#,##0.00');

  static const List<_TxnCol> _txnCols = [
    _TxnCol('#', 1),
    _TxnCol('Date', 4),
    _TxnCol('Qty', 1, right: true),
    _TxnCol('Price', 2, right: true),
    _TxnCol('Disc', 2, right: true),
    _TxnCol('Total', 2, right: true),
    _TxnCol('Profit', 2, right: true),
    _TxnCol('Type', 3),
    _TxnCol('Customer', 3, minWidth: 820),
    _TxnCol('Staff', 3),

    _TxnCol('Sales Mode', 2, minWidth: 940),
    _TxnCol('Price Mode', 2, minWidth: 1040),
  ];

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
      return t['returnedTransMode'] == 'credit' ? 'Credit Return' : 'Cash Return';
    }
    final m = (t['transMode'] ?? '').toString();
    return m.isEmpty ? 'Sale' : 'Sale · $m';
  }

  Color _txnColor(Map<String, dynamic> t) {
    if (_isRet(t)) {
      return t['returnedTransMode'] == 'credit'
          ? Colors.orange
          : Colors.redAccent;
    }
    return Colors.greenAccent;
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
      onLongPress:
      (narrow && tip != null) ? () => _showBreakdown(label, tip) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? _accent : Colors.transparent,
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
                color: active ? _accent : Colors.white54,
                fontSize: 10,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: active ? _accent : _textColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );

    if (!narrow && tip != null) w = _tip(tip, w, title: label);
    return w;
  }

  Widget _txnStats(
      Map<String, double> s,
      String? kind,
      ValueChanged<String?> setKind,
      ) {
    void toggle(String k) => setKind(kind == k ? null : k);
    double v(String k) => s[k] ?? 0;

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _txnStat(
          label: 'Cash Sales',
          value: _n(v('cash')),
          tip: 'Cash sales: ${_n(v('cash'))}\n'
              'Less cash returns: ${_n(v('cashRet'))}\n'
              'Cash @ Hand: ${_n(v('cashAtHand'))}',
          active: kind == 'cashSales',
          onTap: () => toggle('cashSales'),
        ),
        _txnStat(
          label: 'Credit Sales',
          value: _n(v('credit')),
          tip: 'Credit sales: ${_n(v('credit'))}\n'
              'Less credit returns: ${_n(v('creditRet'))}\n'
              'Net credit: ${_n(v('credit') - v('creditRet'))}',
          active: kind == 'creditSales',
          onTap: () => toggle('creditSales'),
        ),
        _txnStat(
          label: 'Returns',
          value: _n(v('returns')),
          tip: 'Cash returns: ${_n(v('cashRet'))}\n'
              'Credit returns: ${_n(v('creditRet'))}\n'
              'Total returns: ${_n(v('returns'))}',
          active: kind == 'totalReturns',
          onTap: () => toggle('totalReturns'),
        ),
        _txnStat(
          label: 'Discount',
          value: _n(v('discount')),
          tip: 'Discount given: ${_n(v('saleDisc'))}\n'
              'Less discount on returns: ${_n(v('retDisc'))}\n'
              'Net discount: ${_n(v('discount'))}',
          active: kind == 'discount',
          onTap: () => toggle('discount'),
        ),
        _txnStat(
          label: 'Qty Sold',
          value: _q(v('qty')),
          tip: 'Qty sold: ${_q(v('saleQty'))}\n'
              'Less qty returned: ${_q(v('retQty'))}\n'
              'Net qty: ${_q(v('qty'))}',
        ),
        _txnStat(
          label: 'Net Revenue',
          value: _n(v('net')),
          tip: 'Cash + credit sales: ${_n(v('cash') + v('credit'))}\n'
              'Less returns: ${_n(v('returns'))}\n'
              'Net revenue: ${_n(v('net'))}',
        ),
        _txnStat(
          label: 'Profit',
          value: _n(v('profit')),
          tip: 'Profit on sales: ${_n(v('saleProfit'))}\n'
              'Less profit on returns: ${_n(v('retProfit'))}\n'
              'Net profit: ${_n(v('profit'))}',
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
    String sg(double v) => ret && v != 0 ? '-${_n(v)}' : _n(v);

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
        return _n(_num(t['price']));
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
      List<_TxnCol> cols,
      Widget Function(_TxnCol col, int c) cellBuilder, {
        required Color color,
        double vertical = 8,
      }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: vertical),
      decoration: BoxDecoration(
        color: color,
        border: const Border(
          bottom: BorderSide(color: Color(0xFF475569), width: 0.7),
        ),
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

  Widget _txnTableRow(List<_TxnCol> cols, Map<String, dynamic> t, int i) {
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
            color: ret && numeric ? Colors.redAccent : _textColor,
            fontSize: 12,
          ),
        );
      },
        color: ret ? Colors.red.withOpacity(0.05) : _cardColor,
    );
  }

  Widget _txnCard(Map<String, dynamic> t, int i) {
    final ret = _isRet(t);
    String sg(double v) => ret && v != 0 ? '-${_n(v)}' : _n(v);
    final q = _num(t['qty']);
    final qtyStr = ret && q != 0 ? '-${_q(q)}' : _q(q);

    Widget kv(String k, String v) {
      if (v.trim().isEmpty) return const SizedBox.shrink();
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            TextSpan(
              text: v,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ret ? Colors.red.withOpacity(0.08) : _cardColor,
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#${i + 1}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(width: 8),
              Flexible(child: _typeBadge(t)),
              const Spacer(),
              Text(
                _txnDate(t['date']),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$qtyStr × ${_n(_num(t['price']))}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Text(
                sg(_num(t['total'])),
                style: TextStyle(
                  color: ret ? Colors.redAccent : _textColor,
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

              //kv('Branch', (t['branch'] ?? '').toString()),
              kv('Sales mode', (t['salesMode'] ?? '').toString()),
              kv('Price mode', (t['pricingMode'] ?? '').toString()),
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
      {int page = 0,
      int totalPages = 1,
      ValueChanged<int>? onPageChanged,
      }) {
    if (list.isEmpty) {
      return const Center(
        child: Text('No transactions found',
            style: TextStyle(color: Colors.white70)),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final visible = list.skip(page * _rowsPerPage).take(_rowsPerPage).toList();

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
                    itemBuilder: (_, i) {
                      return _txnCard(visible[i], page * _rowsPerPage + i);
                    },
                  ),
                ),
              ),
              _txnTotalCard(list.length, s),
            ],
          );
        }


        final cols = _txnCols.where((x) => c.maxWidth >= x.minWidth).toList();

        Widget total(_TxnCol col, int _) {
          String text = '';
          switch (col.label) {
            case 'Date':
              text = 'TOTAL (${list.length})';
              break;
            case 'Qty':
              text = _q(s['qty'] ?? 0);
              break;
            case 'Disc':
              text = _n(s['discount'] ?? 0);
              break;
            case 'Total':
              text = _n(s['net'] ?? 0);
              break;
            case 'Profit':
              text = _n(s['profit'] ?? 0);
              break;
          }
          return Text(
            text,
            textAlign: col.right ? TextAlign.right : TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
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
                  style: _headerStyle,
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
                    itemBuilder: (_, i) {
                      return _txnTableRow(cols, visible[i], page * _rowsPerPage + i);
                    },
                  ),
                ),
              ),
              _txnRowShell(cols, total, color: _totalColor),
            ],
        );
      },
    );
  }

  // Widget _itemTransactionsPager(
  //     int page, int totalPages, int totalCount, ValueChanged<int> onPageChanged) {
  //   return Container(
  //     decoration: const BoxDecoration(
  //       color: _cardColor,
  //       border: Border(top: BorderSide(color: Color(0xFF475569), width: 0.7)),
  //     ),
  //     child: Row(
  //       children: [
  //         Expanded(
  //             child: Padding(
  //                 padding: const EdgeInsets.all(8),
  //                 child: Text('$totalCount Transactions',
  //                     style: const TextStyle(color: Colors.white60, fontSize: 12)))),
  //         IconButton(
  //             padding: EdgeInsets.zero,
  //             onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
  //             icon: const Icon(Icons.chevron_left)),
  //         Text('${page + 1}/$totalPages',
  //             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  //         IconButton(
  //             padding: EdgeInsets.zero,
  //             onPressed: page < totalPages - 1 ? () => onPageChanged(page + 1) : null,
  //             icon: const Icon(Icons.chevron_right)),
  //       ],
  //     ),
  //   );
  // }

  bool _canSelect(Datafeed v) {
    final r = v.normalizedAccessLevelNoSpaces;
    return r == 'superadmin' || r == 'systemadmin' || r == 'admin';
  }

  @override
  void initState() {
    super.initState();
    verticalController = ScrollController();
    horizontalController = ScrollController();
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
    _listController = ScrollController();

    Future.microtask(() {
      if (!mounted) return;
      final provider = context.read<Datafeed>();
      provider.fetchBranches();
      provider.updateSearch('');
      _selectedBranch = _canSelect(provider)
          ? null
          : (provider.branchid.isEmpty ? null : provider.branchid);
      setState(() {});
      provider.fetchsalesreport(
        selectedDate: selectedDate,
        selectedBranch: _selectedBranch,
        productType: _selectedType,
        category: _selectedCategory,
      );
    });
  }

  @override
  void dispose() {
    selectedDate = null;
    _selectedBranch = null;
    verticalController.dispose();
    horizontalController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    _listController.dispose();
    _mainSearchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch(Datafeed value) {
    setState(() {
      _isSearching = false;
      _mainSearchController.clear();
    });
    value.updateSearch('');
  }

  String _branchLabel(Datafeed value) {
    if (!_canSelect(value)) return value.branch;
    if (_selectedBranch == null) return 'All Branches';
    final matches = value.branches.where((b) => b.branchname != 'Warehouse').where((b) => b.id == _selectedBranch);
    if (matches.isEmpty) return 'All Branches';
    return matches.first.branchname;
  }

  void _showBranchMenu(BuildContext context, Datafeed value) {
    final RenderBox button =
    _branchKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
    Overlay.of(context).context.findRenderObject() as RenderBox;

    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        buttonPosition.dx,
        buttonPosition.dy + button.size.height,
        button.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String?>(
      context: context,
      position: position,
      color: _cardColor,
      items: [
        const PopupMenuItem<String?>(
          value: '__ALL__',
          child: Text(
            'All Branches',
            style: TextStyle(color: _textColor, fontSize: 13),
          ),
        ),
        ...{
          for (final b in value.branches) b.id: b,
        }.values.where((b) => b.id != null && b.id!.isNotEmpty).map(
              (b) => PopupMenuItem<String?>(
            value: b.id,
            child: Text(
              b.branchname,
              style: const TextStyle(color: _textColor, fontSize: 13),
            ),
          ),
        ),
      ],
    ).then((picked) {
      if (picked == null) return;
      final branch = picked == '__ALL__' ? null : picked;
      setState(() => _selectedBranch = branch);
      _applyFilter(value);
    });
  }

  Comparable _sortValue(_BranchRow r, int col) {
    switch (col) {
      case 1:
        return r.branchName.toLowerCase();
      case 2:
        return r.cashSales;
      case 3:
        return r.credit;
      case 4:
        return r.totalSales;
      case 5:
        return r.returns;
      case 6:
        return r.discount;
      case 7:
        return r.profit;
      case 8:
        return r.cashAtHand;
      default:
        return 0.0;
    }
  }

  List<_BranchRow> _rows(Datafeed value) {
    final rows = value
        .filterbranchsalesreport()
        .map((m) => _BranchRow.fromMap(m))
        .toList();
    final col = _sortColumn;
    if (col != null) {
      rows.sort((a, b) {
        final c = Comparable.compare(_sortValue(a, col), _sortValue(b, col));
        return _sortAscending ? c : -c;
      });
    }
    return rows;
  }

  String _n(double v) => _nf.format(v);

  String _lines(
      List<MapEntry<String, double>> parts,
      String totalLabel,
      double total, {
        bool skipZero = false,
      }) {
    final lines = <String>[];
    for (final p in parts) {
      if (skipZero && p.value == 0) continue;
      lines.add('${p.key}: ${_n(p.value)}');
    }
    lines.add('$totalLabel: ${_n(total)}');
    return lines.join('\n');
  }

  String _tipCash(_BranchRow r) => _lines(
    [
      MapEntry('Cash', r.cash),
      MapEntry('MoMo', r.momo),
      MapEntry('Card', r.card),
      MapEntry('Bank', r.bank),
      MapEntry('Hubtel', r.hubtel),
      MapEntry('Cheque', r.cheque),
    ],
    'Cash Sales',
    r.cashSales,
    skipZero: true,
  );

  String _tipCredit(_BranchRow r) {
    final base = 'Credit Sales (on account): ${_n(r.credit)}';
    if (r.debt == 0) return base;
    return '$base\nDebt payments received: ${_n(r.debt)}';
  }

  String _tipTotal(_BranchRow r) => _lines(
    [
      MapEntry('Cash', r.cash),
      MapEntry('MoMo', r.momo),
      MapEntry('Card', r.card),
      MapEntry('Bank', r.bank),
      MapEntry('Hubtel', r.hubtel),
      MapEntry('Cheque', r.cheque),
      MapEntry('Credit', r.credit),
    ],
    'Total Sales',
    r.totalSales,
    skipZero: true,
  );

  String _tipReturns(_BranchRow r) => _lines(
    [
      MapEntry('Cash Returns', r.cashReturns),
      MapEntry('Credit Returns', r.creditReturns),
    ],
    'Total Returns',
    r.returns,
  );

  String _tipDiscount(_BranchRow r) =>
      'Discount given: ${_n(r.grossDiscount)}\n'
          'Less discount on returns: ${_n(r.returnDiscount)}\n'
          'Net Discount: ${_n(r.discount)}';

  String _tipProfit(_BranchRow r) =>
      'Gross profit: ${_n(r.grossProfit)}\n'
          'Less profit on returns: ${_n(r.returnProfit)}\n'
          'Net Profit: ${_n(r.profit)}';

  String _tipCashAtHand(_BranchRow r) =>
      'Cash received: ${_n(r.cash)}\n'
          'Less cash returns: ${_n(r.cashReturns)}\n'
          'Cash @ Hand: ${_n(r.cashAtHand)}';

  List<String> _tips(_BranchRow r) => [
    _tipCash(r),
    'MoMo: ${_n(r.momo)}',
    'Hubtel: ${_n(r.hubtel)}',
    'Card: ${_n(r.card)}',
    'Bank: ${_n(r.bank)}',
    'Cheque: ${_n(r.cheque)}',
    _tipCredit(r),
    _tipTotal(r),
    _tipReturns(r),
    _tipDiscount(r),
    _tipProfit(r),
    _tipCashAtHand(r),
  ];

  List<double> _values(_BranchRow r) => [
    r.cash,
    r.momo,
    r.hubtel,
    r.card,
    r.bank,
    r.cheque,
    r.credit,
    r.totalSales,
    r.returns,
    r.discount,
    r.profit,
    r.cashAtHand,
  ];



  Widget _tip(String message, Widget child, {String title = 'Breakdown'}) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showBreakdown(title, message),
        child: child,
      );
    }
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(seconds: 6),
      preferBelow: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _headerColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      textStyle: const TextStyle(color: _textColor, fontSize: 12, height: 1.5),
      child: child,
    );
  }

  void _showBreakdown(String title, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _headerColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: _textColor, fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipStat(String title, double value, String tip) {
    return _tip(tip, _miniStat(title, value), title: title);
  }

  Widget _dialogFilter({ required IconData icon, required String tooltip, required String allLabel, required List<String> options, required String? current, required ValueChanged<String?> onPicked,}) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      color: _cardColor,
      icon: Icon(icon, color: current != null ? _accent : Colors.white70, size: 21),
      onSelected: (v) => onPicked(v == '__ALL__' ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: '__ALL__',
          child: Text(
            allLabel,
            style: TextStyle(
              color: current == null ? _accent : _textColor,
              fontSize: 13,
            ),
          ),
        ),
        ...options.map(
              (o) => PopupMenuItem<String>(
            value: o,
            child: Text(
              o,
              style: TextStyle(
                color: o == current ? _accent : _textColor,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemTable(
      List<Map<String, dynamic>> maps,
      List<_BranchRow> rows,
      _BranchRow totals,
      void Function(Map<String, dynamic>) onTap,
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
              color: _cardColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  for (int i = 0; i < _headers.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: _colFlexes[i],
                      child: Text(
                        i == 1 ? 'Item' : _headers[i],
                        textAlign: i >= 2 ? TextAlign.right : TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        style: _headerStyle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: verticalController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: verticalController,
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    return InkWell(
                      onTap: () => onTap(maps[index]),
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
      List<_BranchRow> rows,
      _BranchRow totals,
      void Function(Map<String, dynamic>) onTap,
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
              final tips = _tips(r);
              return InkWell(
                onTap: () => onTap(maps[index]),
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
                          Text('#${index + 1}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.branchName,
                              style: const TextStyle(
                                color: Colors.amberAccent,
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

  Widget _txnTotalCard(int count, Map<String, double> s) {
    Widget kv(String k, String v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(k, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(v,
            style: const TextStyle(
                color: _textColor,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
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
          Text('TOTAL ($count)',
              style: const TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              kv('Qty', _q(s['qty'] ?? 0)),
              kv('Disc', _n(s['discount'] ?? 0)),
              kv('Net Total', _n(s['net'] ?? 0)),
              kv('Profit', _n(s['profit'] ?? 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCell(int i) {
    final label = _headers[i];
    final numeric = i >= 2;
    final sorted = _sortColumn == i;

    if (i == 0) {
      return Expanded(
        flex: _colFlexes[i],
        child: Text(label, style: _headerStyle),
      );
    }

    return Expanded(
      flex: _colFlexes[i],
      child: InkWell(
        onTap: () {
          setState(() {
            if (sorted) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumn = i;
              _sortAscending = true;
            }
          });
        },
        child: Row(
          mainAxisAlignment:
          numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: _headerStyle,
              ),
            ),
            if (sorted)
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: _textColor,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    color: _textColor,
    fontWeight: FontWeight.w700,
    fontSize: 13,
    letterSpacing: 0.4,
  );

  Widget _dataRow(_BranchRow r, int index, {bool total = false}) {
    final tips = _tips(r);
    final values = _values(r);

    return Container(
      color: total
          ? _totalColor
          : (index.isEven ? const Color(0xFF0D1B2A) : const Color(0xFF111E2F)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: _colFlexes[0],
            child: Text(
              total ? '' : '${index + 1}',
              style: const TextStyle(color: _textColor, fontSize: 13),
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
              child: _tip(
                tips[i],
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    _n(values[i]),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: i == values.length - 1 ? Colors.white : _textColor,
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

  Widget _buildDesktopLayout(List<_BranchRow> rows, _BranchRow totals,
      int page, int totalPages, int totalCount) {

    return Align(
      alignment: Alignment.topCenter,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: _cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    for (int i = 0; i < _headers.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      _headerCell(i),
                    ],
                  ],
                ),
              ),
              Flexible(
                child: Scrollbar(
                  controller: _listController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _listController,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final r = rows[index];
                      return InkWell(
                        onTap: () => showBranchItemTransactionsDialog(
                          context,
                          itemId: r.branchId,
                          itemName: r.branchName,
                          branchId: r.branchId,
                        ),
                        child: _dataRow(r, index),
                      );
                    },
                  ),
                ),
              ),
              _dataRow(totals, rows.length, total: true),
              _salesReportPager(page, totalPages, totalCount),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildMobileList(List<_BranchRow> rows, _BranchRow totals,
      int page, int totalPages, int totalCount) {
    return Column(
      children: [
        Align(alignment: Alignment.centerLeft, child: _mobileSortBar()),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final r = rows[index];
              final tips = _tips(r);

              return InkWell(
                onTap: () => showBranchItemTransactionsDialog(
                  context,
                  itemId: r.branchId,
                  itemName: r.branchName,
                  branchId: r.branchId,
                ),
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
                          Text('#${page * _rowsPerPage + index + 1}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.branchName,
                              style: const TextStyle(
                                color: Colors.amberAccent,
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
        _mobileTotalsCard(totals),
        _salesReportPager(page, totalPages, totalCount),
      ],
    );
  }

  Widget _salesReportPager(int page, int totalPages, int totalCount) {
    return Container(
      decoration: const BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: Color(0xFF475569), width: 0.7)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('$totalCount Branches',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: page > 0 ? () => setState(() => _mainPage = page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('${page + 1}/$totalPages',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: page < totalPages - 1
                ? () => setState(() => _mainPage = page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _applyFilter(Datafeed value) {
    value.applySalesReportFilter(
      selectedBranch: _selectedBranch,
      productType: _selectedType,
      category: _selectedCategory,
    );
  }

  void _showFilterMenu(
      GlobalKey key,
      String allLabel,
      List<String> options,
      String? current,
      ValueChanged<String?> onPicked,
      ) {
    final RenderBox button = key.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
    Overlay.of(context).context.findRenderObject() as RenderBox;
    final p = button.localToGlobal(Offset.zero, ancestor: overlay);

    final position = RelativeRect.fromRect(
      Rect.fromLTWH(p.dx, p.dy + button.size.height, button.size.width, 0),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: _cardColor,
      items: [
        PopupMenuItem<String>(
          value: '__ALL__',
          child: Text(
            allLabel,
            style: TextStyle(
              color: current == null ? _accent : _textColor,
              fontSize: 13,
            ),
          ),
        ),
        ...options.map(
              (o) => PopupMenuItem<String>(
            value: o,
            child: Text(
              o,
              style: TextStyle(
                color: o == current ? _accent : _textColor,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    ).then((picked) {
      if (picked == null) return;
      onPicked(picked == '__ALL__' ? null : picked);
    });
  }

  void _pickType(Datafeed value) {
    _showFilterMenu(
      _typeKey,
      'All Product Types',
      value.salesReportProductTypes,
      _selectedType,
          (v) {
        setState(() => _selectedType = v);
        _applyFilter(value);
      },
    );
  }

  void _pickCategory(Datafeed value) {
    debugPrint('CATEGORY OPTIONS: ${value.salesReportCategories}');
    _showFilterMenu(
      _categoryKey,
      'All Categories',
      value.salesReportCategories,
      _selectedCategory,
          (v) {
        setState(() => _selectedCategory = v);
        _applyFilter(value);
      },
    );
  }

  String _filterSummary() {
    final parts = <String>[
      if (_selectedType != null) _selectedType!,
      if (_selectedCategory != null) _selectedCategory!,
    ];
    return parts.isEmpty ? '' : ' • ${parts.join(' • ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final canSelect = _canSelect(value);
        final rows = _rows(value);

        final totals = _BranchRow.sum(rows);
        final totalPages = rows.isEmpty ? 1 : ((rows.length - 1) ~/ _rowsPerPage) + 1;
        final page = _mainPage.clamp(0, totalPages - 1);
        final visibleRows = rows.skip(page * _rowsPerPage).take(_rowsPerPage).toList();

        final effectiveStart = selectedDate?.start ?? DateTime.now();
        final effectiveEnd = selectedDate?.end ?? DateTime.now();

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: AppBar(
              backgroundColor: _cardColor,
              elevation: 0,
              iconTheme: const IconThemeData(color: _textColor),
              title: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 700;

                  final periodText =
                      '${DateFormat('dd MMM yyyy').format(effectiveStart)}'
                      ' - '
                      '${DateFormat('dd MMM yyyy').format(effectiveEnd)}';
                  final branchLabel = _branchLabel(value);

                  if (_isSearching) {
                    return Row(
                      children: [
                        IconButton(
                          tooltip: 'Close search',
                          icon: const Icon(
                            Icons.arrow_back,
                            color: _textColor,
                            size: 21,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: () => _closeSearch(value),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: _backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: TextField(
                                controller: _mainSearchController,
                                focusNode: _searchFocusNode,
                                autofocus: true,
                                style: const TextStyle(
                                  color: _textColor,
                                  fontSize: 15,
                                ),
                                cursorColor: _textColor,
                                decoration: const InputDecoration(
                                  hintText: 'Search sales report...',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                                onChanged: (text) {
                                  setState(() {});
                                  context.read<Datafeed>().updateSearch(text);
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_mainSearchController.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(
                              Icons.clear,
                              color: _textColor,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            onPressed: () {
                              setState(() => _mainSearchController.clear());
                              context.read<Datafeed>().updateSearch('');
                              _searchFocusNode.requestFocus();
                            },
                          ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sales Report',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(

                              isMobile
                                  ? '$branchLabel${_filterSummary()} • $periodText'
                                  : '$branchLabel${_filterSummary()} • Sales Report For The Period Of $periodText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Search',
                        icon: const Icon(
                          Icons.search,
                          color: _textColor,
                          size: 21,
                        ),
                        onPressed: _openSearch,
                      ),
                      if (canSelect)
                        IconButton(
                          key: _branchKey,
                          tooltip: 'Branch: $branchLabel',
                          icon: const Icon(
                            Icons.store_outlined,
                            color: _textColor,
                            size: 21,
                          ),
                          onPressed: () => _showBranchMenu(context, value),
                        ),
                      if (canSelect)
                          Tooltip(
                            message: 'Select date',
                            child: ReusableDatePickerWidget(
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Icon(
                                  Icons.calendar_today_outlined,
                                  color: _textColor,
                                  size: 19,
                                ),
                              ),
                              onDateSelected: (selection) {
                                setState(() => selectedDate = selection);
                                context.read<Datafeed>().fetchsalesreport(
                                  selectedDate: selectedDate,
                                  selectedBranch: _selectedBranch,
                                  productType: _selectedType,
                                  category: _selectedCategory,
                                );
                              },
                            ),
                          ),

                      if (canSelect)
                        IconButton(
                          key: _typeKey,
                          tooltip: 'Product type: ${_selectedType ?? 'All'}',
                          icon: Icon(
                            Icons.inventory_2_outlined,
                            color: _selectedType != null ? _accent : _textColor,
                            size: 21,
                          ),
                          onPressed: () => _pickType(value),
                        ),
                        if (canSelect)
                          IconButton(
                            key: _categoryKey,
                            tooltip: 'Category: ${_selectedCategory ?? 'All'}',
                            icon: Icon(
                              Icons.category_outlined,
                              color: _selectedCategory != null ? _accent : _textColor,
                              size: 21,
                            ),
                            onPressed: () => _pickCategory(value),
                          ),



                      // ),

                      PopupMenuButton<String>(
                        tooltip: 'Print / Download',
                        color: _cardColor,
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: _textColor,
                          size: 20,
                        ),
                        itemBuilder: (_) => [
                          const PopupMenuItem<String>(
                            value: 'print',
                            child: Row(
                              children: [
                                Icon(Icons.print_outlined, size: 18, color: Colors.white70),
                                SizedBox(width: 10),
                                Text('Print'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'pdf',
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.white70),
                                SizedBox(width: 10),
                                Text('Download PDF'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'excel',
                            child: Row(
                              children: [
                                Icon(Icons.grid_on_outlined, size: 18, color: Colors.white70),
                                SizedBox(width: 10),
                                Text('Download Excel'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (selected) async {
                          try {
                            switch (selected) {
                              case 'print':
                                await _printMain(value, rows, totals);
                                break;
                              case 'pdf':
                                await _downloadMainPdf(value, rows, totals);
                                break;
                              case 'excel':
                                await _downloadMainExcel(value, rows, totals);
                                break;
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Action failed: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: value.isloadingsalesreport
                    ? const Center(
                  child: CircularProgressIndicator(color: _textColor),
                )
                    : rows.isEmpty
                    ? const Center(
                  child: Text(
                    'No Sales Found',
                    style: TextStyle(color: _textColor),
                  ),
                )
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 700) {
                      return _buildDesktopLayout(
                          visibleRows, totals, page, totalPages, rows.length);
                    }
                    return _buildMobileList(
                        visibleRows, totals, page, totalPages, rows.length);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniStat(String title, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
          Text(
            _n(value),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _mobileTotalsCard(_BranchRow totals) {
    final tips = _tips(totals);
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
          _tip(
            _tipCashAtHand(totals),
            Column(
             // mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL CASH@HAND',
                  style: TextStyle(
                      color: _textColor, fontWeight: FontWeight.bold),
                ),
                Text(
                  'GHC ${_n(totals.cashAtHand)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
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

  Widget _mobileSortBar() {
    const options = <int, String>{
      1: 'Branch',
      2: 'Cash Sales',
      3: 'Credit Sales',
      4: 'Total Sales',
      5: 'Returns',
      6: 'Discount',
      7: 'Profit',
      8: 'Cash@Hand',
    };
    final active = _sortColumn;

    return Row(
      children: [
        PopupMenuButton<int>(
          tooltip: 'Sort by',
          color: _cardColor,
          onSelected: (i) => setState(() {
            if (i == 0) {
              _sortColumn = null;
              _sortAscending = true;
            } else if (_sortColumn == i) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumn = i;
              _sortAscending = true;
            }
          }),
          itemBuilder: (_) => [
            PopupMenuItem<int>(
              value: 0,
              child: Text(
                'Default order',
                style: TextStyle(
                  color: active == null ? _accent : _textColor,
                  fontSize: 13,
                ),
              ),
            ),
            ...options.entries.map(
                  (e) => PopupMenuItem<int>(
                value: e.key,
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: active == e.key ? _accent : _textColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort,
                    size: 18, color: active != null ? _accent : Colors.white70),
                const SizedBox(width: 6),
                Text(
                  active == null ? 'Sort' : 'Sort: ${options[active]}',
                  style: TextStyle(
                    color: active != null ? _accent : Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (active != null)
          IconButton(
            tooltip: _sortAscending ? 'Ascending' : 'Descending',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: _accent,
            ),
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
          ),
      ],
    );
  }

  Future<void> showBranchItemTransactionsDialog(BuildContext context, { required String itemId,required String itemName, required String? branchId, }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final provider = Provider.of<Datafeed>(context, listen: false);
    final previousSearch = provider.searchQuery;
    provider.updateSearch('');
    final dialogSearchController = TextEditingController();

    try {
      await provider.loadBranchItemsReport(
        startDate: selectedDate?.start ?? DateTime.now(),
        endDate: selectedDate?.end ?? DateTime.now(),
        branchId: branchId,
      );
    } catch (e) {
      debugPrint('showBranchItemTransactionsDialog error: $e');
    }

    if (!context.mounted) {
      dialogSearchController.dispose();
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    DateTimeRange? dialogDateRange = selectedDate;
    String? dType;
    String? dCategory;
    bool dLoading = false;
    var itemPage = 0;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final maps = provider.filterBranchItems(
              productType: dType,
              category: dCategory,
            );
            final rows = maps.map(_BranchRow.fromItem).toList();
            final totals = _BranchRow.sum(rows);
            final isSmall = MediaQuery.sizeOf(ctx).width < 600;
            final Smallphone = MediaQuery.sizeOf(ctx).width < 300;
            final totalPages = rows.isEmpty ? 1 : ((rows.length - 1) ~/ _rowsPerPage) + 1;
            final visibleMaps = maps.skip(itemPage * _rowsPerPage).take(_rowsPerPage).toList();
            final visibleRows = rows.skip(itemPage * _rowsPerPage).take(_rowsPerPage).toList();

            Future<void> reload(DateTimeRange range) async {
              setDialogState(() {
                dialogDateRange = range;
                dLoading = true;
              });
              setState(() => selectedDate = range);
              await provider.loadBranchItemsReport(
                startDate: range.start,
                endDate: range.end,
                branchId: branchId,
              );
              provider.fetchsalesreport(
                selectedDate: range,
                selectedBranch: _selectedBranch,
                productType: _selectedType,
                category: _selectedCategory,
              );
              if (!ctx.mounted) return;
              setDialogState(() => dLoading = false);
            }

            void openItem(Map<String, dynamic> m) {
              showSalesTransactionsDialog(
                context,
                itemId: (m['itemid'] ?? '').toString(),
                itemName: (m['item'] ?? '').toString(),
                branchId: (m['branchId'] ?? branchId)?.toString(),
                producttypr: (m['producttype']?? ''),
                pcategory: (m['pcategory']?? ''),
              );
            }

            return AlertDialog(
              backgroundColor: _backgroundColor,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              insetPadding: EdgeInsets.symmetric(
                horizontal: isSmall ? 8 : 24,
                vertical: 12,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$itemName — Branch Sales Report',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dialogSearchController,
                          onChanged: (val) {
                            provider.updateSearch(val);
                            itemPage = 0;
                            setDialogState(() {});
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search item...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon:
                            const Icon(Icons.search, color: Colors.white70),
                            filled: true,
                            fillColor: const Color(0xFF1A2235),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
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
                      _dialogFilter(
                        icon: Icons.inventory_2_outlined,
                        tooltip: 'Product type: ${dType ?? 'All'}',
                        allLabel: 'All Product Types',
                        options: provider.branchItemProductTypes,
                        current: dType,
                        onPicked: (v) => setDialogState(() {
                          dType = v;
                          itemPage = 0;
                        }),
                      ),
                      _dialogFilter(
                        icon: Icons.category_outlined,
                        tooltip: 'Category: ${dCategory ?? 'All'}',
                        allLabel: 'All Categories',
                        options: provider.branchItemCategories,
                        current: dCategory,
                        onPicked: (v) => setDialogState(() {
                          dCategory = v;
                          itemPage = 0;
                        }),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: ctx,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: dialogDateRange,
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFF415A77),
                                  surface: Color(0xFF1B263B),
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) await reload(picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2235),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.date_range,
                                color: Colors.white70,
                                size: 18,
                              ),
                              if (!isSmall) ...[
                                const SizedBox(width: 6),
                                Text(
                                  dialogDateRange != null
                                      ? '${DateFormat('dd MMM').format(dialogDateRange!.start)} - '
                                      '${DateFormat('dd MMM yyyy').format(dialogDateRange!.end)}'
                                      : 'Pick dates',
                                  style: const TextStyle(
                                    color: Colors.white70,
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
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(ctx).height * 0.95,
                child: dLoading
                    ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
                    : rows.isEmpty
                    ? const Center(
                  child: Text(
                    'No Sales found',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      return _itemTable(visibleMaps, visibleRows, totals, openItem);
                    }
                    return _itemMobileList(visibleMaps, visibleRows, totals, openItem);
                  },
                ),
              ),
              actions: [


                PopupMenuButton<String>(
                  tooltip: 'Print / Download',
                  color: _cardColor,
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: _textColor, size: 20),
                  itemBuilder: (_) => [
                    const PopupMenuItem<String>(
                      value: 'print',
                      child: Row(children: [
                        Icon(Icons.print_outlined, size: 18, color: Colors.white70),
                        SizedBox(width: 10),
                        Text('Print'),
                      ]),
                    ),
                    const PopupMenuItem<String>(
                      value: 'pdf',
                      child: Row(children: [
                        Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.white70),
                        SizedBox(width: 10),
                        Text('Download PDF'),
                      ]),
                    ),
                    const PopupMenuItem<String>(
                      value: 'excel',
                      child: Row(children: [
                        Icon(Icons.grid_on_outlined, size: 18, color: Colors.white70),
                        SizedBox(width: 10),
                        Text('Download Excel'),
                      ]),
                    ),
                  ],
                  onSelected: (selected) async {
                    try {
                      switch (selected) {
                        case 'print':
                          await _printReport(
                            title: 'ITEM SALES REPORT',
                            company: provider.company,
                            branchLabel: itemName,
                            countLabel: 'Items',
                            firstColumn: 'ITEM',
                            start: dialogDateRange?.start ?? DateTime.now(),
                            end: dialogDateRange?.end ?? DateTime.now(),
                            type: dType,
                            category: dCategory,
                            rows: rows,
                            t: totals,
                          );
                          break;
                        case 'pdf':
                          await _downloadReportPdf(
                            title: 'ITEM SALES REPORT',
                            company: provider.company,
                            branchLabel: itemName,
                            countLabel: 'Items',
                            firstColumn: 'ITEM',
                            start: dialogDateRange?.start ?? DateTime.now(),
                            end: dialogDateRange?.end ?? DateTime.now(),
                            type: dType,
                            category: dCategory,
                            rows: rows,
                            t: totals,
                          );
                          break;
                        case 'excel':
                          await _exportReportExcel(
                            title: 'ITEM SALES REPORT',
                            company: provider.company,
                            branchLabel: itemName,
                            countLabel: 'Items',
                            firstColumn: 'ITEM',
                            start: dialogDateRange?.start ?? DateTime.now(),
                            end: dialogDateRange?.end ?? DateTime.now(),
                            type: dType,
                            category: dCategory,
                            rows: rows,
                            t: totals,
                          );
                          break;
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Action failed: $e')),
                        );
                      }
                    }
                  },
                ),
                TextButton(
                  onPressed: itemPage > 0
                      ? () => setDialogState(() => itemPage--)
                      : null,
                  child: const Icon(Icons.chevron_left),
                ),
                Text('${itemPage + 1}/$totalPages',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: itemPage < totalPages - 1
                      ? () => setDialogState(() => itemPage++)
                      : null,
                  child: const Icon(Icons.chevron_right),
                ),
                if(Smallphone)...[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ],
              ],
            );
          },
        );
      },
    ).then((_) {
      provider.updateSearch(previousSearch);
      _mainSearchController.text = previousSearch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        dialogSearchController.dispose();
      });
    });
  }



  Future<void> showSalesTransactionsDialog( BuildContext context, {required String itemId,required String itemName,required String? branchId,String?producttypr,String?pcategory}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final provider = Provider.of<Datafeed>(context, listen: false);
    final previousSearch = provider.searchQuery;
    provider.updateSearch('');
    final searchCtrl = TextEditingController();
    final listCtrl = ScrollController();

    try {
      await provider.loadItemSalesTransactions(
        startDate: selectedDate?.start ?? DateTime.now(),
        endDate: selectedDate?.end ?? DateTime.now(),
        itemId: itemId,
        itemName: itemName,
        branchId: branchId,
      );
    } catch (e) {
      debugPrint('Error from individual sales $e');
    }

    if (!context.mounted) {
      searchCtrl.dispose();
      listCtrl.dispose();
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    String? fStaff, fType, fCategory, fKind;
    var transactionPage = 0;



    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            final size = MediaQuery.sizeOf(ctx);
            final isSmall = size.width < 600;
            final insetH = isSmall ? 8.0 : 24.0;
            final width = (size.width - insetH * 2).clamp(0.0, 1200.0).toDouble();

            final kind = fKind;
            final base = provider.filteredItemTransactions(
              staff: fStaff,
            );
            final list =
            kind == null ? base : _filterTransactionsByCategory(base, kind);
            final s = _txnSummary(base);
            final hasFilter = fStaff != null ||
                kind != null;

            return Dialog(
              backgroundColor: _backgroundColor,
              insetPadding: EdgeInsets.symmetric(horizontal: insetH, vertical: 16),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              child: SizedBox(
                width: width,
                height: size.height * 0.92,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${_branchLabel(provider)} • Sales transactions • ${list.length} record${list.length == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.of(dialogContext).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 42,
                                  child: TextField(
                                    controller: searchCtrl,
                                    onChanged: (val) {
                                      provider.updateSearch(val);
                                      setD(() => transactionPage = 0);
                                    },
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Search receipt, customer, staff...',
                                      hintStyle:
                                      const TextStyle(color: Colors.white54),
                                      prefixIcon: const Icon(Icons.search,
                                          color: Colors.white70, size: 20),
                                      suffixIcon: searchCtrl.text.isNotEmpty
                                          ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            color: Colors.white54,
                                            size: 18),
                                        onPressed: () {
                                          searchCtrl.clear();
                                          provider.updateSearch('');
                                          setD(() {});
                                        },
                                      )
                                          : null,
                                      filled: true,
                                      fillColor: const Color(0xFF1A2235),
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              _dialogFilter(
                                icon: Icons.people_alt_outlined,
                                tooltip: 'Staff: ${fStaff ?? 'All'}',
                                allLabel: 'All Staff',
                                options: provider.itemTxnStaff,
                                current: fStaff,
                                  onPicked: (v) => setD(() {
                                    fStaff = v;
                                    transactionPage = 0;
                                  }),
                              ),


                            ],
                          ),
                          const SizedBox(height: 8),
                          _txnStats(s, kind, (k) => setD(() {
                            fKind = k;
                            transactionPage = 0;
                          })),
                          if (isSmall)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Tap a total to filter • long-press for breakdown',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 10),
                              ),
                            ),
                          if (hasFilter)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 0),
                                  minimumSize: const Size(0, 28),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.filter_alt_off,
                                    size: 15, color: _accent),
                                label: const Text('Clear filters',
                                    style:
                                    TextStyle(color: _accent, fontSize: 12)),
                                onPressed: () => setD(() {
                                  fStaff = null;
                                  fKind = null;

                                  transactionPage = 0;
                                  fKind = null;
                                  transactionPage = 0;
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _borderColor),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isSmall ? 0 : 12),
                        child: _txnBody(
                          list,
                          _txnSummary(list),
                          listCtrl,
                          page: transactionPage,
                          totalPages: list.isEmpty
                              ? 1
                              : ((list.length - 1) ~/ _rowsPerPage) + 1,
                          onPageChanged: (next) => setD(() => transactionPage = next),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: _borderColor),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [

                          PopupMenuButton<String>(
                            tooltip: 'Print / Download',
                            color: _cardColor,
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                              color: _textColor,
                              size: 20,
                            ),
                            enabled: list.isNotEmpty,
                            itemBuilder: (_) => [
                              const PopupMenuItem<String>(
                                value: 'print',
                                child: Row(
                                  children: [
                                    Icon(Icons.print_outlined, size: 18, color: Colors.white70),
                                    SizedBox(width: 10),
                                    Text('Print'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'pdf',
                                child: Row(
                                  children: [
                                    Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.white70),
                                    SizedBox(width: 10),
                                    Text('Download PDF'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'excel',
                                child: Row(
                                  children: [
                                    Icon(Icons.grid_on_outlined, size: 18, color: Colors.white70),
                                    SizedBox(width: 10),
                                    Text('Download Excel'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (selected) async {
                              try {
                                switch (selected) {
                                  case 'print':
                                    await _printItemTransactions(
                                      company: provider.company,
                                      itemName: itemName,
                                      branchLabel: _branchLabel(provider),
                                      start: selectedDate?.start ?? DateTime.now(),
                                      end: selectedDate?.end ?? DateTime.now(),
                                      rows: list,
                                      s: _txnSummary(list),
                                      staff: fStaff,
                                      type: producttypr,
                                      category: pcategory,
                                      kind: kind,
                                    );
                                    break;
                                  case 'pdf':
                                    await _downloadItemTransactionsPdf(
                                      company: provider.company,
                                      itemName: itemName,
                                      branchLabel: _branchLabel(provider),
                                      start: selectedDate?.start ?? DateTime.now(),
                                      end: selectedDate?.end ?? DateTime.now(),
                                      rows: list,
                                      s: _txnSummary(list),
                                      staff: fStaff,
                                      type: producttypr,
                                      category: pcategory,
                                      kind: kind,
                                    );
                                    break;
                                  case 'excel':
                                    await _exportItemTransactionsExcel(
                                      company: provider.company,
                                      itemName: itemName,
                                      branchLabel: _branchLabel(provider),
                                      start: selectedDate?.start ?? DateTime.now(),
                                      end: selectedDate?.end ?? DateTime.now(),
                                      rows: list,
                                      s: _txnSummary(list),
                                      staff: fStaff,
                                      type: producttypr,
                                      category: pcategory,
                                      kind: kind,
                                    );
                                    break;
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Action failed: $e')),
                                  );
                                }
                              }
                            },
                          ),
                          TextButton(
                            onPressed: transactionPage > 0
                                ? () => setD(() => transactionPage--)
                                : null,
                            child: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            '${transactionPage + 1}/${list.isEmpty ? 1 : ((list.length - 1) ~/ _rowsPerPage) + 1}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: transactionPage <
                                    (list.isEmpty ? 1 : ((list.length - 1) ~/ _rowsPerPage) + 1) - 1
                                ? () => setD(() => transactionPage++)
                                : null,
                            child: const Icon(Icons.chevron_right),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Close',
                                style: TextStyle(color: Colors.white70)),
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
      },
    ).then((_) {
      provider.updateSearch(previousSearch);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchCtrl.dispose();
        listCtrl.dispose();
      });
    });
  }


  Future<pw.Document> _buildItemTransactionsPdfDoc({
    required String company,
    required String itemName,
    required String branchLabel,
    required DateTime start,
    required DateTime end,
    required List<Map<String, dynamic>> rows,
    required Map<String, double> s,
    String? staff,
    String? type,
    String? category,
    String? kind,
  }) async {
    final pdf = pw.Document(title: '$itemName sales transactions');

    final regular =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final nf = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');
    final dtFmt = DateFormat('dd MMM yy, hh:mm a');
    final now = DateTime.now();
    final period = '${dateFmt.format(start)} - ${dateFmt.format(end)}';

    const headerBg = PdfColors.white;
    const totalBg = PdfColors.white;

    double v(String k) => s[k] ?? 0;
    String qf(double x) =>
        x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(2);

    const kindLabels = {
      'cashSales': 'Cash Sales',
      'creditSales': 'Credit Sales',
      'totalReturns': 'Returns',
      'discount': 'With Discount',
    };

    pw.Widget cell(
        String text, {
          bool head = false,
          bool isBold = false,
          bool right = false,
          PdfColor? color,
        }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: (head || isBold) ? bold : regular,
            fontSize: head ? 8 : 9,
            color: color ?? PdfColors.black,
          ),
        ),
      );
    }

    pw.Widget infoRow(String label, String val, {bool end = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          mainAxisAlignment:
          end ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
          children: [
            pw.Text('$label:  ', style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text(val, style: pw.TextStyle(font: regular, fontSize: 10)),
          ],
        ),
      );
    }

    pw.Widget sectionLabel(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold,
          fontSize: 10,
          color: PdfColors.grey600,
          letterSpacing: 1.4,
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(thickness: 0.1, color: PdfColors.grey),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(now)}',
                  style: pw.TextStyle(
                      font: regular, fontSize: 9, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: regular, fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      company.toUpperCase(),
                      style: pw.TextStyle(font: bold, fontSize: 22),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      itemName,
                      style: pw.TextStyle(
                          font: regular, fontSize: 11, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('$branchLabel $itemName Sales Transactions',
                      style: pw.TextStyle(font: bold, fontSize: 18)),
                  pw.SizedBox(height: 5),

                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    infoRow('Period', period),
                    infoRow('Branch', branchLabel),
                    infoRow('Transactions', '${rows.length}'),
                    infoRow('Qty Sold', qf(v('qty'))),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    infoRow('Staff', staff ?? 'All', end: true),
                    if(type!.isNotEmpty)
                    infoRow('Product Type', type ?? '', end: true),
                    if(category!.isNotEmpty)
                    infoRow('Category', category ?? '', end: true),
                    infoRow('Showing', kindLabels[kind] ?? '', end: true),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 10),
          sectionLabel('TRANSACTIONS'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(2.1),
              2: const pw.FlexColumnWidth(0.8),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.1),
              5: const pw.FlexColumnWidth(1.3),
              6: const pw.FlexColumnWidth(1.2),
              7: const pw.FlexColumnWidth(1.6),
              8: const pw.FlexColumnWidth(1.1),
              9: const pw.FlexColumnWidth(1.7),
              10: const pw.FlexColumnWidth(1.5),
            //  11: const pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('#', head: true),
                  cell('DATE', head: true),
                  cell('QTY', head: true, right: true),
                  cell('PRICE', head: true, right: true),
                  cell('DISCOUNT', head: true, right: true),
                  cell('TOTAL', head: true, right: true),
                  cell('PROFIT', head: true, right: true),
                  cell('TYPE', head: true),
                  cell('MODE', head: true),
                  cell('CUSTOMER', head: true),
                  cell('STAFF', head: true),
                 // cell('BRANCH', head: true),
                ],
              ),
              ...rows.asMap().entries.map((e) {
                final t = e.value;
                final ret = t['isReturned'] == true;
                String sg(double x) =>
                    ret && x != 0 ? '-${nf.format(x)}' : nf.format(x);
                final red = ret ? PdfColors.red700 : null;

                final d = t['date'];
                final dateStr = d is Timestamp
                    ? dtFmt.format(d.toDate())
                    : (d is DateTime ? dtFmt.format(d) : '-');

                final typeStr = ret
                    ? (t['returnedTransMode'] == 'credit'
                    ? 'Credit Return'
                    : 'Cash Return')
                    : 'Sale / ${(t['transMode'] ?? '').toString()}';

                return pw.TableRow(
                  children: [
                    cell('${e.key + 1}'),
                    cell(dateStr),
                    cell(ret ? '-${qf(_num(t['qty']))}' : qf(_num(t['qty'])),
                        right: true, color: red),
                    cell(nf.format(_num(t['price'])), right: true),
                    cell(sg(_num(t['discount'])), right: true, color: red),
                    cell(sg(_num(t['total'])),
                        right: true, isBold: true, color: red),
                    cell(sg(_num(t['profit'])), right: true, color: red),
                    cell(typeStr, color: red),
                    cell((t['salesMode'] ?? '').toString()),
                    cell((t['customer'] ?? '').toString()),
                    cell((t['staff'] ?? '').toString()),
                   // cell((t['branch'] ?? '').toString()),
                  ],
                );
              }),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: totalBg),
                children: [
                  cell(''),
                  cell('GRAND TOTAL', isBold: true),
                  cell(qf(v('qty')), right: true, isBold: true),
                  cell(''),
                  cell(nf.format(v('discount')), right: true, isBold: true),
                  cell(nf.format(v('net')), right: true, isBold: true),
                  cell(nf.format(v('profit')), right: true, isBold: true),
                  cell(''),
                  cell(''),
                  cell(''),
                  cell(''),
                  cell(''),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  /// Opens the OS print / share dialog (unchanged behaviour).
  Future<void> _printItemTransactions({
    required String company,
    required String itemName,
    required String branchLabel,
    required DateTime start,
    required DateTime end,
    required List<Map<String, dynamic>> rows,
    required Map<String, double> s,
    String? staff,
    String? type,
    String? category,
    String? kind,
  }) async {
    final pdf = await _buildItemTransactionsPdfDoc(
      company: company,
      itemName: itemName,
      branchLabel: branchLabel,
      start: start,
      end: end,
      rows: rows,
      s: s,
      staff: staff,
      type: type,
      category: category,
      kind: kind,
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// Saves the PDF directly to disk / triggers a browser download — no
  /// print dialog — on Android, iOS, Web, Windows, macOS and Linux.
  Future<void> _downloadItemTransactionsPdf({
    required String company,
    required String itemName,
    required String branchLabel,
    required DateTime start,
    required DateTime end,
    required List<Map<String, dynamic>> rows,
    required Map<String, double> s,
    String? staff,
    String? type,
    String? category,
    String? kind,
  }) async {
    final pdf = await _buildItemTransactionsPdfDoc(
      company: company,
      itemName: itemName,
      branchLabel: branchLabel,
      start: start,
      end: end,
      rows: rows,
      s: s,
      staff: staff,
      type: type,
      category: category,
      kind: kind,
    );

    final bytes = await pdf.save();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName =
        '${itemName.replaceAll(' ', '_')}_transactions_$ts';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  /// Exports the same transaction data to an .xlsx file, saved/downloaded
  /// directly on every platform.
  Future<void> _exportItemTransactionsExcel({
    required String company,
    required String itemName,
    required String branchLabel,
    required DateTime start,
    required DateTime end,
    required List<Map<String, dynamic>> rows,
    required Map<String, double> s,
    String? staff,
    String? type,
    String? category,
    String? kind,
  }) async {
    final nf = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');
    final dtFmt = DateFormat('dd MMM yy, hh:mm a');
    final period = '${dateFmt.format(start)} - ${dateFmt.format(end)}';

    double v(String k) => s[k] ?? 0;
    String qf(double x) =>
        x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(2);

    const kindLabels = {
      'cashSales': 'Cash Sales',
      'creditSales': 'Credit Sales',
      'totalReturns': 'Returns',
      'discount': 'With Discount',
    };

    final excelFile = xls.Excel.createExcel();
    const sheetName = 'Item Transactions';
    final sheet = excelFile[sheetName];
    excelFile.delete('Sheet1');

    final titleStyle = xls.CellStyle(bold: true, fontSize: 16);
    final headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#DDDDDD'),
    );
    final boldStyle = xls.CellStyle(bold: true);

    // --- Title block ---
    sheet.appendRow([xls.TextCellValue(company.toUpperCase())]);
    sheet
        .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .cellStyle = titleStyle;
    sheet.appendRow([xls.TextCellValue('ITEM SALES TRANSACTIONS')]);
    sheet.appendRow([xls.TextCellValue('Item: $itemName')]);
    sheet.appendRow([xls.TextCellValue('Branch: $branchLabel')]);
    sheet.appendRow([xls.TextCellValue('Period: $period')]);
    sheet.appendRow([xls.TextCellValue('Transactions: ${rows.length}')]);
    sheet.appendRow([xls.TextCellValue('Qty Sold: ${qf(v('qty'))}')]);
    sheet.appendRow([xls.TextCellValue('Staff: ${staff ?? 'All'}')]);
    sheet.appendRow([xls.TextCellValue('Product Type: ${type ?? 'All'}')]);
    sheet.appendRow([xls.TextCellValue('Category: ${category ?? 'All'}')]);
    sheet.appendRow([xls.TextCellValue('Showing: ${kindLabels[kind] ?? 'All'}')]);
    sheet.appendRow([]); // spacer

    // --- Headers ---
    final headers = <String>[
      '#',
      'DATE',
      'QTY',
      'PRICE',
      'DISCOUNT',
      'TOTAL',
      'PROFIT',
      'TYPE',
      'MODE',
      'CUSTOMER',
      'STAFF',
      'BRANCH',
    ];
    sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());
    final headerRowIdx = sheet.maxRows - 1;
    for (int c = 0; c < headers.length; c++) {
      sheet
          .cell(xls.CellIndex.indexByColumnRow(
          columnIndex: c, rowIndex: headerRowIdx))
          .cellStyle = headerStyle;
    }

    // --- Data rows ---
    for (int i = 0; i < rows.length; i++) {
      final t = rows[i];
      final ret = t['isReturned'] == true;
      double sg(double x) => ret && x != 0 ? -x : x;

      final d = t['date'];
      final dateStr = d is Timestamp
          ? dtFmt.format(d.toDate())
          : (d is DateTime ? dtFmt.format(d) : '-');

      final typeStr = ret
          ? (t['returnedTransMode'] == 'credit'
          ? 'Credit Return'
          : 'Cash Return')
          : 'Sale / ${(t['transMode'] ?? '').toString()}';

      final qty = _num(t['qty']);

      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(dateStr),
        xls.DoubleCellValue(ret ? -qty : qty),
        xls.DoubleCellValue(_num(t['price'])),
        xls.DoubleCellValue(sg(_num(t['discount']))),
        xls.DoubleCellValue(sg(_num(t['total']))),
        xls.DoubleCellValue(sg(_num(t['profit']))),
        xls.TextCellValue(typeStr),
        xls.TextCellValue((t['salesMode'] ?? '').toString()),
        xls.TextCellValue((t['customer'] ?? '').toString()),
        xls.TextCellValue((t['staff'] ?? '').toString()),
        xls.TextCellValue((t['branch'] ?? '').toString()),
      ]);
    }

    // --- Grand total row ---
    sheet.appendRow([
      xls.TextCellValue(''),
      xls.TextCellValue('GRAND TOTAL'),
      xls.DoubleCellValue(v('qty')),
      xls.TextCellValue(''),
      xls.DoubleCellValue(v('discount')),
      xls.DoubleCellValue(v('net')),
      xls.DoubleCellValue(v('profit')),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
    ]);
    final totalRowIdx = sheet.maxRows - 1;
    for (int c = 0; c < headers.length; c++) {
      sheet
          .cell(xls.CellIndex.indexByColumnRow(
          columnIndex: c, rowIndex: totalRowIdx))
          .cellStyle = boldStyle;
    }

    // --- Save (works on web, Windows, macOS, Linux, Android, iOS) ---
    final bytes = excelFile.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file — no data to export.');
    }

    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName =
        '${itemName.replaceAll(' ', '_')}_transactions_$ts';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }
  Map<String, dynamic> aggregateItemStats(List<Map<String, dynamic>> transactions) {
    double cashSales = 0;
    double creditSales = 0;
    double cashReturns = 0;
    double creditReturns = 0;
    double totalDiscount = 0;
    double totalQty = 0;
    double totalCost = 0;
    double profit = 0;

    for (final t in transactions) {
      final total = (t['total'] as num?)?.toDouble() ?? 0;
      final qty = (t['qty'] as num?)?.toDouble() ?? 0;
      final discount = (t['discount'] as num?)?.toDouble() ?? 0;
      final cp = (t['cp'] as num?)?.toDouble() ?? 0;
      final profitt = (t['profit'] as num?)?.toDouble() ?? 0;
      final returnedAmount = (t['returnedAmount'] as num?)?.toDouble() ?? 0;
      final isReturned = t['isReturned'] == true;

      if (isReturned) {
        // Returns: subtract qty, profit, discount — don't add to sales
        totalQty -= qty;
        totalDiscount -= discount;
        totalCost -= qty * cp;
        profit -= profitt;

        if (t['isCashReturn'] == true) {
          cashReturns += returnedAmount;
        } else if (t['isCreditReturn'] == true) {
          creditReturns += returnedAmount;
        }
      } else {
        // Normal sales only
        totalQty += qty;
        totalDiscount += discount;
        totalCost += qty * cp;
        profit += profitt;

        if (t['isCredit'] == true) {
          creditSales += total;
        } else {
          cashSales += total;
        }
      }
    }

    final totalReturns = cashReturns + creditReturns;
    final grossRevenue = (cashSales + creditSales) - totalReturns;

    return {
      'cashSales': cashSales,
      'creditSales': creditSales,
      'cashReturns': cashReturns,
      'creditReturns': creditReturns,
      'totalReturns': totalReturns,
      'totalDiscount': totalDiscount,
      'totalQty': totalQty,
      'profit': profit,
      'total': grossRevenue,
    };
  }

  List<Map<String, dynamic>> _filterTransactionsByCategory(   List<Map<String, dynamic>> transactions, String category) {
    switch (category) {
      case 'cashSales':
        return transactions.where((t) =>
        t['isReturned'] != true && t['isCredit'] != true).toList();
      case 'creditSales':
        return transactions.where((t) =>
        t['isReturned'] != true && t['isCredit'] == true).toList();
      case 'cashReturns':
        return transactions.where((t) =>
        t['isReturned'] == true && t['isCashReturn'] == true).toList();
      case 'creditReturns':
        return transactions.where((t) =>
        t['isReturned'] == true && t['isCreditReturn'] == true).toList();
      case 'totalReturns':
        return transactions.where((t) => t['isReturned'] == true).toList();
      case 'discount':
        return transactions.where((t) {
          final d = (t['discount'] as num?) ?? 0;
          return d > 0;
        }).toList();
      case 'total':
      case 'profit':
      case 'qty':
      default:
        return transactions;
    }
  }


  Future<void> printTransactions(List transactions, String itemName,String startdate, String endDate, String company, String branch ) async {
    final pdf = pw.Document(title: itemName);

    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    final currencyFormat = NumberFormat.currency(symbol: 'GHC ', decimalDigits: 2);
    String fmt(dynamic v) {
      if (v == null) return 'GHC 0.00';
      final d = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
      return currencyFormat.format(d);
    }

    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return (v as num).toDouble();
    }

    // ── Compute summary totals
    double totalCashSales     = 0;
    double totalCreditSales   = 0;
    double totalCashReturns   = 0;
    double totalCreditReturns = 0;
    double totalReturns       = 0;
    double totalDiscount      = 0;
    double totalQtySold       = 0;
    double totalNetRevenue    = 0;
    double totalProfit        = 0;

    for (final t in transactions) {
      final isReturned       = t['isReturned'] == true;
      final transMode        = (t['transMode']         ?? '').toString().toLowerCase();
      final returnedTransMode= (t['returnedTransMode'] ?? '').toString().toLowerCase();
      final total            = _d(t['total']);
      final qty              = _d(t['qty']);
      final discount         = _d(t['discount']);
      final profit           = _d(t['profit']);

      if (isReturned) {
        // use returnedTransMode to bucket the return
        if (returnedTransMode == 'cash')   totalCashReturns   += total;
        if (returnedTransMode == 'credit') totalCreditReturns += total;
        totalReturns += total;
      } else {
        if (transMode == 'cash')   totalCashSales   += total;
        if (transMode == 'credit') totalCreditSales += total;
        totalNetRevenue += total;
      }

      totalDiscount += discount;
      totalQtySold  += qty;
      totalProfit   += profit;
    }

    // ── Colours
    const headerBg  = PdfColor.fromInt(0xFF1B263B);
    const rowEven   = PdfColor.fromInt(0xFFF4F6FA);
    const returnBg  = PdfColor.fromInt(0x14FF5252);
    const accent    = PdfColor.fromInt(0xFF415A77);

    // ── Helpers
    pw.Widget cell(
        String text, {
          bool header = false,
          bool bold   = false,
          bool right  = false,
          PdfColor? color,
        }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font:     (header || bold) ? boldFont : baseFont,
              fontSize: 8,
              color:    header ? PdfColors.white : (color ?? PdfColors.grey800),
            ),
          ),
        );

    pw.Widget chipBox(String label, String value, {PdfColor? valueColor}) =>
        pw.Container(
          margin:  const pw.EdgeInsets.only(right: 6, bottom: 4),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            border:       pw.Border.all(color: accent, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
            color:        PdfColor.fromInt(0xFF1A2235),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 7, color: PdfColors.grey400)),
              pw.SizedBox(height: 2),
              pw.Text(value,
                  style: pw.TextStyle(
                      font: boldFont, fontSize: 9,
                      color: valueColor ?? PdfColors.white)),
            ],
          ),
        );

    //Page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin:     const pw.EdgeInsets.all(28),
        theme:      pw.ThemeData.withFont(base: baseFont, bold: boldFont),

        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$itemName SALES TRANSACTIONS',
                  style: pw.TextStyle(font: boldFont, fontSize: 16, color: accent),
                ),
                pw.Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  company,
                  style: pw.TextStyle(font: boldFont, fontSize: 10, color: accent),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Branch: $branch',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Period: $startdate  –  $endDate',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.2, color: accent),
            pw.SizedBox(height: 10),

            //Summary chips
            pw.Wrap(
              spacing:    6,
              runSpacing: 4,
              children: [
                chipBox('Cash Sales',     fmt(totalCashSales)),
                chipBox('Credit Sales',   fmt(totalCreditSales)),
                chipBox('Cash Returns',   fmt(totalCashReturns)),
                chipBox('Credit Returns', fmt(totalCreditReturns)),
                chipBox('Total Returns',  fmt(totalReturns)),
                chipBox('Discount',       fmt(totalDiscount)),
                chipBox('Qty Sold',       totalQtySold.toStringAsFixed(0)),
                chipBox('Net Revenue',    fmt(totalNetRevenue)),
                chipBox('Profit',         fmt(totalProfit),
                    valueColor: totalProfit < 0
                        ? PdfColors.red400
                        : PdfColors.greenAccent700),
              ],
            ),
            pw.SizedBox(height: 10),
          ],
        ),

        build: (context) => [
          pw.Table(
            columnWidths: {
              0:  const pw.FixedColumnWidth(20),  // #
              1:  const pw.FlexColumnWidth(2.0),  // Date/Time
              2:  const pw.FlexColumnWidth(2.2),  // Item
              3:  const pw.FixedColumnWidth(30),  // Qty
              4:  const pw.FixedColumnWidth(36),  // Price
              5:  const pw.FixedColumnWidth(44),  // Total
              6:  const pw.FlexColumnWidth(1.2),  // Txn Mode
              7:  const pw.FlexColumnWidth(0.9),  // Sales Mode
              8:  const pw.FlexColumnWidth(1.4),
              9: const pw.FlexColumnWidth(0.9),  // Pricing Mode
              10: const pw.FlexColumnWidth(1.2),  // Staff
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('#',            header: true),
                  cell('DATE/TIME',    header: true),
                  cell('ITEM',         header: true),
                  cell('QTY',          header: true, right: true),
                  cell('PRICE',        header: true, right: true),
                  cell('TOTAL',        header: true, right: true),
                  cell('TXN MODE',     header: true),
                  cell('SALES MODE',   header: true),
                  cell('STAFF',        header: true),
                  cell('CUSTOMER',     header: true),
                  cell('PRICING MODE', header: true),

                ],
              ),

              // Data rows
              ...transactions.asMap().entries.map((entry) {
                final i          = entry.key;
                final t          = entry.value as Map<String, dynamic>;
                final isReturned = t['isReturned'] == true;
                final returnedTransMode = (t['returnedTransMode'] ?? '').toString();

                final String rowTypeLabel = isReturned
                    ? (returnedTransMode == 'credit' ? 'Credit Return' : 'Cash Return')
                    : 'Sale';


                final PdfColor labelColor = isReturned
                    ? (returnedTransMode == 'credit'
                    ? PdfColors.orange
                    : PdfColors.red400)
                    : PdfColors.green700;

                String dateStr = '-';
                final rawDate = t['date'];
                if (rawDate is Timestamp) {
                  dateStr = DateFormat('dd MMM yyyy, hh:mm a')
                      .format(rawDate.toDate());
                } else if (rawDate is DateTime) {
                  dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(rawDate);
                }


                final item        = (t['item']        ?? '-').toString();
                final transMode   = (t['transMode']   ?? '-').toString();
                final salesMode   = (t['salesMode']   ?? '-').toString();
                final customer    = (t['customer']    ?? '-').toString();
                final branch      = (t['branch']      ?? '-').toString();
                final pricingMode = (t['pricingMode'] ?? '-').toString();
                final staff       = (t['staff']       ?? '-').toString();

                // TXN MODE cell: "Sale / cash" or "Cash Return / cash" — mirrors UI
                final txnModeDisplay = isReturned
                    ? '$rowTypeLabel / $returnedTransMode'
                    : '$rowTypeLabel / $transMode';

                return pw.TableRow(
                  decoration: pw.BoxDecoration(),
                  children: [
                    cell('${i + 1}'),
                    cell(dateStr),
                    cell(item),
                    cell(_d(t['qty']).toStringAsFixed(0),    right: true),
                    cell(_d(t['price']).toStringAsFixed(2),  right: true),
                    cell(_d(t['total']).toStringAsFixed(2),  right: true, bold: true),
                    cell(txnModeDisplay, color: labelColor,  bold: true),
                    cell(salesMode),
                    cell(customer),
                    cell(pricingMode),
                    cell(staff),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 6),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total Transactions: ${transactions.length}',
              style: pw.TextStyle(
                  font: baseFont, fontSize: 8, color: PdfColors.grey500),
            ),
          ),
        ],

        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
  Future<void> printTransactionsbr(List<Map<String, dynamic>> filteredList, String itemName, String startDate,String endDate ) async {
    final pdf = pw.Document(title: itemName.trim().isEmpty ? 'Sales Report' : '$itemName Sales Report');
    final provider = context.read<Datafeed>();
    double _d(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return (v as num).toDouble();
    }

    final currencyFormat = NumberFormat.currency(symbol: 'GHC ', decimalDigits: 2);
    String fmt(double v) => currencyFormat.format(v);
    String fmtQty(double v) => v.toStringAsFixed(1);

    double totalCashSales     = 0;
    double totalCreditSales   = 0;
    double totalCashReturns   = 0;
    double totalCreditReturns = 0;
    double totalReturns       = 0;
    double totalDiscount      = 0;
    double totalProfit        = 0;
    double grandTotal         = 0;
    double totalQty           = 0;

    for (final item in filteredList) {
      totalCashSales     += _d(item['cashSales']);
      totalCreditSales   += _d(item['creditSales']);
      totalCashReturns   += _d(item['cashReturns']);
      totalCreditReturns += _d(item['creditReturns']);
      totalReturns       += _d(item['totalReturns']);
      totalDiscount      += _d(item['discount']);
      totalProfit        += _d(item['profit']);
      grandTotal         += _d(item['rowtotal']);
      totalQty           += _d(item['quantity']);
    }

    final cashAtHand = (totalCashSales - totalCashReturns);

    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    const headerBg   = PdfColors.white;
    const rowEven    = PdfColors.white;
    const rowOdd     = PdfColors.white;
    const totalRowBg = PdfColors.white;
    const cashRowBg  = PdfColors.white;
    const accent     = PdfColor.fromInt(0xFF415A77); // muted blue

    pw.Widget cell(
        String text, {
          bool header  = false,
          bool bold    = false,
          bool right   = false,
          PdfColor? color,
        }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font:      (header || bold) ? boldFont : baseFont,
            fontSize:  header ? 8 : 8,
            color:     color ?? PdfColors.grey800,
          ),
        ),
      );
    }

    pw.Widget summaryLine(String label, String value, {bool highlight = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                    font:     highlight ? boldFont : baseFont,
                    fontSize: highlight ? 10 : 9,
                    color:    highlight ? accent : PdfColors.grey700,
                  )),
              pw.Text(value,
                  style: pw.TextStyle(
                    font:     boldFont,
                    fontSize: highlight ? 11 : 9,
                    color:    highlight ? accent : PdfColors.grey800,
                  )),
            ],
          ),
        );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin:     const pw.EdgeInsets.all(28),
        theme:      pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      itemName.toUpperCase(),
                      style: pw.TextStyle(
                          font: boldFont, fontSize: 18, color: accent),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(provider.company                     ,
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 11, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Branch Sales Report',
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 11, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Period $startDate - $endDate',
                      style: pw.TextStyle(
                          font: baseFont, fontSize: 11, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.Text('Date${
                    DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5, color: accent),
            pw.SizedBox(height: 6),
          ],
        ),
        build: (context) => [

          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(24),   // #
              1: const pw.FlexColumnWidth(2.8),   // Item
              2: const pw.FlexColumnWidth(0.8),   // Qty
              3: const pw.FlexColumnWidth(1.2),   // Cash Sales
              4: const pw.FlexColumnWidth(1.2),   // Credit Sales
              5: const pw.FlexColumnWidth(1.1),   // Cash Returns
              6: const pw.FlexColumnWidth(1.1),   // Credit Returns
              7: const pw.FlexColumnWidth(1.0),   // Returns
              8: const pw.FlexColumnWidth(1.0),   // Discount
              9: const pw.FlexColumnWidth(1.0),   // Profit
              10: const pw.FlexColumnWidth(1.2),  // Total
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  cell('#',              header: true),
                  cell('ITEM',           header: true),
                  cell('QTY',            header: true, right: true),
                  cell('CASH SALES',     header: true, right: true),
                  cell('CREDIT SALES',   header: true, right: true),
                  cell('CASH RET.',      header: true, right: true),
                  cell('CREDIT RET.',    header: true, right: true),
                  cell('RETURNS',        header: true, right: true),
                  cell('DISCOUNT',       header: true, right: true),
                  cell('PROFIT',         header: true, right: true),
                  cell('TOTAL',          header: true, right: true),
                ],
              ),

              // Data rows
              ...filteredList.asMap().entries.map((entry) {
                final i    = entry.key;
                final item = entry.value;


                final profit = _d(item['profit']);
                final profitColor = profit < 0 ? PdfColors.red700 : PdfColors.grey800;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(),
                  children: [
                    cell('${i + 1}'),
                    cell(item['item']?.toString() ?? '-'),
                    cell(fmtQty(_d(item['quantity'])),         right: true),
                    cell(fmt(_d(item['cashSales'])),           right: true),
                    cell(fmt(_d(item['creditSales'])),         right: true),
                    cell(fmt(_d(item['cashReturns'])),         right: true),
                    cell(fmt(_d(item['creditReturns'])),       right: true),
                    cell(fmt(_d(item['totalReturns'])),        right: true),
                    cell(fmt(_d(item['discount'])),            right: true),
                    cell(fmt(profit), right: true, color: profitColor),
                    cell(fmt(_d(item['rowtotal'])),            right: true, bold: true),
                  ],
                );
              }),

              // Grand Total row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: totalRowBg),
                children: [
                  cell('', bold: true, header: true),
                  cell('GRAND TOTAL', bold: true, header: true),
                  cell(fmtQty(totalQty),right: true,  bold: true, header: true),
                  cell(fmt(totalCashSales),  right: true, bold: true, header: true),
                  cell(fmt(totalCreditSales),   right: true, bold: true, header: true),
                  cell(fmt(totalCashReturns),   right: true, bold: true, header: true),
                  cell(fmt(totalCreditReturns), right: true, bold: true, header: true),
                  cell(fmt(totalReturns),       right: true, bold: true, header: true),
                  cell(fmt(totalDiscount),      right: true, bold: true, header: true),
                  cell(fmt(totalProfit),        right: true, bold: true, header: true),
                  cell(fmt(grandTotal),         right: true, bold: true, header: true),
                ],
              ),

              // Cash @ Hand row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: cashRowBg),
                children: [
                  cell('', header: true),
                  cell('TOTAL CASH @ HAND', bold: true, header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  cell('', header: true),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    child: pw.Text(
                      fmt(cashAtHand),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font:      boldFont,
                        fontSize:  9,
                        color:     PdfColors.greenAccent700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 280,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color:        rowEven,
                border:       pw.Border.all(color: accent, width: 0.8),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text('SUMMARY',
                      style: pw.TextStyle(
                          font: boldFont, fontSize: 11, color: accent)),
                  pw.SizedBox(height: 10),
                  summaryLine('Total Cash Sales',     fmt(totalCashSales)),
                  summaryLine('Total Credit Sales',   fmt(totalCreditSales)),
                  summaryLine('Total Returns',        fmt(totalReturns)),
                  summaryLine('Total Discount',       fmt(totalDiscount)),
                  summaryLine('Total Profit',         fmt(totalProfit)),
                  pw.Divider(thickness: 0.8, color: accent),
                  summaryLine('Grand Total', fmt(grandTotal),   highlight: true),
                  pw.SizedBox(height: 4),
                  summaryLine('Total Cash @ Hand',    fmt(cashAtHand),   highlight: true),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Total Items: ${filteredList.length}',
                    style: pw.TextStyle(
                        font: baseFont, fontSize: 8, color: PdfColors.grey500),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],

        footer: (context) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(font: baseFont, fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }




  Future<pw.Document> _buildReportPdfDoc({
    required String title,
    required String company,
    required String branchLabel,
    required String countLabel,
    required String firstColumn,
    required DateTime start,
    required DateTime end,
    required String? type,
    required String? category,
    required List<_BranchRow> rows,
    required _BranchRow t,
  }) async {
    final pdf = pw.Document();

    final regular =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final nf = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');
    final now = DateTime.now();
    final period = '${dateFmt.format(start)} - ${dateFmt.format(end)}';

    pw.Widget cell(
        String text, {
          bool head = false,
          bool isBold = false,
          bool right = false,
          PdfColor? color,
        }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: (head || isBold) ? bold : regular,
            fontSize: head ? 9 : 10,
            color: color ?? PdfColors.black,
          ),
        ),
      );
    }

    pw.Widget infoRow(String label, String val, {bool end = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          mainAxisAlignment:
          end ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
          children: [
            pw.Text('$label:  ', style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text(val, style: pw.TextStyle(font: regular, fontSize: 10)),
          ],
        ),
      );
    }

    pw.Widget sectionLabel(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold,
          fontSize: 10,
          color: PdfColors.grey600,
          letterSpacing: 1.4,
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.all(30),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(thickness: 0.1, color: PdfColors.grey),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(now)}',
                  style: pw.TextStyle(
                      font: regular, fontSize: 9, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: regular, fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    company.toUpperCase(),
                    style: pw.TextStyle(font: bold, fontSize: 22),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    branchLabel,
                    style: pw.TextStyle(
                        font: regular, fontSize: 11, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 18)),

                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    infoRow('Period', period),
                    infoRow(countLabel, '${rows.length}'),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    infoRow('Product Type', type ?? 'All', end: true),
                    infoRow('Category', category ?? 'All', end: true),
                  ],
                ),
              ),
            ],
          ),
          // pw.SizedBox(height: 1),
          // sectionLabel('${firstColumn.toUpperCase()} SALES'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            columnWidths: {
              0: const pw.FixedColumnWidth(26),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.6),
              4: const pw.FlexColumnWidth(1.6),
              5: const pw.FlexColumnWidth(1.6),
              6: const pw.FlexColumnWidth(1.6),
              7: const pw.FlexColumnWidth(1.6),
              8: const pw.FlexColumnWidth(2.0),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(),
                children: [
                  cell('#', head: true),
                  cell(firstColumn, head: true),
                  cell('CASH SALES', head: true, right: true),
                  cell('CREDIT SALES', head: true, right: true),
                  cell('TOTAL SALES', head: true, right: true),
                  cell('RETURNS', head: true, right: true),
                  cell('DISCOUNT', head: true, right: true),
                  cell('PROFIT', head: true, right: true),
                  cell('CASH@HAND', head: true, right: true),
                ],
              ),
              ...rows.asMap().entries.map((e) {
                final r = e.value;
                return pw.TableRow(
                  children: [
                    cell('${e.key + 1}'),
                    cell(r.branchName, isBold: true),
                    cell(nf.format(r.cashSales), right: true),
                    cell(nf.format(r.credit), right: true),
                    cell(nf.format(r.totalSales), right: true),
                    cell(nf.format(r.returns), right: true),
                    cell(nf.format(r.discount), right: true),
                    cell(nf.format(r.profit), right: true),
                    cell(nf.format(r.cashAtHand), right: true, isBold: true),
                  ],
                );
              }),
              pw.TableRow(
                decoration: const pw.BoxDecoration(),
                children: [
                  cell(''),
                  cell('GRAND TOTAL', isBold: true),
                  cell(nf.format(t.cashSales), right: true, isBold: true),
                  cell(nf.format(t.credit), right: true, isBold: true),
                  cell(nf.format(t.totalSales), right: true, isBold: true),
                  cell(nf.format(t.returns), right: true, isBold: true),
                  cell(nf.format(t.discount), right: true, isBold: true),
                  cell(nf.format(t.profit), right: true, isBold: true),
                  cell(nf.format(t.cashAtHand), right: true, isBold: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }


  Future<void> _printReport({
    required String title,
    required String company,
    required String branchLabel,
    required String countLabel,
    required String firstColumn,
    required DateTime start,
    required DateTime end,
    required String? type,
    required String? category,
    required List<_BranchRow> rows,
    required _BranchRow t,
  }) async {
    final pdf = await _buildReportPdfDoc(
      title: title,
      company: company,
      branchLabel: branchLabel,
      countLabel: countLabel,
      firstColumn: firstColumn,
      start: start,
      end: end,
      type: type,
      category: category,
      rows: rows,
      t: t,
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }


  Future<void> _downloadReportPdf({
    required String title,
    required String company,
    required String branchLabel,
    required String countLabel,
    required String firstColumn,
    required DateTime start,
    required DateTime end,
    required String? type,
    required String? category,
    required List<_BranchRow> rows,
    required _BranchRow t,
  }) async {
    final pdf = await _buildReportPdfDoc(
      title: title,
      company: company,
      branchLabel: branchLabel,
      countLabel: countLabel,
      firstColumn: firstColumn,
      start: start,
      end: end,
      type: type,
      category: category,
      rows: rows,
      t: t,
    );

    final bytes = await pdf.save();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeTitle = title.replaceAll(' ', '_');
    final fileName = '${company.replaceAll(' ', '_')}_${safeTitle}_$ts';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }


  Future<void> _exportReportExcel({
    required String title,
    required String company,
    required String branchLabel,
    required String countLabel,
    required String firstColumn,
    required DateTime start,
    required DateTime end,
    required String? type,
    required String? category,
    required List<_BranchRow> rows,
    required _BranchRow t,
  }) async {
    final nf = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('dd MMM yyyy');
    final period = '${dateFmt.format(start)} - ${dateFmt.format(end)}';

    final excelFile = xls.Excel.createExcel();
    final sheetName = title.length > 31 ? title.substring(0, 31) : title;
    final sheet = excelFile[sheetName];
    excelFile.delete('Sheet1');

    final titleStyle = xls.CellStyle(bold: true, fontSize: 16);
    final headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#DDDDDD'),
    );
    final boldStyle = xls.CellStyle(bold: true);

    // --- Title block ---
    sheet.appendRow([xls.TextCellValue(company.toUpperCase())]);
    sheet
        .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .cellStyle = titleStyle;
    sheet.appendRow([xls.TextCellValue(title)]);
    sheet.appendRow([xls.TextCellValue(branchLabel)]);
    sheet.appendRow([xls.TextCellValue('Period: $period')]);
    sheet.appendRow([xls.TextCellValue('$countLabel: ${rows.length}')]);
    sheet.appendRow([xls.TextCellValue('Product Type: ${type ?? 'All'}')]);
    sheet.appendRow([xls.TextCellValue('Category: ${category ?? 'All'}')]);
    sheet.appendRow([]); // spacer

    // --- Headers ---
    final headers = <String>[
      '#',
      firstColumn,
      'CASH SALES',
      'CREDIT SALES',
      'TOTAL SALES',
      'RETURNS',
      'DISCOUNT',
      'PROFIT',
      'CASH@HAND',
    ];
    sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());
    final headerRowIdx = sheet.maxRows - 1;
    for (int c = 0; c < headers.length; c++) {
      sheet
          .cell(xls.CellIndex.indexByColumnRow(
          columnIndex: c, rowIndex: headerRowIdx))
          .cellStyle = headerStyle;
    }

    // --- Data rows ---
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      sheet.appendRow([
        xls.IntCellValue(i + 1),
        xls.TextCellValue(r.branchName),
        xls.DoubleCellValue(r.cashSales),
        xls.DoubleCellValue(r.credit),
        xls.DoubleCellValue(r.totalSales),
        xls.DoubleCellValue(r.returns),
        xls.DoubleCellValue(r.discount),
        xls.DoubleCellValue(r.profit),
        xls.DoubleCellValue(r.cashAtHand),
      ]);
    }

    // --- Grand total row ---
    sheet.appendRow([
      xls.TextCellValue(''),
      xls.TextCellValue('GRAND TOTAL'),
      xls.DoubleCellValue(t.cashSales),
      xls.DoubleCellValue(t.credit),
      xls.DoubleCellValue(t.totalSales),
      xls.DoubleCellValue(t.returns),
      xls.DoubleCellValue(t.discount),
      xls.DoubleCellValue(t.profit),
      xls.DoubleCellValue(t.cashAtHand),
    ]);
    final totalRowIdx = sheet.maxRows - 1;
    for (int c = 0; c < headers.length; c++) {
      sheet
          .cell(xls.CellIndex.indexByColumnRow(
          columnIndex: c, rowIndex: totalRowIdx))
          .cellStyle = boldStyle;
    }

    // --- Save (works on web, Windows, macOS, Linux, Android, iOS) ---
    final bytes = excelFile.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file — no data to export.');
    }

    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeTitle = title.replaceAll(' ', '_');
    final fileName = '${company.replaceAll(' ', '_')}_${safeTitle}_$ts';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<void> _printMain(Datafeed value, List<_BranchRow> rows, _BranchRow t) {
    final now = DateTime.now();
    return _printReport(
      title: 'SALES REPORT',
      company: value.company,
      branchLabel: _branchLabel(value),
      countLabel: 'Branches',
      firstColumn: 'BRANCH',
      start: selectedDate?.start ?? now,
      end: selectedDate?.end ?? now,
      type: _selectedType,
      category: _selectedCategory,
      rows: rows,
      t: t,
    );
  }

  Future<void> _downloadMainPdf(Datafeed value, List<_BranchRow> rows, _BranchRow t) {
    final now = DateTime.now();
    return _downloadReportPdf(
      title: 'SALES REPORT',
      company: value.company,
      branchLabel: _branchLabel(value),
      countLabel: 'Branches',
      firstColumn: 'BRANCH',
      start: selectedDate?.start ?? now,
      end: selectedDate?.end ?? now,
      type: _selectedType,
      category: _selectedCategory,
      rows: rows,
      t: t,
    );
  }

  Future<void> _downloadMainExcel(Datafeed value, List<_BranchRow> rows, _BranchRow t) {
    final now = DateTime.now();
    return _exportReportExcel(
      title: 'SALES REPORT',
      company: value.company,
      branchLabel: _branchLabel(value),
      countLabel: 'Branches',
      firstColumn: 'BRANCH',
      start: selectedDate?.start ?? now,
      end: selectedDate?.end ?? now,
      type: _selectedType,
      category: _selectedCategory,
      rows: rows,
      t: t,
    );
  }




}


