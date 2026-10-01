import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/salesmodel.dart';

enum SalesTodayView {
  overview,
  topProducts,
  payments,
  dailySummary,
  staffCollections,
  itemsSold,
}

class SalesTodayPage extends StatefulWidget {
  const SalesTodayPage({
    super.key,
    required this.sales,
    required this.view,
    required this.periodLabel,
    required this.branchLabel,
    this.staffFilter,
    this.paymentMethodFilter,
  });

  final List<SalesModel> sales;
  final SalesTodayView view;
  final String periodLabel;
  final String branchLabel;
  final String? staffFilter;
  final String? paymentMethodFilter;

  @override
  State<SalesTodayPage> createState() => _SalesTodayPageState();
}

class _SalesTodayPageState extends State<SalesTodayPage> {
  static const int _pageSize = 10;
  final Map<String, int> _pages = {};
  final Map<String, int> _pageSizes = {};
  final Map<String, int> _sortColumns = {};
  final Map<String, bool> _ascendingByTable = {};
  final Map<String, String> _searchQueries = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final _money = NumberFormat('#,##0.00');
  bool _isSearching = false;

  String get _activeTableKey => switch (widget.view) {
    SalesTodayView.topProducts => 'products',
    SalesTodayView.payments => 'payments',
    SalesTodayView.staffCollections => 'staff',
    SalesTodayView.itemsSold =>
      'items-${widget.staffFilter ?? 'all'}-${widget.paymentMethodFilter ?? 'all'}',
    _ => '',
  };
  bool get _hasSearchableTable => _activeTableKey.isNotEmpty;

  String get _title => switch (widget.view) {
    SalesTodayView.overview => 'Sales Today',
    SalesTodayView.topProducts => 'Top-selling Products',
    SalesTodayView.payments => 'Payment Breakdown',
    SalesTodayView.dailySummary => 'Sales Summary',
    SalesTodayView.staffCollections => 'Staff Collections',
    SalesTodayView.itemsSold =>
      widget.staffFilter == null && widget.paymentMethodFilter == null
          ? 'Items Sold'
          : [
              if (widget.staffFilter != null) widget.staffFilter!,
              if (widget.paymentMethodFilter != null)
                widget.paymentMethodFilter!,
              'Items Sold',
            ].join(' • '),
  };

  List<SalesModel> get _eligibleSales => widget.sales
      .where((sale) {
        final status = sale.paymentStatus.toLowerCase().trim();
        return !sale.isreturned &&
            status != 'cancelled' &&
            status != 'canceled';
      })
      .toList(growable: false);

  List<SalesModel> get _returnedSales => widget.sales
      .where((sale) {
        final status = sale.paymentStatus.toLowerCase().trim();
        return sale.isreturned && status != 'cancelled' && status != 'canceled';
      })
      .toList(growable: false);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  double get _netSales =>
      _eligibleSales.fold<double>(0, (sum, sale) => sum + _saleNet(sale));

  double get _returnedSalesAmount =>
      _returnedSales.fold<double>(0, (sum, sale) => sum + _saleNet(sale));

  double get _discounts => _eligibleSales.fold<double>(
    0,
    (sum, sale) => sum + (sale.discount ?? 0).abs(),
  );

  double get _collections => _eligibleSales.fold<double>(
    0,
    (sum, sale) => sum + _allocatedPayment(sale),
  );

  double get _outstanding => _eligibleSales.fold<double>(0, (sum, sale) {
    return sum +
        (_saleNet(sale) - _allocatedPayment(sale)).clamp(0, double.infinity);
  });

  double _saleNet(SalesModel sale) =>
      (sale.totalamount - (sale.discount ?? 0)).clamp(0, double.infinity);

  double _number(dynamic value) =>
      double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;

  DateTime? _saleDateTime(SalesModel sale) {
    final createdAt = sale.createdAt?.toDate();
    if (createdAt != null) return createdAt;
    final dateValue = sale.dateymd?.trim();
    if (dateValue == null || dateValue.isEmpty) return null;
    return DateTime.tryParse(dateValue);
  }

  bool _isNumericColumn(String key) => const {
    'quantity',
    'value',
    'amount',
    'Total',
    'Cash',
    'Hubtel',
    'Merchant MoMo',
    'Card',
    'Cheque',
    'Bank Transfer',
    'Credit',
    'Other',
  }.contains(key);

  bool _isCurrencyColumn(String key) =>
      _isNumericColumn(key) && key != 'quantity';

  double _allocatedPayment(SalesModel sale) {
    final paid = sale.amountPaid - sale.change;
    return paid.clamp(0, _saleNet(sale));
  }

  Map<String, double> _salePaymentBreakdown(SalesModel sale) {
    final methods = <String, double>{};
    final payments = sale.payments;
    if (payments != null && payments.isNotEmpty) {
      for (final entry in payments) {
        if (entry is! Map || entry['status'] == false) continue;
        final method = _methodLabel(
          (entry['method'] ?? entry['paymentMethod'] ?? entry['paymentmethod'])
                  ?.toString() ??
              '',
        );
        methods[method] = (methods[method] ?? 0) + _number(entry['amount']);
      }
    }

    if (methods.isEmpty) {
      final amount = _allocatedPayment(sale);
      if (amount > 0) methods[_methodLabel(sale.transMode)] = amount;
      return methods;
    }

    final paymentTotal = methods.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );
    final allocated = _allocatedPayment(sale);
    if (paymentTotal > 0 && allocated < paymentTotal) {
      final allocationRatio = allocated / paymentTotal;
      methods.updateAll((_, amount) => amount * allocationRatio);
    }
    return methods;
  }

  String _methodLabel(String method) {
    final normalized = method.toLowerCase().trim().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    if (normalized.contains('cash')) return 'Cash';
    if (normalized.contains('hubtel')) return 'Hubtel';
    if (normalized.contains('merchantmomo') ||
        normalized == 'momo' ||
        normalized.contains('mobilemoney')) {
      return 'Merchant MoMo';
    }
    if (normalized.contains('card') || normalized.contains('visa')) {
      return 'Card';
    }
    if (normalized.contains('cheque') || normalized.contains('check')) {
      return 'Cheque';
    }
    if (normalized.contains('banktransfer') ||
        normalized.contains('transfer')) {
      return 'Bank Transfer';
    }
    if (normalized.contains('bank')) return 'Bank Transfer';
    if (normalized.contains('credit')) return 'Credit';
    return normalized.isEmpty ? 'Other' : method.trim();
  }

  Map<String, double> _paymentTotals() {
    final totals = <String, double>{
      'Cash': 0,
      'Hubtel': 0,
      'Merchant MoMo': 0,
      'Card': 0,
      'Cheque': 0,
      'Bank Transfer': 0,
      'Credit': 0,
      'Other': 0,
    };
    for (final sale in _eligibleSales) {
      for (final entry in _salePaymentBreakdown(sale).entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
      if (sale.transMode.toLowerCase().trim() == 'credit') {
        totals['Credit'] =
            (totals['Credit'] ?? 0) +
            (_saleNet(sale) - _allocatedPayment(sale)).clamp(
              0,
              double.infinity,
            );
      }
    }
    totals.removeWhere((_, amount) => amount == 0);
    return totals;
  }

  List<Map<String, dynamic>> _productRows() {
    final products = <String, Map<String, dynamic>>{};
    for (final sale in _eligibleSales) {
      for (final rawItem in sale.items.values) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        final name = (item['item'] ?? item['name'] ?? 'Unnamed product')
            .toString()
            .trim();
        final key = (item['itemid']?.toString().trim().isNotEmpty == true)
            ? item['itemid'].toString()
            : name.toLowerCase();
        final row = products.putIfAbsent(
          key,
          () => {'name': name, 'quantity': 0.0, 'value': 0.0},
        );
        row['quantity'] =
            (row['quantity'] as double) +
            _number(item['totalpieces'] ?? item['quantity']);
        row['value'] = (row['value'] as double) + _number(item['totalamount']);
      }
    }
    final rows = products.values.toList()
      ..sort(
        (a, b) => (b['quantity'] as double).compareTo(a['quantity'] as double),
      );
    return rows;
  }

  double _saleCreditAmount(SalesModel sale) {
    if (sale.transMode.toLowerCase().trim() != 'credit') return 0;
    return (_saleNet(sale) - _allocatedPayment(sale)).clamp(0, double.infinity);
  }

  List<Map<String, dynamic>> _staffRows() {
    final staff = <String, Map<String, dynamic>>{};
    for (final sale in _eligibleSales) {
      final name = (sale.createdBy?.trim().isNotEmpty == true)
          ? sale.createdBy!.trim()
          : (sale.staff?.trim().isNotEmpty == true
                ? sale.staff!.trim()
                : 'Unknown');
      final row = staff.putIfAbsent(
        name,
        () => {
          'name': name,
          'Cash': 0.0,
          'Hubtel': 0.0,
          'Merchant MoMo': 0.0,
          'Card': 0.0,
          'Cheque': 0.0,
          'Bank Transfer': 0.0,
          'Credit': 0.0,
          'Other': 0.0,
          'Total': 0.0,
        },
      );
      for (final entry in _salePaymentBreakdown(sale).entries) {
        row[entry.key] = (row[entry.key] as double? ?? 0) + entry.value;
        row['Total'] = (row['Total'] as double) + entry.value;
      }
      final creditAmount = _saleCreditAmount(sale);
      row['Credit'] = (row['Credit'] as double? ?? 0) + creditAmount;
      row['Total'] = (row['Total'] as double) + creditAmount;
    }
    return staff.values.toList();
  }

  List<Map<String, dynamic>> _itemRows({
    String? staffFilter,
    String? paymentMethodFilter,
  }) {
    final rows = <Map<String, dynamic>>[];
    for (final sale in _eligibleSales) {
      final staff = (sale.createdBy?.trim().isNotEmpty == true)
          ? sale.createdBy!.trim()
          : (sale.staff?.trim().isNotEmpty == true
                ? sale.staff!.trim()
                : 'Unknown');
      if (staffFilter != null &&
          staff.toLowerCase() != staffFilter.toLowerCase()) {
        continue;
      }
      final selectedMethodAmount = paymentMethodFilter == null
          ? null
          : paymentMethodFilter == 'Credit'
          ? _saleCreditAmount(sale)
          : _salePaymentBreakdown(sale)[paymentMethodFilter] ?? 0;
      if (selectedMethodAmount != null && selectedMethodAmount <= 0) continue;
      final saleNet = _saleNet(sale);
      final valueRatio = selectedMethodAmount == null || saleNet <= 0
          ? 1.0
          : (selectedMethodAmount / saleNet).clamp(0, 1);
      final soldAt = _saleDateTime(sale);
      for (final rawItem in sale.items.values) {
        if (rawItem is! Map) continue;
        final item = Map<String, dynamic>.from(rawItem);
        rows.add({
          'staff': staff,
          'name': (item['item'] ?? item['name'] ?? 'Unnamed product')
              .toString(),
          'quantity': _number(item['totalpieces'] ?? item['quantity']),
          'value': _number(item['totalamount']) * valueRatio,
          'receipt': sale.receiptNumber,
          'soldAt': soldAt,
          'dateTime': soldAt == null
              ? 'N/A'
              : DateFormat('dd/MM/yyyy HH:mm').format(soldAt),
          'method': paymentMethodFilter ?? '',
        });
      }
    }
    return rows;
  }

  double _saleQuantity(SalesModel sale) =>
      sale.items.values.fold<double>(0, (total, rawItem) {
        if (rawItem is! Map) return total;
        final item = Map<String, dynamic>.from(rawItem);
        return total + _number(item['totalpieces'] ?? item['quantity']);
      });

  void _sortRows(int column, String tableKey) {
    if (_sortColumns[tableKey] == column) {
      _ascendingByTable[tableKey] = !(_ascendingByTable[tableKey] ?? false);
    } else {
      _sortColumns[tableKey] = column;
      _ascendingByTable[tableKey] = false;
    }
    setState(() => _pages[tableKey] = 0);
  }

  Widget _table(
    List<Map<String, dynamic>> rows,
    List<(String, String, bool)> columns,
    String tableKey, {
    void Function(Map<String, dynamic> row, String columnKey)? onCellTap,
  }) {
    final theme = Theme.of(context);
    final query = (_searchQueries[tableKey] ?? '').trim().toLowerCase();
    final filteredRows = query.isEmpty
        ? List<Map<String, dynamic>>.of(rows)
        : rows.where((row) {
            return row.values.any(
              (value) => value.toString().toLowerCase().contains(query),
            );
          }).toList();
    final sortColumn = _sortColumns[tableKey];
    if (sortColumn != null && sortColumn < columns.length) {
      final key = columns[sortColumn].$2;
      final ascending = _ascendingByTable[tableKey] ?? false;
      filteredRows.sort((a, b) {
        final left = a[key];
        final right = b[key];
        final result = left is num && right is num
            ? left.compareTo(right)
            : left.toString().toLowerCase().compareTo(
                right.toString().toLowerCase(),
              );
        return ascending ? result : -result;
      });
    }
    final pageSize = _pageSizes[tableKey] ?? _pageSize;
    final pageCount = filteredRows.isEmpty
        ? 1
        : (filteredRows.length / pageSize).ceil();
    final page = (_pages[tableKey] ?? 0).clamp(0, pageCount - 1).toInt();
    final shown = filteredRows.skip(page * pageSize).take(pageSize).toList();
    return Column(
      children: [
        Expanded(
          child: filteredRows.isEmpty
              ? Center(
                  child: Text(
                    rows.isEmpty
                        ? 'No sales data for this selection'
                        : 'No matching records',
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        sortColumnIndex: _sortColumns[tableKey],
                        sortAscending: _ascendingByTable[tableKey] ?? false,
                        horizontalMargin: 16,
                        columnSpacing: 16,
                        headingRowColor: WidgetStatePropertyAll(
                          theme.colorScheme.surfaceContainerHighest,
                        ),
                        columns: [
                          for (var i = 0; i < columns.length; i++)
                            DataColumn(
                              label: Text(columns[i].$1),
                              numeric: _isNumericColumn(columns[i].$2),
                              onSort: columns[i].$3
                                  ? (_, _) => _sortRows(i, tableKey)
                                  : null,
                            ),
                        ],
                        rows: [
                          for (final row in shown)
                            DataRow(
                              cells: [
                                for (final column in columns)
                                  DataCell(
                                    Text(
                                      column.$2 == 'quantity'
                                          ? _quantity(_number(row[column.$2]))
                                          : _isCurrencyColumn(column.$2)
                                          ? _money.format(
                                              _number(row[column.$2]),
                                            )
                                          : row[column.$2]?.toString() ?? '-',
                                      textAlign: _isNumericColumn(column.$2)
                                          ? TextAlign.right
                                          : TextAlign.left,
                                    ),
                                    onTap: onCellTap == null
                                        ? null
                                        : () => onCellTap(row, column.$2),
                                  ),
                              ],
                            ),
                          DataRow(
                            color: WidgetStatePropertyAll(
                              theme.colorScheme.surfaceContainerHighest,
                            ),
                            cells: [
                              for (
                                var index = 0;
                                index < columns.length;
                                index++
                              )
                                DataCell(
                                  Align(
                                    alignment:
                                        _isNumericColumn(columns[index].$2)
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Text(
                                      _isNumericColumn(columns[index].$2)
                                          ? columns[index].$2 == 'quantity'
                                                ? _quantity(
                                                    filteredRows.fold<double>(
                                                      0,
                                                      (sum, row) =>
                                                          sum +
                                                          _number(
                                                            row[columns[index]
                                                                .$2],
                                                          ),
                                                    ),
                                                  )
                                                : _money.format(
                                                    filteredRows.fold<double>(
                                                      0,
                                                      (sum, row) =>
                                                          sum +
                                                          _number(
                                                            row[columns[index]
                                                                .$2],
                                                          ),
                                                    ),
                                                  )
                                          : index == 0
                                          ? 'Total'
                                          : '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign:
                                          _isNumericColumn(columns[index].$2)
                                          ? TextAlign.right
                                          : TextAlign.left,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filteredRows.isEmpty
                        ? '0 of 0'
                        : '${page * pageSize + 1}-${((page + 1) * pageSize).clamp(0, filteredRows.length)} of ${filteredRows.length}',
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: pageSize,
                    underline: const SizedBox.shrink(),
                    items: const [10, 25, 50]
                        .map(
                          (size) => DropdownMenuItem(
                            value: size,
                            child: Text('$size'),
                          ),
                        )
                        .toList(),
                    onChanged: (size) {
                      if (size == null) return;
                      setState(() {
                        _pageSizes[tableKey] = size;
                        _pages[tableKey] = 0;
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: page == 0
                        ? null
                        : () => setState(() => _pages[tableKey] = page - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: page + 1 >= pageCount
                        ? null
                        : () => setState(() => _pages[tableKey] = page + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _quantity(double quantity) => quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(2);

  Widget _metric(String label, String value) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metrics() {
    final entries = <(String, String)>[
      ('Net Sales', 'GHS ${_money.format(_netSales)}'),
      ('Transactions', _eligibleSales.length.toString()),
      ('Return Sales', 'GHS ${_money.format(_returnedSalesAmount)}'),
      ('Collected', 'GHS ${_money.format(_collections)}'),
      ('Unpaid', 'GHS ${_money.format(_outstanding)}'),
      ('Discount', 'GHS ${_money.format(_discounts)}'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1050
            ? 5
            : constraints.maxWidth >= 650
            ? 3
            : 2;
        return GridView.count(
          crossAxisCount: count,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: constraints.maxWidth < 380 ? 1.65 : 1.9,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [for (final entry in entries) _metric(entry.$1, entry.$2)],
        );
      },
    );
  }

  void _openReport(SalesTodayView view) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalesTodayPage(
          sales: widget.sales,
          view: view,
          periodLabel: widget.periodLabel,
          branchLabel: widget.branchLabel,
        ),
      ),
    );
  }

  void _openStaffItems(String? staff, {String? method}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalesTodayPage(
          sales: widget.sales,
          view: SalesTodayView.itemsSold,
          periodLabel: widget.periodLabel,
          branchLabel: widget.branchLabel,
          staffFilter: staff,
          paymentMethodFilter: method,
        ),
      ),
    );
  }

  Widget _overviewSectionHeading(String title, SalesTodayView destination) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        TextButton(
          onPressed: () => _openReport(destination),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.secondary,
          ),
          child: const Text('View more'),
        ),
      ],
    );
  }

  Widget _overviewContent() {
    final bestSales = _eligibleSales.toList()
      ..sort((a, b) => _saleQuantity(b).compareTo(_saleQuantity(a)));
    final payments = _paymentTotals().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metrics(),
        const SizedBox(height: 16),
        _overviewSectionHeading('Payment breakdown', SalesTodayView.payments),
        for (final item in payments.take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.key),
            trailing: Text('GHS ${_money.format(item.value)}'),
          ),
        const SizedBox(height: 12),
        _overviewSectionHeading(
          'Top-selling products',
          SalesTodayView.topProducts,
        ),
        for (final product in _productRows().take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(product['name'].toString()),
            subtitle: Text('${_quantity(product['quantity'] as double)} units'),
            trailing: Text('GHS ${_money.format(product['value'])}'),
          ),
        const SizedBox(height: 12),
        _overviewSectionHeading(
          'Staff collections',
          SalesTodayView.staffCollections,
        ),
        for (final staff in _staffRows().take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(staff['name'].toString()),
            trailing: Text('GHS ${_money.format(staff['Total'])}'),
            onTap: () => _openStaffItems(staff['name'].toString()),
          ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        Text(
          'Best sales by quantity',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final sale in bestSales.take(5))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Receipt #${sale.receiptNumber}'),
            subtitle: Text(
              sale.customerName?.trim().isNotEmpty == true
                  ? sale.customerName!
                  : 'Walk-in',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_quantity(_saleQuantity(sale))} items'),
                Text('GHS ${_money.format(_saleNet(sale))}'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dailySummaryContent() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _metrics(),
    ],
  );

  Widget _content() {
    switch (widget.view) {
      case SalesTodayView.overview:
        return _overviewContent();
      case SalesTodayView.dailySummary:
        return _dailySummaryContent();
      case SalesTodayView.topProducts:
        return _table(_productRows(), const [
          ('Product', 'name', true),
          ('Quantity', 'quantity', true),
          ('Sales value (GHS)', 'value', true),
        ], 'products');
      case SalesTodayView.payments:
        final rows = _paymentTotals().entries
            .map((e) => {'method': e.key, 'amount': e.value})
            .toList();
        return _table(
          rows,
          const [
            ('Payment method', 'method', true),
            ('Amount received (GHS)', 'amount', true),
          ],
          'payments',
          onCellTap: (row, key) {
            if ((key == 'method' || key == 'amount') &&
                _number(row['amount']) > 0) {
              _openStaffItems(null, method: row['method'].toString());
            }
          },
        );
      case SalesTodayView.staffCollections:
        final staff = _staffRows();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select a staff name to see all items, or a collection amount to see items paid by that method.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Expanded(
              child: _table(
                staff,
                const [
                  ('Staff', 'name', true),
                  ('Cash (GHS)', 'Cash', true),
                  ('Hubtel (GHS)', 'Hubtel', true),
                  ('Merchant MoMo (GHS)', 'Merchant MoMo', true),
                  ('Bank Transfer (GHS)', 'Bank Transfer', true),
                  ('Card (GHS)', 'Card', true),
                  ('Cheque (GHS)', 'Cheque', true),
                  ('Credit (GHS)', 'Credit', true),
                  ('Other (GHS)', 'Other', true),
                  ('Total (GHS)', 'Total', true),
                ],
                'staff',
                onCellTap: (row, key) {
                  final staffName = row['name'].toString();
                  if (key == 'name' || key == 'Total') {
                    _openStaffItems(staffName);
                  } else if (_number(row[key]) > 0) {
                    _openStaffItems(staffName, method: key);
                  }
                },
              ),
            ),
          ],
        );
      case SalesTodayView.itemsSold:
        return _table(
          _itemRows(
            staffFilter: widget.staffFilter,
            paymentMethodFilter: widget.paymentMethodFilter,
          ),
          const [
            ('Staff', 'staff', true),
            ('Item', 'name', true),
            ('Quantity', 'quantity', true),
            ('Sales value (GHS)', 'value', true),
            ('Date & Time', 'dateTime', true),
            ('Receipt', 'receipt', true),
          ],
          'items-${widget.staffFilter ?? 'all'}-${widget.paymentMethodFilter ?? 'all'}',
        );
    }
  }

  void _openSearch() {
    setState(() {
      _isSearching = true;
      _searchController.text = _searchQueries[_activeTableKey] ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchQueries[_activeTableKey] = '';
      _pages[_activeTableKey] = 0;
    });
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final showCollectionNote =
        widget.view == SalesTodayView.overview ||
        widget.view == SalesTodayView.dailySummary ||
        widget.view == SalesTodayView.payments ||
        widget.view == SalesTodayView.staffCollections;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _isSearching ? kToolbarHeight : (isCompact ? 82 : 72),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search $_title...',
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
                onChanged: (query) => setState(() {
                  _searchQueries[_activeTableKey] = query;
                  _pages[_activeTableKey] = 0;
                }),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${widget.branchLabel} • ${widget.periodLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: isCompact ? 10 : 11,
                    ),
                  ),
                  if (showCollectionNote)
                    Text(
                      'Figures use the current selected date,brnch and search filters.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isCompact ? 9 : 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
        actions: [
          if (_hasSearchableTable)
            IconButton(
              tooltip: _isSearching ? 'Close search' : 'Search',
              onPressed: _isSearching ? _closeSearch : _openSearch,
              icon: Icon(_isSearching ? Icons.close : Icons.search),
            ),
        ],
      ),
      body: Padding(padding: const EdgeInsets.all(16), child: _content()),
    );
  }
}
