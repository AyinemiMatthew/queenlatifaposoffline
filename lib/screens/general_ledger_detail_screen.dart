import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/datepicker.dart';
import '../widgets/general_ledger_export.dart';

class GeneralLedgerDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> transactions;
  final bool accountStatement;
  final DateTimeRange? dateRange;
  final Future<List<Map<String, dynamic>>> Function(DateTimeRange dateRange)?
  onDateRangeChanged;
  final Future<void> Function(
    List<Map<String, dynamic>> transactions,
    DateTimeRange dateRange,
  )
  onPrint;
  final String statementAccountName;
  final String statementCompany;
  final String statementBranch;
  final String statementAddress;
  final String activityCompany;
  final String activityBranch;
  final void Function(
    Map<String, dynamic> transaction,
    DateTimeRange dateRange,
  )?
  onTransactionTap;

  const GeneralLedgerDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.transactions,
    required this.accountStatement,
    this.dateRange,
    this.onDateRangeChanged,
    required this.onPrint,
    this.statementAccountName = '',
    this.statementCompany = '',
    this.statementBranch = '',
    this.statementAddress = '',
    this.activityCompany = '',
    this.activityBranch = '',
    this.onTransactionTap,
  });

  @override
  State<GeneralLedgerDetailScreen> createState() =>
      _GeneralLedgerDetailScreenState();
}

class _GeneralLedgerDetailScreenState extends State<GeneralLedgerDetailScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';
  int _currentPage = 0;
  int _rowsPerPage = 10;
  bool _isSearching = false;
  bool _isLoadingDateRange = false;
  late List<Map<String, dynamic>> _transactions;
  late DateTimeRange _selectedDateRange;

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
  Color get _alternateRowColor =>
      _isLightTheme ? const Color(0xFFF3F6FA) : const Color(0xFF13243A);
  Color get _searchFieldColor => _isLightTheme
      ? Theme.of(context).colorScheme.surface
      : Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _cursorColor =>
      _isLightTheme ? Theme.of(context).colorScheme.primary : Colors.white;
  Color get _borderColor =>
      _isLightTheme ? Colors.grey.shade300 : Colors.white.withOpacity(0.1);

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _transactions = List<Map<String, dynamic>>.of(widget.transactions);
    _selectedDateRange =
        widget.dateRange ?? DateTimeRange(start: today, end: today);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    if (query.isEmpty) return _transactions;
    return _transactions.where((row) {
      return row.values.any(
        (value) => value.toString().toLowerCase().contains(query),
      );
    }).toList();
  }

  Widget _datePickerIcon() => ReusableDatePickerWidget(
    initialDateRange: _selectedDateRange,
    onDateSelected: (selection) async {
      final today = DateTime.now();
      final range =
          selection ??
          DateTimeRange(
            start: today.subtract(const Duration(days: 30)),
            end: today,
          );
      final onDateRangeChanged = widget.onDateRangeChanged;
      if (onDateRangeChanged == null) return;

      setState(() => _isLoadingDateRange = true);
      try {
        final transactions = await onDateRangeChanged(range);
        if (!mounted) return;
        setState(() {
          _selectedDateRange = range;
          _transactions = transactions;
          _currentPage = 0;
        });
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load statement for this period: $error'),
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoadingDateRange = false);
      }
    },
    child: Tooltip(
      message:
          'Date range: ${DateFormat('d MMM y').format(_selectedDateRange.start)}'
          ' - ${DateFormat('d MMM y').format(_selectedDateRange.end)}',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _isLoadingDateRange
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.calendar_today_outlined),
      ),
    ),
  );

  Widget _statementHeader(DateTimeRange range) {
    Widget detail(String label, String value, {bool alignRight = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: RichText(
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            text: TextSpan(
              style: TextStyle(color: _textColor, fontSize: 14),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          Text(
            widget.statementCompany,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'ACCOUNT STATEMENT',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _mutedColor,
              fontSize: 17,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    detail('Account Name', widget.statementAccountName),
                    if (widget.statementAddress.isNotEmpty)
                      detail('Address', widget.statementAddress),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    detail('Branch', widget.statementBranch, alignRight: true),
                    detail(
                      'Period',
                      '${DateFormat('d MMM yyyy').format(range.start)}'
                          ' to ${DateFormat('d MMM yyyy').format(range.end)}',
                      alignRight: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> get _headers => widget.accountStatement
      ? const [
          '#',
          'Date',
          'Description',
          'Debit (GHS)',
          'Credit (GHS)',
          'Balance (GHS)',
        ]
      : const [
          '#',
          'Date',
          'Description',
          'Opening Balance (GHS)',
          'Debit (GHS)',
          'Credit (GHS)',
          'Balance (GHS)',
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

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _query = '';
      _currentPage = 0;
      _searchController.clear();
    });
  }

  Widget _appBarSearchField() => TextField(
    controller: _searchController,
    focusNode: _searchFocusNode,
    autofocus: true,
    onChanged: (value) => setState(() {
      _query = value;
      _currentPage = 0;
    }),
    style: TextStyle(color: _textColor),
    cursorColor: _cursorColor,
    decoration: InputDecoration(
      hintText: 'Search entries...',
      hintStyle: TextStyle(color: _mutedColor),
      prefixIcon: Icon(Icons.search, color: _mutedColor, size: 20),
      filled: true,
      fillColor: _searchFieldColor,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                  _currentPage = 0;
                });
                _searchFocusNode.requestFocus();
              },
              icon: const Icon(Icons.close),
            ),
    ),
  );

  Widget _mobileList(
    List<Map<String, dynamic>> rows,
    int firstRowIndex,
  ) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    itemCount: rows.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final row = rows[index];
      final cells = _cells(row, firstRowIndex + index);
      return Material(
        color: index.isEven ? _cardColor : _alternateRowColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: _borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onTransactionTap == null
              ? null
              : () => widget.onTransactionTap!(row, _selectedDateRange),
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

  Widget _desktopTable(List<Map<String, dynamic>> rows, int firstRowIndex) {
    final baseWidths = widget.accountStatement
        ? [55.0, 150.0, 360.0, 130.0, 130.0, 140.0]
        : [55.0, 150.0, 300.0, 150.0, 130.0, 130.0, 140.0];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableColumnWidth = constraints.maxWidth - 24;
        final baseColumnWidth = baseWidths.reduce((a, b) => a + b);
        final scale = availableColumnWidth < baseColumnWidth
            ? availableColumnWidth / baseColumnWidth
            : 1.0;
        final widths = baseWidths.map((width) => width * scale).toList();
        if (availableColumnWidth > baseColumnWidth) {
          widths[2] += availableColumnWidth - baseColumnWidth;
        }

        return SizedBox(
          width: constraints.maxWidth,
          child: Column(
            children: [
              Container(
                color: _headerColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _headers.length; i++)
                      SizedBox(
                        width: widths[i],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            _headers[i],
                            maxLines: 3,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.bold,
                            ),
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
                    final cells = _cells(row, firstRowIndex + index);
                    return InkWell(
                      onTap: widget.onTransactionTap == null
                          ? null
                          : () => widget.onTransactionTap!(
                              row,
                              _selectedDateRange,
                            ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: index.isEven ? _rowColor : _alternateRowColor,
                          border: Border(
                            bottom: BorderSide(color: _borderColor, width: 0.5),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < cells.length; i++)
                              SizedBox(
                                width: widths[i],
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    cells[i],
                                    maxLines: 4,
                                    softWrap: true,
                                    style: TextStyle(color: _textColor),
                                  ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredTransactions;
    final screenSize = MediaQuery.sizeOf(context);
    final isSmall = screenSize.width < 700;
    final pageSize = _rowsPerPage;
    final pageCount = (rows.length / pageSize).ceil().clamp(1, 1 << 30);
    final pageIndex = _currentPage.clamp(0, pageCount - 1);
    final pageStart = pageIndex * pageSize;
    final pageRows = rows.skip(pageStart).take(pageSize).toList();
    final exportRows = rows
        .asMap()
        .entries
        .map((entry) => _cells(entry.value, entry.key))
        .toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: _textColor,
        title: _isSearching
            ? _appBarSearchField()
            : Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_isSearching)
            IconButton(
              tooltip: 'Search entries',
              onPressed: _openSearch,
              icon: const Icon(Icons.search),
            )
          else
            IconButton(
              tooltip: 'Close search',
              onPressed: _closeSearch,
              icon: const Icon(Icons.close),
            ),
          GeneralLedgerExportMenu(
            title: widget.title,
            headers: _headers,
            rows: exportRows,
            exportHeader: widget.accountStatement
                ? GeneralLedgerExportHeader(
                    companyName: widget.statementCompany,
                    heading: 'Account Statement',
                    leftDetails: [
                      GeneralLedgerExportDetail(
                        'Account Name',
                        widget.statementAccountName,
                      ),
                      if (widget.statementAddress.isNotEmpty)
                        GeneralLedgerExportDetail(
                          'Address',
                          widget.statementAddress,
                        ),
                    ],
                    rightDetails: [
                      GeneralLedgerExportDetail(
                        'Branch',
                        widget.statementBranch,
                      ),
                      GeneralLedgerExportDetail(
                        'Period',
                        '${DateFormat('d MMM yyyy').format(_selectedDateRange.start)}'
                            ' to ${DateFormat('d MMM yyyy').format(_selectedDateRange.end)}',
                      ),
                    ],
                  )
                : GeneralLedgerExportHeader(
                    companyName: widget.activityCompany,
                    heading: 'Account Activity',
                    leftDetails: [
                      GeneralLedgerExportDetail(
                        'Account',
                        widget.title.replaceFirst('General Ledger - ', ''),
                      ),
                    ],
                    rightDetails: [
                      GeneralLedgerExportDetail(
                        'Branch',
                        widget.activityBranch,
                      ),
                      GeneralLedgerExportDetail(
                        'Period',
                        '${DateFormat('d MMM yyyy').format(_selectedDateRange.start)}'
                            ' to ${DateFormat('d MMM yyyy').format(_selectedDateRange.end)}',
                      ),
                    ],
                  ),
            metadata: widget.accountStatement ? const [] : [widget.subtitle],
            onPrint: () => widget.onPrint(_transactions, _selectedDateRange),
          ),
          if (widget.accountStatement && widget.onDateRangeChanged != null)
            _datePickerIcon(),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.accountStatement)
            _statementHeader(_selectedDateRange)
          else if (widget.subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                widget.subtitle,
                softWrap: true,
                style: TextStyle(color: _mutedColor),
              ),
            ),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      'No entries found',
                      style: TextStyle(color: _mutedColor),
                    ),
                  )
                : isSmall
                ? _mobileList(pageRows, pageStart)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _desktopTable(pageRows, pageStart),
                  ),
          ),
          if (rows.isNotEmpty)
            GeneralLedgerPagination(
              totalRows: rows.length,
              pageIndex: pageIndex,
              onPageChanged: (page) => setState(() => _currentPage = page),
              pageSize: pageSize,
              onPageSizeChanged: (pageSize) => setState(() {
                _rowsPerPage = pageSize;
                _currentPage = 0;
              }),
            ),
        ],
      ),
    );
  }
}
