import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/models/itemregmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../../providers/SalesProvider.dart';
import '../../providers/item_provider.dart';

class HamperSection extends StatefulWidget {
  final Datafeed datafeed;
  final String activeBranchId;
  final String activeBranchName;

  const HamperSection({
    super.key,
    required this.datafeed,
    required this.activeBranchId,
    required this.activeBranchName,
  });

  @override
  State<HamperSection> createState() => _HamperSectionState();
}

class _HamperSectionState extends State<HamperSection> {
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String _query = '';
  ItemModel? _selectedBundle;
  String? _selectedWarehouseId;
  bool _isAdding = false;

  void _snackMsg(
    String msg, {
    bool isError = false,
    Duration dur = const Duration(seconds: 2),
  }) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = isError ? colors.error : colors.primary;
    final foregroundColor = isError ? colors.onError : colors.onPrimary;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: foregroundColor)),
        backgroundColor: backgroundColor,
        duration: dur,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context
          .read<ItemProvider>()
          .fetchBundles(datafeed: widget.datafeed)
          .catchError((Object error) {
            if (mounted) {
              _snackMsg('Could not load bundles: $error', isError: true);
            }
          });
    });
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim()),
    );
    _qtyCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  List<ItemModel> get _bundles => context
      .read<ItemProvider>()
      .bundleItems
      .where((b) => b.isActive == true)
      .where(
        (b) =>
            _query.isEmpty ||
            (b.name).toString().toLowerCase().contains(_query.toLowerCase()) ||
            (b.barcode).toString().toLowerCase().contains(_query.toLowerCase()),
      )
      .toList();

  List<Map<String, String>> _bundleWarehouseOptions({
    required List<dynamic> bundleItems,
    required double bundleQuantity,
    required Datafeed datafeed,
    required SalesProvider salesProvider,
  }) {
    final requiredByItem = <String, double>{};
    final itemById = <String, ItemModel>{};

    for (final bundleItem in bundleItems) {
      if (bundleItem is! Map) return [];
      final itemId = bundleItem['itemid']?.toString() ?? '';
      if (itemId.isEmpty) return [];

      final item = datafeed.items.cast<ItemModel?>().firstWhere(
        (candidate) => candidate?.id == itemId,
        orElse: () => null,
      );
      if (item == null) return [];
      itemById[itemId] = item;

      final itemQuantity =
          double.tryParse(bundleItem['totalpieces']?.toString() ?? '1') ?? 1;
      requiredByItem[itemId] =
          (requiredByItem[itemId] ?? 0) + itemQuantity * bundleQuantity;
    }

    final assignedWarehouses = <Map<String, String>>[];
    for (var index = 0; index < datafeed.salesWarehouseIds.length; index++) {
      final warehouseId = datafeed.salesWarehouseIds[index];
      final hasAllStock = requiredByItem.entries.every((request) {
        final item = itemById[request.key]!;
        final availableWarehouseIds = salesProvider
            .availableSalesWarehousesForItem(datafeed, item);
        if (!availableWarehouseIds.contains(warehouseId)) return false;

        final balance = salesProvider.resolveBranchBalance(
          item.branchbalance,
          warehouseId,
          datafeed,
        );
        return salesProvider.parseNetPieces(balance) >= request.value;
      });
      if (!hasAllStock) continue;

      assignedWarehouses.add({
        'id': warehouseId,
        'name':
            index < datafeed.salesWarehouseNames.length &&
                datafeed.salesWarehouseNames[index].isNotEmpty
            ? datafeed.salesWarehouseNames[index]
            : warehouseId,
      });
    }
    return assignedWarehouses;
  }

  void _selectBundle(ItemModel bundle) {
    setState(() {
      _selectedBundle = bundle;
      _searchCtrl.text = bundle.name;
      _query = '';
    });
  }

  void _clearBundleSelection() {
    setState(() {
      _selectedBundle = null;
      _selectedWarehouseId = null;
    });
  }

  void _addBundleToCart() {
    if (_selectedBundle == null) return;

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1;

    if (qty <= 0) {
      _snackMsg("Quantity is less than 1", isError: true);
      return;
    }

    final bundleslist = (_selectedBundle?.items as List?) ?? [];

    if (bundleslist.isEmpty) {
      _snackMsg('Bundle has no items', isError: true);
      return;
    }

    final datafeed = context.read<Datafeed>();
    final salesProvider = context.read<SalesProvider>();
    final isSalesPoint = datafeed.isSalesPoint;
    final warehouseOptions = isSalesPoint
        ? _bundleWarehouseOptions(
            bundleItems: bundleslist,
            bundleQuantity: qty,
            datafeed: datafeed,
            salesProvider: salesProvider,
          )
        : const <Map<String, String>>[];

    if (isSalesPoint && warehouseOptions.isEmpty) {
      final message = datafeed.salesWarehouseIds.isEmpty
          ? 'No warehouse is assigned to this sales point.'
          : 'No assigned warehouse has enough stock for every item in this bundle.';
      _snackMsg(message, isError: true);
      return;
    }

    final selectedWarehouseId = _selectedWarehouseId;
    final warehouseId = !isSalesPoint
        ? widget.activeBranchId
        : selectedWarehouseId != null &&
              warehouseOptions.any(
                (option) => option['id'] == selectedWarehouseId,
              )
        ? selectedWarehouseId
        : datafeed.salesWarehouseId != null &&
              warehouseOptions.any(
                (option) => option['id'] == datafeed.salesWarehouseId,
              )
        ? datafeed.salesWarehouseId!
        : warehouseOptions.first['id']!;
    final warehouseName = isSalesPoint
        ? warehouseOptions.firstWhere(
            (option) => option['id'] == warehouseId,
          )['name']!
        : widget.activeBranchName;

    final requiredByItem = <String, double>{};
    final itemById = <String, ItemModel>{};
    for (final bundleItem in bundleslist) {
      final itemId = bundleItem['itemid'];
      ItemModel? realItem;
      try {
        realItem = datafeed.items.firstWhere((item) => item.id == itemId);
      } catch (_) {
        realItem = null;
      }

      if (realItem == null) {
        _snackMsg('Item not found: $itemId', isError: true);
        return;
      }

      final itemIdString = itemId?.toString() ?? '';
      itemById[itemIdString] = realItem;
      final bundleQty =
          double.tryParse(bundleItem['totalpieces']?.toString() ?? '1') ?? 1;
      requiredByItem[itemIdString] =
          (requiredByItem[itemIdString] ?? 0) + bundleQty * qty;
    }

    for (final request in requiredByItem.entries) {
      final realItem = itemById[request.key]!;
      final branchBalance = salesProvider.resolveBranchBalance(
        realItem.branchbalance,
        warehouseId,
        datafeed,
      );

      final availablePieces = salesProvider.parseNetPieces(branchBalance);

      if (request.value > availablePieces) {
        _snackMsg(
          'Insufficient stock for ${realItem.name} (${availablePieces.toStringAsFixed(0)} available)',
          isError: true,
        );
        return;
      }
    }

    if (mounted) {
      setState(() => _isAdding = true);
    }

    for (final bundle in bundleslist) {
      // bundle  qty × number of bundles ordered

      final bundlepiece =
          double.tryParse(bundle['totalpieces']?.toString() ?? '1') ?? 1;
      final amount =
          double.tryParse(bundle['totalamount']?.toString() ?? '1') ?? 1;
      final totalpiece = bundlepiece * qty;
      final totalamount = amount * qty;
      final modeqtyRaw = bundle['modeqty'] ?? '1';
      final modeqty = double.tryParse(modeqtyRaw.toString()) ?? 1;

      final unitPrice = bundle['price']?.toString() ?? '0';

      salesProvider.addToSalesPreview({
        'itemid': bundle['itemid'] ?? '',
        'branchid': warehouseId,
        'branchname': warehouseName,
        'branchtype': isSalesPoint
            ? datafeed.branchtype
            : widget.activeBranchName,
        'modeqty': modeqty.toString(),
        //'item': '${bundle['item']} ($bundlepiece in ${_selectedBundle?.name ?? ''})',
        'item': '${bundle['item']} ( ${_selectedBundle?.name ?? ''})',
        'barcode': bundle['barcode'] ?? '',
        'mode': '${bundle['mode'] ?? 'single'}',
        'quantity': '$totalpiece',
        'price': unitPrice,
        'discount': bundle['discount']?.toString() ?? '0',
        'cp': bundle['cp'] ?? '0',
        'totalpieces': totalpiece.toString(),
        'totalamount': totalamount.toStringAsFixed(2),
        'pricemode': bundle['pricemode'] ?? 'retail',
        'bundle': _selectedBundle?.id ?? '',
        'bundleName': _selectedBundle!.name,
        'pcategory': _selectedBundle?.pcategory ?? '',
        'producttype': _selectedBundle?.producttype ?? '',
      });
    }
    if (mounted) {
      setState(() {
        _isAdding = false;
        _selectedBundle = null;
        _selectedWarehouseId = null;
        _searchCtrl.clear();
        _qtyCtrl.text = '1';
        _query = '';
      });
    }
    _snackMsg('Bundle added to cart');
  }

  InputDecoration _decorateInputField(String hint) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
      prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant, size: 20),
      filled: true,
      fillColor: colors.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      suffixIcon: _query.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.close, color: colors.onSurfaceVariant, size: 18),
              onPressed: () {
                _searchCtrl.clear();
                _clearBundleSelection();
              },
            )
          : null,
    );
  }

  Widget _buildBundleWarehouseSelector(
    ColorScheme colors,
    List<Map<String, String>> options,
    Datafeed datafeed,
  ) {
    if (options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          datafeed.salesWarehouseIds.isEmpty
              ? 'No warehouses assigned to this account. Contact admin.'
              : 'No assigned warehouse has enough stock for every item in this bundle.',
          style: TextStyle(color: colors.error, fontSize: 12),
        ),
      );
    }

    final assignedValue =
        options.any((option) => option['id'] == _selectedWarehouseId)
        ? _selectedWarehouseId
        : options.any((option) => option['id'] == datafeed.salesWarehouseId)
        ? datafeed.salesWarehouseId
        : options.first['id'];

    if (assignedValue != _selectedWarehouseId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || assignedValue == null) return;
        setState(() => _selectedWarehouseId = assignedValue);
      });
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sell Bundle From Warehouse',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: assignedValue,
            isExpanded: true,
            dropdownColor: colors.surfaceContainerHighest,
            style: TextStyle(color: colors.onSurface),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.warehouse_outlined, color: colors.primary),
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
            items: options
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option['id'],
                    child: Text(
                      option['name']!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (warehouseId) {
              if (warehouseId == null) return;
              setState(() => _selectedWarehouseId = warehouseId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ItemProvider>();
    final colors = Theme.of(context).colorScheme;
    final bundles = _bundles;
    final hasSel = _selectedBundle != null;
    final bundleItems = (_selectedBundle?.items as List?) ?? [];
    final bundleQuantity = double.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final warehouseOptions = widget.datafeed.isSalesPoint && hasSel
        ? _bundleWarehouseOptions(
            bundleItems: bundleItems,
            bundleQuantity: bundleQuantity,
            datafeed: widget.datafeed,
            salesProvider: context.read<SalesProvider>(),
          )
        : const <Map<String, String>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.card_giftcard, color: colors.onSurfaceVariant, size: 18),
            const SizedBox(width: 6),
            Text(
              'Bundle',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Search box
        TextFormField(
          controller: _searchCtrl,
          style: TextStyle(color: colors.onSurface),
          decoration: _decorateInputField('Search bundle or hamper name…'),
        ),

        // Suggestions
        if (_query.isNotEmpty && !hasSel && bundles.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: bundles.length,
              itemBuilder: (_, i) {
                final b = bundles[i];
                final count = (b.items as List?)?.length ?? 0;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.card_giftcard,
                    color: colors.onSurface,
                    size: 18,
                  ),
                  title: Text(
                    (b.name).toString(),
                    style: TextStyle(color: colors.onSurface, fontSize: 13),
                  ),
                  subtitle: Text(
                    '$count item(s)',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  onTap: () {
                    _selectBundle(b);
                  },
                );
              },
            ),
          ),

        if (_query.isNotEmpty && !hasSel && bundles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No bundles found',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),

        //Selected bundle + qty + Add button
        if (hasSel) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.card_giftcard,
                      color: colors.onSurface,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (_selectedBundle?.name ?? '').toString(),
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    // Qty stepper
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: colors.onSurfaceVariant,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        final v = (int.tryParse(_qtyCtrl.text) ?? 1) - 1;
                        _qtyCtrl.text = (v < 1 ? 1 : v).toString();
                      },
                    ),
                    SizedBox(
                      width: 48,
                      child: TextFormField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: colors.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: colors.onSurfaceVariant,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        final v = (int.tryParse(_qtyCtrl.text) ?? 1) + 1;
                        _qtyCtrl.text = v.toString();
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isAdding ? null : _addBundleToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.secondary,
                        foregroundColor: colors.onSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isAdding
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onSecondary,
                              ),
                            )
                          : const Text(
                              'Add',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
                if (widget.datafeed.isSalesPoint)
                  _buildBundleWarehouseSelector(
                    colors,
                    warehouseOptions,
                    widget.datafeed,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
