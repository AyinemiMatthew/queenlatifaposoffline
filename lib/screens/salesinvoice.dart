import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/screens/salesviewdetails.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import '../widgets/salesviewpdf.dart';

class SalesInvoice extends StatefulWidget {
  const SalesInvoice({super.key});

  @override
  State<SalesInvoice> createState() => _SalesInvoiceState();
}

class _SalesInvoiceState extends State<SalesInvoice> {
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final now = DateTime.now();

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _mobileListController = ScrollController();

  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _mutedTextColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _backgroundColor =>
      _isLightTheme ? Colors.white : Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => _isLightTheme
      ? Colors.white
      : Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _headerColor =>
      _isLightTheme ? Colors.white : const Color(0xFF0D1B2A);
  Color get _fieldColor => _isLightTheme
      ? Colors.white
      : Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _borderColor => _isLightTheme
      ? Colors.grey.shade300
      : Colors.white.withValues(alpha: 0.1);

  Color _tableRowColor(int index) => _isLightTheme
      ? Colors.white
      : index.isEven
      ? const Color(0xFF0D1B2A)
      : const Color(0xFF111E2F);

  static const Color _scrollColor = Color(0xFF415A77);
  static const double _scrollThickness = 8.0;

  ScrollbarThemeData get _scrollbarTheme => ScrollbarThemeData(
    thumbColor: WidgetStateProperty.all(_scrollColor),
    trackColor: WidgetStateProperty.all(_scrollColor.withOpacity(0.15)),
    trackBorderColor: WidgetStateProperty.all(_scrollColor.withOpacity(0.30)),
    thickness: WidgetStateProperty.all(_scrollThickness),
    radius: const Radius.circular(6),
    thumbVisibility: WidgetStateProperty.all(true),
    trackVisibility: WidgetStateProperty.all(true),
  );

  void _sort<T>(
    Comparable<T> Function(dynamic d) getField,
    int columnIndex,
    bool ascending,
    List list,
  ) {
    list.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchsalesview();
    });
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _mobileListController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch(Datafeed value) {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    value.updateSearch('');
  }

  void _showViewModal(BuildContext context, dynamic salesview) {
    final receipt = salesview.receiptNumber;
    final customerName = (salesview.customerName?.toString().isNotEmpty == true)
        ? salesview.customerName.toString()
        : '-';

    final Map<String, dynamic> itemMap = Map<String, dynamic>.from(
      salesview.items,
    );
    final numberFormat = NumberFormat('#,##0.00');

    final totalamountt = itemMap.values.fold<double>(0, (sum, item) {
      if (item is Map<String, dynamic>) {
        return sum +
            (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
      }
      return sum;
    });

    final totalQty = itemMap.values.fold<double>(0, (sum, item) {
      if (item is Map<String, dynamic>) {
        return sum +
            (double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0);
      }
      return sum;
    });

    final modalScrollController = ScrollController();

    showDialog(
      context: context,
      builder: (ctx) {
        final isSmall = MediaQuery.sizeOf(ctx).width < 600;
        return Dialog(
          backgroundColor: _backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isSmall ? double.infinity : 680,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, color: _textColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Receipt  #$receipt',
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: _mutedTextColor,
                          size: 20,
                        ),
                        onPressed: () {
                          modalScrollController.dispose();
                          Navigator.pop(ctx);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Scrollbar(
                    controller: modalScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: modalScrollController,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _chip(
                                Icons.person_outline,
                                'Customer',
                                customerName,
                              ),
                              _chip(
                                Icons.person_outline,
                                'Staff',
                                salesview.createdBy ?? '-',
                              ),
                              _chip(
                                Icons.calendar_today_outlined,
                                'Date',
                                salesview.dateymd != null &&
                                        salesview.dateymd!.isNotEmpty
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(
                                        DateTime.parse(salesview.dateymd!),
                                      )
                                    : '-',
                              ),
                              _chip(
                                Icons.swap_horiz,
                                'Trans Mode',
                                salesview.transMode ?? '-',
                              ),
                              _chip(
                                Icons.payment,
                                'Status',
                                salesview.paymentStatus ?? '-',
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _sectionLabel('ITEMS'),
                          const SizedBox(height: 8),
                          ...itemMap.values.map((item) {
                            if (item is! Map<String, dynamic>) {
                              return const SizedBox();
                            }
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _fieldColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (item['item'] ?? '')
                                              .toString()
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: _textColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ' ${item['totalamount']}',
                                        style: TextStyle(
                                          color: _textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(color: _borderColor, height: 14),
                                  Wrap(
                                    spacing: 18,
                                    runSpacing: 8,
                                    children: [
                                      _pair(
                                        'Qty',
                                        '${item['quantity']} (${item['mode']})',
                                      ),
                                      _pair(
                                        'Pieces in receipt',
                                        totalQty.toStringAsFixed(0),
                                      ),
                                      _pair('Price(GHS)', ' ${item['price']}'),
                                      _pair('Discount', '${item['discount']}'),
                                      _pair(
                                        'Price Mode',
                                        capitalize(
                                          item['pricemode']?.toString(),
                                        ),
                                      ),
                                      if (item['cp'] != null)
                                        _pair(
                                          'Cost Price(GHS)',
                                          ' ${item['cp']}',
                                        ),
                                      if (item['barcode'] != null)
                                        _pair('Barcode', '${item['barcode']}'),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          Divider(color: _borderColor),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL AMOUNT(GHS)',
                                style: TextStyle(
                                  color: _mutedTextColor,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                ' ${numberFormat.format(totalamountt)}',
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          modalScrollController.dispose();
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'Close',
                          style: TextStyle(color: _mutedTextColor),
                        ),
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
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(color: _mutedTextColor, fontSize: 10, letterSpacing: 1.6),
  );

  Widget _chip(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: _fieldColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _borderColor),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _mutedTextColor, size: 13),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: _mutedTextColor, fontSize: 9)),
            Text(
              value,
              style: TextStyle(
                color: _textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _pair(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: _mutedTextColor, fontSize: 9)),
      Text(
        value,
        style: TextStyle(
          color: _textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _buildBranchDropdown(Datafeed value) {
    final currentId =
        value.branches.any((b) => b.id == value.selectedBranch?.id)
        ? value.selectedBranch?.id
        : null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentId,
          dropdownColor: _cardColor,
          icon: Icon(Icons.expand_more, color: _mutedTextColor, size: 16),
          style: TextStyle(color: _textColor, fontSize: 12),
          isDense: true,
          isExpanded: true,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Branches'),
            ),
            ...{for (final b in value.branches) b.id: b}.values.map(
              (b) => DropdownMenuItem<String?>(
                value: b.id,
                child: Text(b.branchname, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (val) {
            setState(() => _selectedBranch = val);
            value.fetchsalesview(
              selectedDate: selectedDate,
              selectedBranch: val,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchField(Datafeed value) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
      ),
      cursorColor: Theme.of(context).colorScheme.secondary,
      decoration: InputDecoration(
        hintText: 'Search receipt, customer...',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        border: InputBorder.none,
        isDense: true,
      ),
      onChanged: value.updateSearch,
    );
  }

  String _branchLabel(Datafeed value) {
    if (_selectedBranch == null) return 'All Branches';
    final match = value.branches.where((b) => b.id == _selectedBranch);
    if (match.isEmpty) return 'All Branches';
    return match.first.branchname;
  }

  Widget _buildTitleWithPeriod(
    DateTime start,
    DateTime end,
    String branchName,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sales Invoice List',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$branchName sales invoice for the period '
          '${DateFormat('yyyy MMM dd').format(start)}  -  '
          '${DateFormat('yyyy MMM dd').format(end)}',
          style: TextStyle(color: _mutedTextColor, fontSize: 10),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final effectiveStart =
            selectedDate?.start ?? now.subtract(const Duration(days: 0));
        final effectiveEnd = selectedDate?.end ?? now;
        final filteredSalesview = value.filtersalesview();

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            backgroundColor: _cardColor,
            foregroundColor: _textColor,
            elevation: 0,
            toolbarHeight: 64,
            titleSpacing: _isSearching ? 4 : 12,
            leading: _isSearching
                ? IconButton(
                    tooltip: "close",
                    icon: Icon(Icons.arrow_back, color: _mutedTextColor),
                    onPressed: () => _closeSearch(value),
                  )
                : null,
            automaticallyImplyLeading: _isSearching,
            title: _isSearching
                ? _buildSearchField(value)
                : _buildTitleWithPeriod(
                    effectiveStart,
                    effectiveEnd,
                    _branchLabel(value),
                  ),
            iconTheme: IconThemeData(color: _textColor),
            actions: _isSearching
                ? [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, color: _mutedTextColor),
                        onPressed: () {
                          _searchController.clear();
                          value.updateSearch('');
                          setState(() {});
                        },
                      ),
                  ]
                : [
                    _buildBranchDropdown(value),
                    IconButton(
                      icon: Icon(Icons.search, color: _mutedTextColor),
                      onPressed: _openSearch,
                    ),
                    ReusableDatePickerWidget(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: _mutedTextColor,
                        ),
                      ),
                      onDateSelected: (selection) {
                        setState(() => selectedDate = selection);
                        context.read<Datafeed>().fetchsalesview(
                          selectedDate: selectedDate,
                          selectedBranch: _selectedBranch,
                        );
                      },
                    ),
                  ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: value.isloadingsalesview
                          ? Center(
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : value.salesview.isEmpty
                          ? Center(
                              child: Text(
                                'No Sales found',
                                style: TextStyle(color: _mutedTextColor),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final isDesktop = constraints.maxWidth > 900;
                                if (isDesktop) {
                                  return _buildDesktopLayout(
                                    context,
                                    filteredSalesview,
                                    value,
                                    constraints.maxWidth,
                                  );
                                }
                                return _buildMobileList(
                                  context,
                                  filteredSalesview,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<_SalesColumn> _salesColumns() {
    return const [
      _SalesColumn('#', 30),
      _SalesColumn('Receipt', 90),
      _SalesColumn('Customer', 180),
      _SalesColumn('Branch', 120),
      _SalesColumn('Entry Date', 100),
      _SalesColumn('Trx Date', 100),
      _SalesColumn('Mode', 90),
      _SalesColumn('Total(GHS)', 100),
      _SalesColumn('Action', 90),
    ];
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    List filteredSalesview,
    Datafeed value,
    double availableWidth,
  ) {
    final columns = _salesColumns();
    const double gap = 24.0;
    final double totalColsWidth =
        columns.fold<double>(0, (s, c) => s + c.width) +
        (columns.length - 1) * gap +
        32;

    return ScrollbarTheme(
      data: _scrollbarTheme,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double contentWidth = totalColsWidth;
          return Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // -- Header (tap-to-sort)
                    Container(
                      width: contentWidth,
                      height: 44,
                      color: _cardColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          for (int i = 0; i < columns.length; i++) ...[
                            SizedBox(
                              width: columns[i].width,
                              child: _sortableHeaderCell(
                                columns[i].label,
                                i,
                                numeric: columns[i].numeric,
                                filteredSalesview: filteredSalesview,
                              ),
                            ),
                            if (i != columns.length - 1)
                              const SizedBox(width: gap),
                          ],
                        ],
                      ),
                    ),
                    Divider(height: 0.4, thickness: 0.4, color: _borderColor),
                    // -- Body (virtualized rows)
                    Expanded(
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: ListView.builder(
                          controller: _verticalController,
                          itemCount: filteredSalesview.length,
                          itemBuilder: (context, index) => _buildDesktopRow(
                            context,
                            filteredSalesview[index],
                            index,
                            columns,
                            gap,
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

  Widget _sortableHeaderCell(
    String label,
    int columnIndex, {
    bool numeric = false,
    required List filteredSalesview,
  }) {
    final isSorted = _sortColumnIndex == columnIndex;

    Comparable Function(dynamic) getField;
    switch (columnIndex) {
      case 1:
        getField = (d) => d.receiptNumber;
        break;
      case 2:
        getField = (d) => (d.customerName?.toString() ?? '').toLowerCase();
        break;
      case 3:
        getField = (d) => d.branchName ?? '';
        break;
      case 4:
      case 5:
        getField = (d) => d.createdAt?.toDate().toString() ?? '';
        break;
      case 6:
        getField = (d) => d.transMode ?? '';
        break;
      case 7:
        getField = (d) {
          final m = Map<String, dynamic>.from(d.items);
          return m.values.fold<double>(0, (s, item) {
            if (item is Map<String, dynamic>) {
              return s +
                  (double.tryParse(item['totalamount']?.toString() ?? '0') ??
                      0);
            }
            return s;
          });
        };
        break;
      default:
        getField = (d) => '';
    }

    final sortable = columnIndex >= 1 && columnIndex <= 7;

    return InkWell(
      onTap: sortable
          ? () => _sort(
              getField,
              columnIndex,
              isSorted ? !_sortAscending : true,
              filteredSalesview,
            )
          : null,
      child: Row(
        mainAxisAlignment: numeric
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSorted) ...[
            const SizedBox(width: 4),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 13,
              color: _mutedTextColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopRow(
    BuildContext context,
    dynamic sv,
    int index,
    List<_SalesColumn> columns,
    double gap,
  ) {
    final receipt = sv.receiptNumber;

    final customerName = (sv.customerName?.toString().isNotEmpty == true)
        ? sv.customerName.toString()
        : '-';
    final branchName = (sv.branchName?.toString().isNotEmpty == true)
        ? sv.branchName.toString()
        : '-';
    final itemMap = Map<String, dynamic>.from(sv.items);

    final total = itemMap.values.fold<double>(0, (s, item) {
      if (item is Map<String, dynamic>) {
        return s +
            (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
      }
      return s;
    });

    final nf = NumberFormat('#,##0.00');
    final dateStr = sv.createdAt != null
        ? sv.createdAt!.toDate().toString().split(' ').first
        : '-';
    final dateymd = sv.dateymd != null && sv.dateymd!.isNotEmpty
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(sv.dateymd!))
        : '-';

    final cells = <Widget>[
      Text(
        '${index + 1}',
        style: TextStyle(color: _mutedTextColor, fontSize: 13),
      ),
      GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: '#$receipt'));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                'Receipt copied',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        },
        child: Text(
          '#$receipt',
          style: TextStyle(color: _textColor, fontSize: 13),
        ),
      ),
      Text(
        customerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: _textColor, fontSize: 13),
      ),
      Text(branchName, style: TextStyle(color: _textColor, fontSize: 13)),
      Text(dateStr, style: TextStyle(color: _textColor, fontSize: 13)),
      Text(dateymd, style: TextStyle(color: _textColor, fontSize: 13)),
      Text(
        sv.transMode ?? '-',
        style: TextStyle(color: _textColor, fontSize: 13),
      ),
      Text(
        ' ${nf.format(total)}',
        textAlign: TextAlign.center,
        style: TextStyle(color: _textColor, fontSize: 13),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionIcon(
            Icons.visibility,
            _textColor,
            'View',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SalesDetailPage(salesview: sv)),
            ),
          ),
          _actionIcon(
            Icons.print,
            _textColor,
            'Print',
            () => printSalesModelReceipt(context, sv),
          ),
        ],
      ),
    ];

    return InkWell(
      onTap: () => _showViewModal(context, sv),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 64),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _tableRowColor(index),
          border: Border(
            bottom: BorderSide(
              color: _isLightTheme ? _borderColor : Colors.transparent,
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (int i = 0; i < columns.length; i++) ...[
              SizedBox(width: columns[i].width, child: cells[i]),
              if (i != columns.length - 1) SizedBox(width: gap),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(BuildContext context, List filteredSalesview) {
    return Consumer<Datafeed>(
      builder: (context, value, _) => Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: Scrollbar(
              controller: _mobileListController,
              thumbVisibility: true,
              child: ListView.separated(
                controller: _mobileListController,
                itemCount: filteredSalesview.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final sv = filteredSalesview[index];
                  final receipt = sv.receiptNumber;
                  final customerName =
                      (sv.customerName?.toString().isNotEmpty == true)
                      ? sv.customerName.toString()
                      : '-';
                  final branchName =
                      (sv.branchName?.toString().isNotEmpty == true)
                      ? sv.branchName.toString()
                      : '-';

                  final Map<String, dynamic> iMap = Map<String, dynamic>.from(
                    sv.items,
                  );
                  final total = iMap.values.fold<double>(0, (s, item) {
                    if (item is Map<String, dynamic>) {
                      return s +
                          (double.tryParse(
                                item['totalamount']?.toString() ?? '0',
                              ) ??
                              0);
                    }
                    return s;
                  });
                  final nf = NumberFormat('#,##0.00');

                  return GestureDetector(
                    onTap: () => _showViewModal(context, sv),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // card header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _headerColor,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    color: _mutedTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                          SizedBox(height: 5),
                          GestureDetector(
                            onTap: () async {
                              await Clipboard.setData(
                                ClipboardData(text: 'Receipt #$receipt'),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied')),
                              );
                            },
                            child: Text(
                              'Receipt #$receipt',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _headerColor,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 8),

                                const Spacer(),
                                Text(
                                  ' ${nf.format(total)}',
                                  style: TextStyle(
                                    color: _textColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // card body
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      color: _mutedTextColor,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        branchName,
                                        style: TextStyle(
                                          color: _mutedTextColor,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        customerName,
                                        style: TextStyle(
                                          color: _mutedTextColor,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _pair('Mode', sv.transMode ?? '-'),
                                    _pair('Status', sv.paymentStatus ?? '-'),
                                    _pair(
                                      'Date',
                                      sv.createdAt != null
                                          ? DateFormat(
                                              'dd MMM yyyy',
                                            ).format(sv.createdAt!.toDate())
                                          : '-',
                                    ),
                                    _pair(
                                      'Trx Date',
                                      sv.dateymd != null &&
                                              sv.dateymd!.isNotEmpty
                                          ? DateFormat('dd MMM yyyy').format(
                                              DateTime.parse(sv.dateymd!),
                                            )
                                          : '-',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // card footer actions
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _headerColor,
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.visibility,
                                    color: _textColor,
                                    size: 20,
                                  ),
                                  tooltip: 'View',
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SalesDetailPage(salesview: sv),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.print,
                                    color: _textColor,
                                    size: 20,
                                  ),
                                  tooltip: 'Print',
                                  onPressed: () =>
                                      printSalesModelReceipt(context, sv),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onTap,
  ) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: color, size: 18),
      ),
    ),
  );
}

class _SalesColumn {
  final String label;
  final double width;
  final bool numeric;
  const _SalesColumn(this.label, this.width, {this.numeric = false});
}
