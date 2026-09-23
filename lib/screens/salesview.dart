
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/screens/salesviewdetails.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import '../widgets/salesviewpdf.dart';

class SalesViewPage extends StatefulWidget {
  const SalesViewPage({super.key});

  @override
  State<SalesViewPage> createState() => _SalesViewPageState();
}

class _SalesViewPageState extends State<SalesViewPage> {
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  final GlobalKey _branchKey = GlobalKey();
  int? _sortColumnIndex;
  bool _sortAscending = true;
   double previousbal  = 0.0;
  final now = DateTime.now();

  final ScrollController _verticalController = ScrollController();


  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  static const Color _backgroundColor = Color(0xFF101624);
  static const Color _cardColor = Color(0xFF1B263B);
  static const Color _headerColor = Color(0xFF0D1B2A);
  static const Color _borderColor = Colors.white12;

  static const Color _textColor = Colors.white;


  static final ScrollBehavior _smoothScrollBehavior = _SmoothScrollBehavior();

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
    if (text == null || text.isEmpty) {
      return '';
    }

    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final provider = context.read<Datafeed>();

      await provider.fetchBranches();

      _selectedBranch = provider.branchid;

      await provider.fetchsalesview(
        selectedBranch: _selectedBranch,
      );

      await provider.computePreviousBalances(provider.salesview);
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }


  void _openSearch() {
    setState(() {
      _isSearching = true;
    });


    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch(Datafeed value) {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });

    value.updateSearch('');
  }

  void _showBranchMenu( BuildContext context, Datafeed value, ) {
    final RenderBox button =
    _branchKey.currentContext!.findRenderObject() as RenderBox;

    final RenderBox overlay =
    Overlay.of(context).context.findRenderObject() as RenderBox;

    final buttonPosition = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

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
            style: TextStyle(
              color: _textColor,
              fontSize: 13,
            ),
          ),
        ),
        ...{
          for (final b in value.branches) b.id: b,
        }.values
            .where(
              (b) => b.id != null && b.id!.isNotEmpty,
        )
            .map(
              (b) => PopupMenuItem<String?>(
            value: b.id,
            child: Text(
              b.branchname,
              style: const TextStyle(
                color: _textColor,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    ).then((selectedBranch) {
      if (selectedBranch == null) return;

      final branch = selectedBranch == '__ALL__' ? null : selectedBranch;

      setState(() {
        _selectedBranch = branch;
      });

      value.fetchsalesview(
        selectedDate: selectedDate,
        selectedBranch: branch,
      ).then((_) {
        value.computePreviousBalances(value.salesview);
      });
    });
  }

  void _showViewModal(BuildContext context,dynamic salesview,) {
    final provider = context.read<Datafeed>();

    final canSelectDate = provider.accesslevel == 'super admin' ||
        provider.accesslevel == 'systemadmin' ||
        provider.accesslevel == 'admin';

    final receipt = salesview.receiptNumber;

    final customerName = (salesview.customerName?.toString().isNotEmpty == true)
        ? salesview.customerName.toString()
        : '-';

    final Map<String, dynamic> itemMap =
    Map<String, dynamic>.from(salesview.items);

    final numberFormat = NumberFormat('#,##0.00');

    final totalAmount = itemMap.values.fold<double>( 0, (sum, item) {
      if (item is Map<String, dynamic>) {
        return sum +
            (double.tryParse(
              item['totalamount']?.toString() ?? '0',
            ) ??
                0);
      }

      return sum;
    },
    );

    final totalQty = itemMap.values.fold<double>(0, (sum, item) {
      if (item is Map<String, dynamic>) {
        return sum +
            (double.tryParse(
              item['totalpieces']?.toString() ?? '0',
            ) ??
                0);
      }

      return sum;
    },
    );

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
              maxWidth: isSmall ? double.infinity : 880,
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
                  decoration: const BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: _textColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Receipt #$receipt',
                          style: const TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: _textColor,
                          size: 20,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),


                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: [
                                    _plainInfoLine(
                                      'Customer',
                                      customerName,
                                    ),
                                    _plainInfoLine(
                                      'Staff    ',
                                      salesview.createdBy ?? '-',
                                    ),
                                    _plainInfoLine(
                                      'Date',
                                      salesview.dateymd != null &&
                                          salesview.dateymd!.isNotEmpty
                                          ? DateFormat('dd MMM yyyy, hh:mm a').format(
                                        DateTime.parse(
                                          salesview.dateymd!,
                                        ),
                                      )
                                          : '-',
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    _plainInfoLine(
                                      'Transaction Mode',
                                      salesview.transMode ?? '-',
                                    ),
                                    _plainInfoLine(
                                      'Payment Status',
                                      salesview.paymentStatus ?? '-',
                                    ),
                                    _plainInfoLine(
                                      'Pieces',
                                      totalQty.toString(),
                                    ),
                                  ],
                                ),


                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        _sectionLabel('ITEMS'),

                        const SizedBox(height: 10),

                        _buildItemsTable(
                          itemMap.values
                              .whereType<Map<String, dynamic>>()
                              .toList(),
                          canSelectDate,
                        ),

                        const SizedBox(height: 8),

                        const Divider(
                          color: Colors.white12,
                        ),

                        const SizedBox(height: 8),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Expanded(
                              child: Text(
                                'TOTAL AMOUNT',
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              'GHC ${numberFormat.format(totalAmount)}',
                              style: const TextStyle(
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


                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
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
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: _textColor,
                          ),
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

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _textColor,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _plainInfoLine(
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: _textColor,
            fontSize: 13,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildItemsTable(
      List<Map<String, dynamic>> items,
      bool canSelectDate,
      ) {
    final numberFormat = NumberFormat('#,##0.00');

    String money(dynamic v) {
      final parsed = double.tryParse(v?.toString() ?? '');
      return parsed == null ? '-' : 'GHC ${numberFormat.format(parsed)}';
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        horizontalMargin: 0,
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
        dividerThickness: 0.5,
        headingRowColor: const WidgetStatePropertyAll(_headerColor),
        headingTextStyle: const TextStyle(
          color: _textColor,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
        dataTextStyle: const TextStyle(
          color: _textColor,
          fontSize: 12,
        ),
        columns: [
          const DataColumn(label: Text('ITEM')),
          const DataColumn(label: Text('BARCODE')),
          const DataColumn(label: Text('QTY')),
          const DataColumn(label: Text('PRICE'), numeric: true),
          const DataColumn(label: Text('DISCOUNT'), numeric: true),
          //   if (canSelectDate) const DataColumn(label: Text('PRICE MODE')),
          if (canSelectDate)
            const DataColumn(label: Text('COST PRICE'), numeric: true),
          if (canSelectDate)
            const DataColumn(label: Text('PROFIT'), numeric: true),
          const DataColumn(label: Text('TOTAL'), numeric: true),
        ],
        rows: items.map((item) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  (item['item'] ?? '-').toString().toUpperCase(),
                ),
              ),
              DataCell(
                Text('${item['barcode'] ?? '-'}'),
              ),
              DataCell(
                Text(
                  '${item['quantity'] ?? '-'} (${item['mode'] ?? '-'})',
                ),
              ),
              DataCell(
                Text(money(item['price'])),
              ),
              DataCell(
                Text('${item['discount'] ?? '0'}'),
              ),



              if (canSelectDate) DataCell(
                Text(
                  item['cp'] != null ? money(item['cp']) : '-',
                ),
              ),
              if (canSelectDate)
                DataCell(
                  Text(
                    item['profit'] != null ? money(item['profit']) : '-',
                  ),
                ),
              DataCell(
                Text(money(item['totalamount'])),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _handleDelete(
      BuildContext context,
      String itemName,
      String id,
      String receipt,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          'Delete $itemName?',
          style: const TextStyle(
            color: _textColor,
          ),
        ),
        content: const Text(
          'This action cannot be undone. Are you sure?',
          style: TextStyle(
            color: _textColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(innerContext, false);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _textColor,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () {
              Navigator.pop(innerContext, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: _textColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await context.read<Datafeed>().deletesalesview(
        id,
        receipt,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$itemName deleted successfully',
            style: const TextStyle(
              color: _textColor,
            ),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to delete item',
            style: TextStyle(
              color: _textColor,
            ),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _selectedBranchLabel(Datafeed value) {
    if (value.isSalesStaff) {
      return value.branch;
    }

    if (_selectedBranch == null) {
      return 'All Branches';
    }

    final matches = value.branches.where(
          (b) => b.id == _selectedBranch,
    );

    if (matches.isEmpty) {
      return 'All Branches';
    }

    return matches.first.branchname;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final effectiveStart = selectedDate?.start ?? now;
        final effectiveEnd = selectedDate?.end ?? now;

        final filteredSalesview = value.filtersalesview();

        final canSelectDate = value.accesslevel == 'super admin' ||
            value.accesslevel == 'systemadmin' ||
            value.accesslevel == 'admin';

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: AppBar(
              backgroundColor: _cardColor,
              elevation: 0,
              iconTheme: const IconThemeData(
                color: _textColor,
              ),
              title: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 700;

                  final periodText =
                      '${DateFormat('dd MMM yyyy').format(effectiveStart)}'
                      ' - '
                      '${DateFormat('dd MMM yyyy').format(effectiveEnd)}';

                  final branchLabel = _selectedBranchLabel(value);


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
                            height: 60,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                autofocus: true,
                                style: const TextStyle(
                                  color: _textColor,
                                  fontSize: 15,
                                ),
                                cursorColor: _textColor,
                                decoration: const InputDecoration(
                                  hintText: 'Search sales...',
                                  hintStyle: TextStyle(
                                    color: Colors.white54,
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                                onChanged: (text) {
                                  // setState so the clear (x) button
                                  // appears/disappears as the user types.
                                  setState(() {});
                                  context.read<Datafeed>().updateSearch(text);
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
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
                              setState(() {
                                _searchController.clear();
                              });
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
                              'Sales View List',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMobile
                                  ? '$branchLabel • $periodText'
                                  : '$branchLabel • Sales View For The Period Of $periodText',
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


                      if (!value.isSalesStaff)
                        IconButton(
                          key: _branchKey,
                          tooltip: 'Branch: $branchLabel',
                          icon: const Icon(
                            Icons.store_outlined,
                            color: _textColor,
                            size: 21,
                          ),
                          onPressed: () {
                            _showBranchMenu(
                              context,
                              value,
                            );
                          },
                        ),


                      if (canSelectDate)
                        ReusableDatePickerWidget(
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
                            setState(() {
                              selectedDate = selection;
                            });

                            final provider = context.read<Datafeed>();

                            provider.fetchsalesview(
                              selectedDate: selectedDate,
                              selectedBranch: _selectedBranch,
                            ).then((_) {
                              provider.computePreviousBalances(provider.salesview);
                            });
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
              constraints: const BoxConstraints(
                maxWidth: 1000,
              ),
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
                          ? const Center(
                        child: CircularProgressIndicator(
                          color: _textColor,
                        ),
                      )
                          : value.salesview.isEmpty
                          ? const Center(
                        child: Text(
                          'No Sales Found',
                          style: TextStyle(
                            color: _textColor,
                          ),
                        ),
                      )
                          : LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop =
                              constraints.maxWidth > 700;

                          if (isDesktop) {
                            return _buildDesktopLayout(
                              context,
                              filteredSalesview,
                              value,
                              canSelectDate,
                            );
                          }

                          return _buildMobileList(
                            context,
                            filteredSalesview,
                            canSelectDate,
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

  Widget _buildDesktopRow( BuildContext context, dynamic sv, int index, Datafeed value,bool canSelectDate ) {
    final receipt = sv.receiptNumber;

    final customerName = (sv.customerName?.toString().isNotEmpty == true)
        ? sv.customerName.toString()
        : '-';

    final itemMap = Map<String, dynamic>.from(sv.items);

    final total = itemMap.values.fold<double>(
      0,
          (sum, item) {
        if (item is Map<String, dynamic>) {
          return sum +
              (double.tryParse(
                item['totalamount']?.toString() ?? '0',
              ) ??
                  0);
        }

        return sum;
      },
    );

    final nf = NumberFormat('#,##0.00');

    final dateStr = sv.dateymd ?? '-';

    return InkWell(
      onTap: () => _showViewModal(context, sv),
      child: Container(
        color: index.isEven
            ? const Color(0xFF0D1B2A)
            : const Color(0xFF111E2F),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Expanded(
              flex: _colFlexes[0],
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: _colFlexes[1],
              child: GestureDetector(
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: '$receipt',
                    ),
                  );

                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Receipt copied',
                        style: TextStyle(
                          color: _textColor,
                        ),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text(
                  '#$receipt',
                  style: const TextStyle(
                    color: _textColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: _colFlexes[2],
              child: Text(
                customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: _colFlexes[3],
              child: Text(
                dateStr,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: _colFlexes[4],
              child: Text(
                sv.transMode ?? '-',
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (canSelectDate) ...[
              Expanded(
                flex: _colFlexes[5],
                child: Text(
                  'GHC ${nf.format(value.previousBalanceByReceipt[sv.id] ?? 0.0)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: _textColor, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
            ],
            const SizedBox(width: 12),
            Expanded(
              flex: _colFlexes[6],
              child: Text(
                'GHC ${nf.format(total)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: _colFlexes[7],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value.canView(AppModules.sales))
                    _actionIcon(
                      Icons.visibility,
                      'View',
                          () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SalesDetailPage(
                            salesview: sv,
                          ),
                        ),
                      ),
                    ),
                  if (value.can_Print(AppModules.sales))
                    _actionIcon(
                      Icons.print,
                      'Print',
                          () => printSalesModelReceipt(context, sv),),
                  if (value.canDelete(AppModules.sales))
                    _actionIcon(
                      Icons.delete_outline,
                      'Delete',
                          () => _handleDelete(
                        context,
                        customerName,
                        sv.id,
                        receipt,
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

  static const List<int> _colFlexes = [
    1, // #
    3, // Receipt
    4, // Customer
    3, // Date
    2, // Mode
    3, // Prev. Balance
    3, // Total
    3, // Actions
  ];

  Widget _sortableHeaderCell(
      String label,
      int flex,
      int columnIndex,
      Comparable Function(dynamic d) getField,
      List list, {
        bool numeric = false,
      }) {
    final isSorted = _sortColumnIndex == columnIndex;

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _sort(
          getField,
          columnIndex,
          isSorted ? !_sortAscending : true,
          list,
        ),
        child: Row(
          mainAxisAlignment:
          numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _textColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
            if (isSorted)
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

  Widget _plainHeaderCell(
      String label,
      int flex, {
        bool numeric = false,
      }) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          color: _textColor,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildDesktopLayout( BuildContext context, List filteredSalesview, Datafeed value, bool canSelectDate, ) {
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              child: Row(
                children: [
                  _plainHeaderCell(
                    '#',
                    _colFlexes[0],
                  ),
                  const SizedBox(width: 12),
                  _sortableHeaderCell(
                    'Receipt',
                    _colFlexes[1],
                    1,
                        (d) => d.receiptNumber ?? '',
                    filteredSalesview,
                  ),
                  const SizedBox(width: 12),
                  _sortableHeaderCell(
                    'Customer',
                    _colFlexes[2],
                    2,
                        (d) => (d.customerName?.toString() ?? '').toLowerCase(),
                    filteredSalesview,
                  ),
                  const SizedBox(width: 12),
                  _sortableHeaderCell(
                    'Date',
                    _colFlexes[3],
                    4,
                        (d) => d.dateymd ?? '',
                    filteredSalesview,
                  ),
                  const SizedBox(width: 12),
                  _sortableHeaderCell(
                    'Mode',
                    _colFlexes[4],
                    5,
                        (d) => d.transMode ?? '',
                    filteredSalesview,
                  ),
                  const SizedBox(width: 12),

                  if (canSelectDate) ...[
                    _sortableHeaderCell(
                      'Previous Bal',
                      _colFlexes[5],
                      55,
                          (d) => value.previousBalanceByReceipt[d.id] ?? 0.0,
                      filteredSalesview,
                      numeric: true,
                    ),
                    const SizedBox(width: 12),
                  ],
                  const SizedBox(width: 12),
                  _sortableHeaderCell(
                    'Total',
                    _colFlexes[5],
                    6,
                        (d) {
                      final itemMap = Map<String, dynamic>.from(
                        d.items,
                      );

                      return itemMap.values.fold<double>(
                        0,
                            (sum, item) {
                          if (item is Map<String, dynamic>) {
                            return sum +
                                (double.tryParse(
                                  item['totalamount']?.toString() ?? '0',
                                ) ??
                                    0);
                          }

                          return sum;
                        },
                      );
                    },
                    filteredSalesview,
                    numeric: true,
                  ),
                  const SizedBox(width: 12),
                  _plainHeaderCell(
                    'Actions',
                    _colFlexes[6],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ScrollConfiguration(
                behavior: _smoothScrollBehavior,
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: ListView.builder(
                    controller: _verticalController,
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),

                    cacheExtent: 600,
                    itemCount: filteredSalesview.length,
                    itemBuilder: (context, index) {
                      return _buildDesktopRow(
                        context,
                        filteredSalesview[index],
                        index,
                        value,
                        canSelectDate,

                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList( BuildContext context,  List filteredSalesview,bool canSelectDate, ) {
    return Consumer<Datafeed>(
      builder: (context, value, _) {
        return ScrollConfiguration(
          behavior: _smoothScrollBehavior,
          child: ListView.separated(
            padding: const EdgeInsets.only(
              top: 4,
              bottom: 16,
            ),
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            cacheExtent: 600,
            itemCount: filteredSalesview.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final sv = filteredSalesview[index];

              final id = sv.id;
              final receipt = sv.receiptNumber;

              final customerName =
              (sv.customerName?.toString().isNotEmpty == true)
                  ? sv.customerName.toString()
                  : '-';

              final staffName = (sv.createdBy?.toString().isNotEmpty == true)
                  ? sv.createdBy.toString()
                  : '-';

              final transactionMode =
              (sv.transMode?.toString().isNotEmpty == true)
                  ? sv.transMode.toString()
                  : '-';

              final paymentStatus =
              (sv.paymentStatus?.toString().isNotEmpty == true)
                  ? sv.paymentStatus.toString()
                  : '-';

              final date = (sv.dateymd?.toString().isNotEmpty == true)
                  ? sv.dateymd.toString()
                  : '-';

              final Map<String, dynamic> itemMap =
              Map<String, dynamic>.from(sv.items);

              final total = itemMap.values.fold<double>( 0, (sum, item) {
                if (item is Map<String, dynamic>) {
                  return sum +
                      (double.tryParse(
                        item['totalamount']?.toString() ?? '0',
                      ) ??
                          0);
                }

                return sum;
              },
              );

              final nf = NumberFormat('#,##0.00');

              return InkWell(
                onTap: () => _showViewModal(context, sv),
                child: Container(
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _borderColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          color: _headerColor,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Receipt #$receipt',
                                style: const TextStyle(
                                  color: _textColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              'GHC ${nf.format(total)}',
                              style: const TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),


                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _mobileInfoRow(
                              'Customer',
                              customerName,
                            ),
                            const SizedBox(height: 10),
                            _mobileInfoRow(
                              'Staff',
                              staffName,
                            ),
                            const SizedBox(height: 10),
                            _mobileInfoRow(
                              'Transaction Mode',
                              transactionMode,
                            ),
                            const SizedBox(height: 10),
                            _mobileInfoRow(
                              'Payment Status',
                              paymentStatus,
                            ),
                            const SizedBox(height: 10),
                            _mobileInfoRow(
                              'Date',
                              date,
                            ),
                            if (canSelectDate) ...[
                              const SizedBox(height: 10),
                              _mobileInfoRow(
                                'Previous Balance',
                                'GHC ${nf.format(value.previousBalanceByReceipt[sv.id] ?? 0.0)}',
                              ),
                            ],

                            const SizedBox(height: 14),
                            const Divider(
                              color: Colors.white12,
                              height: 1,
                            ),
                            const SizedBox(height: 12),
                            _mobileInfoRow(
                              'Total Amount',
                              'GHC ${nf.format(total)}',
                              valueBold: true,
                            ),
                          ],
                        ),
                      ),


                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: const BoxDecoration(
                          color: _headerColor,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (value.canView(AppModules.sales))
                              Expanded(
                                child: _mobileActionButton(
                                  icon: Icons.visibility_outlined,
                                  label: 'View',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SalesDetailPage(
                                          salesview: sv,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                            if (value.can_Print(AppModules.sales))
                              Expanded(
                                child: _mobileActionButton(
                                  icon: Icons.print_outlined,
                                  label: 'Print',
                                  onPressed: () {
                                    printSalesModelReceipt(context,sv,);
                                  },
                                ),
                              ),
                            if (value.canDelete(AppModules.sales))
                              Expanded(
                                child: _mobileActionButton(
                                  icon: Icons.delete_outline,
                                  label: 'Delete',
                                  onPressed: () {
                                    _handleDelete(
                                      context,
                                      customerName,
                                      id,
                                      receipt,
                                    );
                                  },
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
          ),
        );
      },
    );
  }

  Widget _mobileInfoRow(
      String label,
      String value, {
        bool valueBold = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: const TextStyle(
              color: _textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textColor,
              fontSize: 12,
              fontWeight: valueBold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _textColor,
        padding: const EdgeInsets.symmetric(
          vertical: 8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _textColor,
            size: 19,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: _textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(
      IconData icon,
      String tooltip,
      VoidCallback onTap,
      ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            color: _textColor,
            size: 18,
          ),
        ),
      ),
    );
  }
}


class _SmoothScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}