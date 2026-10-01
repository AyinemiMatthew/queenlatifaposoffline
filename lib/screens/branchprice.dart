import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/itemregmodel.dart';
import '../providers/Datafeed.dart';

import 'branchpriceedit.dart';

class BranchPricePage extends StatefulWidget {
  const BranchPricePage({super.key});

  @override
  State<BranchPricePage> createState() => _BranchPricePageState();
}

class _BranchPricePageState extends State<BranchPricePage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String searchQuery = '';
  String? userbranchid;
  String? userrole;
  String? staff;
  String? companyid;
  String? selectedBranchId;
  String? selectedBranchName;
  bool showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  int _rowsPerPage = 10;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final provider = context.read<Datafeed>();
      await provider.initUserAndBranches();
      await provider.fetchBranches();
      provider.fetchItems();
      if (!mounted) return;
      final vvalue = provider;
      final branchId = vvalue.branchid;
      final assignedBranches = vvalue.branches
          .where((branch) => branch.id == branchId)
          .toList();
      final branch = assignedBranches.isEmpty ? null : assignedBranches.first;
      setState(() {
        companyid = vvalue.companyid;
        userbranchid = branchId;
        userrole = vvalue.accesslevel;
        staff = vvalue.staff;
        if (!vvalue.canSelectBranch && branch != null) {
          selectedBranchId = branch.id;
          selectedBranchName = branch.branchname;
        }
      });
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ItemModel> filteredItems(Datafeed value) {
    final query = searchQuery.toLowerCase();

    if (query.isEmpty) return value.items;

    return value.items.where((item) {
      final name = (item.name ?? '').toLowerCase();
      final barcode = (item.barcode ?? '').toLowerCase();
      final company = (item.company ?? '').toLowerCase();
      final category = (item.pcategory ?? '').toLowerCase();

      return name.contains(query) ||
          barcode.contains(query) ||
          company.contains(query) ||
          category.contains(query);
    }).toList();
  }

  List<ItemModel> _sortedItems(List<ItemModel> items) {
    final sorted = List<ItemModel>.from(items);
    if (_sortColumnIndex == null) return sorted;

    sorted.sort((a, b) {
      int result = 0;
      switch (_sortColumnIndex) {
        case 1: // Name
          result = a.name.compareTo(b.name);
          break;
        case 3: // Category
          result = (a.pcategory).compareTo(b.pcategory ?? '');
          break;
        default:
          return 0;
      }
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 700;

    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            centerTitle: false,
            title: isDesktop
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          value.company,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showSearch)
                        SizedBox(
                          width: width > 1000 ? 260 : 180,
                          child: _searchField(),
                        ),
                      const Expanded(child: SizedBox()),
                    ],
                  )
                : showSearch
                ? _searchField()
                : Text(value.company, overflow: TextOverflow.ellipsis),
            actions: [
              if (value.canSelectBranch) _branchSelector(value),
              IconButton(
                tooltip: showSearch ? 'Close search' : 'Search items',
                icon: Icon(showSearch ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    showSearch = !showSearch;
                    if (!showSearch) {
                      _searchController.clear();
                      searchQuery = '';
                    }
                  });
                },
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                Expanded(
                  child: Builder(
                    builder: (_) {
                      if (value.loading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (selectedBranchId == null) {
                        return Center(
                          child: Text(
                            'Please select a branch',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        );
                      }

                      if (value.items.isEmpty) {
                        return Center(
                          child: Text(
                            "No items registered yet",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        );
                      }

                      final filtered = filteredItems(value);

                      return isDesktop
                          ? _desktopTable(filtered)
                          : _mobileCards(filtered);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _searchField() {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        autofocus: showSearch,
        onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          hintText: 'Search items...',
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _branchSelector(Datafeed value) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentBranch = selectedBranchId == null
        ? 'Please select a branch'
        : selectedBranchName ?? 'Selected Branch';

    return PopupMenuButton<String>(
      tooltip: 'Branch: $currentBranch',
      icon: Icon(Icons.store_outlined, color: colorScheme.onSurface),
      onSelected: (branchId) {
        final branch = value.branches.firstWhere((b) => b.id == branchId);
        setState(() {
          selectedBranchId = branchId;
          selectedBranchName = branch.branchname;

          showSearch = false;
          _searchController.clear();
          searchQuery = '';
        });
      },
      itemBuilder: (context) => [
        for (final branch in value.branches)
          PopupMenuItem<String>(
            value: branch.id,
            child: Row(
              children: [
                Icon(Icons.store_outlined, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    branch.branchname,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selectedBranchId == branch.id)
                  Icon(Icons.check, color: colorScheme.primary, size: 18),
              ],
            ),
          ),
      ],
    );
  }

  bool _itemHasBranchPrice(ItemModel item) {
    final branchPrices = item.branchprices;
    if (branchPrices == null || branchPrices.isEmpty) return false;
    if (selectedBranchId == null) return false;
    final branch = branchPrices[selectedBranchId];
    if (branch is! Map) return false;
    final pricing = branch['pricing'];
    return pricing is Map && pricing.isNotEmpty;
  }

  Widget _mobileCards(List<ItemModel> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        try {
          final item = items[i];

          final branchPrices = item.branchprices;
          final modes = item.modes;

          final selectedBranch = selectedBranchId == null
              ? null
              : branchPrices?[selectedBranchId];
          final hasBranchPricing = _itemHasBranchPrice(item);
          final selectedBranchMap = selectedBranch is Map
              ? Map<String, dynamic>.from(selectedBranch)
              : <String, dynamic>{};
          final selectedPricingValue = selectedBranchMap['pricing'];
          final selectedPricing = selectedPricingValue is Map
              ? Map<String, dynamic>.from(selectedPricingValue)
              : <String, dynamic>{};

          final hasModes = modes != null && modes is Map && modes.isNotEmpty;

          return Card(
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                if (selectedBranchId == null) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Branchitempriceupdate(
                      item: item,
                      branchId: selectedBranchId!,
                      staff: staff!,
                      branchname: selectedBranchName!,
                    ),
                  ),
                ).then((_) {
                  if (mounted) setState(() {});
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// HEADER
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          child: Text('${i + 1}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (item.barcode != null &&
                                  item.barcode!.isNotEmpty)
                                Text(
                                  'Barcode: ${item.barcode}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    /// PRICING
                    if (!hasBranchPricing && !hasModes)
                      Text(
                        'No pricing',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),

                    if (hasBranchPricing)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((selectedBranchMap['name'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                selectedBranchMap['name'].toString(),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ...selectedPricing.entries.map((e) {
                            final p = Map<String, dynamic>.from(e.value);
                            return _pricingCard(
                              name: p['name'] ?? e.key,
                              qty: p['qty'] ?? '',
                              rp: p['rp'] ?? '',
                              wp: p['wp'] ?? '',
                              sp: p['sp'] ?? '',
                            );
                          }),
                        ],
                      ),

                    /// FALLBACK → MODES
                    if (!hasBranchPricing && hasModes)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Default Pricing',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...modes.map((e) {
                            return _pricingCard(
                              name: e.name,
                              qty: e.qty,
                              rp: e.rp,
                              wp: e.wp,
                              sp: e.sp,
                            );
                          }),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        } catch (e) {
          print('Error building item card: $e');
          return Card(
            color: Theme.of(context).colorScheme.surface,
            child: ListTile(
              leading: Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Error loading item',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
      },
    );
  }

  static const double _colIndexW = 30;
  static const double _colNameW = 200;
  static const double _colBarcodeW = 200;
  static const double _colCategoryW = 90;
  static const double _colPricingW = 90;
  static const double _colHasPriceW = 90;
  static const double _colActionsW = 90;
  static const double _tableWidth =
      _colIndexW +
      _colNameW +
      _colBarcodeW +
      _colCategoryW +
      _colPricingW +
      _colHasPriceW +
      _colActionsW +
      (25 * 6) +
      40;

  Widget _headerCell(String label, {double width = 0, int? sortIndex}) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        if (sortIndex != null && _sortColumnIndex == sortIndex)
          Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: Colors.amber,
          ),
      ],
    );

    final cell = SizedBox(width: width, child: child);

    if (sortIndex == null) return cell;

    return InkWell(onTap: () => _onSort(sortIndex), child: cell);
  }

  Widget _dataCell(Widget child, double width) {
    return SizedBox(width: width, child: child);
  }

  Widget _desktopTable(List<ItemModel> items) {
    final sorted = _sortedItems(items);

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
        trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
        trackBorderColor: MaterialStateProperty.all(const Color(0xFF1B263B)),
        thickness: MaterialStateProperty.all(10),
        radius: const Radius.circular(8),
      ),
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (notif) => notif.depth == 1,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _tableWidth,
            child: Column(
              children: [
                // Header row
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      _headerCell('#', width: _colIndexW),
                      const SizedBox(width: 25),
                      _headerCell('Name', width: _colNameW, sortIndex: 1),
                      const SizedBox(width: 25),
                      _headerCell('Barcode', width: _colBarcodeW),
                      const SizedBox(width: 25),
                      _headerCell(
                        'Category',
                        width: _colCategoryW,
                        sortIndex: 3,
                      ),
                      const SizedBox(width: 25),
                      _headerCell('Pricing', width: _colPricingW),
                      const SizedBox(width: 25),
                      _headerCell('Has Price', width: _colHasPriceW),
                      const SizedBox(width: 25),
                      _headerCell('Actions', width: _colActionsW),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: Scrollbar(
                    child: ListView.builder(
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        return _desktopRow(sorted, index);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopRow(List<ItemModel> items, int index) {
    final item = items[index];

    try {
      final branchPrices = item.branchprices;
      final modes = item.modes;

      final hasBranchPricing = _itemHasBranchPrice(item);
      final hasModes = modes != null && modes.isNotEmpty;

      String tooltipText = '';

      if (hasBranchPricing && selectedBranchId != null) {
        final branchData = branchPrices![selectedBranchId];
        if (branchData != null && branchData['pricing'] != null) {
          final pricingMap = Map<String, dynamic>.from(branchData['pricing']);
          tooltipText = pricingMap.entries
              .map((entry) {
                final p = Map<String, dynamic>.from(entry.value);
                final name = p['name'] ?? entry.key;
                final qty = p['qty'] ?? '';
                final rp = p['rp'] ?? '';
                final wp = p['wp'] ?? '';
                final sp = p['sp'] ?? '';
                return '$name: Retail=$rp, Box=$wp, Supplier=$sp, Qty=$qty';
              })
              .join('\n');
        }
      }

      if (tooltipText.isEmpty && hasModes) {
        tooltipText = modes
            .map((m) {
              final name = m.name ?? '';
              return '$name: Retail=${m.rp}, Box=${m.wp}, Supplier=${m.sp}, Qty=${m.qty}';
            })
            .join('\n');
      }

      final hasPricing = _itemHasBranchPrice(item);

      return InkWell(
        onTap: () {
          if (selectedBranchId == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Branchitempriceupdate(
                item: item,
                branchId: selectedBranchId!,
                staff: staff!,
                branchname: selectedBranchName!,
              ),
            ),
          ).then((_) {
            if (mounted) setState(() {});
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.7,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              _dataCell(
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                _colIndexW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                Text(
                  item.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                _colNameW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                Text(
                  item.barcode,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                _colBarcodeW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                Text(
                  item.pcategory,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                _colCategoryW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                (!hasBranchPricing && !hasModes)
                    ? Text(
                        'No pricing',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      )
                    : Tooltip(
                        message: tooltipText,
                        waitDuration: const Duration(milliseconds: 300),
                        showDuration: const Duration(seconds: 5),
                        child: Text(
                          'View Pricing',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                _colPricingW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                Text(
                  hasPricing ? 'Yes' : 'Default',
                  style: TextStyle(
                    color: hasPricing
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _colHasPriceW,
              ),
              const SizedBox(width: 25),
              _dataCell(
                IconButton(
                  tooltip: selectedBranchId == null
                      ? 'Select a branch to edit pricing'
                      : 'Edit branch pricing',
                  icon: Icon(
                    Icons.edit,
                    color: selectedBranchId == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: selectedBranchId == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Branchitempriceupdate(
                                item: item,
                                branchId: selectedBranchId!,
                                staff: staff!,
                                branchname: selectedBranchName!,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) setState(() {});
                          });
                        },
                ),
                _colActionsW,
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error row $index: $e');
      return Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          'Error loading row',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
  }

  Widget _pricingCard({
    required String name,
    required dynamic qty,
    required dynamic rp,
    required dynamic wp,
    required dynamic sp,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: [
              _priceBox("Quantity", qty),
              _priceBox("Retail Price", rp),
              _priceBox("Wholesale Price", wp),
              _priceBox("Supplier Price", sp),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceBox(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11,
            ),
          ),
          Text(
            (value?.toString().isEmpty ?? true) ? "-" : value.toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
