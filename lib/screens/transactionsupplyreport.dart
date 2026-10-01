import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../constants/constants.dart';
import '../providers/Datafeed.dart';

class TransactionSupplyReportPage extends StatefulWidget {
  const TransactionSupplyReportPage({super.key});

  @override
  State<TransactionSupplyReportPage> createState() =>
      _TransactionSupplyReportPageState();
}

class _TransactionSupplyReportPageState
    extends State<TransactionSupplyReportPage> {
  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _pageColor =>
      _isLightTheme ? Theme.of(context).colorScheme.surface : Constants.bgDark;
  Color get _cardColor =>
      _isLightTheme ? Theme.of(context).colorScheme.surface : Constants.bgCard;
  Color get _inputColor => _isLightTheme
      ? Colors.white
      : Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _tableRowColor =>
      _isLightTheme ? Theme.of(context).colorScheme.surface : Constants.bgDark;
  Color get _primaryTextColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurface
      : Constants.textPrimary;
  Color get _secondaryTextColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : Constants.textSecondary;
  Color get _borderColor => _isLightTheme
      ? Theme.of(context).colorScheme.outline
      : Constants.borderColor;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  final DateTime _today = DateTime.now();
  late DateTime _startDate;
  late DateTime _endDate;
  DateTimeRange? _selectedDateRange;

  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _transactions = [];
  String? _selectedBranchId;
  String _searchQuery = '';
  String? _expandedTransactionId;
  bool _loading = false;
  bool _salesLoaded = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(_today.year, _today.month, _today.day);
    _endDate = _startDate;
    _selectedDateRange = DateTimeRange(start: _startDate, end: _endDate);
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
          if (_salesLoaded) {
            _transactions = _aggregateTransactions(context.read<Datafeed>());
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final datafeed = context.read<Datafeed>();
      datafeed.fetchBranches();
      _loadReport();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReport({bool refresh = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final datafeed = context.read<Datafeed>();
      if (!_salesLoaded || refresh) {
        await datafeed.getdata();
        if (datafeed.companyid.isEmpty) throw 'Company information not found.';
        final startYmd =
            '${_startDate.year.toString().padLeft(4, '0')}-'
            '${_startDate.month.toString().padLeft(2, '0')}-'
            '${_startDate.day.toString().padLeft(2, '0')}';

        final endYmd =
            '${_endDate.year.toString().padLeft(4, '0')}-'
            '${_endDate.month.toString().padLeft(2, '0')}-'
            '${_endDate.day.toString().padLeft(2, '0')}';

        final snapshot = await _db
            .collection('sales')
            .where('companyId', isEqualTo: datafeed.companyid)
            .where('dateymd', isGreaterThanOrEqualTo: startYmd)
            .where('dateymd', isLessThanOrEqualTo: endYmd)
            .orderBy('dateymd', descending: true)
            .get();

        _sales = snapshot.docs.map((doc) {
          final sale = Map<String, dynamic>.from(doc.data());
          sale['_documentId'] = doc.id;
          return sale;
        }).toList();
        _salesLoaded = true;
      }

      _transactions = _aggregateTransactions(datafeed);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load transaction report: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _aggregateTransactions(Datafeed datafeed) {
    final endExclusive = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day + 1,
    );
    final isSuperAdmin =
        datafeed.accesslevel.toLowerCase().trim() == 'super admin';
    final transactions = <Map<String, dynamic>>[];

    for (final sale in _sales) {
      final dateYmd = sale['dateymd']?.toString().trim() ?? '';

      final date = DateTime.tryParse(dateYmd);

      if (date == null) {
        continue;
      }

      if (date.isBefore(
            DateTime(_startDate.year, _startDate.month, _startDate.day),
          ) ||
          date.isAfter(DateTime(_endDate.year, _endDate.month, _endDate.day))) {
        continue;
      }
      final items = <Map<String, dynamic>>[];
      final rawItems = sale['items'];
      if (rawItems is Map) {
        for (final value in rawItems.values) {
          if (value is! Map) continue;
          final item = Map<String, dynamic>.from(value);
          final branchId = item['branchid']?.toString().trim() ?? '';
          if (branchId.isEmpty) continue;
          if (!isSuperAdmin && branchId != datafeed.branchid) continue;
          if (isSuperAdmin &&
              _selectedBranchId != null &&
              _selectedBranchId!.isNotEmpty &&
              branchId != _selectedBranchId) {
            continue;
          }
          items.add(item);
        }
      }
      if (items.isEmpty) continue;

      final supplied = items.where(_isSupplied).length;
      final id = (sale['id'] ?? sale['_documentId'] ?? '').toString();
      final transaction = {
        'id': id,
        'customerName': (sale['customerName'] ?? '').toString(),
        'customerPhone': (sale['customerPhone'] ?? '').toString(),
        'date': date,
        'branchName': (sale['branchName'] ?? '').toString(),
        'branchId': (sale['branchId'] ?? '').toString(),
        'totalItems': items.length,
        'suppliedItems': supplied,
        'pendingItems': items.length - supplied,
        'items': items,
      };

      final searchable = [
        transaction['id'],
        transaction['customerName'],
        transaction['customerPhone'],
        transaction['branchName'],
        transaction['branchId'],
      ].join(' ').toLowerCase();
      if (_searchQuery.isEmpty || searchable.contains(_searchQuery)) {
        transactions.add(transaction);
      }
    }
    return transactions;
  }

  bool _isSupplied(Map<String, dynamic> item) {
    final value = item['isSupplied'];
    return value == true || value?.toString().toLowerCase() == 'true';
  }

  void _showDateRangePicker() {
    var selectedRange = _selectedDateRange;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          'Select Date Range',
          style: TextStyle(color: _primaryTextColor),
        ),
        content: SizedBox(
          height: 400,
          width: 320,
          child: SfDateRangePicker(
            backgroundColor: _pageColor,
            headerStyle: DateRangePickerHeaderStyle(
              backgroundColor: _cardColor,
              textAlign: TextAlign.center,
              textStyle: TextStyle(
                color: _primaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            monthViewSettings: DateRangePickerMonthViewSettings(
              viewHeaderStyle: DateRangePickerViewHeaderStyle(
                textStyle: TextStyle(
                  color: _secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            monthCellStyle: DateRangePickerMonthCellStyle(
              textStyle: TextStyle(color: _primaryTextColor),
              todayTextStyle: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
              weekendTextStyle: TextStyle(color: _secondaryTextColor),
              disabledDatesTextStyle: TextStyle(color: _secondaryTextColor),
            ),
            selectionColor: Colors.blueAccent,
            startRangeSelectionColor: Colors.blueAccent,
            endRangeSelectionColor: Colors.blueAccent,
            rangeSelectionColor: Color(0x262196F3),
            todayHighlightColor: Colors.blueAccent,
            selectionTextStyle: TextStyle(
              color: _isLightTheme
                  ? Theme.of(context).colorScheme.onPrimary
                  : Colors.white,
              fontWeight: FontWeight.w600,
            ),
            selectionMode: DateRangePickerSelectionMode.range,
            initialSelectedRange: selectedRange == null
                ? null
                : PickerDateRange(selectedRange?.start, selectedRange?.end),
            onSelectionChanged: (args) {
              if (args.value is PickerDateRange) {
                final range = args.value as PickerDateRange;
                if (range.startDate == null) return;
                selectedRange = DateTimeRange(
                  start: range.startDate!,
                  end: range.endDate ?? range.startDate!,
                );
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedRange == null) return;
              setState(() {
                _selectedDateRange = selectedRange;
                _startDate = DateTime(
                  selectedRange!.start.year,
                  selectedRange!.start.month,
                  selectedRange!.start.day,
                );
                _endDate = DateTime(
                  selectedRange!.end.year,
                  selectedRange!.end.month,
                  selectedRange!.end.day,
                );
              });
              Navigator.pop(dialogContext);
              _loadReport(refresh: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.amberFill,
              foregroundColor: _isLightTheme
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.white,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  String _dateLabel() {
    return '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<Datafeed>();
    final isSuperAdmin =
        datafeed.accesslevel.toLowerCase().trim() == 'super admin';

    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: _primaryTextColor,
        title: const Text('Transaction Supply Report'),
        actions: [
          IconButton(
            tooltip: 'Refresh from database',
            onPressed: _loading ? null : () => _loadReport(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(datafeed, isSuperAdmin),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Constants.amberFill,
                    ),
                  )
                : _transactions.isEmpty
                ? Center(
                    child: Text(
                      'No transactions found.',
                      style: TextStyle(color: _secondaryTextColor),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 700
                        ? _buildMobileList()
                        : _buildDesktopTable(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(Datafeed datafeed, bool isSuperAdmin) {
    final dateButton = _filterButton(
      Icons.date_range,
      'Date range',
      _dateLabel(),
      _showDateRangePicker,
    );

    final branch = _branchDropdown(datafeed);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _cardColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date picker
              SizedBox(width: 260, child: dateButton),

              // Branch
              if (isSuperAdmin) SizedBox(width: 260, child: branch),

              // Search
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: _primaryTextColor),
                  decoration: InputDecoration(
                    hintText:
                        'Search transaction ID, customer, phone or branch',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: _searchController.clear,
                          ),
                    filled: true,
                    fillColor: _inputColor,
                    enabledBorder: _border(context),
                    focusedBorder: _border(context, focused: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputBorder _border(BuildContext context, {bool focused = false}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: focused
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
      );

  Widget _filterButton(
    IconData icon,
    String title,
    String value,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _secondaryTextColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: _secondaryTextColor),
                  ),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _primaryTextColor,
                      fontWeight: FontWeight.w600,
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

  Widget _branchDropdown(Datafeed datafeed) {
    return DropdownButtonFormField<String>(
      value: _selectedBranchId,
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: 'Branch',
        prefixIcon: const Icon(Icons.store),
        enabledBorder: _border(context),
        focusedBorder: _border(context, focused: true),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All branches')),
        ...datafeed.branches.map(
          (branch) => DropdownMenuItem(
            value: branch.id,
            child: Text(branch.branchname),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedBranchId = value;
          _transactions = _aggregateTransactions(datafeed);
        });
      },
    );
  }

  Widget _buildMobileList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        final id = transaction['id'].toString();
        return _transactionCard(transaction, id == _expandedTransactionId);
      },
    );
  }

  Widget _transactionCard(Map<String, dynamic> transaction, bool expanded) {
    final id = transaction['id'].toString();
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: (value) =>
            setState(() => _expandedTransactionId = value ? id : null),
        iconColor: Constants.amberFill,
        collapsedIconColor: _secondaryTextColor,
        title: Text(
          id,
          style: TextStyle(
            color: _primaryTextColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${transaction['customerName']}  |  ${_dateTime(transaction['date'])}',
          style: TextStyle(color: _secondaryTextColor),
        ),
        trailing: _countBadge(transaction['pendingItems'], Constants.amber),
        children: [_details(transaction)],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1200),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(_cardColor),
          dataRowColor: WidgetStateProperty.all(_tableRowColor),
          dataTextStyle: TextStyle(color: _primaryTextColor),
          columns: const [
            DataColumn(label: Text('Transaction ID')),
            DataColumn(label: Text('Customer')),
            DataColumn(label: Text('Transactions')),
            DataColumn(label: Text('Supplied')),
            DataColumn(label: Text('Pending')),
            DataColumn(label: Text('Date')),
          ],
          rows: _transactions.map((transaction) {
            return DataRow(
              onSelectChanged: (_) => _showDetails(transaction),
              cells: [
                DataCell(Text(transaction['id'].toString())),
                DataCell(Text(transaction['customerName'].toString())),
                DataCell(Text(transaction['totalItems'].toString())),
                DataCell(Text(transaction['suppliedItems'].toString())),
                DataCell(Text(transaction['pendingItems'].toString())),
                DataCell(Text(_dateTime(transaction['date']))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        child: _details(transaction, includeHeader: true),
      ),
    );
  }

  Widget _details(
    Map<String, dynamic> transaction, {
    bool includeHeader = false,
  }) {
    final items = transaction['items'] as List<Map<String, dynamic>>;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (includeHeader) ...[
            Text(
              transaction['id'].toString(),
              style: TextStyle(
                color: _primaryTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Customer: ${transaction['customerName']}',
              style: TextStyle(color: _secondaryTextColor),
            ),
            Text(
              'Phone: ${transaction['customerPhone']}',
              style: TextStyle(color: _secondaryTextColor),
            ),
            Divider(color: _borderColor),
          ],
          for (final item in items) _itemDetail(item),
        ],
      ),
    );
  }

  Widget _itemDetail(Map<String, dynamic> item) {
    final supplied = _isSupplied(item);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            supplied ? Icons.check_circle : Icons.pending,
            color: supplied ? Constants.green : Constants.amber,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['item']?.toString() ?? 'Unnamed item',
                  style: TextStyle(
                    color: _primaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Qty: ${item['quantity'] ?? 0}  |  Branch: ${item['branchname'] ?? item['branchid'] ?? ''}',
                  style: TextStyle(color: _secondaryTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            supplied ? 'Supplied' : 'Pending',
            style: TextStyle(
              color: supplied ? Constants.green : Constants.amber,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countBadge(dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$value pending',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _dateTime(dynamic value) =>
      DateFormat('dd MMM yyyy, HH:mm').format(value as DateTime);
}
