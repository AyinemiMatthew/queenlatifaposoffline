import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../models/itemregmodel.dart';
import '../providers/Datafeed.dart';
import '../widgets/itemmodal.dart';
import 'itemreg.dart';

class ItemListPage extends StatefulWidget {
  const ItemListPage({super.key});

  @override
  State<ItemListPage> createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String searchQuery = "";
  bool _isSearching = false;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  static const List<double> _columnWidths = [
    50,
    180,
    140,
    100,
    90,
    100,
    100,
    140,
    110,
  ];
  static const double _horizontalPadding = 24;
  static const double _mobileInset = 16;

  double get _totalWidth =>
      _columnWidths.reduce((a, b) => a + b) + _horizontalPadding;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  List<ItemModel> _filteredItems(List<ItemModel> items) {
    if (searchQuery.isEmpty) return items;

    final query = searchQuery.toLowerCase();
    return items.where((item) {
      final name = (item.name).toLowerCase();
      final barcode = (item.barcode).toLowerCase();
      final company = (item.company).toLowerCase();
      final category = (item.pcategory).toLowerCase();

      return name.contains(query) ||
          barcode.contains(query) ||
          company.contains(query) ||
          category.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1000;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final filteredItems = _filteredItems(value.items);
        final pageCount = (filteredItems.length / _itemsPerPage).ceil();
        final currentPage = pageCount == 0
            ? 0
            : _currentPage.clamp(0, pageCount - 1);
        final startIndex = currentPage * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage).clamp(
          0,
          filteredItems.length,
        );
        final pageItems = filteredItems.sublist(startIndex, endIndex);
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isSearching
                  ? SizedBox(
                      key: const ValueKey('search'),
                      child: _buildAppBarSearchField(),
                    )
                  : const Text("Registered Items", key: ValueKey('title')),
            ),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  backgroundColor: Colors.transparent,
                  overlayColor: Colors.transparent,
                  side: BorderSide.none,
                  shape: const CircleBorder(),
                ),
                onPressed: () {
                  setState(() {
                    if (_isSearching) {
                      _searchController.clear();
                      searchQuery = "";
                      _currentPage = 0;
                    }
                    _isSearching = !_isSearching;
                  });
                },
              ),
            ],
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 56),
            child: FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ItemRegPage()),
                );
              },
            ),
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                Expanded(
                  child: value.loading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            "No items registered yet",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : isDesktop
                      ? _desktopTable(pageItems, value, startIndex)
                      : _mobileCards(pageItems, value, startIndex),
                ),
                _paginationFooter(
                  totalItems: filteredItems.length,
                  currentPage: currentPage,
                  pageCount: pageCount,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBarSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      cursorColor: Theme.of(context).colorScheme.secondary,
      onChanged: (v) => setState(() {
        searchQuery = v.toLowerCase();
        _currentPage = 0;
      }),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: "Search name, barcode, company...",
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
  }

  Widget _paginationFooter({
    required int totalItems,
    required int currentPage,
    required int pageCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstItem = totalItems == 0 ? 0 : currentPage * _itemsPerPage + 1;
    final lastItem = ((currentPage + 1) * _itemsPerPage).clamp(0, totalItems);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$firstItem-$lastItem of $totalItems',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Previous page',
              onPressed: currentPage > 0
                  ? () => setState(() => _currentPage = currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              pageCount == 0 ? '0 / 0' : '${currentPage + 1} / $pageCount',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: currentPage + 1 < pageCount
                  ? () => setState(() => _currentPage = currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileCards(List<ItemModel> items, Datafeed value, int startIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return ListView.builder(
      padding: const EdgeInsets.all(_mobileInset),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        try {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                ItemDetailsModal(context: context, item: item).show();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF415A77),
                      foregroundColor: Colors.white,
                      child: Text("${startIndex + index + 1}"),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              color: isLightTheme
                                  ? colorScheme.onSurface
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Barcode: ${item.barcode}",
                            style: TextStyle(
                              color: isLightTheme
                                  ? colorScheme.onSurfaceVariant
                                  : Colors.white70,
                            ),
                          ),
                          if (item.shelfnumber != null &&
                              item.shelfnumber!.isNotEmpty)
                            Text(
                              "Shell Number: ${item.shelfnumber}",
                              style: TextStyle(
                                color: isLightTheme
                                    ? colorScheme.onSurfaceVariant
                                    : Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: isLightTheme
                          ? colorScheme.onSurfaceVariant
                          : Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
          );
        } catch (e) {
          print("Error building item card for item ${items[index].id}: $e");
          return Container();
        }
      },
    );
  }

  Widget _desktopTable(List<ItemModel> items, Datafeed value, int startIndex) {
    final columnWidths = _columnWidths;
    final totalWidth = _totalWidth;
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    Widget headerCell(String text, double width) {
      return SizedBox(
        width: width,
        child: Text(
          text,
          style: TextStyle(
            color: isLightTheme ? colorScheme.onSurface : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    Widget bodyCell(Widget child, double width) {
      return SizedBox(width: width, child: child);
    }

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(
          isLightTheme ? colorScheme.primary : const Color(0xFF415A77),
        ),
        trackColor: MaterialStateProperty.all(
          isLightTheme
              ? colorScheme.surfaceContainerHighest
              : const Color(0xFF22304A),
        ),
        trackBorderColor: MaterialStateProperty.all(
          isLightTheme ? colorScheme.outlineVariant : const Color(0xFF1B263B),
        ),
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
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                Container(
                  height: 48,
                  color: isLightTheme
                      ? colorScheme.surface
                      : colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      headerCell("#", columnWidths[0]),
                      headerCell("Name", columnWidths[1]),
                      headerCell("Barcode", columnWidths[2]),
                      headerCell("Cost Price", columnWidths[3]),
                      headerCell("Retail", columnWidths[4]),
                      headerCell("Wholesale", columnWidths[5]),
                      headerCell("Supplier", columnWidths[6]),
                      headerCell("Inactive/Active", columnWidths[7]),
                      headerCell("Actions", columnWidths[8]),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: ListView.builder(
                      controller: _verticalController,
                      itemCount: items.length,
                      itemExtent: 64,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final supplierPrices =
                            item.modes
                                ?.where((d) => d.name.toLowerCase() == 'carton')
                                .map((m) => " ${m.sp}")
                                .join("\n") ??
                            "";
                        final wholesalePrices =
                            item.modes
                                ?.where((d) => d.name.toLowerCase() == 'carton')
                                .map((m) => " ${m.wp}")
                                .join("\n") ??
                            "";
                        final singlePrices =
                            item.modes
                                ?.where((d) => d.name.toLowerCase() == 'single')
                                .map((m) => "${m.rp}")
                                .join("\n") ??
                            "";

                        try {
                          return InkWell(
                            onTap: () => ItemDetailsModal(
                              context: context,
                              item: item,
                            ).show(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isLightTheme
                                    ? colorScheme.surface
                                    : colorScheme.surfaceContainerHighest,
                                border: Border(
                                  bottom: BorderSide(
                                    color: isLightTheme
                                        ? colorScheme.outlineVariant
                                        : colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  bodyCell(
                                    Text(
                                      "${startIndex + index + 1}",
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    columnWidths[0],
                                  ),
                                  bodyCell(
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    columnWidths[1],
                                  ),
                                  bodyCell(
                                    Text(
                                      item.barcode,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    columnWidths[2],
                                  ),
                                  bodyCell(
                                    Text(
                                      item.cp,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    columnWidths[3],
                                  ),
                                  bodyCell(
                                    Tooltip(
                                      message: singlePrices,
                                      child: Text(
                                        singlePrices,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    columnWidths[4],
                                  ),
                                  bodyCell(
                                    Tooltip(
                                      message: wholesalePrices,
                                      child: Text(
                                        wholesalePrices,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    columnWidths[5],
                                  ),
                                  bodyCell(
                                    Tooltip(
                                      message: supplierPrices,
                                      child: Text(
                                        supplierPrices,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    columnWidths[6],
                                  ),
                                  bodyCell(
                                    Center(
                                      child: Switch(
                                        value: item.isActive == true,
                                        activeColor: Colors.green,
                                        onChanged: (val) {
                                          if (!mounted) return;
                                          context
                                              .read<Datafeed>()
                                              .toggleNormalItemActive(
                                                docId: item.id,
                                                newStatus: val,
                                              );
                                        },
                                      ),
                                    ),
                                    columnWidths[7],
                                  ),
                                  bodyCell(
                                    Row(
                                      children: [
                                        Visibility(
                                          visible: value.canEdit(
                                            AppModules.stock,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.amber,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ItemRegPage(
                                                    docId: item.id,
                                                    item: item,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        Visibility(
                                          visible: value.canDelete(
                                            AppModules.stock,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () =>
                                                _deleteItem(item.id),
                                          ),
                                        ),
                                      ],
                                    ),
                                    columnWidths[8],
                                  ),
                                ],
                              ),
                            ),
                          );
                        } catch (e) {
                          print(
                            "Error building table row for item ${item.id}: $e",
                          );
                          return SizedBox(height: 64, width: totalWidth);
                        }
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

  Future<void> _deleteItem(String id) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Confirm Delete",
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Text(
          "Are you sure you want to delete this item?\nThis action cannot be undone.",
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: colorScheme.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Delete",
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final provider = context.read<Datafeed>();
      final formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final docRef = db.collection('itemsreg').doc(id);

      final snapshot = await docRef.get();

      if (snapshot.exists) {
        final data = snapshot.data()!;

        //deletedcollection
        await db.collection('deletedcollection').add({
          ...data,
          'originalCollection': 'itemsreg',
          'originalId': id,
          'type': 'itemsreg',
          'status': 'deleted',
          'branchid': provider.branchid,
          'deleted_at': FieldValue.serverTimestamp(),
          'deleted_by': provider.staff,
          'deleted_email': provider.staffemail,
          'companyid': provider.companyid,
          'datedmy': formattedDate,
        });
        await docRef.delete();
      }

      final datafeed = context.read<Datafeed>();
      datafeed.items.removeWhere((item) => item.id == id);
      datafeed.notifyListeners();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Item deleted successfully",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to delete item: $e",
              style: TextStyle(color: Theme.of(context).colorScheme.surface),
            ),
          ),
        );
      }
    }
  }
}
