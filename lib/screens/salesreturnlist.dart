import 'dart:math' show max;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/appModuls.dart';
import 'package:kologsoft/models/salesreturnmodel.dart';
import 'package:kologsoft/screens/salesreturn.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import '../widgets/offline_indicator.dart';
import '../widgets/salesreturnpdf.dart';

const int _pageSize = 10;

final NumberFormat _money = NumberFormat('#,##0.00');
final NumberFormat _qty = NumberFormat('#,##0.##');
final NumberFormat _currency = NumberFormat.currency(
  symbol: 'GH₵',
  decimalDigits: 2,
);
final DateFormat _day = DateFormat('dd MMM yyyy');
final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');

enum _SalesReturnReport {
  registerReturn('Register return', Icons.add_circle_outline),
  overview('Return overview', Icons.dashboard_outlined),
  reasons('Returns by reason', Icons.report_problem_outlined),
  suppliers('Returns by supplier', Icons.local_shipping_outlined),
  branches('Returns by branch', Icons.store_outlined),
  customers('Returns by customer', Icons.person_search_outlined),
  staff('Returns by staff', Icons.person_outline),
  items('Returns by item', Icons.inventory_2_outlined);

  const _SalesReturnReport(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum _ReportSort {
  amount('Sort by return value'),
  quantity('Sort by quantity'),
  transactions('Sort by transactions'),
  name('Sort by name');

  const _ReportSort(this.label);
  final String label;
}

class _TableColumn {
  const _TableColumn(
      this.label, {
        this.strong = false,
        this.sortIndex,
        this.extra = 0,
        this.minContent = 0,
      });

  final String label;
  final bool strong;
  final int? sortIndex;
  final double extra;
  final double minContent;
}

class _Bucket {
  double amount = 0;
  double units = 0;
  final Set<String> returnIds = {};
}

String _text(dynamic value) => value?.toString().trim() ?? '';

String _firstText(Map<String, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final value = _text(item[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

double _num(dynamic value) =>
    double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;

List<Map<String, dynamic>> _items(salereturn record) => record.items.values
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList();

double _itemAmount(Map<String, dynamic> item) =>
    _num(item['returned_totalamount']);

double _itemUnits(Map<String, dynamic> item) {
  final pieces = double.tryParse(_text(item['returned_totalpieces']));
  return pieces ?? _num(item['returned_quantity']);
}

String _itemName(Map<String, dynamic> item) {
  final name = _text(item['returned_item']);
  return name.isEmpty ? 'Item not recorded' : name;
}

String _itemReason(Map<String, dynamic> item) {
  final reason = _firstText(item, ['returned_condition', 'returned_reason']);
  return reason.isEmpty ? 'Unspecified' : reason;
}

String _itemSupplier(Map<String, dynamic> item) {
  final supplier = _firstText(item, [
    'returned_supplier',
    'returned_suppliername',
    'supplier',
    'suppliername',
  ]);
  return supplier.isEmpty ? 'Unspecified' : supplier;
}

double _value(salereturn record) =>
    _items(record).fold(0.0, (sum, item) => sum + _itemAmount(item));

double _units(salereturn record) =>
    _items(record).fold(0.0, (sum, item) => sum + _itemUnits(item));

String _reason(salereturn record) {
  final reasons = _items(record)
      .map((i) => _firstText(i, ['returned_condition', 'returned_reason']))
      .where((r) => r.isNotEmpty)
      .toSet();
  return reasons.isEmpty ? 'Unspecified' : reasons.join(', ');
}

String _customer(salereturn record) {
  for (final item in _items(record)) {
    final name = _firstText(item, [
      'returned_customer',
      'returned_customername',
      'customer',
      'customername',
    ]);
    if (name.isNotEmpty) return name;
  }
  return 'Cash customer';
}

String _status(salereturn record) {
  for (final item in _items(record)) {
    final status = _firstText(item, [
      'refund_status',
      'returned_refundstatus',
      'returned_status',
      'status',
    ]);
    if (status.isNotEmpty) {
      return status
          .split(RegExp(r'[_\s]+'))
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
          .join(' ');
    }
  }
  return 'Returned';
}

int _pageCount(int length) => length == 0 ? 1 : (length - 1) ~/ _pageSize + 1;

List<T> _pageOf<T>(List<T> list, int page) =>
    list.skip(page * _pageSize).take(_pageSize).toList();

class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.page,
    required this.total,
    required this.onChanged,
  });

  final int page;
  final int total;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pages = _pageCount(total);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            const Spacer(),
            IconButton(
              tooltip: 'Previous page',
              onPressed: page > 0 ? () => onChanged(page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${page + 1}/$pages',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: page < pages - 1 ? () => onChanged(page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 72),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.records);

  final List<salereturn> records;

  @override
  Widget build(BuildContext context) {
    final totalValue = records.fold(0.0, (s, r) => s + _value(r));
    final totalUnits = records.fold(0.0, (s, r) => s + _units(r));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '${records.length} transactions  ·  ${_qty.format(totalUnits)} units'
              '  ·  ${_currency.format(totalValue)}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class SalesreturnListPage extends StatefulWidget {
  const SalesreturnListPage({super.key});

  @override
  State<SalesreturnListPage> createState() => _SalesreturnListPageState();
}

class _SalesreturnListPageState extends State<SalesreturnListPage> {
  static const List<_TableColumn> _columns = [
    _TableColumn('#'),
    _TableColumn('Customer', sortIndex: 1),
    _TableColumn('Receipt ID', sortIndex: 2),
    _TableColumn('Date & time', sortIndex: 3),
    _TableColumn('Return value (GH₵)', strong: true, sortIndex: 4),
    _TableColumn('Units', sortIndex: 7),
    _TableColumn('Reason', sortIndex: 5),
    _TableColumn('Status', sortIndex: 6, extra: 22),
    _TableColumn('Actions', minContent: 48),
  ];

  ColorScheme get _c => Theme.of(context).colorScheme;
  Color get _muted => _c.onSurfaceVariant;
  Color get _surface => _c.surfaceContainerLow;
  Color get _header => _c.surfaceContainer;
  Color get _border => _c.outlineVariant;

  DateTimeRange? _range;
  String? _branch;
  bool _loading = true;
  bool _searching = false;
  int _page = 0;
  int _sortColumn = 3;
  bool _ascending = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final provider = context.read<Datafeed>();
      try {
        await provider.fetchBranches();
        final canSeeAll = provider.isAdminLevel || provider.canSelectBranch;
        _branch = canSeeAll ? null : provider.branchid;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        _range = DateTimeRange(start: today, end: today);
        await _reload(provider);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _reload(Datafeed provider) => provider.fetchsalesreturn(
    selectedDate: _range,
    selectedBranch: _branch,
  );

  Future<void> _setRange(Datafeed provider, DateTimeRange? range) {
    setState(() {
      _range = range;
      _page = 0;
    });
    return _reload(provider);
  }

  Future<void> _setBranch(Datafeed provider, String? id) {
    setState(() {
      _branch = id;
      _page = 0;
    });
    return _reload(provider);
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback(
          (_) => _searchFocus.requestFocus(),
    );
  }

  void _closeSearch(Datafeed provider) {
    setState(() {
      _searching = false;
      _searchController.clear();
    });
    provider.updateSearch('');
  }

  void _search(Datafeed provider, String query) {
    setState(() => _page = 0);
    provider.updateSearch(query);
  }

  List<dynamic> _branches(Datafeed provider) {
    String normalized(String? type) =>
        (type ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    return {
      for (final b in provider.branches)
        if (normalized(b.branchtype) != 'warehouse') b.id: b,
    }.values.where((b) => b.id != null && b.id!.isNotEmpty).toList();
  }

  String _branchLabel(Datafeed provider) {
    for (final b in _branches(provider)) {
      if (b.id == _branch) return b.branchname;
    }
    return 'All Branches';
  }

  Future<void> _pickRange(Datafeed provider) async {
    final selection = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (selection == null || !mounted) return;
    await _setRange(provider, selection);
  }

  Future<void> _pickBranch(Datafeed provider) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surface,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final b in [null, ..._branches(provider)])
              ListTile(
                title: Text(b == null ? 'All Branches' : b.branchname),
                trailing: (b?.id) == _branch
                    ? Icon(Icons.check, color: _c.primary)
                    : null,
                onTap: () => Navigator.pop(sheet, b?.id ?? ''),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await _setBranch(provider, selected.isEmpty ? null : selected);
  }

  Future<void> _registerReturn(Datafeed provider) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Salesreturn()),
    );
    if (mounted) await _reload(provider);
  }

  Future<void> _openReport(
      List<salereturn> records,
      _SalesReturnReport report,
      Datafeed provider,
      ) async {
    final Widget page;
    switch (report) {
      case _SalesReturnReport.registerReturn:
        return _registerReturn(provider);
      case _SalesReturnReport.overview:
        final recent = List<salereturn>.of(records)
          ..sort((a, b) => b.createdat.compareTo(a.createdat));
        page = _RecordListPage(title: report.label, records: recent);
      default:
        page = _GroupedReportPage(records: records, report: report);
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _sortBy(int column) {
    setState(() {
      _ascending = _sortColumn == column ? !_ascending : true;
      _sortColumn = column;
      _page = 0;
    });
  }

  List<salereturn> _sorted(List<salereturn> records) {
    final result = List<salereturn>.of(records);
    result.sort((a, b) {
      final order = switch (_sortColumn) {
        1 => _customer(a).compareTo(_customer(b)),
        2 => a.receiptid.compareTo(b.receiptid),
        4 => _value(a).compareTo(_value(b)),
        5 => _reason(a).compareTo(_reason(b)),
        6 => _status(a).compareTo(_status(b)),
        7 => _units(a).compareTo(_units(b)),
        _ => a.createdat.compareTo(b.createdat),
      };
      return _ascending ? order : -order;
    });
    return result;
  }

  Future<void> _print(salereturn record) async {
    final items = <String, dynamic>{};
    var transmode = '';
    Map<String, dynamic>.from(record.items).forEach((key, value) {
      if (value is! Map) return;
      final mode = _text(value['returned_transMode']);
      if (transmode.isEmpty) transmode = mode;
      items[key] = value.map(
            (k, v) => MapEntry(
          k.toString().startsWith('returned_')
              ? k.toString().substring('returned_'.length)
              : k,
          v,
        ),
      );
    });

    await SalesReturnPdf.generate(
      heading: 'RETURN SALES',
      header: {
        'company': record.companyid,
        'branchname': record.branchname,
        'createdby': record.createdby,
        'createdat': record.createdat,
        'receiptid': record.receiptid,
        'transmode': transmode,
      },
      itemsMap: items,
    );
  }

  Future<void> _delete(salereturn record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete return ${record.receiptid}?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _c.error,
              foregroundColor: _c.onError,
            ),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<Datafeed>().deletesalesreturn(record.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Return ${record.receiptid} deleted')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to delete return')),
      );
    }
  }

  Future<void> _edit(salereturn record, Datafeed provider) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Salesreturn(salesitem: record)),
    );
    if (mounted) await _reload(provider);
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _c.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _c.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _syncStatusBadge(salereturn record) {
    if (!record.pendingSync) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Waiting to sync',
        style: TextStyle(
          color: Colors.deepOrange,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actions(salereturn record, Datafeed provider) {
    return PopupMenuButton<String>(
      tooltip: 'More return actions',
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, color: _muted),
      onSelected: (action) async {
        switch (action) {
          case 'view':
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _DetailsPage(record: record),
              ),
            );
          case 'print':
            try {
              await _print(record);
            } catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not print return: $error')),
              );
            }
          case 'edit':
            await _edit(record, provider);
          case 'delete':
            await _delete(record);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'view', child: Text('View return items')),
        const PopupMenuItem(value: 'print', child: Text('Print')),
      //  if (provider.canEdit(AppModules.sales))       const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (provider.canDelete(AppModules.sales))
          PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: _c.error)),
          ),
      ],
    );
  }

  TextStyle _cellStyle(
      double fontSize, {
        bool strong = false,
        bool header = false,
      }) {
    return TextStyle(
      fontSize: fontSize,
      color: strong && !header ? _c.onSurface : _muted,
      fontWeight: strong || header ? FontWeight.w600 : FontWeight.w400,
    );
  }

  double _measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  List<String> _rowTexts(salereturn r, int number) => [
    '$number',
    _customer(r),
    r.receiptid,
    _dateTime.format(r.createdat.toDate()),
    _money.format(_value(r)),
    _qty.format(_units(r)),
    _reason(r),
    _status(r),
    '',
  ];

  List<double> _columnWidths(
      double available,
      double gutter,
      double fontSize,
      List<List<String>> rows,
      ) {
    final natural = <double>[];
    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      var content =
          _measure(column.label, _cellStyle(fontSize, header: true)) +
              (column.sortIndex == null ? 0 : 18);
      final style = _cellStyle(fontSize, strong: column.strong);
      for (final row in rows) {
        content = max(content, _measure(row[i], style) + column.extra);
      }
      natural.add(max(content, column.minContent) + gutter);
    }

    final total = natural.fold(0.0, (sum, w) => sum + w);
    if (total >= available) {
      return [for (final w in natural) w * available / total];
    }
    final spare = (available - total) / natural.length;
    return [for (final w in natural) w + spare];
  }

  Widget _tableRow(
      List<Widget> cells,
      List<double> widths,
      double gutter, {
        double vPad = 8,
      }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16 - gutter / 2,
        vertical: vPad,
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width: widths[i],
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter / 2),
                child: cells[i],
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerCell(_TableColumn column, double fontSize) {
    final selected =
        column.sortIndex != null && _sortColumn == column.sortIndex;
    final arrow = selected
        ? Icon(
      _ascending ? Icons.arrow_upward : Icons.arrow_downward,
      size: 14,
      color: _muted,
    )
        : null;
    final label = Flexible(
      child: Text(
        column.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _cellStyle(fontSize, header: true),
      ),
    );
    return InkWell(
      onTap: column.sortIndex == null ? null : () => _sortBy(column.sortIndex!),
      child: Row(children: [label, if (arrow != null) arrow]),
    );
  }

  Widget _bodyText(String text, double fontSize, _TableColumn column) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _cellStyle(fontSize, strong: column.strong),
    );
  }

  Widget _desktopTable(
      List<salereturn> records,
      int page,
      Datafeed provider,
      ) {
    final rows = _pageOf(_sorted(records), page);
    final footer = [
      '',
      'Total',
      '',
      '',
      _money.format(records.fold(0.0, (s, r) => s + _value(r))),
      _qty.format(records.fold(0.0, (s, r) => s + _units(r))),
      '',
      '',
      '',
    ];

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gutter = (constraints.maxWidth * 0.012).clamp(8.0, 20.0);
                final fontSize = constraints.maxWidth < 1000 ? 12.0 : 13.0;
                final widths = _columnWidths(
                  constraints.maxWidth - 2 * (16 - gutter / 2) - 1,
                  gutter,
                  fontSize,
                  [
                    for (var i = 0; i < records.length; i++)
                      _rowTexts(records[i], i + 1),
                    footer,
                  ],
                );
                final divider = BorderSide(color: _border);

                return Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _header,
                        border: Border(bottom: divider),
                      ),
                      child: _tableRow(
                        [for (final c in _columns) _headerCell(c, fontSize)],
                        widths,
                        gutter,
                        vPad: 12,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final record = rows[i];
                          final texts = _rowTexts(
                            record,
                            page * _pageSize + i + 1,
                          );
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(bottom: divider),
                            ),
                            child: _tableRow(
                              [
                                for (var c = 0; c < _columns.length; c++)
                                  switch (c) {
                                    7 => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _statusBadge(texts[c]),
                                            _syncStatusBadge(record),
                                          ],
                                        ),
                                      ),
                                    8 => Align(
                                      alignment: Alignment.centerLeft,
                                      child: _actions(record, provider),
                                    ),
                                    _ => _bodyText(
                                      texts[c],
                                      fontSize,
                                      _columns[c],
                                    ),
                                  },
                              ],
                              widths,
                              gutter,
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: _header,
                        border: Border(top: divider),
                      ),
                      child: _tableRow(
                        [
                          for (var c = 0; c < _columns.length; c++)
                            footer[c].isEmpty
                                ? const SizedBox.shrink()
                                : _bodyText(
                              footer[c],
                              fontSize,
                              const _TableColumn('', strong: true),
                            ),
                        ],
                        widths,
                        gutter,
                        vPad: 10,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: _border),
          _PageBar(
            page: page,
            total: records.length,
            onChanged: (p) => setState(() => _page = p),
          ),
        ],
      ),
    );
  }

  Widget _metric(double width, IconData icon, String label, String value) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _c.surface,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _c.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _c.onPrimaryContainer, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _c.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileSummary(List<salereturn> records) {
    final metrics = [
      (
      Icons.payments_outlined,
      'Return value',
      _currency.format(records.fold(0.0, (s, r) => s + _value(r))),
      ),
      (
      Icons.receipt_long_outlined,
      'Return transactions',
      '${records.length}',
      ),
      (
      Icons.inventory_2_outlined,
      'Units returned',
      _qty.format(records.fold(0.0, (s, r) => s + _units(r))),
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 520 ? 2 : 1;
          const gap = 10.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final m in metrics) _metric(width, m.$1, m.$2, m.$3)],
          );
        },
      ),
    );
  }

  Widget _mobileCard(salereturn record, int index, Datafeed provider) {
    return Card(
      margin: EdgeInsets.zero,
      color: _surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _DetailsPage(record: record)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${index + 1}. ${record.receiptid}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _currency.format(_value(record)),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  _actions(record, provider),
                ],
              ),
              const SizedBox(height: 8),
              Text(_customer(record), style: TextStyle(color: _muted)),
              const SizedBox(height: 8),
              Text(
                '${record.createdby}  ·  ${_dateTime.format(record.createdat.toDate())}',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _reason(record),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statusBadge(_status(record)),
                      _syncStatusBadge(record),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(
      Datafeed provider,
      List<salereturn> records,
      bool compact,
      ) {
    final range = _range;
    var subtitle = 'Return activity';
    if (range != null) {
      subtitle += ' - ${_day.format(range.start)}';
      if (range.start != range.end) subtitle += ' - ${_day.format(range.end)}';
    }

    return AppBar(
      backgroundColor: _surface,
      foregroundColor: _c.onSurface,
      automaticallyImplyLeading: false,
      titleSpacing: _searching ? 4 : 16,
      toolbarHeight: _searching
          ? kToolbarHeight
          : compact
          ? 108
          : 96,
      leading: IconButton(
        tooltip: _searching ? 'Close search' : 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: _searching
            ? () => _closeSearch(provider)
            : () => Navigator.maybePop(context),
      ),
      title: _searching
          ? TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        style: const TextStyle(fontSize: 14),
        cursorColor: _c.secondary,
        decoration: InputDecoration(
          hintText: 'Search customer, receipt, item or reason',
          hintStyle: TextStyle(color: _muted, fontSize: 13),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (query) => _search(provider, query),
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales Returns',
            style: TextStyle(
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
      actions: [
        if (_searching) ...[
          if (_searchController.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _search(provider, '');
              },
            ),
        ] else ...[
          if (provider.isAdminLevel || provider.canSelectBranch)
            compact
                ? IconButton(
              tooltip: _branchLabel(provider),
              icon: const Icon(Icons.store_outlined),
              onPressed: () => _pickBranch(provider),
            )
                : _BranchDropdown(
              branches: _branches(provider),
              selected: _branch,
              onChanged: (id) => _setBranch(provider, id),
            ),
          PopupMenuButton<_SalesReturnReport>(
            tooltip: 'Return reports',
            icon: const Icon(Icons.analytics_outlined),
            onSelected: (report) => _openReport(records, report, provider),
            itemBuilder: (_) => [
              for (final report in _SalesReturnReport.values)
                PopupMenuItem(
                  value: report,
                  child: ListTile(
                    leading: Icon(report.icon),
                    title: Text(report.label),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Search returns',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
          compact
              ? IconButton(
            tooltip: 'Filter dates',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () => _pickRange(provider),
          )
              : ReusableDatePickerWidget(
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.calendar_today_outlined, size: 20),
            ),
            onDateSelected: (range) => _setRange(provider, range),
          ),
        ],
        if (provider.isAdminLevel)
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false),
          ),
      ],
    );
  }

  Widget _body(List<salereturn> records, Datafeed provider, bool desktop) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_return_outlined, color: _muted, size: 42),
            const SizedBox(height: 10),
            Text(
              provider.salesreturn.isEmpty
                  ? 'No returns for the selected filters'
                  : 'No matching returns found',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      );
    }

    final page = _page.clamp(0, _pageCount(records.length) - 1);
    if (desktop) return _desktopTable(records, page, provider);

    final rows = _pageOf(_sorted(records), page);
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _mobileCard(rows[i], page * _pageSize + i, provider),
          ),
        ),
        _PageBar(
          page: page,
          total: records.length,
          onChanged: (p) => setState(() => _page = p),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;
    final compact = width < 620;

    return Consumer<Datafeed>(
      builder: (context, provider, _) {
        final records = provider.filtersalesreturn();
        return Scaffold(
          appBar: _appBar(provider, records, compact),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Register return',
            onPressed: () => _registerReturn(provider),
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              const OfflineIndicator(),
              Expanded(
                child: _loading || provider.isloadingsalesreturn
                    ? const Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: EdgeInsets.all(compact ? 12 : 20),
                        child: Column(
                          children: [
                            if (!desktop) ...[
                              _mobileSummary(records),
                              const SizedBox(height: 16),
                            ],
                            Expanded(child: _body(records, provider, desktop)),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({
    required this.branches,
    required this.selected,
    required this.onChanged,
  });

  final List<dynamic> branches;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = branches.any((b) => b.id == selected) ? selected : null;
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          isExpanded: true,
          style: TextStyle(color: colors.onSurface, fontSize: 12),
          dropdownColor: colors.surfaceContainerLow,
          icon: Icon(Icons.expand_more, color: colors.onSurfaceVariant, size: 16),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Branches'),
            ),
            for (final b in branches)
              DropdownMenuItem<String?>(
                value: b.id,
                child: Text(b.branchname, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _GroupedReportPage extends StatefulWidget {
  const _GroupedReportPage({required this.records, required this.report});

  final List<salereturn> records;
  final _SalesReturnReport report;

  @override
  State<_GroupedReportPage> createState() => _GroupedReportPageState();
}

class _GroupedReportPageState extends State<_GroupedReportPage> {
  _ReportSort _sort = _ReportSort.amount;
  bool _descending = true;
  int _page = 0;

  Iterable<(String, Map<String, dynamic>?)> _entries(salereturn record) sync* {
    String orElse(String value, String fallback) =>
        value.trim().isEmpty ? fallback : value;

    switch (widget.report) {
      case _SalesReturnReport.reasons:
        for (final item in _items(record)) {
          yield (_itemReason(item), item);
        }
      case _SalesReturnReport.suppliers:
        for (final item in _items(record)) {
          yield (_itemSupplier(item), item);
        }
      case _SalesReturnReport.items:
        for (final item in _items(record)) {
          yield (_itemName(item), item);
        }
      case _SalesReturnReport.branches:
        yield (orElse(record.branchname, 'Branch not recorded'), null);
      case _SalesReturnReport.staff:
        yield (orElse(record.createdby, 'Staff not recorded'), null);
      case _SalesReturnReport.customers:
        yield (_customer(record), null);
      default:
        break;
    }
  }

  List<MapEntry<String, _Bucket>> _rows() {
    final groups = <String, _Bucket>{};
    for (final record in widget.records) {
      for (final (label, item) in _entries(record)) {
        final bucket = groups.putIfAbsent(label, _Bucket.new);
        bucket.returnIds.add(record.id);
        bucket.amount += item == null ? _value(record) : _itemAmount(item);
        bucket.units += item == null ? _units(record) : _itemUnits(item);
      }
    }
    final rows = groups.entries.toList();
    rows.sort((a, b) {
      final order = switch (_sort) {
        _ReportSort.amount => a.value.amount.compareTo(b.value.amount),
        _ReportSort.quantity => a.value.units.compareTo(b.value.units),
        _ReportSort.transactions => a.value.returnIds.length.compareTo(
          b.value.returnIds.length,
        ),
        _ReportSort.name => a.key.toLowerCase().compareTo(b.key.toLowerCase()),
      };
      return _descending ? -order : order;
    });
    return rows;
  }

  void _open(String label, _Bucket bucket) {
    final records = widget.records
        .where((r) => bucket.returnIds.contains(r.id))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RecordListPage(
          title: label,
          records: records,
          report: widget.report,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = _rows();
    final page = _page.clamp(0, _pageCount(rows.length) - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.report.label),
        actions: [
          PopupMenuButton<_ReportSort>(
            tooltip: 'Sort report',
            icon: const Icon(Icons.sort),
            onSelected: (sort) => setState(() {
              _descending = _sort == sort ? !_descending : true;
              _sort = sort;
              _page = 0;
            }),
            itemBuilder: (_) => [
              for (final sort in _ReportSort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _SummaryLine(widget.records),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No return data for this report.'))
                : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in _pageOf(rows, page))
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colors.secondaryContainer,
                        foregroundColor: colors.onSecondaryContainer,
                        child: Icon(widget.report.icon),
                      ),
                      title: Text(entry.key),
                      subtitle: Text(
                        '${entry.value.returnIds.length} transactions · '
                            '${_qty.format(entry.value.units)} units',
                      ),
                      trailing: Text(
                        _currency.format(entry.value.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _open(entry.key, entry.value),
                    ),
                  ),
              ],
            ),
          ),
          if (rows.isNotEmpty)
            _PageBar(
              page: page,
              total: rows.length,
              onChanged: (p) => setState(() => _page = p),
            ),
        ],
      ),
    );
  }
}

class _RecordListPage extends StatefulWidget {
  const _RecordListPage({
    required this.title,
    required this.records,
    this.report,
  });

  final String title;
  final List<salereturn> records;
  final _SalesReturnReport? report;

  @override
  State<_RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends State<_RecordListPage> {
  int _page = 0;

  bool _matches(Map<String, dynamic> item) => switch (widget.report) {
    _SalesReturnReport.items => _itemName(item) == widget.title,
    _SalesReturnReport.reasons => _itemReason(item) == widget.title,
    _SalesReturnReport.suppliers => _itemSupplier(item) == widget.title,
    _ => true,
  };

  Widget _tile(salereturn record) {
    final names = _items(record)
        .where(_matches)
        .map(_itemName)
        .toSet()
        .join(', ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.info_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(record.receiptid),
        subtitle: Text(
          names.isEmpty ? _customer(record) : '${_customer(record)}\n$names',
        ),
        isThreeLine: names.isNotEmpty,
        trailing: Text(
          _currency.format(_value(record)),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _DetailsPage(record: record)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _page.clamp(0, _pageCount(widget.records.length) - 1);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          _SummaryLine(widget.records),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final r in _pageOf(widget.records, page)) _tile(r)],
            ),
          ),
          if (widget.records.isNotEmpty)
            _PageBar(
              page: page,
              total: widget.records.length,
              onChanged: (p) => setState(() => _page = p),
            ),
        ],
      ),
    );
  }
}

class _DetailsPage extends StatelessWidget {
  const _DetailsPage({required this.record});

  final salereturn record;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = _items(record);

    return Scaffold(
      appBar: AppBar(title: Text(record.receiptid)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Returned items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'No returned item details were saved.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          for (final item in items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _itemName(item),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          _currency.format(_itemAmount(item)),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Quantity: ${_qty.format(_itemUnits(item))} '
                              '${_text(item['returned_mode'])}',
                        ),
                        Text(
                          'Unit price: ${_currency.format(_num(item['returned_price']))}',
                        ),
                      ],
                    ),
                    if (_itemReason(item) != 'Unspecified') ...[
                      const SizedBox(height: 8),
                      Text('Reason: ${_itemReason(item)}'),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}