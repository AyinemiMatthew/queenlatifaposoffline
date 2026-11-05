import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/itemregmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../models/branch.dart';
import '../models/itemmodel.dart';
import '../models/salesmodel.dart';
import '../paymentwidgets/BarcodeScannerScreen.dart';
import '../paymentwidgets/customerinfodialog.dart';
import '../paymentwidgets/momoDialog.dart';
import '../paymentwidgets/printDialog.dart';
import '../providers/SalesProvider.dart';
import '../widgets/salespagewidgets/hamper.dart';
import '../widgets/salespagewidgets/mobilesalespreview.dart';
import '../widgets/salespagewidgets/snackmsg.dart';
import '../widgets/salespagewidgets/validators/salespagevalidator.dart';
import '../widgets/offline_indicator.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  ColorScheme get _colorScheme => Theme.of(context).colorScheme;
  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _primaryText =>
      _isLightTheme ? _colorScheme.onSurface : Colors.white;
  Color get _secondaryText =>
      _isLightTheme ? _colorScheme.onSurfaceVariant : Colors.white70;
  Color get _successText =>
      _isLightTheme ? Colors.green.shade700 : Colors.greenAccent;
  Color get _panelSurface => _isLightTheme
      ? _colorScheme.surfaceContainerHighest
      : const Color(0xFF22304A);
  Color get _outlineColor =>
      _isLightTheme ? _colorScheme.outline : Colors.white24;
  ColorScheme get _datePickerColorScheme => _isLightTheme
      ? _colorScheme
      : _colorScheme.copyWith(
          primary: Colors.blue,
          onPrimary: Colors.white,
          surface: _panelSurface,
          onSurface: Colors.white,
        );

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _totalPiecesController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedSalesMode;
  List<String> _salesMode = [];
  String? _selectedPriceMode;
  List<dynamic> _priceMode = [];
  Map<String, dynamic>? _itemModes;
  Map<String, dynamic>? _currentModeData;
  bool showHamperSection = false;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  bool _showMobilePreview = false;
  ItemModel? _selectedItem;
  String _searchQuery = '';

  String branchid = "";
  String branchtype = "";
  String _superAdminBranchId = "";
  String _superAdminBranchName = "";
  String _displayBranchName = "";
  String get _activeBranchId {
    final datafeed = Provider.of<Datafeed>(context, listen: false);
    if (datafeed.isSalesPoint &&
        (datafeed.salesWarehouseId?.isNotEmpty ?? false)) {
      return datafeed.salesWarehouseId!;
    }
    return _superAdminBranchId.isNotEmpty
        ? _superAdminBranchId
        : branchid.isNotEmpty
        ? branchid
        : datafeed.activeBranchId;
  }

  String get _activeBranchName {
    final datafeed = Provider.of<Datafeed>(context, listen: false);
    if (datafeed.isSalesPoint &&
        (datafeed.salesWarehouseName?.isNotEmpty ?? false)) {
      return datafeed.salesWarehouseName!;
    }
    return _superAdminBranchName.isNotEmpty
        ? _superAdminBranchName
        : datafeed.activeBranchName;
  }

  String? cp;
  Map<String, dynamic>? branchbalance;
  final List<Map<String, dynamic>>? items = [];
  final TextEditingController _discountCodeController = TextEditingController();
  String? _appliedDiscountCode;
  bool _showDiscountCodeField = false;
  final TextEditingController _bulkDiscountController = TextEditingController();
  bool _isSavingDirect = false;
  bool _isNormalizingQuantity = false;
  late final Datafeed _datafeed;
  BranchModel? _originalBranch;
  String? _originalSalesWarehouseId;
  String? _originalSalesWarehouseName;
  Future<void>? _branchSwitchFuture;
  Future<void>? _restoreBranchFuture;
  bool _hasTemporaryBranchSwitch = false;

  bool get _quantityLimitedSalesMode {
    final mode = (_selectedSalesMode ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();
    return (mode.contains('half') && mode.contains('carton')) ||
        RegExp(r'\bpack\b').hasMatch(mode) ||
        RegExp(r'\bquarter\b').hasMatch(mode) ||
        mode.contains('1/4') ||
        mode.contains('¼');
  }

  bool _isFullCartonMode(String mode) {
    final normalized = mode
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();
    final isPartialCarton =
        normalized.contains('half') ||
        normalized.contains('quarter') ||
        normalized.contains('1/2') ||
        normalized.contains('1/4') ||
        normalized.contains('½') ||
        normalized.contains('¼');
    return normalized.contains('carton') && !isPartialCarton;
  }

  bool _isSplitSalesMode(String mode) {
    final normalized = mode
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();
    return normalized.contains('half') ||
        normalized.contains('quarter') ||
        RegExp(r'\bpack\b').hasMatch(normalized) ||
        normalized.contains('½') ||
        normalized.contains('¼') ||
        normalized.contains('1/2') ||
        normalized.contains('1/4');
  }

  String? _validateQuantity(String? value) {
    final quantityError = SalesFormValidators.quantity(value);
    if (quantityError != null) return quantityError;

    final quantity = int.parse(value!);
    if (_quantityLimitedSalesMode && quantity > 1) {
      return 'Quantity for half carton, pack, or quarter is limited to 1';
    }
    return null;
  }

  bool _isSalesPointType(String? t) =>
      (t ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') ==
      'salespoint';

  String get _effectivePriceMode =>
      (_selectedPriceMode ?? '').toLowerCase().trim() == 'wholesale'
      ? 'wholesale'
      : 'retail';

  @override
  void initState() {
    super.initState();
    _datafeed = context.read<Datafeed>();
    _quantityController.text = '1';
    Future.microtask(() async {
      _datafeed.fetchItems();
      _datafeed.fetchBranches();
      _datafeed.fetchDiscountCodes();
      final value = _datafeed;
      await value.getdata();

      if (!mounted) return;
      _originalBranch =
          value.selectedBranch ??
          BranchModel(
            id: value.branchid,
            branchname: value.branch,
            branchtype: value.branchtype,
            address: value.branchaddress,
            branchcontact: value.branchphone,
            companyid: value.companyid,
            companyemail: value.companyemail,
          );
      _originalSalesWarehouseId = value.salesWarehouseId;
      _originalSalesWarehouseName = value.salesWarehouseName;
      if (branchid.isEmpty) {
        branchid = value.branchid;
      }

      _superAdminBranchId = value.branchid;
      _superAdminBranchName = value.branch;
      _displayBranchName = value.branch;
      _barcodeController.addListener(_onBarcodeChanged);
      _quantityController.addListener(_onQuantityChanged);
      _discountController.addListener(_calculateTotals);
      _priceController.addListener(_calculateTotals);

      branchtype = value.branchtype;
      _priceMode = value.pricingmode.map((e) => e.toString()).toList();
      if (_selectedPriceMode == null && _priceMode.isNotEmpty) {
        _selectedPriceMode = _priceMode.first;
      }
    });

    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().setSaleDate(_selectedDate);
    });
  }

  Future<void> _restoreOriginalBranch() {
    final original = _originalBranch;
    if (!_hasTemporaryBranchSwitch || original == null) {
      return Future<void>.value();
    }
    return _restoreBranchFuture ??= _restoreOriginalBranchNow(original);
  }

  Future<void> _restoreOriginalBranchNow(BranchModel original) async {
    try {
      final pendingSwitch = _branchSwitchFuture;
      if (pendingSwitch != null) {
        try {
          await pendingSwitch;
        } catch (error, stackTrace) {
          debugPrint('Sales branch switch failed before restore: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      final restore = _datafeed.setBranch(
        original.id,
        original.branchname,
        original.address,
        original.branchcontact,
        type: original.branchtype,
      );
      _restoreBranchFuture = restore;
      await restore;
      _datafeed.setSalesWarehouse(
        _originalSalesWarehouseId,
        _originalSalesWarehouseName,
      );
      _hasTemporaryBranchSwitch = false;
      if (mounted) {
        setState(() {
          branchid = original.id;
          branchtype = original.branchtype;
          _superAdminBranchId = original.id;
          _superAdminBranchName = original.branchname;
          _displayBranchName = original.branchname;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to restore the original sales branch: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _restoreBranchFuture = null;
    }
  }

  int _currentQuantityValue() {
    final parsed = int.tryParse(_quantityController.text.trim());
    if (parsed == null || parsed <= 0) return 1;
    return parsed;
  }

  void _setQuantityValue(int value) {
    final normalized = _quantityLimitedSalesMode
        ? (value > 1 ? 1 : value)
        : value <= 0
        ? 1
        : value;
    final text = normalized.toString();
    _quantityController.text = text;
    _quantityController.selection = TextSelection.collapsed(
      offset: text.length,
    );
  }

  void _incrementQuantity() {
    _setQuantityValue(_currentQuantityValue() + 1);
  }

  void _decrementQuantity() {
    final next = _currentQuantityValue() - 1;
    _setQuantityValue(next <= 0 ? 1 : next);
  }

  String _calculateGrossAmount() {
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final qty = (int.tryParse(_quantityController.text.trim()) ?? 0).toDouble();

    final gross = price * qty;

    return gross.toStringAsFixed(2);
  }

  void _refreshPricingForBranch(String newBranchId) {
    if (_selectedItem == null) return;

    final item = _selectedItem!;
    Map<String, dynamic> effectivePricing = {};

    final branchPrices = item.branchprices;
    final modes = item.modes;

    if (branchPrices != null &&
        branchPrices.containsKey(newBranchId) &&
        branchPrices[newBranchId]['pricing'] != null) {
      effectivePricing = Map<String, dynamic>.from(
        branchPrices[newBranchId]['pricing'],
      );
    } else if (modes != null) {
      for (var mode in modes) {
        effectivePricing[mode.name] = {
          'id': mode.id,
          'name': mode.name,
          'qty': mode.qty,
          'cp': mode.cp,
          'rp': mode.rp,
          'wp': mode.wp,
          'sp': mode.sp,
        };
      }
    }

    _itemModes = effectivePricing;

    if (_itemModes != null && _itemModes!.isNotEmpty) {
      _salesMode = _itemModes!.entries.map((e) {
        final data = e.value as Map<String, dynamic>;
        return data['name']?.toString() ?? e.key;
      }).toList();

      final bool isWholesale = _effectivePriceMode == 'wholesale';
      double cartonQty = 0;
      for (final entry in _itemModes!.entries) {
        if (entry.key.toLowerCase().trim() == 'carton') {
          cartonQty =
              double.tryParse(entry.value['qty']?.toString() ?? '0') ?? 0;
          break;
        }
      }
      if (isWholesale) {
        final cartonModes = _salesMode
            .where((mode) => mode.toLowerCase().contains('carton'))
            .toList();
        if (cartonQty <= 1) {
          final baseModes = cartonModes.isNotEmpty
              ? cartonModes
              : _salesMode
                    .where((mode) => mode.toLowerCase().trim() == 'single')
                    .toList();
          _salesMode = [
            ...baseModes,
            ..._salesMode.where(
              (mode) => _isSplitSalesMode(mode) && !baseModes.contains(mode),
            ),
          ];
        } else {
          _salesMode = cartonModes;
        }
        if (_salesMode.isEmpty) {
          _salesMode = _itemModes!.entries.map((e) {
            final data = e.value as Map<String, dynamic>;
            return data['name']?.toString() ?? e.key;
          }).toList();
        }
        _salesMode.sort((a, b) {
          if (a.toLowerCase() == 'carton') return -1;
          if (b.toLowerCase() == 'carton') return 1;
          return 0;
        });
      } else {
        if (cartonQty <= 1) {
          final nonCartonModes = _salesMode
              .where((mode) => !_isFullCartonMode(mode))
              .toList();
          if (nonCartonModes.isNotEmpty) {
            _salesMode = nonCartonModes;
          }
        }
        final first = context.read<Datafeed>().isSalesPoint
            ? 'carton'
            : 'single';
        _salesMode.sort((a, b) {
          if (a.toLowerCase() == first) return -1;
          if (b.toLowerCase() == first) return 1;
          return 0;
        });
      }

      if (!_salesMode.contains(_selectedSalesMode)) {
        _selectedSalesMode = _salesMode.first;
      }
    } else {
      _salesMode = const ['single'];
      _selectedSalesMode = null;
      _currentModeData = null;
    }
    // Recalculate price under new branch
    _updatePrice();
  }

  @override
  void dispose() {
    if (_hasTemporaryBranchSwitch) {
      unawaited(_restoreOriginalBranch());
    }
    _barcodeController.removeListener(_onBarcodeChanged);
    _quantityController.removeListener(_onQuantityChanged);
    _discountController.removeListener(_calculateTotals);
    _priceController.removeListener(_calculateTotals);
    _discountCodeController.dispose();
    _bulkDiscountController.dispose();
    // _dateController.clear();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
      );

      if (result != null && result is String) {
        setState(() {
          _barcodeController.text = result;
        });
        _formKey.currentState?.validate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening scanner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onBarcodeChanged() {
    setState(() {
      _searchQuery = _barcodeController.text.trim();
      _showSuggestions = _searchQuery.isNotEmpty;
    });
  }

  void _onQuantityChanged() {
    if (_isNormalizingQuantity) return;

    final enteredQuantity = int.tryParse(_quantityController.text.trim());
    if (_quantityLimitedSalesMode &&
        enteredQuantity != null &&
        enteredQuantity > 1) {
      _isNormalizingQuantity = true;
      _quantityController.value = const TextEditingValue(
        text: '1',
        selection: TextSelection.collapsed(offset: 1),
      );
      _isNormalizingQuantity = false;
    }
    _updatePrice();
  }

  void _handleQuantityInput(String value) {
    final enteredQuantity = int.tryParse(value.trim());
    if (_quantityLimitedSalesMode &&
        enteredQuantity != null &&
        enteredQuantity > 1) {
      _setQuantityValue(1);
      return;
    }
    _onQuantityChanged();
  }

  void _calculateTotals() {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);

    final result = salesProvider.calculateTotals(
      quantityText: _quantityController.text,
      priceText: _priceController.text,
      discountText: _discountController.text,
      modeData: _currentModeData,
    );

    _totalPiecesController.text = result['pieces']!;
    _totalAmountController.text = result['amount']!;

    setState(() {});
  }

  bool _isSalesBranchType(String? t) =>
      (t ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') ==
      'salesbranch';

  bool _isWarehouseType(String? t) =>
      (t ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') == 'warehouse';

  List<BranchModel> _assignedWarehousesForItem(
    Datafeed datafeed,
    SalesProvider salesProvider,
    ItemModel? item,
  ) {
    final assignedIds = datafeed.salesWarehouseIds
        .map((id) => id.toLowerCase())
        .toSet();
    final warehouses = datafeed.branches
        .where(
          (branch) =>
              assignedIds.contains(branch.id.toLowerCase()) &&
              _isWarehouseType(branch.branchtype),
        )
        .toList();
    if (item == null ||
        item.producttype.toLowerCase().trim() == 'service' ||
        !datafeed.stockCheckEnabled) {
      return warehouses;
    }
    return warehouses.where((warehouse) {
      final balance =
          item.branchbalance?[warehouse.id] as Map<String, dynamic>? ?? {};
      return salesProvider.parseNetPieces(balance) > 0;
    }).toList();
  }

  Widget _buildSalesWarehouseSelector(Datafeed datafeed) {
    InputDecoration deco(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      floatingLabelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );

    if (datafeed.canSellAnyBranch) {
      final sp = Provider.of<SalesProvider>(context, listen: false);

      final allBranches = datafeed.branches
          .where((b) {
            final isSalesBranch = _isSalesBranchType(b.branchtype);
            final isSalesPointBranch = _isSalesPointType(b.branchtype);
            return isSalesBranch || isSalesPointBranch;
          })
          .fold<Map<String, BranchModel>>({}, (map, b) {
            if (!map.containsKey(b.id)) map[b.id] = b;
            return map;
          })
          .values
          .toList();

      if (datafeed.branches.isEmpty) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text(
            'Loading branches -',
            style: TextStyle(color: _secondaryText),
          ),
        );
      }

      final item = _selectedItem;
      final isService =
          (item?.producttype ?? '').toLowerCase().trim() == 'service';
      final bool filterByBalance =
          item != null && !isService && datafeed.stockCheckEnabled;

      double balanceOf(String id) {
        final bal = item?.branchbalance?[id] as Map<String, dynamic>? ?? {};
        return sp.parseNetPieces(bal);
      }

      double boxQty = 1.0;
      final modes = item?.modes;
      if (modes != null) {
        final carton = modes.where((m) => m.name.toLowerCase() == 'carton');
        final single = modes.where((m) => m.name.toLowerCase() == 'single');
        final qtyString = carton.isNotEmpty
            ? carton.first.qty
            : single.isNotEmpty
            ? single.first.qty
            : '1';
        boxQty = double.tryParse(qtyString) ?? 1.0;
      }

      final available = filterByBalance
          ? allBranches
                .where(
                  (b) => _isSalesPointType(b.branchtype) || balanceOf(b.id) > 0,
                )
                .toList()
          : allBranches;

      if (available.isEmpty) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text(
            item == null
                ? 'No sales branches or sales points are available.'
                : 'No sales branches or sales points have stock for this item.',
            style: TextStyle(
              color: _colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        );
      }

      Future<void> applyBranch(BranchModel b) async {
        try {
          final branchChanged = datafeed.branchid != b.id;
          _hasTemporaryBranchSwitch = true;
          final switchBranch = datafeed.setBranch(
            b.id,
            b.branchname,
            b.address,
            b.branchcontact,
            type: b.branchtype,
            temporarySalesSwitch: true,
          );
          _branchSwitchFuture = switchBranch;
          await switchBranch;
          if (identical(_branchSwitchFuture, switchBranch)) {
            _branchSwitchFuture = null;
          }
          if (!mounted) return;
          if (branchChanged) {
            sp.clearCurrentCart();
            _resetForm(clearSelectedItem: true);
          }
          String branchForPricing = b.id;
          if (_isSalesPointType(b.branchtype)) {
            final assignedWarehouses = _assignedWarehousesForItem(
              datafeed,
              sp,
              _selectedItem,
            );
            final warehouse = assignedWarehouses
                .where(
                  (warehouse) =>
                      warehouse.id.toLowerCase() ==
                      (datafeed.salesWarehouseId ?? '').toLowerCase(),
                )
                .firstOrNull;
            datafeed.setSalesWarehouse(warehouse?.id, warehouse?.branchname);
            branchForPricing = datafeed.salesWarehouseId ?? b.id;
          } else {
            datafeed.setSalesWarehouse(null, null);
          }
          if (!mounted) return;
          setState(() {
            branchid = b.id;
            branchtype = b.branchtype;
            _superAdminBranchId = b.id;
            _superAdminBranchName = b.branchname;
            _displayBranchName = b.branchname;
            _refreshPricingForBranch(branchForPricing);
          });
        } catch (error) {
          _branchSwitchFuture = null;
          if (!mounted) return;
          snackMsg(context, 'Could not switch branch: $error', Colors.red);
        }
      }

      final availableIds = available.map((b) => b.id).toList();
      final current = _superAdminBranchId.isNotEmpty
          ? _superAdminBranchId
          : datafeed.branchid;
      final safeValue = availableIds.contains(current) ? current : null;

      final branchDropdown = Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: DropdownButtonFormField<String>(
          key: ValueKey('branch_${item?.id ?? 'none'}_$safeValue'),
          value: safeValue,
          isExpanded: true,
          dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: deco('Sell From (Sales Branch / Sales Point)'),
          hint: Text(
            'Select a sales branch or point',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          items: available.map((b) {
            final pcs = balanceOf(b.id);
            final boxes = boxQty > 0 ? pcs / boxQty : 0.0;
            final typeLabel = b.branchtype.isNotEmpty
                ? ' (${b.branchtype})'
                : '';
            final label =
                item == null || isService || _isSalesPointType(b.branchtype)
                ? '${b.branchname}$typeLabel'
                : '${b.branchname}$typeLabel - ${pcs.toStringAsFixed(0)} pcs / ${boxes.toStringAsFixed(2)} boxes';
            return DropdownMenuItem<String>(
              value: b.id,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            );
          }).toList(),
          onChanged: (v) async {
            if (v == null) return;
            final selected = available.firstWhere((b) => b.id == v);
            await applyBranch(selected);
          },
        ),
      );
      if (!datafeed.isSalesPoint) return branchDropdown;

      final assignedWarehouses = datafeed.branches
          .where(
            (branch) =>
                datafeed.salesWarehouseIds.any(
                  (id) => id.toLowerCase() == branch.id.toLowerCase(),
                ) &&
                _isWarehouseType(branch.branchtype),
          )
          .toList();
      if (assignedWarehouses.isEmpty) {
        return Column(
          children: [
            branchDropdown,
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No warehouse is assigned to your staff account for this Sales Point.',
                style: TextStyle(color: _colorScheme.error),
              ),
            ),
          ],
        );
      }

      if (item == null || isService) {
        return Column(
          children: [
            branchDropdown,
            if (item == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Select an item to see assigned warehouses with stock.',
                  style: TextStyle(color: _secondaryText),
                ),
              ),
          ],
        );
      }

      final itemWarehouses = _assignedWarehousesForItem(datafeed, sp, item);
      if (itemWarehouses.isEmpty) {
        return Column(
          children: [
            branchDropdown,
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No assigned warehouse has stock for this item.',
                style: TextStyle(color: _colorScheme.error),
              ),
            ),
          ],
        );
      }

      final warehouseIds = itemWarehouses.map((e) => e.id).toSet();
      final currentWarehouse = datafeed.salesWarehouseId;
      final selectedWarehouseId =
          currentWarehouse != null && warehouseIds.contains(currentWarehouse)
          ? currentWarehouse
          : itemWarehouses.first.id;
      if (selectedWarehouseId != currentWarehouse) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !datafeed.isSalesPoint ||
              _selectedItem?.id != item.id) {
            return;
          }
          final warehouse = itemWarehouses.firstWhere(
            (item) => item.id == selectedWarehouseId,
          );
          datafeed.setSalesWarehouse(warehouse.id, warehouse.branchname);
          _refreshPricingForBranch(warehouse.id);
        });
      }

      return Column(
        children: [
          branchDropdown,
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                'assigned_warehouse_${item.id}_$selectedWarehouseId',
              ),
              initialValue: selectedWarehouseId,
              isExpanded: true,
              dropdownColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: deco('Sell From Assigned Warehouse'),
              items: itemWarehouses.map((warehouse) {
                final balance =
                    item.branchbalance?[warehouse.id]
                        as Map<String, dynamic>? ??
                    {};
                final pieces = sp.parseNetPieces(balance);
                return DropdownMenuItem<String>(
                  value: warehouse.id,
                  child: Text(
                    '${warehouse.branchname} - ${pieces.toStringAsFixed(0)} pcs',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id == null) return;
                final warehouse = itemWarehouses.firstWhere(
                  (candidate) => candidate.id == id,
                );
                datafeed.setSalesWarehouse(id, warehouse.branchname);
                _refreshPricingForBranch(id);
                setState(() {});
              },
            ),
          ),
        ],
      );
    }

    if (datafeed.branchid.isEmpty) return const SizedBox.shrink();
    final branchDropdown = Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        key: ValueKey('own_branch_${datafeed.branchid}'),
        value: datafeed.branchid,
        isExpanded: true,
        dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: deco('Branch'),
        items: [
          DropdownMenuItem<String>(
            value: datafeed.branchid,
            child: Text(
              datafeed.branch,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
        onChanged: null,
      ),
    );
    if (!datafeed.isSalesPoint) return branchDropdown;

    final item = _selectedItem;
    if (item == null) {
      return Column(
        children: [
          branchDropdown,
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Select an item first to choose warehouse.',
              style: TextStyle(color: _secondaryText),
            ),
          ),
        ],
      );
    }

    if (item.producttype.toLowerCase().trim() == 'service') {
      return branchDropdown;
    }

    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final assignedIds = datafeed.salesWarehouseIds
        .map((id) => id.toLowerCase())
        .toSet();
    final itemWarehouseIds = salesProvider
        .availableSalesWarehousesForItem(datafeed, item)
        .map((id) => id.toLowerCase())
        .toSet();
    final itemWarehouses = datafeed.branches
        .where(
          (branch) =>
              assignedIds.contains(branch.id.toLowerCase()) &&
              itemWarehouseIds.contains(branch.id.toLowerCase()) &&
              _isWarehouseType(branch.branchtype),
        )
        .toList();

    if (itemWarehouses.isEmpty) {
      return Column(
        children: [
          branchDropdown,
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'No assigned warehouse has a balance for this item.',
              style: TextStyle(color: _colorScheme.error),
            ),
          ),
        ],
      );
    }

    final currentWarehouse = datafeed.salesWarehouseId;
    final selectedWarehouseId =
        itemWarehouses.any((warehouse) => warehouse.id == currentWarehouse)
        ? currentWarehouse!
        : itemWarehouses.first.id;
    if (selectedWarehouseId != currentWarehouse) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            datafeed.canSellAnyBranch ||
            !datafeed.isSalesPoint ||
            _selectedItem?.id != item.id) {
          return;
        }
        final warehouse = itemWarehouses.firstWhere(
          (entry) => entry.id == selectedWarehouseId,
        );
        datafeed.setSalesWarehouse(warehouse.id, warehouse.branchname);
        _refreshPricingForBranch(warehouse.id);
      });
    }

    double boxQty = 1;
    final carton = item.modes?.where(
      (mode) => mode.name.toLowerCase() == 'carton',
    );
    if (carton != null && carton.isNotEmpty) {
      boxQty = double.tryParse(carton.first.qty) ?? 1;
    }

    return Column(
      children: [
        branchDropdown,
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            key: ValueKey(
              'own_assigned_warehouse_${item.id}_$selectedWarehouseId',
            ),
            initialValue: selectedWarehouseId,
            isExpanded: true,
            dropdownColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: deco('Sell From Assigned Warehouse'),
            items: itemWarehouses.map((warehouse) {
              final balance =
                  item.branchbalance?[warehouse.id] as Map<String, dynamic>? ??
                  {};
              final pieces = salesProvider.parseNetPieces(balance);
              final boxes = boxQty > 0 ? pieces / boxQty : 0;
              return DropdownMenuItem<String>(
                value: warehouse.id,
                child: Text(
                  '${warehouse.branchname} - ${pieces.toStringAsFixed(0)} pcs / ${boxes.toStringAsFixed(2)} boxes',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (id) {
              if (id == null) return;
              final warehouse = itemWarehouses.firstWhere(
                (entry) => entry.id == id,
              );
              datafeed.setSalesWarehouse(id, warehouse.branchname);
              _refreshPricingForBranch(id);
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addToSalesPreview() async {
    if (_formKey.currentState!.validate()) {
      final datafeed = Provider.of<Datafeed>(context, listen: false);
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      final isService =
          (_selectedItem?.producttype ?? '').toLowerCase().trim() == 'service';

      if (!isService &&
          datafeed.isSalesPoint &&
          !datafeed.salesWarehouseIds.any(
            (id) =>
                id.toLowerCase() ==
                (datafeed.salesWarehouseId ?? '').toLowerCase(),
          )) {
        snackMsg(
          context,
          'Select an assigned warehouse to sell from this Sales Point.',
          Colors.orange,
        );
        return;
      }

      if (!isService &&
          datafeed.isSalesPoint &&
          !salesProvider.ensureSalesWarehouseSelected(
            context,
            datafeed,
            _selectedItem,
          ))
        return;

      final activeBranchId = _activeBranchId;
      final activeBranchName = _activeBranchName;

      final balanceBranchId = activeBranchId;
      final balanceBranchName = activeBranchName;
      final balanceBranchType = datafeed.isSalesPoint
          ? datafeed.branches
                .firstWhere(
                  (b) => b.id == balanceBranchId,
                  orElse: () => BranchModel(),
                )
                .branchtype
          : branchtype;
      final totalPieces = double.tryParse(_totalPiecesController.text) ?? 0;

      if (!isService && datafeed.stockCheckEnabled) {
        final branchBalance = salesProvider.resolveBranchBalance(
          _selectedItem?.branchbalance,
          balanceBranchId,
          datafeed,
        );

        final availableNetPieces = salesProvider.parseNetPieces(branchBalance);

        if (totalPieces > availableNetPieces) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        _syncItemBalance(
                          _selectedItem?.id ?? '',
                          _selectedItem?.name ?? '',
                          balanceBranchId,
                          balanceBranchName,
                        );
                      },
                      child: Text(
                        'Click to update balance ',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Insufficient stock: ${availableNetPieces.toStringAsFixed(0)} pcs available',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }

      double totalAmt = double.parse(_totalAmountController.text.toString());
      double totalpcs = double.parse(_totalPiecesController.text.toString());
      double cp = double.tryParse(_selectedItem?.cp ?? '') ?? 0;

      double sp =
          double.tryParse(
            _itemModes?['single']?['rp']?.toString() ??
                _itemModes?['Single']?['rp']?.toString() ??
                '0',
          ) ??
          0;

      double profitonsale = totalAmt - (totalpcs * cp);

      final salesItem = {
        'itemid': _selectedItem?.id ?? '',
        'branchid': balanceBranchId,
        'branchname': balanceBranchName,
        'branchtype': balanceBranchType,
        'modeqty': _currentModeData?['qty'] ?? '',
        'item': _itemController.text.toString(),
        'barcode': _barcodeController.text.trim().toString(),
        'mode': _selectedSalesMode ?? '',
        'quantity': _quantityController.text.trim().toString(),
        'price': _priceController.text.trim().toString(),
        'profit': profitonsale.toString(),
        'discount': _discountController.text.trim().toString().isEmpty
            ? '0'
            : _discountController.text.trim().toString(),
        'cp': cp.toString(),
        'sp': sp.toString(),
        'pcategory': _selectedItem?.pcategory ?? '',
        'producttype': _selectedItem?.producttype ?? '',
        'totalpieces': totalpcs.toString(),
        'totalamount': totalAmt.toString(),
        'grosstotalamount': _calculateGrossAmount(),
        'pricemode': _effectivePriceMode,
        'boxpiece':
            (_itemModes?['carton']?['qty'] ??
            _itemModes?['Carton']?['qty'] ??
            '1'),
        'stockcheck': datafeed.stockCheckEnabled,
      };
      salesProvider.addToSalesPreview(salesItem);

      if (_appliedDiscountCode != null) {
        await context.read<Datafeed>().markDiscountCodeUsed(
          _appliedDiscountCode!,
          usedBy: Provider.of<Datafeed>(context, listen: false).staff,
          usedBranch: Provider.of<Datafeed>(context, listen: false).branch,
        );
      }

      //Clear form
      _resetForm();
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Item added to sales preview',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveDirectSale() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final datafeed = Provider.of<Datafeed>(context, listen: false);
    final salesItems = salesProvider.salesItems;

    if (_isSavingDirect || salesItems.isEmpty) {
      if (salesItems.isEmpty)
        snackMsg(context, 'Please add items to the sale first', Colors.red);
      return;
    }

    final activeBranchId = _activeBranchId;
    final activeBranchName = _activeBranchName;

    setState(() => _isSavingDirect = true);

    try {
      if (datafeed.isOffline) {
        snackMsg(
          context,
          'Offline sales are available only from Print Dialog when stock checking is disabled.',
          Colors.orange,
        );
        return;
      }

      if (datafeed.stockCheckEnabled) {
        final isValid = await salesProvider.validateCartStockOnSaves(
          activeBranchId,
        );
        if (!mounted) return;
        if (!isValid) {
          snackMsg(
            context,
            'Insufficient stock detected. Please adjust cart.',
            Colors.red,
          );
          return;
        }
      }

      final double totalDiscount = salesProvider.calculateDiscountTotal();
      final double grossTotal = salesProvider.calculateGrossTotal();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final saleDocId =
          '${datafeed.companyid}_${datafeed.staffPosition}_$timestamp';
      final receiptNumber = '${datafeed.staffPosition}$timestamp';

      final itemsMap = {
        for (int i = 0; i < salesItems.length; i++) 'item_$i': salesItems[i],
      };

      final payments = <Map<String, dynamic>>[];

      final now = DateTime.now();
      final day = DateFormat('EEEE').format(now);
      final year = now.year.toString();
      final month = '${now.year}.${now.month}';
      final weekNumber =
          ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;
      final week = '${now.year}.$weekNumber';
      final formattedDate = salesProvider.saleDate;
      final saleBranchId = datafeed.isSalesPoint
          ? datafeed.branchid
          : activeBranchId;
      final saleBranchName = datafeed.isSalesPoint
          ? datafeed.branch
          : activeBranchName;

      final saleData = SalesModel(
        id: saleDocId,
        companyId: datafeed.companyid,
        companyname: datafeed.company,
        branchId: saleBranchId,
        branchName: saleBranchName,
        address: datafeed.isSalesPoint ? datafeed.branchaddress : null,
        branchType: datafeed.isSalesPoint ? 'Sales Point' : branchtype,
        pricingtype: datafeed.isSalesPoint ? 'Sales Point' : branchtype,
        staffPosition: datafeed.staffPosition,
        payments: payments,
        receiptNumber: receiptNumber,
        receiptby: '',
        receiptat: null,
        paymentStatus: 'pending',
        transMode: 'cash',
        items: itemsMap,
        totalamount: grossTotal,
        amountPaid: 0.0,
        discount: totalDiscount,
        change: 0.0,
        itemCount: salesItems.length,
        isreturned: false,
        createdAt: Timestamp.now(),
        createdBy: datafeed.staff,
        approvedby: datafeed.staff,
        printedby: '',
        printedat: null,
        staffemail: datafeed.staffemail,
        receiptbyemail: '',
        dateymd: formattedDate,
        stockCheckedAt: Timestamp.now(),
        stockCheckStatus: null,
        timestamp: timestamp,
        printed: false,
        customerName: 'Cash Customer',
        customerPhone: '0000000000',
        reciepted: false,
        day: day,
        week: week,
        month: month,
        year: year,
        supplystatus: false,
      );

      await datafeed.db
          .collection('sales')
          .doc(saleDocId)
          .set(saleData.toMap());

      final skipCheck =
          !datafeed.stockCheckEnabled ||
          salesProvider.isServiceOnlySale(salesItems);
      if (!context.mounted) return;
      final approved = await salesProvider.ensureSaleApproved(
        context,
        saleDocId,
        skipStockCheck: skipCheck,
      );

      if (!approved) {
        return;
      }

      if (context.mounted) {
        snackMsg(context, 'Sale saved successfully!', Colors.green);
        Provider.of<SalesProvider>(context, listen: false).clearCurrentCart();
      }
    } catch (e) {
      if (context.mounted) {
        snackMsg(context, 'Error saving sale: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDirect = false);
      }
    }
  }

  void _resetForm({bool clearSelectedItem = false}) {
    _itemController.clear();
    _barcodeController.clear();
    _quantityController.text = '1';
    _priceController.clear();
    _discountController.clear();
    _totalPiecesController.clear();
    _totalAmountController.clear();
    setState(() {
      if (clearSelectedItem) _selectedItem = null;
      _selectedSalesMode = null;
      _selectedPriceMode = null;
      _currentModeData = null;
      _itemModes = null;
      _salesMode = [];

      _discountCodeController.clear();
      _appliedDiscountCode = null;
      _showDiscountCodeField = false;
    });
  }

  Future<void> _printReceipt() async {
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final value = Provider.of<Datafeed>(context, listen: false);
    if (value.isOffline && value.stockCheckEnabled) {
      snackMsg(
        context,
        'Sales with stock checking require an internet connection.',
        Colors.orange,
      );
      return;
    }

    if (value.isOffline) {
      await printReceipt(
        context: context,
        salesItems: salesProvider.salesItems,
        selectedItem: _selectedItem,
      );
      return;
    }

    if (value.isSalesPoint) {
      await _saveDirectSale();
      return;
    }

    final isService =
        (_selectedItem?.producttype ?? '').toLowerCase().trim() == 'service';

    if (!isService && value.stockCheckEnabled) {
      bool isValid = await salesProvider.validateCartStockOnSaves(
        _activeBranchId,
      );

      if (!isValid) {
        snackMsg(
          context,
          'Insufficient stock detected. Please adjust cart.',
          Colors.red,
        );
        return;
      }
    }
    await printReceipt(
      context: context,
      salesItems: salesProvider.salesItems,
      selectedItem: _selectedItem,
    );
  }

  Future<void> _syncItemBalance(
    String itemId,
    String itemName,
    String branchId,
    String branchName,
  ) async {
    final provider = context.read<Datafeed>();
    final balance = await provider.fetchItemCurrentBalance(
      itemId: itemId,
      selectedBranch: branchId,
    );
    await provider.db.collection('itemsreg').doc(itemId).update({
      'branchbalance.$branchId.netpieces': balance,
      'branchbalance.$branchId.lastupdate': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      snackMsg(
        context,
        'Balance synced: $itemName â†’ $branchName | $balance pcs',
        Colors.green,
      );
    }
  }

  void _selectItem(ItemModel? item, Datafeed datafeed) {
    if (item == null) return;
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    if (datafeed.isSalesPoint &&
        item.producttype.toLowerCase().trim() != 'service') {
      if (datafeed.canSellAnyBranch) {
        final warehouses = _assignedWarehousesForItem(
          datafeed,
          salesProvider,
          item,
        );
        final warehouse =
            warehouses
                .where((entry) => entry.id == datafeed.salesWarehouseId)
                .firstOrNull ??
            (warehouses.isEmpty ? null : warehouses.first);
        datafeed.setSalesWarehouse(warehouse?.id, warehouse?.branchname);
      } else {
        salesProvider.ensureSalesWarehouse(datafeed, item);
      }
    }
    setState(() {
      _selectedItem = item;

      /// Fill text fields
      _itemController.text = item.name;
      _barcodeController.text = item.barcode;

      Map<String, dynamic> effectivePricing = {};

      final branchPrices = item.branchprices;
      final modes = item.modes;
      final branchId = _activeBranchId.isNotEmpty
          ? _activeBranchId
          : datafeed.activeBranchId;

      if (branchPrices != null &&
          branchPrices.containsKey(branchId) &&
          branchPrices[branchId]['pricing'] != null) {
        effectivePricing = Map<String, dynamic>.from(
          branchPrices[branchId]['pricing'],
        );
      } else if (modes != null) {
        for (var mode in modes) {
          effectivePricing[mode.name] = {
            'id': mode.id,
            'name': mode.name,
            'qty': mode.qty,
            'cp': mode.cp,
            'rp': mode.rp,
            'wp': mode.wp,
            'sp': mode.sp,
          };
        }
      }

      _itemModes = effectivePricing;

      /// Build sales mode list

      /// Build sales mode list
      if (_itemModes != null && _itemModes!.isNotEmpty) {
        _salesMode = _itemModes!.entries.map((e) {
          final data = e.value as Map<String, dynamic>;
          return data['name']?.toString() ?? e.key;
        }).toList();

        final bool isWholesale = _effectivePriceMode == 'wholesale';
        double cartonQty = 0;
        for (final entry in _itemModes!.entries) {
          if (entry.key.toLowerCase().trim() == 'carton') {
            cartonQty =
                double.tryParse(entry.value['qty']?.toString() ?? '0') ?? 0;
            break;
          }
        }
        if (isWholesale) {
          final cartonModes = _salesMode
              .where((mode) => mode.toLowerCase().contains('carton'))
              .toList();
          if (cartonQty <= 1) {
            final baseModes = cartonModes.isNotEmpty
                ? cartonModes
                : _salesMode
                      .where((mode) => mode.toLowerCase().trim() == 'single')
                      .toList();
            _salesMode = [
              ...baseModes,
              ..._salesMode.where(
                (mode) => _isSplitSalesMode(mode) && !baseModes.contains(mode),
              ),
            ];
          } else {
            _salesMode = cartonModes;
          }

          if (_salesMode.isEmpty) {
            _salesMode = _itemModes!.entries.map((e) {
              final data = e.value as Map<String, dynamic>;
              return data['name']?.toString() ?? e.key;
            }).toList();
          }
          _salesMode.sort((a, b) {
            if (a.toLowerCase() == 'carton') return -1;
            if (b.toLowerCase() == 'carton') return 1;
            return 0;
          });
        } else {
          if (cartonQty <= 1) {
            final nonCartonModes = _salesMode
                .where((mode) => !_isFullCartonMode(mode))
                .toList();
            if (nonCartonModes.isNotEmpty) {
              _salesMode = nonCartonModes;
            }
          }

          /// Put "Single" first
          if (datafeed.isSalesPoint) {
            _salesMode.sort((a, b) {
              if (a.toLowerCase() == 'carton') return -1;
              if (b.toLowerCase() == 'carton') return 1;
              return 0;
            });
          } else {
            _salesMode.sort((a, b) {
              if (a.toLowerCase() == 'single') return -1;
              if (b.toLowerCase() == 'single') return 1;
              return 0;
            });
          }
        }

        _selectedSalesMode = _salesMode.first;

        _onQuantityChanged();
      } else {
        _salesMode = const ['single'];
        _selectedSalesMode = null;
        _currentModeData = null;
      }
      _showSuggestions = false;
      _suggestions.clear();
    });
  }

  void _updatePrice() {
    if (_selectedItem == null ||
        _selectedSalesMode == null ||
        _itemModes == null ||
        _itemModes!.isEmpty) {
      _priceController.text = '0';
      _currentModeData = null;
      return;
    }
    final int qty = int.tryParse(_quantityController.text) ?? 0;
    final datafeed = context.read<Datafeed>();
    final pricingBranchId =
        datafeed.canSellAnyBranch && _activeBranchId.isNotEmpty
        ? _activeBranchId
        : datafeed.activeBranchId;
    final branchPricing = _selectedItem!.branchprices?[pricingBranchId];
    final branchSupplierMinQty = branchPricing is Map
        ? branchPricing['sminqty']?.toString()
        : null;
    final sminqty =
        double.tryParse(branchSupplierMinQty ?? _selectedItem!.sminqty) ?? 0;

    Map<String, dynamic>? selectedModeData;
    String normalizeMode(String mode) =>
        mode.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    for (final entry in _itemModes!.entries) {
      final data = entry.value;
      if (data is! Map) continue;
      final modeData = Map<String, dynamic>.from(data);
      final modeKey = normalizeMode(entry.key);
      final modeId = normalizeMode(modeData['id']?.toString() ?? '');
      final modeName = normalizeMode(modeData['name']?.toString() ?? '');
      final selectedMode = normalizeMode(_selectedSalesMode!);
      if (modeKey == selectedMode ||
          modeId == selectedMode ||
          modeName == selectedMode) {
        selectedModeData = modeData;
        break;
      }
    }

    if (selectedModeData == null) {
      _priceController.text = '0';
      _currentModeData = null;
      return;
    }

    _currentModeData = selectedModeData;

    String price = '0';

    String selectedModePrice(String field, {String fallback = '0'}) {
      final value = selectedModeData![field]?.toString().trim();
      return value == null || value.isEmpty ? fallback : value;
    }

    final selectedModeName = normalizeMode(
      selectedModeData['id']?.toString() ??
          selectedModeData['name']?.toString() ??
          _selectedSalesMode!,
    );
    MapEntry<String, dynamic>? cartonEntry;
    for (final entry in _itemModes!.entries) {
      final data = entry.value;
      if (data is! Map) continue;
      final modeData = Map<String, dynamic>.from(data);
      if (normalizeMode(entry.key) == 'carton' ||
          normalizeMode(modeData['id']?.toString() ?? '') == 'carton' ||
          normalizeMode(modeData['name']?.toString() ?? '') == 'carton') {
        cartonEntry = entry;
        break;
      }
    }
    final cartonQuantity = cartonEntry == null
        ? null
        : double.tryParse(cartonEntry.value['qty']?.toString() ?? '');
    final isSingleMode = selectedModeName == 'single';
    final isCartonMode = selectedModeName == 'carton';
    final isSplitMode = const {
      'half',
      'halfcarton',
      'quarter',
      'quartercarton',
      'pack',
    }.contains(selectedModeName);
    final supplierThresholdApplies =
        isSplitMode ||
        isCartonMode ||
        (isSingleMode && (cartonQuantity == null || cartonQuantity <= 1));
    final retailPrice = selectedModePrice('rp');

    if (sminqty > 0 && qty >= sminqty && supplierThresholdApplies) {
      price = selectedModePrice('sp', fallback: retailPrice);
    } else if (_effectivePriceMode == 'wholesale') {
      price = selectedModePrice('wp', fallback: retailPrice);
    } else {
      price = retailPrice;
    }
    _priceController.text = price;

    _calculateTotals();
  }

  Widget _previewActionTile({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double minWidth,
    bool isLoading = false,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _isLightTheme ? color : Colors.white,
                    ),
                  )
                else
                  Icon(
                    icon,
                    color: _isLightTheme ? color : Colors.white,
                    size: 18,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _isLightTheme ? color : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.2,
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

  Future<void> _applyDiscountCode(String code) async {
    final upperCaseCode = code.trim().toUpperCase();
    if (upperCaseCode.isEmpty) return;

    try {
      final datafeed = context.read<Datafeed>();

      final match = await datafeed.validateDiscountCode(upperCaseCode);

      if (match == null) {
        snackMsg(context, 'Invalid or used discount code', Colors.red);
        return;
      }

      final amount = (match['amount'] as num).toDouble();

      setState(() {
        _appliedDiscountCode = match['code'];
        _discountController.text = amount.toStringAsFixed(2);
      });

      _calculateTotals();

      snackMsg(
        context,
        'Code "${match['code']}" applied - GHS ${amount.toStringAsFixed(2)} off',
        Colors.green,
      );
    } catch (e) {
      print('Error applying discount code: $e');

      snackMsg(
        context,
        'Failed to apply discount. Check connection and try again.',
        Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final salesItems = context.watch<SalesProvider>().salesItems;
        final allowed = value.allowedPaymentMethods;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final bool cashAllowed = allowed
            .map((e) => e.toLowerCase())
            .contains('cash');

        return Theme(
          data: theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              floatingLabelStyle: TextStyle(color: colorScheme.onSurface),
            ),
          ),
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              leading: Navigator.of(context).canPop()
                  ? PopScope<Object?>(
                      canPop: !_hasTemporaryBranchSwitch,
                      onPopInvokedWithResult: (didPop, result) async {
                        if (didPop || !_hasTemporaryBranchSwitch) return;
                        await _restoreOriginalBranch();
                        if (mounted) {
                          Navigator.of(context).pop(result);
                        }
                      },
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: _primaryText),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    )
                  : null,
              title: Text(
                "SALES TRANSACTIONS ${(_displayBranchName.isNotEmpty ? _displayBranchName : value.branch).toString().toUpperCase()}",
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              centerTitle: true,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              actions: [],
            ),
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 8.0,
                    top: 8,
                    right: 8,
                    bottom: 20,
                  ),
                  child: Column(
                    children: [
                      const OfflineIndicator(),
                      Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isSmallScreen = constraints.maxWidth < 900;
                            final double itemWidth = isSmallScreen
                                ? constraints.maxWidth
                                : (constraints.maxWidth / 2) - 24;
                            final bool isMobile = constraints.maxWidth < 600;
                            final provider = Provider.of<Datafeed>(
                              context,
                              listen: false,
                            );
                            final salesProvider = Provider.of<SalesProvider>(
                              context,
                              listen: false,
                            );
                            final isSalesBranch =
                                provider.branchtype ==
                                "Sales Branch"; //"Sales Point";
                            final canPrint = provider.canPrint;
                            final posPrint =
                                !provider.isSalesPoint &&
                                (isSalesBranch || canPrint);
                            return Column(
                              children: [
                                if (isMobile)
                                  Container(
                                    width: itemWidth,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _outlineColor),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  !_showMobilePreview
                                                  ? Colors.orange
                                                  : _panelSurface,
                                              foregroundColor:
                                                  !_showMobilePreview
                                                  ? (_isLightTheme
                                                        ? Colors.black87
                                                        : Colors.white)
                                                  : _primaryText,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              elevation: !_showMobilePreview
                                                  ? 2
                                                  : 0,
                                            ),

                                            onPressed: () {
                                              FocusScope.of(context).unfocus();
                                              setState(
                                                () =>
                                                    _showMobilePreview = false,
                                              );
                                            },
                                            child: const Text('Sale Form'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  _showMobilePreview
                                                  ? Colors.lightBlue
                                                  : _panelSurface,
                                              foregroundColor:
                                                  _showMobilePreview
                                                  ? (_isLightTheme
                                                        ? Colors.black87
                                                        : Colors.white)
                                                  : _primaryText,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              elevation: _showMobilePreview
                                                  ? 2
                                                  : 0,
                                            ),
                                            onPressed: () {
                                              FocusScope.of(context).unfocus();
                                              setState(
                                                () => _showMobilePreview = true,
                                              );
                                            },
                                            child: const Text('Preview'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                if (isMobile) const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    if (!isMobile || !_showMobilePreview)
                                      SizedBox(
                                        width: itemWidth,
                                        child: Container(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (isMobile)
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _panelSurface,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color: _outlineColor,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .shopping_cart,
                                                              color:
                                                                  Colors.orange,
                                                              size: 18,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                'Open: Cart ${salesProvider.currentCartId.split('_').length > 1 ? salesProvider.currentCartId.split('_')[1] : salesProvider.currentCartId}',
                                                                style: TextStyle(
                                                                  color:
                                                                      _secondaryText,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                            Text(
                                                              '${salesItems.length} item(s)',
                                                              style: TextStyle(
                                                                color:
                                                                    _secondaryText,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Total Amount',
                                                              style: TextStyle(
                                                                color:
                                                                    _secondaryText,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            Text(
                                                              'GHS ${salesProvider.calculateTaxableTotal().toStringAsFixed(2)}',
                                                              style: TextStyle(
                                                                color:
                                                                    _primaryText,
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                if (isMobile)
                                                  const SizedBox(height: 12),
                                                Text(
                                                  "SALES ENTRIES",
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: _primaryText,
                                                  ),
                                                ),
                                                Divider(color: _outlineColor),
                                                Visibility(
                                                  visible: value.hamperEnabled,
                                                  maintainState: false,
                                                  child: Column(
                                                    children: [
                                                      HamperSection(
                                                        datafeed: value,
                                                        activeBranchId:
                                                            _activeBranchId,
                                                        activeBranchName:
                                                            _activeBranchName,
                                                      ),
                                                      Divider(
                                                        color: _outlineColor,
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                SizedBox(height: 8),
                                                Form(
                                                  key: _formKey,
                                                  child: Column(
                                                    children: [
                                                      if (value
                                                          .canSelectDate) ...[
                                                        TextFormField(
                                                          controller:
                                                              _dateController,
                                                          readOnly: true,
                                                          style: TextStyle(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ),
                                                          decoration:
                                                              _inputDecoration(
                                                                label: 'Date',
                                                                prefix: Icons
                                                                    .calendar_today,
                                                                hint:
                                                                    'yyyy-mm-dd',
                                                              ),
                                                          onTap: () async {
                                                            DateTime?
                                                            picked = await showDatePicker(
                                                              context: context,
                                                              initialDate:
                                                                  _selectedDate ??
                                                                  DateTime.now(),
                                                              firstDate:
                                                                  DateTime(
                                                                    2020,
                                                                  ),
                                                              lastDate:
                                                                  DateTime.now(),
                                                              builder: (context, child) {
                                                                return Theme(
                                                                  data:
                                                                      Theme.of(
                                                                        context,
                                                                      ).copyWith(
                                                                        colorScheme:
                                                                            _datePickerColorScheme,
                                                                      ),
                                                                  child: child!,
                                                                );
                                                              },
                                                            );

                                                            if (picked !=
                                                                null) {
                                                              context
                                                                  .read<
                                                                    SalesProvider
                                                                  >()
                                                                  .setSaleDate(
                                                                    picked,
                                                                  );

                                                              setState(() {
                                                                _selectedDate =
                                                                    picked;
                                                                _dateController
                                                                        .text =
                                                                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                                              });
                                                            }
                                                          },
                                                          validator: (value) =>
                                                              value == null ||
                                                                  value.isEmpty
                                                              ? 'Select date'
                                                              : null,
                                                        ),
                                                      ],
                                                      SizedBox(height: 8),
                                                      _buildSalesWarehouseSelector(
                                                        value,
                                                      ),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: TextFormField(
                                                              controller:
                                                                  _barcodeController,
                                                              style: TextStyle(
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.onSurface,
                                                              ),
                                                              decoration: InputDecoration(
                                                                labelText:
                                                                    'Barcode',
                                                                labelStyle: TextStyle(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurfaceVariant,
                                                                ),
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                                enabledBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.outline,
                                                                  ),
                                                                ),
                                                                focusedBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.primary,
                                                                  ),
                                                                ),
                                                                fillColor:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .surfaceContainerHighest,
                                                                filled: true,
                                                              ),

                                                              validator:
                                                                  SalesFormValidators
                                                                      .barcode,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Container(
                                                            height: 56,
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  _panelSurface,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    _outlineColor,
                                                              ),
                                                            ),
                                                            child: IconButton(
                                                              icon: Icon(
                                                                Icons
                                                                    .qr_code_scanner,
                                                                color:
                                                                    _secondaryText,
                                                              ),
                                                              onPressed:
                                                                  _scanBarcode,
                                                              tooltip:
                                                                  'Scan Barcode/QR Code',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (_showSuggestions)
                                                        value.loading
                                                            ? const Center(
                                                                child: CircularProgressIndicator(
                                                                  color: Colors
                                                                      .blue,
                                                                  strokeWidth:
                                                                      2,
                                                                ),
                                                              )
                                                            : (() {
                                                                final query =
                                                                    _searchQuery
                                                                        .toLowerCase();

                                                                final filteredItems =
                                                                    query
                                                                        .isEmpty
                                                                    ? value
                                                                          .items
                                                                    : value
                                                                          .items
                                                                          .where(
                                                                            (
                                                                              item,
                                                                            ) =>
                                                                                item.isActive ==
                                                                                true,
                                                                          )
                                                                          .where((
                                                                            item,
                                                                          ) {
                                                                            final name =
                                                                                item.name.toLowerCase();
                                                                            final barcode =
                                                                                item.barcode.toLowerCase();
                                                                            final company =
                                                                                item.company.toLowerCase();
                                                                            final category =
                                                                                item.pcategory.toLowerCase();

                                                                            return name.contains(
                                                                                  query,
                                                                                ) ||
                                                                                barcode.contains(
                                                                                  query,
                                                                                ) ||
                                                                                company.contains(
                                                                                  query,
                                                                                ) ||
                                                                                category.contains(
                                                                                  query,
                                                                                );
                                                                          })
                                                                          .take(
                                                                            10,
                                                                          )
                                                                          .toList();

                                                                if (filteredItems
                                                                    .isEmpty) {
                                                                  return const SizedBox.shrink();
                                                                }

                                                                return Container(
                                                                  margin:
                                                                      const EdgeInsets.only(
                                                                        top: 4,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        _panelSurface,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                    border: Border.all(
                                                                      color: Colors
                                                                          .blue
                                                                          .withOpacity(
                                                                            0.3,
                                                                          ),
                                                                    ),
                                                                    boxShadow: const [
                                                                      BoxShadow(
                                                                        color: Colors
                                                                            .black26,
                                                                        blurRadius:
                                                                            8,
                                                                        offset:
                                                                            Offset(
                                                                              0,
                                                                              4,
                                                                            ),
                                                                      ),
                                                                    ],
                                                                  ),

                                                                  constraints:
                                                                      const BoxConstraints(
                                                                        maxHeight:
                                                                            250,
                                                                      ),
                                                                  child: ListView.builder(
                                                                    shrinkWrap:
                                                                        true,
                                                                    itemCount:
                                                                        filteredItems
                                                                            .length,
                                                                    itemBuilder:
                                                                        (
                                                                          context,
                                                                          index,
                                                                        ) {
                                                                          final item =
                                                                              filteredItems[index];
                                                                          final branchId =
                                                                              value.canSellAnyBranch
                                                                              ? _activeBranchId
                                                                              : value.activeBranchId;
                                                                          final branchbalance =
                                                                              item.branchbalance?[branchId]
                                                                                  as Map<
                                                                                    String,
                                                                                    dynamic
                                                                                  >? ??
                                                                              {};

                                                                          final double
                                                                          netPieces =
                                                                              (branchbalance['netpieces']
                                                                                      as num?)
                                                                                  ?.toDouble() ??
                                                                              0.0;

                                                                          final cartonMode = item.modes?.firstWhere(
                                                                            (
                                                                              m,
                                                                            ) =>
                                                                                m.name.toLowerCase() ==
                                                                                'carton',
                                                                            orElse: () => Mode(
                                                                              id: '',
                                                                              name: '',
                                                                              qty: '1',
                                                                              cp: '',
                                                                              rp: '',
                                                                              wp: '',
                                                                              sp: '',
                                                                            ),
                                                                          );

                                                                          final singleMode = item.modes?.firstWhere(
                                                                            (
                                                                              m,
                                                                            ) =>
                                                                                m.name.toLowerCase() ==
                                                                                'single',
                                                                            orElse: () => Mode(
                                                                              id: '',
                                                                              name: '',
                                                                              qty: '1',
                                                                              cp: '',
                                                                              rp: '',
                                                                              wp: '',
                                                                              sp: '',
                                                                            ),
                                                                          );

                                                                          final String
                                                                          boxPrice =
                                                                              cartonMode !=
                                                                                      null &&
                                                                                  cartonMode.wp.isNotEmpty
                                                                              ? cartonMode.wp
                                                                              : (singleMode?.wp ??
                                                                                    '0');
                                                                          return Material(
                                                                            color:
                                                                                Colors.transparent,
                                                                            child: ListTile(
                                                                              dense: true,
                                                                              leading: const Icon(
                                                                                Icons.inventory_2,
                                                                                color: Colors.blue,
                                                                                size: 20,
                                                                              ),
                                                                              title: Text(
                                                                                item.name,
                                                                                style: TextStyle(
                                                                                  color: _primaryText,
                                                                                  fontSize: 14,
                                                                                  fontWeight: FontWeight.w500,
                                                                                ),
                                                                              ),
                                                                              subtitle: Text(
                                                                                'Barcode: ${item.barcode} | Box Price: GHS $boxPrice | Retail Price: GHS ${singleMode?.rp} '
                                                                                //'| Boxes Balance: ${cartonsLeft.toStringAsFixed(2)}'
                                                                                ' | Pieces: ${netPieces.toStringAsFixed(0)}',
                                                                                style: TextStyle(
                                                                                  color: _secondaryText,
                                                                                  fontSize: 11,
                                                                                ),
                                                                              ),
                                                                              trailing: Icon(
                                                                                Icons.arrow_forward_ios,
                                                                                color: _secondaryText,
                                                                                size: 14,
                                                                              ),
                                                                              onTap: () {
                                                                                _selectItem(
                                                                                  item,
                                                                                  value,
                                                                                );
                                                                              },
                                                                            ),
                                                                          );
                                                                        },
                                                                  ),
                                                                );
                                                              })(),

                                                      SizedBox(height: 8),
                                                      TextFormField(
                                                        enabled: false,
                                                        controller:
                                                            _itemController,
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                        decoration: InputDecoration(
                                                          labelText: 'Item',
                                                          labelStyle: TextStyle(
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                          border: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            borderSide: BorderSide(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .outline,
                                                            ),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            borderSide: BorderSide(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                            ),
                                                          ),
                                                          fillColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surfaceContainerHighest,
                                                          filled: true,
                                                        ),

                                                        validator:
                                                            SalesFormValidators
                                                                .item,
                                                      ),
                                                      SizedBox(height: 8),
                                                      DropdownButtonFormField<
                                                        String
                                                      >(
                                                        value:
                                                            _selectedSalesMode,
                                                        dropdownColor: Theme.of(
                                                          context,
                                                        ).colorScheme.surface,
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                        decoration: InputDecoration(
                                                          labelText:
                                                              'Sales Mode',
                                                          labelStyle: TextStyle(
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                          border: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            borderSide: BorderSide(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .outline,
                                                            ),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            borderSide: BorderSide(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                            ),
                                                          ),
                                                          fillColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surfaceContainerHighest,
                                                          filled: true,
                                                        ),
                                                        items:
                                                            _salesMode.isEmpty
                                                            ? null
                                                            : _salesMode.map((
                                                                type,
                                                              ) {
                                                                return DropdownMenuItem<
                                                                  String
                                                                >(
                                                                  value: type,
                                                                  child: Text(
                                                                    type,
                                                                  ),
                                                                );
                                                              }).toList(),
                                                        onChanged: (value) {
                                                          setState(() {
                                                            _selectedSalesMode =
                                                                value;
                                                            _onQuantityChanged();
                                                          });
                                                        },

                                                        validator:
                                                            SalesFormValidators
                                                                .salesMode,
                                                      ),
                                                      SizedBox(height: 8),
                                                      TextFormField(
                                                        controller:
                                                            _priceController,
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                        decoration: InputDecoration(
                                                          labelText: 'Price',
                                                          labelStyle: TextStyle(
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                          border: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            borderSide: BorderSide(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .outline,
                                                            ),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            borderSide: BorderSide(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                            ),
                                                          ),
                                                          fillColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surfaceContainerHighest,
                                                          filled: true,
                                                        ),
                                                        inputFormatters: [
                                                          FilteringTextInputFormatter.allow(
                                                            RegExp(
                                                              r'^\d*\.?\d*$',
                                                            ),
                                                          ),
                                                        ],

                                                        validator:
                                                            SalesFormValidators
                                                                .price,
                                                        enabled:
                                                            value.canEditPrice,
                                                      ),
                                                      Visibility(
                                                        visible: false,
                                                        child: Row(
                                                          children: [
                                                            Visibility(
                                                              visible: false,
                                                              child: Expanded(
                                                                child: DropdownButtonFormField<String>(
                                                                  initialValue:
                                                                      _selectedPriceMode,
                                                                  dropdownColor:
                                                                      Theme.of(
                                                                        context,
                                                                      ).colorScheme.surface,
                                                                  style: TextStyle(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.onSurface,
                                                                  ),
                                                                  decoration: InputDecoration(
                                                                    border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                    ),
                                                                    enabledBorder: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                      borderSide: BorderSide(
                                                                        color: Theme.of(
                                                                          context,
                                                                        ).colorScheme.outline,
                                                                      ),
                                                                    ),
                                                                    focusedBorder: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                      borderSide: BorderSide(
                                                                        color: Theme.of(
                                                                          context,
                                                                        ).colorScheme.primary,
                                                                      ),
                                                                    ),
                                                                    fillColor:
                                                                        Theme.of(
                                                                          context,
                                                                        ).colorScheme.surfaceContainerHighest,
                                                                    filled:
                                                                        true,
                                                                  ),
                                                                  items: _priceMode.map((
                                                                    type,
                                                                  ) {
                                                                    return DropdownMenuItem<
                                                                      String
                                                                    >(
                                                                      value:
                                                                          type,
                                                                      child:
                                                                          Text(
                                                                            type,
                                                                          ),
                                                                    );
                                                                  }).toList(),
                                                                  onChanged: (value) {
                                                                    setState(() {
                                                                      _selectedPriceMode =
                                                                          value;
                                                                      _updatePrice();
                                                                    });
                                                                  },

                                                                  validator:
                                                                      SalesFormValidators
                                                                          .priceMode,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      Row(
                                                        children: [
                                                          SizedBox(
                                                            width: 52,
                                                            height: 52,
                                                            child: Material(
                                                              color:
                                                                  _panelSurface,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              child: InkWell(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                onTap:
                                                                    _decrementQuantity,
                                                                child: Icon(
                                                                  Icons.remove,
                                                                  color:
                                                                      _secondaryText,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: TextFormField(
                                                              controller:
                                                                  _quantityController,
                                                              onChanged:
                                                                  _handleQuantityInput,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: TextStyle(
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                              keyboardType:
                                                                  TextInputType
                                                                      .number,
                                                              inputFormatters: [
                                                                TextInputFormatter.withFunction((
                                                                  oldValue,
                                                                  newValue,
                                                                ) {
                                                                  return newValue
                                                                              .text
                                                                              .isEmpty ||
                                                                          RegExp(
                                                                            r'^[0-9]+$',
                                                                          ).hasMatch(
                                                                            newValue.text,
                                                                          )
                                                                      ? newValue
                                                                      : oldValue;
                                                                }),
                                                              ],
                                                              decoration: InputDecoration(
                                                                labelText:
                                                                    'Quantity',
                                                                labelStyle: TextStyle(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurfaceVariant,
                                                                ),
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                                enabledBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.outline,
                                                                  ),
                                                                ),
                                                                focusedBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.primary,
                                                                  ),
                                                                ),
                                                                fillColor:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .surfaceContainerHighest,
                                                                filled: true,
                                                              ),

                                                              validator:
                                                                  _validateQuantity,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          SizedBox(
                                                            width: 52,
                                                            height: 52,
                                                            child: Material(
                                                              color:
                                                                  _panelSurface,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              child: InkWell(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                onTap:
                                                                    _incrementQuantity,
                                                                child: Icon(
                                                                  Icons.add,
                                                                  color:
                                                                      _secondaryText,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 8),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: TextFormField(
                                                              controller:
                                                                  _totalPiecesController,
                                                              style: TextStyle(
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.onSurface,
                                                              ),
                                                              readOnly: true,
                                                              decoration: InputDecoration(
                                                                labelText:
                                                                    'Total Pieces',
                                                                labelStyle: TextStyle(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurfaceVariant,
                                                                ),
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                                enabledBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.outline,
                                                                  ),
                                                                ),
                                                                focusedBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.primary,
                                                                  ),
                                                                ),
                                                                fillColor:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .surfaceContainerHighest,
                                                                filled: true,
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(width: 10),
                                                          Expanded(
                                                            child: TextFormField(
                                                              controller:
                                                                  _totalAmountController,
                                                              style: TextStyle(
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.onSurface,
                                                              ),
                                                              readOnly: true,
                                                              decoration: InputDecoration(
                                                                labelText:
                                                                    'Total Amount',
                                                                labelStyle: TextStyle(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurfaceVariant,
                                                                ),
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                                enabledBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.outline,
                                                                  ),
                                                                ),
                                                                focusedBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.primary,
                                                                  ),
                                                                ),
                                                                fillColor:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .surfaceContainerHighest,
                                                                filled: true,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),

                                                      SizedBox(height: 8),
                                                      if (value
                                                          .allowDiscount) ...[
                                                        TextFormField(
                                                          controller:
                                                              _discountController,
                                                          style: TextStyle(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ),
                                                          keyboardType:
                                                              const TextInputType.numberWithOptions(
                                                                decimal: true,
                                                              ),
                                                          inputFormatters: [
                                                            FilteringTextInputFormatter.allow(
                                                              RegExp(
                                                                r'^(0(\.\d*)?|[1-9]\d*(\.\d*)?)?$',
                                                              ),
                                                            ),
                                                          ],
                                                          decoration: InputDecoration(
                                                            labelText:
                                                                'Discount',
                                                            labelStyle: TextStyle(
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                            prefixText: 'GHS ',
                                                            border: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              borderSide: BorderSide(
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.outline,
                                                              ),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              borderSide: BorderSide(
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.primary,
                                                              ),
                                                            ),
                                                            fillColor:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .surfaceContainerHighest,
                                                            filled: true,
                                                          ),
                                                          validator: (value) {
                                                            if (value == null ||
                                                                value
                                                                    .trim()
                                                                    .isEmpty) {
                                                              return null;
                                                            }
                                                            final parsed =
                                                                double.tryParse(
                                                                  value.trim(),
                                                                );
                                                            if (parsed ==
                                                                null) {
                                                              return 'Enter a valid discount';
                                                            }
                                                            if (parsed < 0) {
                                                              return 'Discount cannot be negative';
                                                            }
                                                            return null;
                                                          },
                                                        ),
                                                      ],
                                                      SizedBox(height: 8),
                                                      if (value
                                                          .allowDiscountCode) ...[
                                                        // clickable discount code field
                                                        GestureDetector(
                                                          onTap: () => setState(
                                                            () => _showDiscountCodeField =
                                                                !_showDiscountCodeField,
                                                          ),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 10,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  _panelSurface,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    _appliedDiscountCode !=
                                                                        null
                                                                    ? _successText
                                                                          .withOpacity(
                                                                            0.6,
                                                                          )
                                                                    : _outlineColor,
                                                              ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .discount_outlined,
                                                                  color:
                                                                      _appliedDiscountCode !=
                                                                          null
                                                                      ? _successText
                                                                      : _secondaryText,
                                                                  size: 18,
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    _appliedDiscountCode !=
                                                                            null
                                                                        ? 'Code "$_appliedDiscountCode" applied'
                                                                        : 'Have a discount code? Tap to enter',
                                                                    style: TextStyle(
                                                                      color:
                                                                          _appliedDiscountCode !=
                                                                              null
                                                                          ? _successText
                                                                          : _secondaryText,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Icon(
                                                                  _showDiscountCodeField
                                                                      ? Icons
                                                                            .keyboard_arrow_up
                                                                      : Icons
                                                                            .keyboard_arrow_down,
                                                                  color:
                                                                      _secondaryText,
                                                                  size: 18,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),

                                                        // Expandable code entry
                                                        if (_showDiscountCodeField) ...[
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Expanded(
                                                                child: TextFormField(
                                                                  controller:
                                                                      _discountCodeController,
                                                                  style: TextStyle(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.onSurface,
                                                                    letterSpacing:
                                                                        2,
                                                                  ),
                                                                  textCapitalization:
                                                                      TextCapitalization
                                                                          .characters,
                                                                  inputFormatters: [
                                                                    FilteringTextInputFormatter.allow(
                                                                      RegExp(
                                                                        r'[A-Za-z0-9]',
                                                                      ),
                                                                    ),
                                                                  ],
                                                                  onFieldSubmitted:
                                                                      _applyDiscountCode,
                                                                  decoration: InputDecoration(
                                                                    labelText:
                                                                        'Enter Discount Code',
                                                                    labelStyle: TextStyle(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                    hintText:
                                                                        'e.g. ABC12345',
                                                                    hintStyle: TextStyle(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurfaceVariant,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                    filled:
                                                                        true,
                                                                    fillColor:
                                                                        Theme.of(
                                                                          context,
                                                                        ).colorScheme.surfaceContainerHighest,
                                                                    suffixIcon:
                                                                        _appliedDiscountCode !=
                                                                            null
                                                                        ? Icon(
                                                                            Icons.check_circle,
                                                                            color:
                                                                                Colors.greenAccent,
                                                                            size:
                                                                                20,
                                                                          )
                                                                        : null,
                                                                    enabledBorder: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                      borderSide: BorderSide(
                                                                        color:
                                                                            _appliedDiscountCode !=
                                                                                null
                                                                            ? Colors.greenAccent
                                                                            : Theme.of(
                                                                                context,
                                                                              ).colorScheme.outline,
                                                                      ),
                                                                    ),
                                                                    focusedBorder: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                      borderSide: BorderSide(
                                                                        color: Theme.of(
                                                                          context,
                                                                        ).colorScheme.primary,
                                                                      ),
                                                                    ),
                                                                    border: OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              SizedBox(
                                                                height: 56,
                                                                child: ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor:
                                                                        Colors
                                                                            .orangeAccent,
                                                                    foregroundColor:
                                                                        Colors
                                                                            .white,
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                    ),
                                                                  ),
                                                                  onPressed: () =>
                                                                      _applyDiscountCode(
                                                                        _discountCodeController
                                                                            .text,
                                                                      ),
                                                                  child: const Text(
                                                                    'Apply',
                                                                    style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (_appliedDiscountCode !=
                                                              null)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    top: 6,
                                                                  ),
                                                              child: Row(
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .check_circle,
                                                                    color: Colors
                                                                        .greenAccent,
                                                                    size: 13,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Expanded(
                                                                    child: Text(
                                                                      '$_appliedDiscountCode applied',
                                                                      style: const TextStyle(
                                                                        color: Colors
                                                                            .greenAccent,
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  GestureDetector(
                                                                    onTap: () => setState(() {
                                                                      _appliedDiscountCode =
                                                                          null;
                                                                      _discountCodeController
                                                                          .clear();
                                                                      _discountController
                                                                          .clear();
                                                                      _calculateTotals();
                                                                    }),
                                                                    child: const Text(
                                                                      'Remove',
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .redAccent,
                                                                        fontSize:
                                                                            12,
                                                                        decoration:
                                                                            TextDecoration.underline,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          if (!_showDiscountCodeField &&
                                                              _appliedDiscountCode ==
                                                                  null) ...[
                                                            TextFormField(
                                                              controller:
                                                                  _discountController,
                                                              style: TextStyle(
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.onSurface,
                                                              ),
                                                              keyboardType:
                                                                  const TextInputType.numberWithOptions(
                                                                    decimal:
                                                                        true,
                                                                  ),
                                                              inputFormatters: [
                                                                FilteringTextInputFormatter.allow(
                                                                  RegExp(
                                                                    r'^(0(\.\d*)?|[1-9]\d*(\.\d*)?)?$',
                                                                  ),
                                                                ),
                                                              ],
                                                              decoration: InputDecoration(
                                                                labelText:
                                                                    'Discount',
                                                                labelStyle: TextStyle(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurfaceVariant,
                                                                ),
                                                                prefixText:
                                                                    'GHS ',
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                                enabledBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.outline,
                                                                  ),
                                                                ),
                                                                focusedBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  borderSide: BorderSide(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.primary,
                                                                  ),
                                                                ),
                                                                fillColor:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .surfaceContainerHighest,
                                                                filled: true,
                                                              ),
                                                              validator: (value) {
                                                                if (value ==
                                                                        null ||
                                                                    value
                                                                        .trim()
                                                                        .isEmpty) {
                                                                  return null;
                                                                }
                                                                final parsed =
                                                                    double.tryParse(
                                                                      value
                                                                          .trim(),
                                                                    );
                                                                if (parsed ==
                                                                    null) {
                                                                  return 'Enter a valid discount';
                                                                }
                                                                if (parsed <
                                                                    0) {
                                                                  return 'Discount cannot be negative';
                                                                }
                                                                return null;
                                                              },
                                                            ),
                                                          ],
                                                        ],
                                                      ],
                                                      SizedBox(height: 8),

                                                      Divider(
                                                        color: _outlineColor,
                                                      ),
                                                      Wrap(
                                                        spacing: 10,
                                                        runSpacing: 10,
                                                        children: [
                                                          SizedBox(
                                                            width: 150,
                                                            child: ElevatedButton(
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    Colors
                                                                        .orangeAccent,
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      vertical:
                                                                          16,
                                                                    ),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                              ),
                                                              onPressed:
                                                                  _addToSalesPreview,
                                                              child: Text(
                                                                "Save Record",
                                                                style: TextStyle(
                                                                  color:
                                                                      _isLightTheme
                                                                      ? Colors
                                                                            .black87
                                                                      : Colors
                                                                            .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: 150,
                                                            child: ElevatedButton(
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    Colors
                                                                        .lightBlue,
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      vertical:
                                                                          16,
                                                                    ),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                              ),
                                                              onPressed:
                                                                  _resetForm,
                                                              child: Text(
                                                                "Reset",
                                                                style: TextStyle(
                                                                  color:
                                                                      _isLightTheme
                                                                      ? Colors
                                                                            .black87
                                                                      : Colors
                                                                            .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    Visibility(
                                      visible: !isMobile,
                                      child: SizedBox(
                                        width: itemWidth,
                                        child: Container(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          //height: 300,
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      "SALES PREVIEW",
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: _primaryText,
                                                      ),
                                                    ),
                                                    // Cart switcher
                                                    if (salesProvider
                                                            .customerCarts
                                                            .length >
                                                        1)
                                                      PopupMenuButton<String>(
                                                        icon: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .shopping_cart,
                                                              color:
                                                                  Colors.orange,
                                                              size: 20,
                                                            ),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Cart ${salesProvider.currentCartId.split('_')[1]} (${salesProvider.customerCarts.length})',
                                                              style: TextStyle(
                                                                color:
                                                                    _primaryText,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                            Icon(
                                                              Icons
                                                                  .arrow_drop_down,
                                                              color:
                                                                  _primaryText,
                                                              size: 20,
                                                            ),
                                                          ],
                                                        ),
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        itemBuilder: (context) {
                                                          return salesProvider.customerCarts.keys.map((
                                                            cartId,
                                                          ) {
                                                            final cartNum =
                                                                cartId.split(
                                                                  '_',
                                                                )[1];
                                                            final itemCount =
                                                                salesProvider
                                                                    .customerCarts[cartId]
                                                                    ?.length ??
                                                                0;
                                                            final isActive =
                                                                cartId ==
                                                                salesProvider
                                                                    .currentCartId;
                                                            return PopupMenuItem<
                                                              String
                                                            >(
                                                              value: cartId,
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                    isActive
                                                                        ? Icons
                                                                              .radio_button_checked
                                                                        : Icons
                                                                              .radio_button_unchecked,
                                                                    color:
                                                                        isActive
                                                                        ? Colors
                                                                              .orange
                                                                        : Colors
                                                                              .grey,
                                                                    size: 18,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Expanded(
                                                                    child: Text(
                                                                      'Cart $cartNum ($itemCount items)',
                                                                      style: TextStyle(
                                                                        color:
                                                                            isActive
                                                                            ? Colors.orange
                                                                            : Colors.white,
                                                                        fontWeight:
                                                                            isActive
                                                                            ? FontWeight.bold
                                                                            : FontWeight.normal,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  if (!isActive &&
                                                                      salesProvider
                                                                              .customerCarts
                                                                              .length >
                                                                          1)
                                                                    IconButton(
                                                                      icon: Icon(
                                                                        Icons
                                                                            .delete,
                                                                        color: Colors
                                                                            .red,
                                                                        size:
                                                                            18,
                                                                      ),
                                                                      onPressed: () {
                                                                        Navigator.pop(
                                                                          context,
                                                                        );

                                                                        salesProvider.deleteCart(
                                                                          cartId,
                                                                        );
                                                                      },
                                                                      padding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                      constraints:
                                                                          BoxConstraints(),
                                                                    ),
                                                                ],
                                                              ),
                                                            );
                                                          }).toList();
                                                        },
                                                        onSelected: (cartId) {
                                                          context
                                                              .read<
                                                                SalesProvider
                                                              >()
                                                              .switchCart(
                                                                cartId,
                                                              );
                                                        },
                                                      ),
                                                  ],
                                                ),
                                                Divider(color: _outlineColor),
                                                SizedBox(height: 15),

                                                Table(
                                                  border: TableBorder.all(
                                                    color: Colors.grey,
                                                  ),
                                                  columnWidths: const {
                                                    0: FixedColumnWidth(40),
                                                    1: FlexColumnWidth(2),
                                                    2: FlexColumnWidth(1),
                                                    3: FlexColumnWidth(1),
                                                    4: FlexColumnWidth(1),
                                                    5: FlexColumnWidth(1),
                                                    6: FixedColumnWidth(60),
                                                  },
                                                  children: [
                                                    _tableRow([
                                                      "#",
                                                      "Item",
                                                      "Quantity",
                                                      "Price",
                                                      "Discount",
                                                      "Total",
                                                      "Action",
                                                    ], isHeader: true),
                                                    // Display sales items
                                                    ...salesItems.asMap().entries.map((
                                                      entry,
                                                    ) {
                                                      final index = entry.key;
                                                      final item = entry.value;
                                                      //  final isInsufficient =salesProvider.isPreviewItemInsufficient(item, value,);

                                                      final isInsufficient =
                                                          value
                                                              .stockCheckEnabled &&
                                                          salesProvider
                                                              .isPreviewItemInsufficient(
                                                                item,
                                                                value,
                                                              );
                                                      final isUnapproved =
                                                          item['isUnapproved'] ==
                                                          true;

                                                      return _tableRowWithAction(
                                                        (index + 1).toString(),
                                                        item['item'] ?? '',
                                                        "${item['quantity'] ?? '0'}${item['mode'] ?? ''}",
                                                        item['price'] ?? '0',
                                                        item['discount']
                                                                ?.toString() ??
                                                            '0',
                                                        item['totalamount'] ??
                                                            '0',
                                                        () => context
                                                            .read<
                                                              SalesProvider
                                                            >()
                                                            .removeFromSalesPreview(
                                                              index,
                                                            ),
                                                        isInsufficient:
                                                            isInsufficient,
                                                        isUnapproved:
                                                            isUnapproved,
                                                        onSync: isInsufficient
                                                            ? () => _syncItemBalance(
                                                                item['itemid'] ??
                                                                    '',
                                                                item['item'] ??
                                                                    '',
                                                                item['branchid'] ??
                                                                    '',
                                                                item['branchname'] ??
                                                                    '',
                                                              )
                                                            : null,
                                                      );
                                                    }).toList(),
                                                    _tableRow([
                                                      "",
                                                      "Taxable Total",
                                                      "",
                                                      "",
                                                      "",
                                                      salesProvider
                                                          .calculateTaxableTotal()
                                                          .toStringAsFixed(2),
                                                      "",
                                                    ]),
                                                    if (salesProvider
                                                            .calculateDiscountTotal() >
                                                        0)
                                                      _tableRow([
                                                        "",
                                                        "Discount Total",
                                                        "",
                                                        "",
                                                        "",
                                                        salesProvider
                                                            .calculateDiscountTotal()
                                                            .toStringAsFixed(2),
                                                        "",
                                                      ]),
                                                    _tableRow([
                                                      "",
                                                      "Payable Amount",
                                                      "",
                                                      "",
                                                      "",
                                                      salesProvider
                                                          .calculateTaxableTotal()
                                                          .toStringAsFixed(2),
                                                      "",
                                                    ]),
                                                  ],
                                                ),

                                                SizedBox(height: 20),
                                                LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    final isWideScreen =
                                                        constraints.maxWidth >
                                                        600;
                                                    final minWidth =
                                                        isWideScreen
                                                        ? 170.0
                                                        : 130.0;

                                                    return Wrap(
                                                      spacing: isWideScreen
                                                          ? 12
                                                          : 10,
                                                      runSpacing: isWideScreen
                                                          ? 12
                                                          : 10,
                                                      alignment:
                                                          WrapAlignment.center,
                                                      children: [
                                                        if (cashAllowed)
                                                          _previewActionTile(
                                                            label: posPrint
                                                                ? 'POS PRINT'
                                                                : 'SAVE',
                                                            icon: posPrint
                                                                ? Icons.print
                                                                : Icons.save,
                                                            color: posPrint
                                                                ? Colors.teal
                                                                : Colors.green,
                                                            onTap:
                                                                _printReceipt,
                                                            minWidth: minWidth,
                                                            isLoading:
                                                                _isSavingDirect,
                                                          ),

                                                        _previewActionTile(
                                                          label:
                                                              'NEW TRANSACTION',
                                                          icon: Icons
                                                              .add_shopping_cart,
                                                          color:
                                                              Colors.lightBlue,

                                                          onTap: () {
                                                            final provider =
                                                                context
                                                                    .read<
                                                                      SalesProvider
                                                                    >();
                                                            provider
                                                                .createNewCart();

                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'New transaction created: ${provider.currentCartId}',
                                                                ),
                                                                backgroundColor:
                                                                    Colors.blue,
                                                                duration:
                                                                    const Duration(
                                                                      seconds:
                                                                          2,
                                                                    ),
                                                              ),
                                                            );
                                                          },
                                                          minWidth: minWidth,
                                                        ),
                                                        _previewActionTile(
                                                          label:
                                                              'CUSTOMER INFO',
                                                          icon: Icons.person,
                                                          color: Colors.orange,
                                                          onTap: () async {
                                                            final salesProvider =
                                                                Provider.of<
                                                                  SalesProvider
                                                                >(
                                                                  context,
                                                                  listen: false,
                                                                );
                                                            final activeBranchId =
                                                                _activeBranchId;

                                                            final isService =
                                                                (_selectedItem
                                                                            ?.producttype ??
                                                                        '')
                                                                    .toLowerCase()
                                                                    .trim() ==
                                                                'service';

                                                            if (!isService &&
                                                                value
                                                                    .stockCheckEnabled) {
                                                              bool
                                                              isValid = await salesProvider
                                                                  .validateCartStockOnSaves(
                                                                    activeBranchId,
                                                                  );

                                                              if (!isValid) {
                                                                snackMsg(
                                                                  context,
                                                                  'Insufficient stock detected. Please adjust cart.',
                                                                  Colors.red,
                                                                );

                                                                return;
                                                              }
                                                            }
                                                            CustomerInfoDialog.show(
                                                              context: context,
                                                              // activeBranchId: value.activeBranchId,
                                                              activeBranchId:
                                                                  activeBranchId,
                                                              selectedItem:
                                                                  _selectedItem,
                                                            );
                                                          },
                                                          minWidth: minWidth,
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    Visibility(
                                      visible: isMobile && _showMobilePreview,
                                      child: MobileSalesPreview(
                                        cartItems: salesProvider.salesItems,
                                        customerCarts:
                                            salesProvider.customerCarts,
                                        currentCartId:
                                            salesProvider.currentCartId,
                                        taxableTotal: salesProvider
                                            .calculateTaxableTotal(),
                                        payableTotal: salesProvider
                                            .calculateTaxableTotal(),
                                        insufficientIndices: {
                                          for (
                                            int i = 0;
                                            i < salesProvider.salesItems.length;
                                            i++
                                          )
                                            if (value.stockCheckEnabled &&
                                                salesProvider
                                                    .isPreviewItemInsufficient(
                                                      salesProvider
                                                          .salesItems[i],
                                                      value,
                                                    ))
                                              i,
                                        },
                                        onSwitchCart: salesProvider.switchCart,
                                        onDeleteCart: salesProvider.deleteCart,
                                        onPrintReceipt: _printReceipt,
                                        onMomo: () {
                                          MomoDialog.showMomo(
                                            context: context,
                                            salesItems:
                                                salesProvider.salesItems,
                                          );
                                        },
                                        onNewTransaction:
                                            salesProvider.createNewCart,
                                        onCustomerInfo: () {
                                          CustomerInfoDialog.show(
                                            context: context,
                                            activeBranchId: _activeBranchId,
                                            // activeBranchId: value.activeBranchId,
                                            selectedItem: _selectedItem,
                                          );
                                        },
                                        onSaveDirect:
                                            value.accesslevel
                                                .toLowerCase()
                                                .contains('sales attendance')
                                            ? _saveDirectSale
                                            : null,
                                        saveDirectLabel: _isSavingDirect
                                            ? 'SAVING...'
                                            : 'SAVE DIRECT',
                                        isSavingDirect: _isSavingDirect,
                                        onRemoveItem: (int index) {
                                          salesProvider.removeFromSalesPreview(
                                            index,
                                          );
                                        },
                                        posPrint: posPrint,
                                        cashAllowed: cashAllowed,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefix,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      prefixIcon: prefix != null
          ? Icon(prefix, color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      filled: true,
    );
  }

  TableRow _tableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells
          .map(
            (e) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                e,
                textAlign: isHeader ? TextAlign.center : TextAlign.left,
                style: TextStyle(
                  fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  color: _primaryText,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  TableRow _tableRowWithAction(
    String index,
    String item,
    String quantity,
    String price,
    String discount,
    String total,
    VoidCallback onDelete, {
    bool isInsufficient = false,
    bool isUnapproved = false,
    VoidCallback? onSync,
  }) {
    final textColor = isInsufficient ? Colors.redAccent : _primaryText;

    return TableRow(
      decoration: isInsufficient
          ? BoxDecoration(color: Colors.red.withOpacity(0.12))
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(index, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(item, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(quantity, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(price, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(discount, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(total, style: TextStyle(color: textColor)),
        ),

        Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (isInsufficient && onSync != null)
                IconButton(
                  icon: const Icon(Icons.sync, color: Colors.orange, size: 18),
                  onPressed: onSync,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
