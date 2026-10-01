import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/staffreportsalespdf.dart';
import 'sales_report_shared.dart';
import 'sales_staff_models.dart';

class SalesStaffTransactionsPage extends StatefulWidget {
  final String staffName;
  final String staffEmail;
  final String branchId;
  final String branchLabel;
  final DateTimeRange? dateRange;

  const SalesStaffTransactionsPage({
    super.key,
    required this.staffName,
    required this.staffEmail,
    required this.branchId,
    required this.branchLabel,
    required this.dateRange,
  });

  @override
  State<SalesStaffTransactionsPage> createState() =>
      _SalesStaffTransactionsPageState();
}

class _SalesStaffTransactionsPageState
    extends State<SalesStaffTransactionsPage> {
  bool get _isLightTheme => srIsLightTheme(context);
  Color get _bg => srBackgroundColor(context);
  Color get _bar => srCardColor(context);
  Color get _field => _isLightTheme
      ? Theme.of(context).colorScheme.surfaceContainerHighest
      : srCardColor(context);
  Color get _textColor => srTextColor(context);
  Color get _mutedTextColor => srMutedTextColor(context);
  Color get _borderColor => srBorderColor(context);
  Color get _accent => srAccentColor(context);
  Color get _errorColor =>
      _isLightTheme ? Colors.red.shade700 : Colors.redAccent;
  Color get _successColor =>
      _isLightTheme ? Colors.green.shade700 : Colors.greenAccent;
  static const _rowsPerPage = 10;

  static const _paymentOptions = <PaymentFilterOption>[
    PaymentFilterOption('All', null, Icons.apps_rounded),
    PaymentFilterOption('Cash', 'cash', Icons.payments_outlined),
    PaymentFilterOption('Credit', 'credit', Icons.payments_outlined),
    PaymentFilterOption('MoMo', 'momo', Icons.smartphone_outlined),
    PaymentFilterOption('Card', 'card', Icons.credit_card_outlined),
    PaymentFilterOption(
      'Hubtel',
      'hubtel',
      Icons.account_balance_wallet_outlined,
    ),
    PaymentFilterOption('Cheque', 'cheque', Icons.receipt_long_outlined),
    PaymentFilterOption('Bank', 'bank', Icons.account_balance_outlined),
  ];

  late final Datafeed _provider;
  late final String _previousSearch;
  final _searchCtrl = TextEditingController();
  final _h = ScrollController();
  final _v = ScrollController();

  bool _loading = true;
  bool _searchExpanded = false;
  int _page = 0;
  String? _paymentFilter;

  @override
  void initState() {
    super.initState();
    _provider = context.read<Datafeed>();
    _previousSearch = _provider.searchQuery;
    Future.microtask(_load);
  }

  Future<void> _load() async {
    _provider.updateSearch('');
    try {
      final now = DateTime.now();
      await _provider.loadSalesStaffTransactions(
        startDate: widget.dateRange?.start ?? now,
        endDate: widget.dateRange?.end ?? now,
        staffName: widget.staffName,
        staffEmail: widget.staffEmail,
        companyId: _provider.companyid,
        selectedBranch: widget.branchId.isEmpty ? null : widget.branchId,
      );
    } catch (e) {
      debugPrint('Staff transactions error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    Future.microtask(() => _provider.updateSearch(_previousSearch));
    _searchCtrl.dispose();
    _h.dispose();
    _v.dispose();
    super.dispose();
  }

  bool _matchesPayment(Map<String, dynamic> t, String keyword) {
    if ((t['payment']?.toString().toLowerCase() ?? '').contains(keyword)) {
      return true;
    }
    final payments = t['payments'];
    if (payments is List) {
      for (final p in payments) {
        if (p is Map &&
            (p['method']?.toString().toLowerCase() ?? '').contains(keyword)) {
          return true;
        }
      }
    }
    return false;
  }

  DateTime _resolveDate(Map<String, dynamic> t) {
    final datetime = t['datetime'];
    if (datetime is Timestamp) return datetime.toDate();
    return DateTime.tryParse(t['date']?.toString() ?? '') ?? DateTime.now();
  }

  Map<String, dynamic> _resolveItems(Map<String, dynamic> t) {
    final raw = t['items'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: _mutedTextColor, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: _textColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showItemsPopup(String receipt, List<ItemLine> lines) {
    Widget card(ItemLine line) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.name,
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _kv('Barcode', line.barcode),
          _kv('Mode', line.mode),
          _kv('Qty', '${line.qty}'),
          _kv('PriceMode', capitalize(line.priceMode)),
          _kv('Price', f2(line.price)),
          _kv('Disc', f2(line.discount)),
          _kv('Amount', f2(line.totalAmount)),
          _kv('Profit', f2(line.profit)),
        ],
      ),
    );

    DataColumn col(String t, {bool numeric = false}) => DataColumn(
      label: Text(t, style: TextStyle(color: _textColor)),
      numeric: numeric,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg,
        title: Text(receipt, style: TextStyle(color: _textColor)),
        content: SizedBox(
          width: 1000,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = MediaQuery.of(context).size.width < 600;
              if (lines.isEmpty) {
                return Text(
                  'No item detail',
                  style: TextStyle(color: _textColor),
                );
              }
              if (isMobile) {
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: lines.length,
                  itemBuilder: (context, i) => card(lines[i]),
                );
              }
              final s = TextStyle(color: _textColor);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 10,
                    headingRowColor: WidgetStateProperty.all(_field),
                    dataRowColor: WidgetStateProperty.all(_bg),
                    columns: [
                      col('Item'),
                      col('Barcode'),
                      col('Mode'),
                      col('Qty', numeric: true),
                      col('Price Mode'),
                      col('Price', numeric: true),
                      col('Discount', numeric: true),
                      col('Amount', numeric: true),
                      col('Profit', numeric: true),
                    ],
                    rows: lines
                        .map(
                          (l) => DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  l.name,
                                  style: TextStyle(color: _textColor),
                                ),
                              ),
                              DataCell(Text(l.barcode, style: s)),
                              DataCell(Text(l.mode, style: s)),
                              DataCell(Text('${l.qty}', style: s)),
                              DataCell(Text(capitalize(l.priceMode), style: s)),
                              DataCell(Text(f2(l.price), style: s)),
                              DataCell(Text(f2(l.discount), style: s)),
                              DataCell(Text(f2(l.totalAmount), style: s)),
                              DataCell(Text(f2(l.profit), style: s)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _textColor)),
          ),
        ],
      ),
    );
  }

  void _showPaymentPopup(
    String receipt, {
    required List<PaymentLine> payments,
    required String paymentStatus,
    required double amountPaid,
    required double totalAmount,
  }) {
    Widget card(PaymentLine p) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            capitalize(p.method),
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _kv('Account Name', p.accountName),
          _kv('Account Number', p.accountNumber),
          _kv('Reference', p.reference),
          _kv('Amount', f2(p.amount)),
          Row(
            children: [
              Text(
                'Status: ',
                style: TextStyle(color: _mutedTextColor, fontSize: 12),
              ),
              Text(
                p.status ? 'Success' : 'Failed',
                style: TextStyle(
                  color: p.status ? _successColor : _errorColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    DataColumn col(String t, {bool numeric = false}) => DataColumn(
      label: Text(t, style: TextStyle(color: _textColor)),
      numeric: numeric,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg,
        title: Text(receipt, style: TextStyle(color: _textColor)),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    miniStatString(context, 'Amount Paid', f2(amountPaid)),
                    miniStatString(context, 'Total Amount', f2(totalAmount)),
                    miniStatString(
                      context,
                      'Payment Status',
                      capitalize(paymentStatus),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'PAYMENT BREAKDOWN',
                  style: TextStyle(
                    color: _mutedTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final isMobile = MediaQuery.of(context).size.width < 600;
                    if (payments.isEmpty) {
                      return Text(
                        'No payment detail',
                        style: TextStyle(color: _mutedTextColor),
                      );
                    }
                    if (isMobile) {
                      return Column(children: payments.map(card).toList());
                    }
                    final s = TextStyle(color: _textColor);
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(_field),
                        dataRowColor: WidgetStateProperty.all(_bg),
                        columns: [
                          col('Method'),
                          col('Account Name'),
                          col('Account Number'),
                          col('Reference'),
                          col('Amount', numeric: true),
                          col('Status'),
                        ],
                        rows: payments
                            .map(
                              (p) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      capitalize(p.method),
                                      style: TextStyle(color: _textColor),
                                    ),
                                  ),
                                  DataCell(Text(p.accountName, style: s)),
                                  DataCell(Text(p.accountNumber, style: s)),
                                  DataCell(Text(p.reference, style: s)),
                                  DataCell(Text(f2(p.amount), style: s)),
                                  DataCell(
                                    Text(
                                      p.status ? 'Success' : 'Failed',
                                      style: TextStyle(
                                        color: p.status
                                            ? _successColor
                                            : _errorColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _textColor)),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(
    Datafeed provider,
    List<Map<String, dynamic>> displayedSales,
  ) {
    if (_searchExpanded) {
      return AppBar(
        backgroundColor: _bar,
        iconTheme: IconThemeData(color: _textColor),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: (val) {
            setState(() => _page = 0);
            provider.updateSearch(val);
          },
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            border: InputBorder.none,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchCtrl.clear();
              provider.updateSearch('');
              setState(() => _searchExpanded = false);
            },
            child: Text('Cancel', style: TextStyle(color: _mutedTextColor)),
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: _bar,
      elevation: 0,
      iconTheme: IconThemeData(color: _textColor),
      title: Text(
        '${widget.staffName} SALES TRANSACTIONS',
        style: TextStyle(
          color: _textColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: 'Search',
          icon: Icon(Icons.search, color: _textColor),
          onPressed: () => setState(() => _searchExpanded = true),
        ),
        IconButton(
          tooltip: 'Print / Download',
          icon: Icon(
            Icons.picture_as_pdf_outlined,
            color: _textColor,
            size: 20,
          ),
          onPressed: displayedSales.isEmpty
              ? null
              : () async {
                  try {
                    await printSalesStaffTransactionsPdf(
                      staffName: widget.staffName,
                      sales: displayedSales,
                      companyName: provider.company,
                      branchName: widget.branchLabel,
                      dateRange: widget.dateRange,
                      paymentFilter: _paymentFilter == null
                          ? null
                          : _paymentOptions
                                .firstWhere((o) => o.value == _paymentFilter)
                                .label,
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Print failed: $e')),
                      );
                    }
                  }
                },
        ),
      ],
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 40,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          scrollbars: false,
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              for (final opt in _paymentOptions) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() {
                    _paymentFilter = opt.value;
                    _page = 0;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _paymentFilter == opt.value
                          ? _accent
                          : _isLightTheme
                          ? _field
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _paymentFilter == opt.value
                            ? _accent
                            : _borderColor,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          opt.icon,
                          size: 16,
                          color: _paymentFilter == opt.value
                              ? Colors.white
                              : _textColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          opt.label,
                          style: TextStyle(
                            color: _paymentFilter == opt.value
                                ? Colors.white
                                : _textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileList(List<Map<String, dynamic>> paged) {
    return ListView.builder(
      itemCount: paged.length,
      itemBuilder: (context, index) {
        final t = paged[index];
        final no = _page * _rowsPerPage + index + 1;
        final formattedDate = DateFormat(
          'yyyy-MM-dd – hh:mm a',
        ).format(_resolveDate(t));
        final receipt = (t['receipt'] ?? '').toString();
        final customer = (t['customer'] ?? '').toString();
        final amount = _d(t['amount']);
        final amountPaid = _d(t['amountPaid']);
        final discount = _d(t['discount']);
        final itemMap = _resolveItems(t);
        final itemLines = parseItemLines(t['items']);

        return Card(
          color: _isLightTheme ? Colors.white : _field,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(
              color: _isLightTheme ? _borderColor : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#$no',
                      style: TextStyle(
                        color: _mutedTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(color: _mutedTextColor, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  receipt,
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    miniStatString(context, 'Customer', customer),
                    miniStatString(
                      context,
                      'Transaction Type',
                      (t['transMode'] ?? '').toString(),
                    ),
                    miniStatTap(
                      context,
                      'Amount Paid',
                      f2(amountPaid),
                      onTap: () => _showPaymentPopup(
                        receipt,
                        payments: parsePaymentLines(t['payments']),
                        paymentStatus: (t['paymentStatus'] ?? '').toString(),
                        amountPaid: amountPaid,
                        totalAmount: amount,
                      ),
                    ),
                    miniStatString(context, 'Discount', f2(discount)),
                    miniStatTap(
                      context,
                      'Items',
                      '${itemMap.length}',
                      onTap: () => _showItemsPopup(receipt, itemLines),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _desktopTable(List<Map<String, dynamic>> paged) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const widths = [30, 170, 150, 190, 90, 120, 90, 80];
        const gap = 15.0;
        final contentWidth =
            widths.reduce((a, b) => a + b) + (widths.length - 1) * gap + 32;
        final tableWidth = constraints.maxWidth > contentWidth
            ? constraints.maxWidth
            : contentWidth;

        Widget rowOf(List<Widget> cells) => Container(
          decoration: BoxDecoration(
            color: _isLightTheme ? Colors.white : null,
            border: Border(bottom: BorderSide(color: _borderColor, width: 0.7)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: const BoxConstraints(minHeight: 46, maxHeight: 64),
          alignment: Alignment.center,
          child: Row(
            children: [
              for (int i = 0; i < cells.length; i++) ...[
                SizedBox(width: widths[i].toDouble(), child: cells[i]),
                if (i != cells.length - 1) const SizedBox(width: gap),
              ],
            ],
          ),
        );

        Widget headerCell(String label, {bool alignRight = false}) => Text(
          label,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        );

        final dim = TextStyle(color: _textColor);
        final link = TextStyle(
          color: _textColor,
          decoration: TextDecoration.underline,
        );

        return RawScrollbar(
          controller: _h,
          thumbVisibility: true,
          trackVisibility: true,
          thumbColor: _isLightTheme
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFF415A77),
          trackColor: _isLightTheme ? _field : const Color(0xFF22304A),
          trackBorderColor: _bar,
          thickness: 10,
          radius: const Radius.circular(8),
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _h,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _bar,
                      border: Border(
                        bottom: BorderSide(color: _borderColor, width: 0.7),
                      ),
                    ),
                    child: rowOf([
                      headerCell('#'),
                      headerCell('Date'),
                      headerCell('Receipt'),
                      headerCell('Customer'),
                      headerCell('Items'),
                      headerCell('Transaction Type'),
                      headerCell('Amount Paid', alignRight: true),
                      headerCell('Discount', alignRight: true),
                    ]),
                  ),
                  Expanded(
                    child: RawScrollbar(
                      controller: _v,
                      thumbVisibility: true,
                      trackVisibility: true,
                      thumbColor: _isLightTheme
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFF415A77),
                      trackColor: _isLightTheme
                          ? _field
                          : const Color(0xFF22304A),
                      trackBorderColor: _bar,
                      thickness: 10,
                      radius: const Radius.circular(8),
                      scrollbarOrientation: ScrollbarOrientation.right,
                      child: ListView.builder(
                        controller: _v,
                        itemCount: paged.length,
                        itemBuilder: (context, i) {
                          final s = paged[i];
                          final formattedDate = DateFormat(
                            'yyyy-MM-dd – hh:mm a',
                          ).format(_resolveDate(s));
                          final amountRow = _d(s['amount']);
                          final amountPaidRow = _d(s['amountPaid']);
                          final discountRow = _d(s['discount']);
                          final receiptRow = (s['receipt'] ?? '').toString();
                          final itemMapRow = _resolveItems(s);
                          final itemLinesRow = parseItemLines(s['items']);

                          return rowOf([
                            Text('${_page * _rowsPerPage + i + 1}', style: dim),
                            Text(formattedDate, style: dim),
                            InkWell(
                              onTap: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: receiptRow),
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Receipt copied'),
                                  ),
                                );
                              },
                              child: Text(receiptRow, style: link),
                            ),
                            Text('${s['customer'] ?? ''}', style: dim),
                            InkWell(
                              onTap: () =>
                                  _showItemsPopup(receiptRow, itemLinesRow),
                              child: Text('${itemMapRow.length}', style: link),
                            ),
                            Text('${s['transMode'] ?? ''}', style: dim),
                            InkWell(
                              onTap: () => _showPaymentPopup(
                                receiptRow,
                                payments: parsePaymentLines(s['payments']),
                                paymentStatus: (s['paymentStatus'] ?? '')
                                    .toString(),
                                amountPaid: amountPaidRow,
                                totalAmount: amountRow,
                              ),
                              child: Text(
                                f2(amountPaidRow),
                                textAlign: TextAlign.right,
                                style: link,
                              ),
                            ),
                            Text(
                              f2(discountRow),
                              textAlign: TextAlign.right,
                              style: dim,
                            ),
                          ]);
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
    );
  }

  Widget _pager(int totalPages) {
    return Container(
      color: _bar,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              color: _textColor,
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${_page + 1}/$totalPages',
              style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
            ),
            IconButton(
              color: _textColor,
              onPressed: _page < totalPages - 1
                  ? () => setState(() => _page++)
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
        final allSales = provider.filteredSalesStaffTransactions();
        final displayedSales = _paymentFilter == null
            ? allSales
            : allSales
                  .where(
                    (t) => _matchesPayment(
                      Map<String, dynamic>.from(t),
                      _paymentFilter!,
                    ),
                  )
                  .toList();

        final totalPages = displayedSales.isEmpty
            ? 1
            : ((displayedSales.length - 1) ~/ _rowsPerPage) + 1;
        if (_page > totalPages - 1) _page = totalPages - 1;

        final pagedSales = displayedSales
            .skip(_page * _rowsPerPage)
            .take(_rowsPerPage)
            .map((t) => Map<String, dynamic>.from(t))
            .toList();

        final isSmall = MediaQuery.sizeOf(context).width < 600;

        return Scaffold(
          backgroundColor: _bg,
          appBar: _appBar(provider, displayedSales),
          bottomNavigationBar: _loading ? null : _pager(totalPages),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _filterBar(),
                ),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: _accent))
                      : displayedSales.isEmpty
                      ? Center(
                          child: Text(
                            'No transactions found',
                            style: TextStyle(color: _mutedTextColor),
                          ),
                        )
                      : isSmall
                      ? _mobileList(pagedSales)
                      : _desktopTable(pagedSales),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
