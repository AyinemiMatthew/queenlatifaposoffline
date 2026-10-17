import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GeneralLedgerDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> transactions;
  final bool accountStatement;
  final Future<void> Function() onPrint;
  final void Function(Map<String, dynamic> transaction)? onTransactionTap;

  const GeneralLedgerDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.transactions,
    required this.accountStatement,
    required this.onPrint,
    this.onTransactionTap,
  });

  @override
  State<GeneralLedgerDetailScreen> createState() =>
      _GeneralLedgerDetailScreenState();
}

class _GeneralLedgerDetailScreenState extends State<GeneralLedgerDetailScreen> {
  final _searchController = TextEditingController();
  final _horizontalController = ScrollController();
  String _query = '';

  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;
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

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  String _value(Map<String, dynamic> row, String key) =>
      (row[key] ?? '').toString();

  double _number(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(Map<String, dynamic> row, String key) =>
      NumberFormat('#,##0.00').format(_number(row, key).abs());

  List<Map<String, dynamic>> get _filteredTransactions {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.transactions;
    return widget.transactions.where((row) {
      return row.values.any(
        (value) => value.toString().toLowerCase().contains(query),
      );
    }).toList();
  }

  List<String> get _headers => widget.accountStatement
      ? const ['#', 'Date', 'Description', 'Debit', 'Credit', 'Balance']
      : const [
          '#',
          'Date',
          'Description',
          'Opening Balance',
          'Debit',
          'Credit',
          'Balance',
        ];

  List<String> _cells(Map<String, dynamic> row, int index) {
    if (widget.accountStatement) {
      return [
        '${index + 1}',
        _value(row, 'transactionDate'),
        _value(row, 'description'),
        _money(row, 'debit'),
        _money(row, 'credit'),
        _money(row, 'balance'),
      ];
    }
    return [
      _value(row, 'number').isEmpty ? '${index + 1}' : _value(row, 'number'),
      _value(row, 'date'),
      _value(row, 'description'),
      _money(row, 'openingBalance'),
      _money(row, 'debit'),
      _money(row, 'credit'),
      _money(row, 'balance'),
    ];
  }

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      style: TextStyle(color: _textColor),
      decoration: InputDecoration(
        hintText: 'Search entries...',
        hintStyle: TextStyle(color: _mutedColor),
        prefixIcon: Icon(Icons.search, color: _mutedColor),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: _fieldColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _borderColor),
        ),
      ),
    ),
  );

  Widget _mobileList(List<Map<String, dynamic>> rows) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    itemCount: rows.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final row = rows[index];
      final cells = _cells(row, index);
      return Material(
        color: _cardColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onTransactionTap == null
              ? null
              : () => widget.onTransactionTap!(row),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cells[2],
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cells[1],
                  style: TextStyle(color: _mutedColor, fontSize: 12),
                ),
                const Divider(height: 18),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    if (!widget.accountStatement) _stat('Opening', cells[3]),
                    _stat('Debit', cells[widget.accountStatement ? 3 : 4]),
                    _stat('Credit', cells[widget.accountStatement ? 4 : 5]),
                    _stat('Balance', cells[widget.accountStatement ? 5 : 6]),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: _mutedColor, fontSize: 11)),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(color: _textColor, fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _desktopTable(List<Map<String, dynamic>> rows) {
    final widths = widget.accountStatement
        ? const [55.0, 150.0, 360.0, 130.0, 130.0, 140.0]
        : const [55.0, 150.0, 300.0, 150.0, 130.0, 130.0, 140.0];
    final tableWidth = widths.reduce((a, b) => a + b) + 24;
    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _headerColor,
                  border: Border(
                    bottom: BorderSide(color: _borderColor, width: 0.8),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _headers.length; i++)
                      SizedBox(
                        width: widths[i],
                        child: Text(
                          _headers[i],
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final cells = _cells(row, index);
                    return InkWell(
                      onTap: widget.onTransactionTap == null
                          ? null
                          : () => widget.onTransactionTap!(row),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _rowColor,
                          border: Border(
                            bottom: BorderSide(color: _borderColor, width: 0.5),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < cells.length; i++)
                              SizedBox(
                                width: widths[i],
                                child: Text(
                                  cells[i],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: _textColor),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredTransactions;
    final isSmall = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: _textColor,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Print / Download',
            onPressed: () async {
              try {
                await widget.onPrint();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Print failed: $error')),
                  );
                }
              }
            },
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                widget.subtitle,
                style: TextStyle(color: _mutedColor),
              ),
            ),
          _searchField(),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'No entries found',
                      style: TextStyle(color: _mutedColor),
                    ),
                  )
                : isSmall
                ? _mobileList(rows)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _desktopTable(rows),
                  ),
          ),
        ],
      ),
    );
  }
}
