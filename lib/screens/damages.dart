import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart' hide Mode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/itemregmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/ReasonsModel.dart';
import '../models/damageitem.dart';
import '../models/itemmodel.dart';
import '../providers/SalesProvider.dart';
import '../widgets/offline_indicator.dart';
import 'damagesslist.dart';

class Damages extends StatefulWidget {
  final damageitemmodel? damageitem;

  const Damages({super.key, this.damageitem});

  @override
  State<Damages> createState() => _DamagesState();
}

class _DamagesState extends State<Damages> {
  bool _isSalesPointType(String? type) =>
      (type ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') ==
      'salespoint';

  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _textColor =>
      _isLightTheme ? Theme.of(context).colorScheme.onSurface : Colors.white;
  Color get _secondaryTextColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : Colors.white70;
  Color get _dividerColor => _isLightTheme
      ? Theme.of(context).colorScheme.outlineVariant
      : Colors.white24;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _totalPiecesController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _cppriceController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedDamageMode;
  List<String> _damageMode = [];

  List<Mode>? _itemModes;

  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  ItemModel? _selectedItem;
  String _searchQuery = '';
  String grandtotal = '0.0';
  List<Map<String, dynamic>> _damageItems = [];

  int? _editingIndex;
  String _branchid = "";
  String _branchname = "";
  double _selectedCartonLeft = 0.0;
  double _singleLeft = 0.0;
  Map<String, dynamic>? branchbalance;
  String? _selecteddamagereason;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final datafeed = context.read<Datafeed>();

      setState(() {
        _branchid = datafeed.branchid;
        _branchname = datafeed.branch;
      });
      context.read<Datafeed>().fetchItems();
      context.read<Datafeed>().fetchSuppliers();
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchReturnreasons();

      _barcodeController.addListener(_onBarcodeChanged);
      _quantityController.addListener(_updateTotals);
      _cppriceController.addListener(_updateTotals);
      _discountController.addListener(_updateTotals);
    });
    if (widget.damageitem != null) {
      final Map<String, dynamic> itemMap = Map<String, dynamic>.from(
        widget.damageitem!.item,
      );

      var indexkeys = itemMap.keys.toList()..sort();

      _damageItems = indexkeys
          .map((key) => Map<String, dynamic>.from(itemMap[key]))
          .toList();
      _syncTotals();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateGrandTotal();
      });
    } else {
      _damageItems = [];
      grandtotal = '0.0';
    }
  }

  @override
  void dispose() {
    _barcodeController.removeListener(_onBarcodeChanged);
    _barcodeController.dispose();
    _itemController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _discountController.removeListener(_updateTotals);
    _cppriceController.removeListener(_updateTotals);
    _totalPiecesController.dispose();
    _totalAmountController.dispose();
    _cppriceController.dispose();
    super.dispose();
  }

  void _syncTotals() {
    double total = 0;

    for (final item in _damageItems) {
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      final modeQty = double.tryParse(item['modeqty']?.toString() ?? '1') ?? 1;

      total += cp * qty * modeQty;
    }

    setState(() {
      grandtotal = total.toStringAsFixed(2);
      _totalAmountController.text = grandtotal;
    });
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

  void _addToSalesPreview() {
    final datafeed = Provider.of<Datafeed>(context, listen: false);
    if (_formKey.currentState!.validate()) {
      final qty = double.tryParse(_quantityController.text) ?? 0;
      final cp = double.tryParse(_cppriceController.text) ?? 0;
      if (_selectedCartonLeft <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No stock available for this item",
              style: TextStyle(color: Theme.of(context).colorScheme.surface),
            ),
          ),
        );
        return;
      }

      if (_selectedDamageMode?.toLowerCase() == 'single') {
        if (qty > _singleLeft) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Quantity exceeds available single stock"),
            ),
          );
          return;
        }
      } else {
        if (qty > _selectedCartonLeft) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Quantity exceeds available carton stock"),
            ),
          );
          return;
        }
      }
      String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final mode = _getSelectedMode();

      final modeQty = double.tryParse(mode?.qty ?? '1') ?? 1;

      final totalPieces = qty * modeQty;
      final itemGrandTotal = cp * totalPieces;
      final now = DateTime.now();

      final day = DateFormat('EEEE').format(now);
      final year = now.year.toString();
      final month = '${now.year}.${now.month}';
      final weekNumber =
          ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;

      final week = '${now.year}.$weekNumber';
      final salesItem = {
        'itemid': _selectedItem?.id ?? '',
        'barcode': _barcodeController.text,
        'cp': _cppriceController.text,
        'reason': _selecteddamagereason ?? '',
        'branchid': _branchid,
        'branchname': _branchname,
        'modeqty': mode?.qty ?? '1',
        'item': _itemController.text,
        'mode': _selectedDamageMode ?? 'single',
        'quantity': _quantityController.text,
        'totalpieces': totalPieces,
        'supplier': datafeed.selectedSupplier?.supplier ?? '',
        'grandtotal': itemGrandTotal.toStringAsFixed(2),
        'dateymd': formattedDate,
        'day': day,
        'week': week,
        'month': month,
        'year': year,
        'boxpiece':
            _itemModes
                ?.firstWhere(
                  (m) => m.name.toLowerCase() == 'carton',
                  orElse: () => Mode(
                    id: '',
                    name: '',
                    qty: '1',
                    cp: '',
                    rp: '',
                    wp: '',
                    sp: '',
                  ),
                )
                .qty ??
            '1',

        'modes': _itemModes != null
            ? {
                for (final m in _itemModes!)
                  m.name: {
                    'id': m.id,
                    'name': m.name,
                    'qty': m.qty,
                    'cp': m.cp,
                    'rp': m.rp,
                    'wp': m.wp,
                    'sp': m.sp,
                  },
              }
            : <String, dynamic>{},
      };

      setState(() {
        if (_editingIndex != null) {
          _damageItems[_editingIndex!] = salesItem;
          _editingIndex = null;
        } else {
          _damageItems.add(salesItem);
        }
        _recalculateGrandTotal();
      });
      _syncTotals();
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Item added to damages preview',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Mode? _getSelectedMode() {
    if (_itemModes == null || _selectedDamageMode == null) return null;

    return _itemModes!.firstWhere(
      (m) => m.name.toLowerCase() == _selectedDamageMode!.toLowerCase(),
      orElse: () =>
          Mode(id: '', name: '', qty: '', cp: '', rp: '', wp: '', sp: ''),
    );
  }

  void _updateTotals() {
    double totalCost = 0;
    double totalPieces = 0;

    for (var item in _damageItems) {
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      final modeQty = double.tryParse(item['modeqty']?.toString() ?? '1') ?? 1;

      final pieces = qty * modeQty;

      totalPieces += pieces;
      totalCost += cp * pieces;
    }

    _totalPiecesController.text = totalPieces.toStringAsFixed(2);
    _totalAmountController.text = totalCost.toStringAsFixed(2);

    setState(() {
      grandtotal = totalCost.toStringAsFixed(2);
    });
  }

  void _resetForm() {
    _itemController.clear();
    _barcodeController.clear();
    _quantityController.clear();
    _priceController.clear();
    _discountController.clear();
    _totalPiecesController.clear();
    _cppriceController.clear();

    setState(() {
      _selectedItem = null;

      _selectedDamageMode = null;

      _itemModes = null;
      _damageMode = [];
      _selecteddamagereason = null;
    });
  }

  void _removeFromSalesPreview(int index) {
    setState(() {
      _damageItems.removeAt(index);
      _recalculateGrandTotal();
    });
    _syncTotals();
  }

  void _recalculateGrandTotal() {
    double total = 0;
    for (final item in _damageItems) {
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      final modeQty = double.tryParse(item['modeqty']?.toString() ?? '1') ?? 1;
      total += cp * qty * modeQty;
    }
    setState(() {
      grandtotal = total.toStringAsFixed(2);
      _totalAmountController.text = grandtotal;
    });
  }

  bool _isLoading = false;

  void _editCartItem(int index) {
    final item = _damageItems[index];
    final datafeed = Provider.of<Datafeed>(context, listen: false);

    _barcodeController.removeListener(_onBarcodeChanged);

    final itemId = item['itemid']?.toString() ?? '';

    if (itemId.isNotEmpty) {
      final foundItem = datafeed.items.firstWhere(
        (i) => i.id == itemId,
        orElse: () => ItemModel.fromMap({'id': itemId}),
      );
      _selectItem(foundItem, datafeed);
    }
    setState(() {
      _editingIndex = index;
      _itemController.text = item['item']?.toString() ?? '';
      _barcodeController.text = item['barcode']?.toString() ?? '';
      _quantityController.text = item['quantity']?.toString() ?? '';
      _totalPiecesController.text = item['totalpieces']?.toString() ?? '';
      _selectedDamageMode = item['mode']?.toString() ?? '';
      _cppriceController.text = item['cp']?.toString() ?? '';
      _selecteddamagereason = item['reason']?.toString();
      _showSuggestions = false;

      double total = 0;
      for (final d in _damageItems) {
        final cp = double.tryParse(d['cp']?.toString() ?? '0') ?? 0;
        final qty = double.tryParse(d['quantity']?.toString() ?? '0') ?? 0;
        final modeQty = double.tryParse(d['modeqty']?.toString() ?? '1') ?? 1;
        total += cp * qty * modeQty;
      }
      grandtotal = total.toStringAsFixed(2);
      _totalAmountController.text = grandtotal;
    });

    _barcodeController.addListener(_onBarcodeChanged);
  }

  void _selectItem(ItemModel? item, Datafeed datafeed) {
    if (item == null) return;

    final branchId = _branchid;

    final branchbalance =
        item.branchbalance?[branchId] as Map<String, dynamic>? ?? {};

    final double netPieces =
        (branchbalance['netpieces'] as num?)?.toDouble() ?? 0.0;

    final mode = item.modes;

    final cartonMode = mode?.firstWhere(
      (m) => m.name.toLowerCase() == 'carton',
      orElse: () =>
          Mode(id: '', name: '', qty: '', cp: '', rp: '', wp: '', sp: ''),
    );

    final singleMode = mode?.firstWhere(
      (m) => m.name.toLowerCase() == 'single',
      orElse: () =>
          Mode(id: '', name: '', qty: '', cp: '', rp: '', wp: '', sp: ''),
    );

    final boxQty = double.tryParse(cartonMode?.qty ?? '1') ?? 1;
    final singleQty = double.tryParse(singleMode?.qty ?? '1') ?? 1;

    final double cartonsLeft = boxQty > 0 ? (netPieces / boxQty) : 0;
    final double singleLeft = singleQty > 0 ? (netPieces / singleQty) : 0;

    List<Mode>? effectivePricing;

    if (item.branchprices != null && item.branchprices!.containsKey(branchId)) {
      final rawPricing = item.branchprices![branchId]['pricing'];

      if (rawPricing is List) {
        effectivePricing = (rawPricing)
            .map((e) {
              final map = Map<String, dynamic>.from(e as Map);
              final id = map['id']?.toString() ?? '';
              return Mode.fromMap(id, map);
            })
            .cast<Mode>()
            .toList();
      } else if (rawPricing is Map) {
        effectivePricing = rawPricing.entries
            .map((entry) {
              final id = entry.key.toString();
              final map = Map<String, dynamic>.from(entry.value as Map);
              return Mode.fromMap(id, map);
            })
            .cast<Mode>()
            .toList();
      } else {
        effectivePricing = item.modes;
      }
    } else {
      effectivePricing = item.modes;
    }

    setState(() {
      _selectedItem = item;
      _selectedCartonLeft = cartonsLeft;
      _singleLeft = singleLeft;
      _itemModes = effectivePricing;

      if (_itemModes != null && _itemModes!.isNotEmpty) {
        _damageMode = _itemModes!.map((e) {
          return e.name.isNotEmpty ? e.name : e.id;
        }).toList();

        _damageMode.sort((a, b) {
          if (a.toLowerCase() == 'single') return -1;
          if (b.toLowerCase() == 'single') return 1;
          return 0;
        });

        _selectedDamageMode = _damageMode.first;
      } else {
        _damageMode = ['Single'];
        _selectedDamageMode = 'Single';
      }

      _itemController.text = item.name;
      _barcodeController.text = item.barcode;
      _cppriceController.text = item.cp;

      _showSuggestions = false;
      _suggestions.clear();
    });
  }

  Future<void> _addDamageReason(Datafeed datafeed) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSaving = false;
    String? errorMessage;

    try {
      final reasonName = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Damage Reason'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  errorText: errorMessage,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a reason'
                    : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        final name = controller.text.trim();
                        ReasonsModel? existingReason;
                        for (final reason in datafeed.returnitemreasons) {
                          if (reason.name.toLowerCase() == name.toLowerCase()) {
                            existingReason = reason;
                            break;
                          }
                        }
                        if (existingReason != null) {
                          Navigator.of(dialogContext).pop(existingReason.name);
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        try {
                          final id = datafeed.normalizeAndSanitize(
                            '${datafeed.companyid}$name',
                          );
                          final reason = ReasonsModel(
                            name: name,
                            staff: datafeed.staff,
                            id: id,
                            date: DateTime.now(),
                            companyid: datafeed.companyid,
                            company: datafeed.company,
                          );

                          await datafeed.db
                              .collection('return_reasons')
                              .doc(id)
                              .set(reason.toMap());
                          datafeed.returnitemreasons.add(reason);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(name);
                          }
                        } catch (error) {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = 'Could not save reason: $error';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          ),
        ),
      );

      if (reasonName != null && mounted) {
        setState(() => _selecteddamagereason = reasonName);
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _saveSale() async {
    if (_damageItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No items to save',
            style: TextStyle(color: Theme.of(context).colorScheme.surface),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final datafeed = Provider.of<Datafeed>(context, listen: false);

      final companyId = datafeed.companyid;
      final staffPosition = datafeed.staffPosition;

      final bool isEditing = widget.damageitem != null;

      final String docId;
      final String trnx;

      if (isEditing) {
        docId = widget.damageitem!.id;
        trnx = widget.damageitem!.trxid!;
      } else {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        docId = '${_branchid}_${staffPosition}_$timestamp'
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_]'), '');
        trnx = '${staffPosition}_$timestamp'.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9_]'),
          '',
        );
      }

      final Map<String, dynamic> itemsMap = {};
      for (int i = 0; i < _damageItems.length; i++) {
        itemsMap['item_$i'] = {..._damageItems[i]};
      }

      final formattedDate = context.read<SalesProvider>().saleDate;

      final damageitem = damageitemmodel(
        id: docId,
        trxid: trnx,
        itemcount: _damageItems.length.toString(),
        item: itemsMap,
        branchid: _branchid,
        branchname: _branchname,
        description: '',

        createdby: isEditing ? widget.damageitem!.createdby : datafeed.staff,
        createdat: isEditing ? widget.damageitem!.createdat : DateTime.now(),
        staffposition: staffPosition.toString(),
        companyid: companyId,
        company: datafeed.company,
        dateymd: formattedDate,
        grandtotal: grandtotal,
      );

      final saveFuture = datafeed.db
          .collection('damageitems')
          .doc(docId)
          .set(damageitem.tomap(), SetOptions(merge: true));

      final wasOffline = datafeed.isOffline;
      damageitemmodel? previousDamage;
      for (final existingDamage in datafeed.damages) {
        if (existingDamage.id == docId) {
          previousDamage = existingDamage;
          break;
        }
      }

      // Always queue the local pending item so desktop/web can save while offline.
      // Firestore persistence will upload it automatically once connection returns.
      datafeed.addPendingDamage(damageitem);
      unawaited(
        _finishQueuedDamageSave(saveFuture, datafeed, docId, previousDamage),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasOffline
                ? 'Damage saved on this device; it will sync when internet is available.'
                : 'Damage saved locally; it will sync automatically when online.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _damageItems.clear();
        _isLoading = false;
        _totalAmountController.text = '0.00';
        grandtotal = '0.00';
      });

      if (isEditing && mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving damages: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.surface),
          ),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _finishQueuedDamageSave(
    Future<void> saveFuture,
    Datafeed datafeed,
    String docId,
    damageitemmodel? previousDamage,
  ) async {
    try {
      await saveFuture;
      datafeed.markDamageSynced(docId);
    } catch (error) {
      datafeed.restoreDamageAfterFailedOfflineSave(docId, previousDamage);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not sync damage record: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final accesslevel = value.accesslevel;
        final isSuperAdmin = accesslevel.toLowerCase().trim() == 'super admin';
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          floatingActionButton: FloatingActionButton(
            backgroundColor: Theme.of(context).colorScheme.primary,
            tooltip: 'View Damages',
            child: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DamagesListPage()),
              );
            },
          ),
          appBar: AppBar(
            title: const Text("Damages"),
            centerTitle: true,
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).colorScheme.onSurface
                : Colors.white,
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 8.0,
                  top: 20,
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
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: itemWidth,
                                child: Container(
                                  color: Theme.of(context).colorScheme.surface,
                                  //height: 600,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Damages Entries",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _textColor,
                                          ),
                                        ),
                                        Divider(color: _dividerColor),
                                        SizedBox(height: 15),
                                        Form(
                                          key: _formKey,
                                          child: Column(
                                            children: [
                                              if (isSuperAdmin) ...[
                                                TextFormField(
                                                  controller: _dateController,
                                                  readOnly: true,
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                                  ),
                                                  decoration: _inputDecoration(
                                                    label: 'Date',
                                                    prefix:
                                                        Icons.calendar_today,
                                                    hint: 'yyyy-mm-dd',
                                                  ),
                                                  onTap: () async {
                                                    final picked = await showDatePicker(
                                                      context: context,
                                                      initialDate:
                                                          _selectedDate ??
                                                          DateTime.now(),
                                                      firstDate: DateTime(2020),
                                                      lastDate: DateTime.now(),
                                                      builder: (context, child) {
                                                        return Theme(
                                                          data: Theme.of(context).copyWith(
                                                            colorScheme:
                                                                Theme.of(
                                                                  context,
                                                                ).colorScheme.copyWith(
                                                                  primary:
                                                                      Colors
                                                                          .blue,
                                                                  onPrimary:
                                                                      Colors
                                                                          .white,
                                                                  surface: Color(
                                                                    0xFF22304A,
                                                                  ),
                                                                  onSurface:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                          ),
                                                          child: child!,
                                                        );
                                                      },
                                                    );

                                                    if (picked != null) {
                                                      context
                                                          .read<SalesProvider>()
                                                          .setSaleDate(picked);

                                                      setState(() {
                                                        _selectedDate = picked;
                                                        _dateController.text =
                                                            '${picked.year}-'
                                                            '${picked.month.toString().padLeft(2, '0')}-'
                                                            '${picked.day.toString().padLeft(2, '0')}';
                                                      });
                                                    }
                                                  },
                                                ),
                                              ],
                                              SizedBox(height: 10),
                                              DropdownButtonFormField<String>(
                                                isExpanded: true,
                                                value:
                                                    value.branches.any(
                                                      (b) =>
                                                          b.id ==
                                                              value.branchid &&
                                                          !_isSalesPointType(
                                                            b.branchtype,
                                                          ),
                                                    )
                                                    ? value.branchid
                                                    : null,
                                                dropdownColor: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Branch',
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
                                                  enabledBorder:
                                                      OutlineInputBorder(
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
                                                  focusedBorder:
                                                      OutlineInputBorder(
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
                                                  fillColor: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  filled: true,
                                                ),
                                                items: value.branches
                                                    .where(
                                                      (branch) =>
                                                          !_isSalesPointType(
                                                            branch.branchtype,
                                                          ),
                                                    )
                                                    .map((branch) {
                                                      return DropdownMenuItem<
                                                        String
                                                      >(
                                                        value: branch.id,
                                                        child: Text(
                                                          branch.branchname,
                                                          style: TextStyle(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ),
                                                        ),
                                                      );
                                                    })
                                                    .toList(),

                                                onChanged: (val) {
                                                  if (val != null) {
                                                    value.selectBranch(val);

                                                    setState(() {
                                                      _branchid = val;
                                                      _branchname = value
                                                          .branches
                                                          .firstWhere(
                                                            (b) =>
                                                                b.id == val &&
                                                                !_isSalesPointType(
                                                                  b.branchtype,
                                                                ),
                                                          )
                                                          .branchname;
                                                    });

                                                    if (_selectedItem != null) {
                                                      _selectItem(
                                                        _selectedItem,
                                                        value,
                                                      );
                                                    }

                                                    _formKey.currentState
                                                        ?.validate();
                                                  }
                                                },

                                                validator: (val) => val == null
                                                    ? 'Please select Branch'
                                                    : null,
                                              ),
                                              SizedBox(height: 10),
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
                                                        labelText: 'Barcode',
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
                                                        fillColor: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        filled: true,
                                                      ),
                                                      validator: (value) =>
                                                          value == null ||
                                                              value.isEmpty
                                                          ? 'Barcode required'
                                                          : null,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    height: 56,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.outline,
                                                      ),
                                                    ),
                                                    child: IconButton(
                                                      icon: Icon(
                                                        Icons.qr_code_scanner,
                                                        color:
                                                            _secondaryTextColor,
                                                      ),
                                                      onPressed: _scanBarcode,
                                                      tooltip:
                                                          'Scan Barcode/QR Code',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (_showSuggestions &&
                                                  _editingIndex == null)
                                                value.loading
                                                    ? Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : (() {
                                                        final query =
                                                            _searchQuery
                                                                .toLowerCase();

                                                        final filteredItems =
                                                            query.isEmpty
                                                            ? value.items
                                                            : value.items
                                                                  .where((
                                                                    item,
                                                                  ) {
                                                                    final name =
                                                                        (item.name)
                                                                            .toLowerCase();
                                                                    final barcode =
                                                                        (item.barcode)
                                                                            .toLowerCase();
                                                                    final company =
                                                                        (item.company)
                                                                            .toLowerCase();
                                                                    final category =
                                                                        (item.pcategory)
                                                                            .toLowerCase();

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
                                                                  .take(10)
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
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .surface,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            border: Border.all(
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .outlineVariant,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .shadow
                                                                        .withValues(
                                                                          alpha:
                                                                              0.12,
                                                                        ),
                                                                blurRadius: 8,
                                                                offset: Offset(
                                                                  0,
                                                                  4,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          constraints:
                                                              const BoxConstraints(
                                                                maxHeight: 250,
                                                              ),
                                                          child: ListView.builder(
                                                            shrinkWrap: true,
                                                            itemCount:
                                                                filteredItems
                                                                    .length,
                                                            itemBuilder: (context, index) {
                                                              final item =
                                                                  filteredItems[index];
                                                              final branchId =
                                                                  _branchid;
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

                                                              final mode =
                                                                  item.modes;

                                                              final cartonMode =
                                                                  mode?.firstWhere(
                                                                    (m) =>
                                                                        m.name
                                                                            .toLowerCase() ==
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

                                                              final singleMode =
                                                                  mode?.firstWhere(
                                                                    (m) =>
                                                                        m.name
                                                                            .toLowerCase() ==
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

                                                              final boxQty =
                                                                  double.tryParse(
                                                                    cartonMode
                                                                            ?.qty ??
                                                                        singleMode
                                                                            ?.qty ??
                                                                        '1',
                                                                  );

                                                              final double
                                                              cartonsLeft =
                                                                  boxQty! > 0
                                                                  ? (netPieces /
                                                                        boxQty)
                                                                  : 0.0;

                                                              return ListTile(
                                                                dense: true,
                                                                leading: Icon(
                                                                  Icons
                                                                      .inventory_2,
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.primary,
                                                                  size: 20,
                                                                ),
                                                                title: Text(
                                                                  item.name,
                                                                  style: TextStyle(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.onSurface,
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                                subtitle: Text(
                                                                  'Barcode: ${item.barcode} | Retail Price: GHS ${item.cp} | Boxes Balance: ${cartonsLeft.toStringAsFixed(2)} | Pieces: ${netPieces.toStringAsFixed(0)}',
                                                                  style: TextStyle(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.onSurfaceVariant,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                                ),
                                                                trailing: Icon(
                                                                  Icons
                                                                      .arrow_forward_ios,
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurfaceVariant,
                                                                  size: 14,
                                                                ),
                                                                onTap: () {
                                                                  _selectItem(
                                                                    item,
                                                                    value,
                                                                  );
                                                                },
                                                              );
                                                            },
                                                          ),
                                                        );
                                                      })(),

                                              SizedBox(height: 10),
                                              TextFormField(
                                                controller: _itemController,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
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
                                                  enabledBorder:
                                                      OutlineInputBorder(
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
                                                  focusedBorder:
                                                      OutlineInputBorder(
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
                                                  fillColor: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  filled: true,
                                                ),
                                                validator: (value) =>
                                                    value == null ||
                                                        value.isEmpty
                                                    ? 'Item required'
                                                    : null,
                                              ),
                                              SizedBox(height: 10),
                                              DropdownButtonFormField<String>(
                                                value: _selectedDamageMode,
                                                dropdownColor: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Sales Mode',
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
                                                  enabledBorder:
                                                      OutlineInputBorder(
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
                                                  focusedBorder:
                                                      OutlineInputBorder(
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
                                                  fillColor: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  filled: true,
                                                ),
                                                items: _damageMode.isEmpty
                                                    ? null
                                                    : _damageMode.map((type) {
                                                        return DropdownMenuItem<
                                                          String
                                                        >(
                                                          value: type,
                                                          child: Text(type),
                                                        );
                                                      }).toList(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedDamageMode = value;
                                                  });

                                                  _updateTotals();
                                                  _formKey.currentState
                                                      ?.validate();
                                                },
                                                validator: (value) =>
                                                    value == null
                                                    ? 'Please select sales mode'
                                                    : null,
                                              ),
                                              SizedBox(height: 10),
                                              TextFormField(
                                                controller: _cppriceController,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Cost price',
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
                                                  enabledBorder:
                                                      OutlineInputBorder(
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
                                                  focusedBorder:
                                                      OutlineInputBorder(
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
                                                  fillColor: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  filled: true,
                                                ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    _selectedDamageMode
                                                                ?.toLowerCase() ==
                                                            'single'
                                                        ? RegExp(r'^\d*$')
                                                        : RegExp(
                                                            r'^\d*\.?\d*$',
                                                          ),
                                                  ),
                                                ],
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Enter amount';
                                                  }
                                                  final amount =
                                                      double.tryParse(value);
                                                  if (amount == null ||
                                                      amount < 1) {
                                                    return 'Amount must be greater than zero';
                                                  }

                                                  return null;
                                                },
                                                enabled: false,
                                              ),
                                              SizedBox(height: 10),
                                              TextFormField(
                                                controller: _quantityController,
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                ),
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    _selectedDamageMode ==
                                                            'Single'
                                                        ? RegExp(r'^\d*$')
                                                        : RegExp(
                                                            r'^\d*\.?\d*$',
                                                          ),
                                                  ),
                                                ],
                                                decoration: InputDecoration(
                                                  labelText: 'Quantity',
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
                                                  enabledBorder:
                                                      OutlineInputBorder(
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
                                                  focusedBorder:
                                                      OutlineInputBorder(
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
                                                  fillColor: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  filled: true,
                                                ),
                                                onChanged: (value) {
                                                  // validate instantly when user types
                                                  _formKey.currentState
                                                      ?.validate();
                                                },
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return "Enter quantity";
                                                  }

                                                  final qty =
                                                      double.tryParse(value) ??
                                                      0;

                                                  if (_selectedCartonLeft <=
                                                      0) {
                                                    return "Item not available in $_branchname branch";
                                                  }

                                                  if (_selectedDamageMode
                                                              ?.toLowerCase() ==
                                                          'single' &&
                                                      qty > _singleLeft) {
                                                    return "Only ${_singleLeft.toStringAsFixed(0)} available in $_branchname branch";
                                                  }

                                                  if (_selectedDamageMode
                                                              ?.toLowerCase() ==
                                                          'carton' &&
                                                      qty >
                                                          _selectedCartonLeft) {
                                                    return "Only ${_selectedCartonLeft.toStringAsFixed(2)} available in $_branchname branch";
                                                  }

                                                  return null;
                                                },
                                              ),
                                              SizedBox(height: 10),
                                              DropdownSearch<String>(
                                                key: ValueKey(
                                                  value.selectedSupplier?.id,
                                                ),
                                                selectedItem:
                                                    value.suppliers.any(
                                                      (supplier) =>
                                                          supplier.id ==
                                                          value
                                                              .selectedSupplier
                                                              ?.id,
                                                    )
                                                    ? value.selectedSupplier!.id
                                                    : null,
                                                items:
                                                    (
                                                      filter,
                                                      infiniteScrollProps,
                                                    ) => value.suppliers
                                                        .map(
                                                          (supplier) =>
                                                              supplier.id,
                                                        )
                                                        .toList(),
                                                itemAsString: (supplierId) =>
                                                    value.suppliers
                                                        .firstWhere(
                                                          (supplier) =>
                                                              supplier.id ==
                                                              supplierId,
                                                        )
                                                        .supplier,
                                                decoratorProps: DropDownDecoratorProps(
                                                  decoration: InputDecoration(
                                                    labelText: 'Supplier',
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
                                                    enabledBorder:
                                                        OutlineInputBorder(
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
                                                    focusedBorder:
                                                        OutlineInputBorder(
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
                                                    fillColor: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    filled: true,
                                                  ),
                                                ),
                                                popupProps: PopupProps.menu(
                                                  showSearchBox: true,
                                                  searchFieldProps: TextFieldProps(
                                                    style: TextStyle(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Search suppliers...',
                                                      hintStyle: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                      prefixIcon: const Icon(
                                                        Icons.search,
                                                      ),
                                                      filled: true,
                                                      fillColor: Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest,
                                                    ),
                                                  ),
                                                  menuProps: MenuProps(
                                                    backgroundColor:
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                  ),
                                                  itemBuilder:
                                                      (
                                                        context,
                                                        supplierId,
                                                        isDisabled,
                                                        isSelected,
                                                      ) => ListTile(
                                                        title: Text(
                                                          value.suppliers
                                                              .firstWhere(
                                                                (supplier) =>
                                                                    supplier
                                                                        .id ==
                                                                    supplierId,
                                                              )
                                                              .supplier,
                                                          style: TextStyle(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                          ),
                                                        ),
                                                      ),
                                                ),
                                                dropdownBuilder:
                                                    (
                                                      context,
                                                      supplierId,
                                                    ) => Text(
                                                      supplierId == null
                                                          ? ''
                                                          : value.suppliers
                                                                .firstWhere(
                                                                  (supplier) =>
                                                                      supplier
                                                                          .id ==
                                                                      supplierId,
                                                                )
                                                                .supplier,
                                                      style: TextStyle(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                      ),
                                                    ),
                                                onSelected: (supplierId) {
                                                  if (supplierId != null) {
                                                    value.selectSupplier(
                                                      supplierId,
                                                    );
                                                  }
                                                },
                                                validator: (supplierId) =>
                                                    supplierId == null
                                                    ? 'Please select Supplier'
                                                    : null,
                                              ),
                                              SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: DropdownButtonFormField<String>(
                                                      value:
                                                          value
                                                              .returnitemreasons
                                                              .any(
                                                                (r) =>
                                                                    r.name ==
                                                                    _selecteddamagereason,
                                                              )
                                                          ? _selecteddamagereason
                                                          : null,
                                                      dropdownColor:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .surfaceContainerHighest,
                                                      style: TextStyle(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                      ),
                                                      iconEnabledColor:
                                                          _secondaryTextColor,
                                                      decoration: InputDecoration(
                                                        labelText:
                                                            'Damage Reason',
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
                                                        fillColor: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        filled: true,
                                                      ),
                                                      items: value.returnitemreasons.map((
                                                        reason,
                                                      ) {
                                                        return DropdownMenuItem<
                                                          String
                                                        >(
                                                          value: reason.name,
                                                          child: Text(
                                                            reason.name,
                                                            style: TextStyle(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurface,
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                      onChanged: (val) {
                                                        setState(() {
                                                          _selecteddamagereason =
                                                              val;
                                                        });
                                                      },
                                                      validator: (val) =>
                                                          val == null ||
                                                              val.isEmpty
                                                          ? 'Please select damage reason'
                                                          : null,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    tooltip:
                                                        'Add damage reason',
                                                    onPressed: () =>
                                                        _addDamageReason(value),
                                                    icon: const Icon(
                                                      Icons.add_circle_outline,
                                                    ),
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 10),
                                              Divider(color: _dividerColor),
                                              Wrap(
                                                spacing: 10,
                                                runSpacing: 10,
                                                children: [
                                                  SizedBox(
                                                    width: 150,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            _isLightTheme
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                            : const Color(
                                                                0xFF405A78,
                                                              ),
                                                        foregroundColor:
                                                            _isLightTheme
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary
                                                            : Colors.white,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 16,
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
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 150,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.orangeAccent,
                                                        foregroundColor:
                                                            _isLightTheme
                                                            ? Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                            : Colors.white,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 16,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: _resetForm,
                                                      child: Text("Reset"),
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
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Damages Preview",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: _textColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Divider(color: _dividerColor),
                                          SizedBox(height: 15),

                                          Table(
                                            border: TableBorder.all(
                                              color: Colors.grey,
                                            ),
                                            columnWidths: const {
                                              0: FixedColumnWidth(40),
                                              1: FlexColumnWidth(3),
                                              2: FlexColumnWidth(2),
                                              3: FlexColumnWidth(1),
                                              4: FlexColumnWidth(1),
                                              5: FlexColumnWidth(1),
                                              6: FixedColumnWidth(60),
                                            },
                                            children: [
                                              _tableRow([
                                                "#",
                                                "Item",
                                                "Mode",
                                                "Qty",
                                                "CP",
                                                "Total",
                                                "Action",
                                              ], isHeader: true),
                                              // Display sales items
                                              ..._damageItems.asMap().entries.map((
                                                entry,
                                              ) {
                                                final index = entry.key;
                                                final item = entry.value;
                                                final modeqty =
                                                    double.tryParse(
                                                      item['modeqty']
                                                              ?.toString() ??
                                                          '1',
                                                    ) ??
                                                    1;
                                                final quantity =
                                                    double.tryParse(
                                                      item['quantity']
                                                              ?.toString() ??
                                                          '0',
                                                    ) ??
                                                    0;
                                                final totalpieces =
                                                    modeqty * quantity;
                                                final itemCost =
                                                    double.tryParse(
                                                      item['cp']?.toString() ??
                                                          '0',
                                                    ) ??
                                                    0;
                                                final costprice =
                                                    itemCost * totalpieces;

                                                return _tableRowWithAction(
                                                  (index + 1).toString(),
                                                  item['item'] ?? '',
                                                  "${item['mode'] ?? ''} (${item['modeqty'] ?? '1'})",
                                                  item['quantity'] ?? '0',
                                                  item['cp'] ?? '0',
                                                  costprice.toStringAsFixed(2),
                                                  () => _removeFromSalesPreview(
                                                    index,
                                                  ),
                                                  onEdit: () =>
                                                      _editCartItem(index),
                                                );
                                              }),

                                              _tableRow([
                                                "",
                                                "Amount",
                                                "",
                                                "",
                                                "",
                                                grandtotal,
                                                "",
                                              ]),
                                            ],
                                          ),

                                          SizedBox(height: 20),
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              final isWideScreen =
                                                  constraints.maxWidth > 600;
                                              final buttonWidth = isWideScreen
                                                  ? 120.0
                                                  : 90.0;
                                              final buttonPadding = isWideScreen
                                                  ? 16.0
                                                  : 12.0;
                                              final fontSize = isWideScreen
                                                  ? 14.0
                                                  : 12.0;

                                              return Wrap(
                                                spacing: isWideScreen ? 10 : 6,
                                                runSpacing: isWideScreen
                                                    ? 10
                                                    : 8,
                                                alignment: WrapAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: buttonWidth,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.teal,
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              vertical:
                                                                  buttonPadding,
                                                              horizontal: 4,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: _isLoading
                                                          ? null
                                                          : _saveSale,
                                                      child: _isLoading
                                                          ? const SizedBox(
                                                              height: 20,
                                                              width: 20,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            )
                                                          : FittedBox(
                                                              fit: BoxFit
                                                                  .scaleDown,
                                                              child: Text(
                                                                "Save",
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      fontSize,
                                                                ),
                                                              ),
                                                            ),
                                                    ),
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
                                visible: isMobile,
                                child: MobileSalesPreview(
                                  cartItems: _damageItems,
                                  saveSale: _saveSale,
                                  isLoading: _isLoading,
                                  onDelete: _removeFromSalesPreview,
                                  onEdit: _editCartItem,
                                ),
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
                  color: _textColor,
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
    String cprice,
    String total,
    VoidCallback onDelete, {
    bool isInsufficient = false,
    VoidCallback? onEdit,
  }) {
    final textColor = isInsufficient ? Colors.redAccent : _textColor;
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
          child: Text(cprice, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(total, style: TextStyle(color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.amber, size: 18),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Edit',
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Barcode Scanner Screen
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Barcode/QR Code'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController,
              builder: (context, value, child) {
                final isFlashOn = value.torchState == TorchState.on;
                return Icon(
                  isFlashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_isProcessing) return;

              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;

              final barcode = barcodes.first;
              final String? code = barcode.rawValue;

              if (code != null && code.isNotEmpty) {
                setState(() => _isProcessing = true);
                Navigator.pop(context, code);
              }
            },
          ),
          // Overlay with scanning guide
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Position the barcode or QR code within the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

class MobileSalesPreview extends StatelessWidget {
  const MobileSalesPreview({
    super.key,
    required this.cartItems,
    required this.saveSale,
    required this.isLoading,
    required this.onDelete,
    required this.onEdit,
  });

  final List<Map<String, dynamic>> cartItems;
  final VoidCallback saveSale;
  final bool isLoading;
  final Function(int) onDelete;
  final Function(int) onEdit;

  double _calculateTotal() {
    double total = 0;

    for (var item in cartItems) {
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final modeqty = double.tryParse(item['modeqty']?.toString() ?? '1') ?? 1;
      final quantity =
          double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;

      final totalpieces = modeqty * quantity;

      total += cp * totalpieces;
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;
    final dividerColor = theme.colorScheme.outlineVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(width: 8),
              Text(
                "Damages Preview",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          Divider(color: dividerColor, height: 20),

          const SizedBox(height: 12),

          /// ITEMS LIST
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            separatorBuilder: (_, __) =>
                Divider(color: dividerColor, thickness: 1, height: 16),
            itemBuilder: (context, index) {
              final item = cartItems[index];
              return _cartItem(item, index, context: context);
            },
          ),

          const SizedBox(height: 20),
          Divider(color: dividerColor),

          /// TOTAL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Amount", style: TextStyle(color: secondaryTextColor)),
              Text(
                "GHS ${_calculateTotal().toStringAsFixed(2)}",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 18),

          /// SAVE BUTTON
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 150,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: isLoading ? null : saveSale,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text("Save"),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ITEM CARD
  Widget _cartItem(
    Map<String, dynamic> item,
    int index, {
    required BuildContext context,
    bool isInsufficient = false,
  }) {
    final name = (item['item'] ?? '').toString();
    final modes = (item['mode'] ?? '').toString();
    final modeqty = (item['modeqty'] ?? '').toString();
    final mode = modes.isNotEmpty ? "$modes ($modeqty)" : "";
    final price = _parseDouble(item['cp']);
    final qty = _parseDouble(item['quantity']);

    final total1 = price * (qty * _parseDouble(modeqty));
    final theme = Theme.of(context);
    final primaryColor = isInsufficient
        ? Colors.redAccent
        : theme.colorScheme.onSurface;
    final secondaryColor = isInsufficient
        ? Colors.redAccent
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: isInsufficient
          ? BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isInsufficient
                ? Colors.red.withOpacity(0.25)
                : theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.inventory_2,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: 10),

          /// ITEM INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// NAME + PRICE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: TextStyle(color: primaryColor, fontSize: 14),
                    ),
                    Text(
                      "GHS ${price.toStringAsFixed(2)}",
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                /// MODE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Mode",
                      style: TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                    Text(mode, style: TextStyle(color: primaryColor)),
                  ],
                ),

                /// QUANTITY
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Quantity",
                      style: TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                    Text(
                      qty.toStringAsFixed(0),
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),

                /// TOTAL
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total",
                      style: TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                    Text(
                      "GHS ${total1.toStringAsFixed(2)}",
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),

                /// WARNING
                if (isInsufficient)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Insufficient balance',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),

                const SizedBox(height: 6),

                /// ACTION BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.amber,
                        size: 18,
                      ),
                      onPressed: () => onEdit(index),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 18,
                      ),
                      onPressed: () => onDelete(index),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
