import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../providers/item_provider.dart';
import '../widgets/datepicker.dart';
import 'bundlesale.dart';

class bundleSaleViewPage extends StatefulWidget {
  const bundleSaleViewPage({super.key});

  @override
  State<bundleSaleViewPage> createState() => _bundleSaleViewPageState();
}

class _bundleSaleViewPageState extends State<bundleSaleViewPage> {
  Color get _dividerColor => Theme.of(context).colorScheme.outlineVariant;

  Alignment _tableCellAlignment(int index) {
    switch (index) {
      case 0:
        return Alignment.center;
      case 3:
        return Alignment.centerRight;
      case 5:
      case 6:
        return Alignment.center;
      default:
        return Alignment.centerLeft;
    }
  }

  String searchQuery = '';
  DateTimeRange? selectedDate;
  final TextEditingController _searchController = TextEditingController();
  bool _showAppBarSearch = false;
  bool _showAppBarBranch = false;

  String _selectedBranch = '';
  String? _selectedBranchName;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      if (!mounted) return;

      final datafeed = context.read<Datafeed>();
      await datafeed.fetchBranches();
      if (!mounted) return;
      await _fetchBundles(datafeed);
    });
  }

  Future<void> _fetchBundles(
    Datafeed datafeed, {
    String? selectedBranch,
  }) async {
    try {
      await context.read<ItemProvider>().fetchBundles(
        datafeed: datafeed,
        selectedBranch: selectedBranch,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load bundles: $error')));
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildBranchSelector(Datafeed value, {bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final branchId = value.selectedBranch?.id;
    final selectedBranchId =
        branchId != null &&
            value.branches.any((branch) => branch.id == branchId)
        ? branchId
        : null;

    return DropdownButtonFormField<String?>(
      value: selectedBranchId,
      isExpanded: true,
      dropdownColor: colorScheme.surface,
      style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
      decoration: InputDecoration(
        labelText: compact ? null : 'Branch',
        hintText: compact ? 'Branch' : null,
        isDense: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        prefixIcon: Icon(Icons.store_outlined, color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'All Branches',
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
        ...{for (final branch in value.branches) branch.id: branch}.values.map(
          (branch) => DropdownMenuItem<String?>(
            value: branch.id,
            child: Text(
              branch.branchname,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ),
        ),
      ],
      onChanged: (branchId) {
        setState(() {
          _selectedBranch = branchId ?? '';
          _selectedBranchName = branchId == null
              ? ''
              : value.branches
                    .firstWhere((branch) => branch.id == branchId)
                    .branchname;
        });
        _fetchBundles(value, selectedBranch: branchId);
      },
    );
  }

  Widget _buildSearchField() {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        autofocus: _showAppBarSearch,
        cursorColor: colorScheme.secondary,
        onChanged: (text) {
          searchQuery = text;
          context.read<Datafeed>().updateSearch(text);
        },
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search bundles...',
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DATE FILTER
  // ---------------------------------------------------------------------------

  void _clearDateRange() {
    setState(() {
      selectedDate = null;
    });
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String capitalize(String? text) {
    if (text == null || text.isEmpty) {
      return '';
    }

    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatBundleDate(Map<String, dynamic> bundle, String pattern) {
    final date = context.read<ItemProvider>().bundleTimestamp(bundle);
    return date == null ? '' : DateFormat(pattern).format(date);
  }

  void _sortSales(List<Map<String, dynamic>> bundles, int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
    context.read<ItemProvider>().sortBundles(
      bundles: bundles,
      columnIndex: columnIndex,
      ascending: _sortAscending,
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;

    return Consumer2<Datafeed, ItemProvider>(
      builder: (context, value, itemProvider, child) {
        final filteredSalesView = itemProvider.filterBundles(
          bundles: itemProvider.bundleView,
          searchQuery: value.searchQuery,
          dateRange: selectedDate,
        );
        final branchLabel = (_selectedBranchName ?? '').isNotEmpty
            ? _selectedBranchName!
            : 'All Branches';
        final showBundleScope =
            selectedDate != null ||
            (_selectedBranchName ?? '').isNotEmpty ||
            (_selectedBranch.isEmpty && itemProvider.bundleView.isNotEmpty);
        final bundleScopeTitle = StringBuffer('Bundle View for $branchLabel');
        if (selectedDate != null) {
          bundleScopeTitle
            ..write(' · ')
            ..write(DateFormat.yMMMd().format(selectedDate!.start))
            ..write(' - ')
            ..write(DateFormat.yMMMd().format(selectedDate!.end));
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,

          // -------------------------------------------------------------------
          // APP BAR
          // -------------------------------------------------------------------
          appBar: AppBar(
            title: _showAppBarSearch
                ? _buildSearchField()
                : _showAppBarBranch
                ? SizedBox(
                    width: isDesktop ? 300 : null,
                    child: _buildBranchSelector(value, compact: !isDesktop),
                  )
                : showBundleScope
                ? Text(
                    bundleScopeTitle.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : const Text(
                    'Bundle Sales View List',
                    overflow: TextOverflow.ellipsis,
                  ),
            backgroundColor: Theme.of(context).colorScheme.surface,

            actions: [
              IconButton(
                tooltip: _showAppBarSearch ? 'Close search' : 'Search bundles',
                icon: Icon(_showAppBarSearch ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _showAppBarSearch = !_showAppBarSearch;
                    if (_showAppBarSearch) _showAppBarBranch = false;
                    if (!_showAppBarSearch) {
                      _searchController.clear();
                      searchQuery = '';
                      value.updateSearch('');
                    }
                  });
                },
              ),
              IconButton(
                tooltip: _showAppBarBranch
                    ? 'Close branch selector'
                    : 'Select branch',
                icon: Icon(
                  _showAppBarBranch ? Icons.close : Icons.store_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _showAppBarBranch = !_showAppBarBranch;
                    if (_showAppBarBranch) _showAppBarSearch = false;
                  });
                },
              ),
              ReusableDatePickerWidget(
                child: const Icon(Icons.calendar_today, size: 25),
                onDateSelected: (selection) {
                  setState(() {
                    selectedDate = selection;
                  });
                },
              ),

              if (selectedDate != null)
                IconButton(
                  tooltip: 'Clear date filter',
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: _clearDateRange,
                ),

              const SizedBox(width: 8),
            ],
          ),

          // -------------------------------------------------------------------
          // ADD BUTTON
          // -------------------------------------------------------------------
          floatingActionButton: FloatingActionButton(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => BundlePage()),
              );
            },
          ),

          // -------------------------------------------------------------------
          // BODY
          // -------------------------------------------------------------------
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    // =========================================================
                    // CONTENT
                    // =========================================================
                    Expanded(
                      child: itemProvider.isLoadingBundles
                          ? Center(
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : itemProvider.bundleView.isEmpty
                          ? Center(
                              child: Text(
                                'No Sales found',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            )
                          : filteredSalesView.isEmpty
                          ? Center(
                              child: Text(
                                'No Sales found for the selected date range',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            )
                          : screenWidth > 900
                          ? _buildDesktopTable(filteredSalesView)
                          : _buildMobileList(filteredSalesView),
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

  // ===========================================================================
  // DESKTOP
  // ===========================================================================

  Widget _buildDesktopTable(List<Map<String, dynamic>> sales) {
    final columnWidths = <double>[40, 190, 300, 110, 100, 110, 220];

    final columnLabels = <String>[
      '#',
      'Name',
      'Item',
      'Total',
      'Date',
      'Enable/Disable',
      'Action',
    ];

    final totalWidth =
        columnWidths.fold<double>(0, (sum, width) => sum + width) +
        ((columnWidths.length - 1) * 10) +
        30;

    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      trackVisibility: true,

      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,

        child: SizedBox(
          width: totalWidth,

          child: Column(
            children: [
              // ===============================================================
              // HEADER
              // ===============================================================

              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),

                child: Row(
                  children: List.generate(columnLabels.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == columnLabels.length - 1 ? 0 : 10,
                      ),

                      child: _buildHeaderCell(
                        index,
                        columnLabels[index],
                        columnWidths[index],
                        sales,
                      ),
                    );
                  }),
                ),
              ),

              // ===============================================================
              // DATA
              // ===============================================================
              Expanded(
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  trackVisibility: true,

                  child: ListView.builder(
                    controller: _verticalController,
                    itemCount: sales.length,

                    itemBuilder: (context, index) {
                      return _buildDesktopRow(
                        sales[index],
                        index,
                        columnWidths,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER CELL
  // ---------------------------------------------------------------------------

  Widget _buildHeaderCell(
    int index,
    String label,
    double width,
    List<Map<String, dynamic>> sales,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final sortable = index == 1 || index == 2 || index == 3 || index == 4;

    final active = _sortColumnIndex == index;

    Widget content = Text(
      label,

      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
    );

    if (sortable && active) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,

          const SizedBox(width: 4),

          Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,

            color: colorScheme.onSurfaceVariant,
            size: 14,
          ),
        ],
      );
    }

    return SizedBox(
      width: width,
      child: sortable
          ? InkWell(
              onTap: () => _sortSales(sales, index),
              child: SizedBox(
                width: width,
                height: 50,
                child: Align(
                  alignment: _tableCellAlignment(index),
                  child: content,
                ),
              ),
            )
          : Align(alignment: _tableCellAlignment(index), child: content),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP ROW
  // ---------------------------------------------------------------------------

  Widget _buildDesktopRow(
    Map<String, dynamic> salesView,
    int index,
    List<double> columnWidths,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final id = salesView['id']?.toString() ?? '';

    final name = salesView['name']?.toString() ?? '';

    final itemMap = context.read<ItemProvider>().bundleItemsMap(salesView);

    final firstItem = itemMap.values.isNotEmpty && itemMap.values.first is Map
        ? Map<String, dynamic>.from(itemMap.values.first)
        : <String, dynamic>{};

    final itemName = firstItem['item']?.toString() ?? name;

    final itemsSummary = itemMap.values
        .whereType<Map>()
        .map(
          (item) =>
              '${item['item'] ?? ''}'
              '(${item['quantity'] ?? 0})',
        )
        .join(', ');

    final total = context.read<ItemProvider>().bundleTotal(salesView);

    final date = _formatBundleDate(salesView, 'yyyy-MM-dd');

    final cells = <Widget>[
      Text(
        '${index + 1}',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
        ),
      ),

      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
        ),
      ),

      Text(
        itemsSummary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
        ),
      ),

      Text(
        NumberFormat('#,##0.00').format(total),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
        ),
      ),

      Text(
        date,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
        ),
      ),

      Center(
        child: Switch(
          value: salesView['isActive'] == true,
          activeThumbColor: Colors.white,
          activeTrackColor: Colors.green,
          inactiveThumbColor: colorScheme.onSurfaceVariant,
          inactiveTrackColor: colorScheme.surfaceContainerHighest,

          onChanged: (val) {
            context
                .read<ItemProvider>()
                .setBundleActive(docId: id, newStatus: val)
                .catchError((Object error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not update bundle status: $error'),
                    ),
                  );
                });
          },
        ),
      ),

      _buildBundleActionsMenu(itemName: itemName, id: id, itemMap: itemMap),
    ];

    return Container(
      constraints: const BoxConstraints(minHeight: 58),

      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,

        children: List.generate(columnWidths.length, (i) {
          return Padding(
            padding: EdgeInsets.only(
              right: i == columnWidths.length - 1 ? 0 : 10,
            ),

            child: SizedBox(
              width: columnWidths[i],

              child: Align(alignment: _tableCellAlignment(i), child: cells[i]),
            ),
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // MOBILE
  // ===========================================================================

  Widget _buildMobileList(List<Map<String, dynamic>> sales) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),

      itemCount: sales.length,

      separatorBuilder: (_, __) {
        return const SizedBox(height: 12);
      },

      itemBuilder: (context, index) {
        return _buildMobileCard(sales[index], index);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE CARD
  // ---------------------------------------------------------------------------

  Widget _buildMobileCard(Map<String, dynamic> salesView, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final id = salesView['id']?.toString() ?? '';

    final name = salesView['name']?.toString() ?? '';

    final itemMap = context.read<ItemProvider>().bundleItemsMap(salesView);

    final firstItem = itemMap.values.isNotEmpty && itemMap.values.first is Map
        ? Map<String, dynamic>.from(itemMap.values.first)
        : <String, dynamic>{};

    final itemName = firstItem['item']?.toString() ?? '';

    final totalAmount = context.read<ItemProvider>().bundleTotal(salesView);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),

      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: colorScheme.outlineVariant),

        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ================================================================
            // HEADER
            // ================================================================

            Container(
              padding: const EdgeInsets.all(16),

              color: colorScheme.surfaceContainerHighest,

              child: Wrap(
                spacing: 8,
                runSpacing: 6,

                crossAxisAlignment: WrapCrossAlignment.center,

                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,

                      borderRadius: BorderRadius.circular(8),
                    ),

                    child: Text(
                      'Name #$name',

                      style: TextStyle(
                        color: colorScheme.onTertiaryContainer,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  Text(
                    '#: ${index + 1}',

                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // ================================================================
            // BODY
            // ================================================================
            Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  ...itemMap.values.map((rawItem) {
                    if (rawItem is! Map) {
                      return const SizedBox();
                    }

                    final item = Map<String, dynamic>.from(rawItem);

                    return _buildMobileItem(item);
                  }),

                  Divider(color: _dividerColor),

                  const SizedBox(height: 8),

                  // STAFF
                  _buildFooterLabel(
                    Icons.person_outline,
                    'Staff: '
                    '${salesView['staff'] ?? ''}',
                  ),

                  const SizedBox(height: 6),

                  // DATE
                  _buildFooterLabel(
                    Icons.calendar_today_outlined,
                    'Date: '
                    '${_formatBundleDate(salesView, 'yyyy-MM-dd HH:mm')}',
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'TOTAL AMOUNT',

                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 10,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'GHS '
                    '${NumberFormat("#,##0.00").format(totalAmount)}',

                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            // ================================================================
            // ACTIONS
            // ================================================================
            Container(
              color: colorScheme.surfaceContainerHighest,

              padding: const EdgeInsets.symmetric(horizontal: 8),

              child: Align(
                alignment: Alignment.centerRight,
                child: _buildBundleActionsMenu(
                  itemName: itemName,
                  id: id,
                  itemMap: itemMap,
                ),
              ),
            ),

            // ================================================================
            // ACTIVE SWITCH
            // ================================================================
            SwitchListTile(
              dense: true,

              title: Text(
                'Active',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              value: salesView['isActive'] == true,
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.green,
              inactiveThumbColor: colorScheme.onSurfaceVariant,
              inactiveTrackColor: colorScheme.surfaceContainerHighest,

              onChanged: (val) {
                context
                    .read<ItemProvider>()
                    .setBundleActive(docId: id, newStatus: val)
                    .catchError((Object error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not update bundle status: $error',
                          ),
                        ),
                      );
                    });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE ITEM
  // ---------------------------------------------------------------------------

  Widget _buildMobileItem(Map<String, dynamic> item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,

        borderRadius: BorderRadius.circular(12),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            item['item']?.toString().toUpperCase() ?? '',

            maxLines: 2,
            overflow: TextOverflow.ellipsis,

            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'GHS ${item['totalamount'] ?? 0}',

            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          Divider(color: _dividerColor, height: 20),

          Table(
            columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},

            children: [
              _buildTableRow(
                'Qty',
                '${item['quantity'] ?? 0}'
                    ' (${item['mode'] ?? ''})',
              ),

              _buildTableRow('Price', 'GHS ${item['price'] ?? 0}'),

              _buildTableRow(
                'Price mode',
                capitalize(item['pricemode']?.toString()),
              ),

              if (item['cp'] != null)
                _buildTableRow('Cost Price', 'GHS ${item['cp']}'),

              if (item['barcode'] != null)
                _buildTableRow('Barcode', '${item['barcode']}'),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SMALL WIDGET HELPERS
  // ===========================================================================

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),

          child: Text(
            label,

            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),

          child: Text(
            value,

            maxLines: 2,
            overflow: TextOverflow.ellipsis,

            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLabel(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,

      children: [
        Icon(icon, color: colorScheme.onSurfaceVariant, size: 14),

        const SizedBox(width: 5),

        Expanded(
          child: Text(
            text,

            maxLines: 1,
            overflow: TextOverflow.ellipsis,

            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBundleActionsMenu({
    required String itemName,
    required String id,
    required Map<String, dynamic> itemMap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemList = itemMap.values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return PopupMenuButton<String>(
      tooltip: 'More actions',
      color: colorScheme.surfaceContainerHighest,
      icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
      onSelected: (action) {
        if (action == 'edit') {
          _handleEdit(context, id, itemList);
        } else if (action == 'delete') {
          _handleDelete(context, itemName, id);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, color: colorScheme.onSurfaceVariant, size: 20),
              const SizedBox(width: 10),
              Text('Edit', style: TextStyle(color: colorScheme.onSurface)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: colorScheme.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DELETE
  // ===========================================================================

  Future<void> _handleDelete(
    BuildContext context,
    String itemName,
    String id,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,

      builder: (innerContext) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,

          title: Text(
            'Delete $itemName?',

            style: TextStyle(color: colorScheme.onSurface),
          ),

          content: Text(
            'This action cannot be undone. '
            'Are you sure?',

            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(innerContext, false);
              },

              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),

              onPressed: () {
                Navigator.pop(innerContext, true);
              },

              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await context.read<ItemProvider>().deleteBundle(
        datafeed: context.read<Datafeed>(),
        id: id,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$itemName deleted successfully',
            style: TextStyle(color: colorScheme.onPrimary),
          ),

          backgroundColor: colorScheme.primary,

          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete bundle: $e',
            style: TextStyle(color: colorScheme.onError),
          ),

          backgroundColor: colorScheme.error,

          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ===========================================================================
  // EDIT
  // ===========================================================================

  Future<void> _handleEdit(
    BuildContext context,
    String id,
    List<Map<String, dynamic>> items,
  ) async {
    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (context) {
          return BundlePage(docId: id, item: items);
        },
      ),
    );
  }
}
