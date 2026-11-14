import 'dart:async';

import 'package:dropdown_search/dropdown_search.dart' hide Mode;
import 'package:flutter/foundation.dart' hide Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide Barcode;
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

import '../models/itemmodel.dart';
import '../models/itemregmodel.dart';
import '../models/productcategorymodel.dart';
import '../providers/Datafeed.dart';
import '../providers/item_provider.dart';
import 'itemlist.dart';

class ItemRegPage extends StatefulWidget {
  final String? docId;
  final ItemModel? item;

  const ItemRegPage({Key? key, this.docId, this.item}) : super(key: key);

  @override
  State<ItemRegPage> createState() => _ItemRegPageState();
}

class _ItemRegPageState extends State<ItemRegPage> {
  final _formKey = GlobalKey<FormState>();
  final _newCategoryController = TextEditingController();

  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costController = TextEditingController();
  int pricingStep = 0;
  bool _enableBoxPricing = false;
  bool _showBoxPricingSwitch = false;
  final _boxQtyController = TextEditingController();
  late final _halfboxqty_controller = TextEditingController();
  final _quarterqty_controller = TextEditingController();
  final _retail_price = TextEditingController();
  final _packQtyController = TextEditingController();

  final _supplierPriceController = TextEditingController();
  final _wholesalePriceController = TextEditingController();
  final _halfboxprice_controller = TextEditingController();
  final _quarterprice_controller = TextEditingController();
  final _packprice_controller = TextEditingController();

  final _wholesaleMinQtyController = TextEditingController();
  final _supplierMinQtyController = TextEditingController();
  final _shelfnumberController = TextEditingController();
  Map<String, TextEditingController> stockingControllers = {};

  final Set<String> _removedModes = {};
  String? _productType;
  String? _productCategory;
  bool _productTypeLocked = false;
  bool _productCategoryLocked = false;

  bool _loading = false;
  bool _imageExpanded = false;
  Uint8List? _logoBytes;
  File? _logoFile;
  String? _existingLogoUrl;
  String? itemname;
  final ImagePicker _picker = ImagePicker();

  String _formatSplitQuantity(double quantity) {
    return quantity.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String? _validateField(String fieldName, String? value) {
    return context.read<ItemProvider>().validateItemField(
      fieldName,
      value,
      ItemValidationValues(
        costPrice: _costController.text,
        retailPrice: _retail_price.text,
        boxQuantity: _boxQtyController.text,
        boxPrice: _wholesalePriceController.text,
        supplierPrice: _supplierPriceController.text,
        halfBoxQuantity: _halfboxqty_controller.text,
        halfBoxPrice: _halfboxprice_controller.text,
        quarterQuantity: _quarterqty_controller.text,
        quarterPrice: _quarterprice_controller.text,
        packQuantity: _packQtyController.text,
        enableBoxPricing: _enableBoxPricing,
      ),
    );
  }

  Future<void> _addProductCategory() async {
    _newCategoryController.clear();
    final datafeed = context.read<Datafeed>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formKey = GlobalKey<FormState>();
    var isSaving = false;

    final categoryName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add product category'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: _newCategoryController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Category name',
                labelStyle: TextStyle(
                  color: isDark
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
                floatingLabelStyle: TextStyle(
                  color: isDark ? colorScheme.onSurface : colorScheme.primary,
                ),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Enter category name';
                if (datafeed.productcategory.any(
                  (category) =>
                      category.productname.trim().toLowerCase() ==
                      name.toLowerCase(),
                )) {
                  return 'This category already exists';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? colorScheme.onSurface
                    : colorScheme.primary,
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final name = _newCategoryController.text.trim();
                      try {
                        await datafeed.addOrUpdateCategory(
                          Productcategorymodel(
                            productname: name,
                            staff: datafeed.staff,
                            companyid: datafeed.companyid,
                            companyemail: datafeed.companyemail,
                            date: DateTime.now(),
                            updatedat: DateTime.now(),
                            updatedby: datafeed.staff,
                          ),
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, name);
                        }
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Could not save category: $error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || categoryName == null) return;
    setState(() {
      _productCategory = categoryName;
    });
    _formKey.currentState?.validate();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchproductcategory();
    });

    if (widget.item != null) {
      final d = widget.item!;
      _existingLogoUrl = d.imageurl;
      _nameController.text = d.name ?? '';
      _barcodeController.text = d.barcode ?? '';
      _costController.text = d.cp ?? '';
      _productCategory = d.pcategory;
      _productType = d.producttype;
      _costController.text = d.cp;
      _shelfnumberController.text = d.shelfnumber ?? '';
      _supplierMinQtyController.text = d.sminqty;

      _enableBoxPricing = d.modemore == true;

      final modes = d.modes ?? <Mode>[];

      if (modes.any((m) => m.id.toLowerCase() == 'carton')) {
        final carton = modes.firstWhere((m) => m.id == 'carton');
        _boxQtyController.text = carton.qty;
        _retail_price.text = carton.rp;
        _wholesalePriceController.text = carton.wp;
        _supplierPriceController.text = carton.sp;
      }

      if (modes.any((m) => m.id.toLowerCase() == 'single')) {
        final single = modes.firstWhere((m) => m.id == 'single');
        _retail_price.text = single.rp;
        _costController.text = single.cp;
        if (!modes.any((m) => m.id.toLowerCase() == 'carton')) {
          _boxQtyController.text = single.qty;
          _wholesalePriceController.text = single.wp;
          _supplierPriceController.text = single.sp;
        }
      }

      if (modes.any((m) => m.id.toLowerCase() == 'half')) {
        final half = modes.firstWhere((m) => m.id == 'half');
        _halfboxqty_controller.text = half.qty;
        _halfboxprice_controller.text = half.wp;
      }

      if (modes.any((m) => m.id.toLowerCase() == 'quarter')) {
        final quarter = modes.firstWhere((m) => m.id == 'quarter');
        _quarterqty_controller.text = quarter.qty;
        _quarterprice_controller.text = quarter.wp;
      }

      if (modes.any((m) => m.id.toLowerCase() == 'pack')) {
        final pack = modes.firstWhere((m) => m.id == 'pack');
        _packQtyController.text = pack.qty;
        _packprice_controller.text = pack.wp;
      }

      int step = 0;
      if (modes.any((m) => m.id.toLowerCase() == 'half')) {
        step = 1;
        if (modes.any((m) => m.id.toLowerCase() == 'quarter')) {
          step = 2;
          if (modes.any((m) => m.id.toLowerCase() == 'pack')) step = 3;
        }
      }

      pricingStep = step;

      _enableBoxPricing =
          modes.isNotEmpty &&
          modes.any(
            (m) => [
              'carton',
              'half',
              'quarter',
              'pack',
            ].contains((m.id).toLowerCase()),
          );

      final boxQty = double.tryParse(_boxQtyController.text) ?? 0;
      _showBoxPricingSwitch = boxQty >= 1;
      if (boxQty >= 1) {
        _halfboxqty_controller.text = _formatSplitQuantity(boxQty / 2);
        _quarterqty_controller.text = _formatSplitQuantity(boxQty / 4);
      }
    }
  }

  void _clearAllFields() {
    _formKey.currentState?.reset();
    setState(() {
      _nameController.clear();
      _barcodeController.clear();
      _shelfnumberController.clear();
      _costController.clear();
      _boxQtyController.clear();
      _halfboxqty_controller.clear();
      _quarterqty_controller.clear();
      _retail_price.clear();
      _packQtyController.clear();
      _supplierPriceController.clear();
      _wholesalePriceController.clear();
      _halfboxprice_controller.clear();
      _quarterprice_controller.clear();
      _packprice_controller.clear();
      _wholesaleMinQtyController.clear();
      _supplierMinQtyController.clear();

      if (!_productTypeLocked) _productType = null;
      if (!_productCategoryLocked) _productCategory = null;
      // Reset pricing options
      pricingStep = 0;
      _enableBoxPricing = false;
      _showBoxPricingSwitch = false;

      // Clear image
      _logoBytes = null;
      _logoFile = null;
      _existingLogoUrl = null;
    });
  }

  Future<void> pickLogo() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    if (kIsWeb) {
      _logoBytes = await picked.readAsBytes();
      _logoFile = null;
    } else {
      _logoFile = File(picked.path);
      _logoBytes = null;
    }

    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, child) {
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
            title: Text(
              widget.docId == null
                  ? 'Register Item'
                  : 'Edit ${_nameController.text}',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.view_list),
                color: const Color(0xFF415A77),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ItemListPage()),
                  );
                },
              ),
            ],
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 1,
              bottom: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SizedBox(child: _imagePickerSection()),
                      const SizedBox(height: 10),
                      SizedBox(
                        child: _buildField(
                          _nameController,
                          'Item Name',
                          Icons.label,
                          onChanged: (v) {
                            _formKey.currentState!.validate();
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildField(
                              _barcodeController,
                              'Barcode',
                              Icons.qr_code,
                              required: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final theme = Theme.of(context);
                              return Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.qr_code_scanner,
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.white
                                        : theme.colorScheme.primary,
                                  ),
                                  onPressed: _scanBarcode,
                                  tooltip: 'Scan Barcode/QR Code',
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        child: _buildField(
                          _costController,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$'),
                            ),
                          ],
                          'Unit Cost Price',
                          Icons.attach_money,
                          isNumber: true,
                          onChanged: (_) {
                            _formKey.currentState?.validate();
                          },
                          validator: (v) => _validateField('costPrice', v),
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        child: _buildField(
                          _retail_price,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$'),
                            ),
                          ],
                          'Retail Price',
                          Icons.attach_money,
                          isNumber: true,
                          validator: (v) => _validateField('retailPrice', v),
                          onChanged: (_) {
                            _formKey.currentState?.validate();
                          },
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        child: _buildField(
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,1}$'),
                            ),
                          ],
                          _boxQtyController,
                          'Box quantity',
                          Icons.attach_money,
                          isNumber: true,
                          onChanged: (value) {
                            final qty = double.tryParse(value) ?? 0;
                            if (qty >= 1) {
                              setState(() {
                                _showBoxPricingSwitch = true;
                                _enableBoxPricing = true;

                                _halfboxqty_controller.text =
                                    _formatSplitQuantity(qty / 2);
                                _quarterqty_controller.text =
                                    _formatSplitQuantity(qty / 4);
                              });
                            } else {
                              setState(() {
                                _showBoxPricingSwitch = false;
                                _enableBoxPricing = false;
                                pricingStep = 0;
                                _halfboxqty_controller.clear();
                                _quarterqty_controller.clear();
                                _packQtyController.clear();
                              });
                            }
                            _formKey.currentState!.validate();
                          },
                          validator: (v) => _validateField('boxQty', v),
                        ),
                      ),
                      if (_showBoxPricingSwitch)
                        Builder(
                          builder: (context) {
                            final scheme = Theme.of(context).colorScheme;
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              selected: _enableBoxPricing,
                              selectedTileColor: scheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              title: Text(
                                'Enable carton and split pricing',
                                style: TextStyle(
                                  color: _enableBoxPricing
                                      ? (isDark ? Colors.white : scheme.primary)
                                      : scheme.onSurface,
                                  fontWeight: _enableBoxPricing
                                      ? FontWeight.w600
                                      : null,
                                ),
                              ),
                              subtitle: const Text(
                                'Add half, quarter, and pack sales modes',
                              ),
                              value: _enableBoxPricing,
                              activeThumbColor: scheme.onPrimary,
                              activeTrackColor: scheme.primary,
                              inactiveThumbColor: scheme.outline,
                              inactiveTrackColor:
                                  scheme.surfaceContainerHighest,
                              onChanged: (enabled) {
                                setState(() => _enableBoxPricing = enabled);
                              },
                            );
                          },
                        ),

                      SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldWithEnabled(
                              onChanged: (val) {
                                _formKey.currentState?.validate();
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}$'),
                                ),
                              ],
                              _wholesalePriceController,
                              'Box Price',
                              Icons.attach_money,
                              isNumber: true,
                              validator: (v) => _validateField('boxPrice', v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFieldWithEnabled(
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}$'),
                                ),
                              ],
                              _supplierPriceController,
                              'Supplier Price',
                              Icons.attach_money,
                              isNumber: true,
                              onChanged: (v) {
                                _formKey.currentState!.validate();
                              },
                              validator: (v) =>
                                  _validateField('supplierPrice', v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        child: _buildField(
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$'),
                            ),
                          ],
                          _supplierMinQtyController,
                          'Supplier Min Qty',
                          Icons.numbers,
                          isNumber: true,
                          onChanged: (value) {
                            _formKey.currentState?.validate();
                          },
                          validator: (v) => _validateField('supplierMinQty', v),
                        ),
                      ),
                      if (_enableBoxPricing) ...[
                        const SizedBox(height: 15),

                        /// HALF ROW
                        if (pricingStep >= 1)
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,3}$'),
                                    ),
                                  ],
                                  enabled: false,
                                  _halfboxqty_controller,
                                  'Half Box Qty',
                                  Icons.inventory,
                                  isNumber: true,
                                  validator: (v) =>
                                      _validateField('halfBoxQty', v),
                                  onChanged: (value) {
                                    _formKey.currentState?.validate();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildField(
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}$'),
                                    ),
                                  ],
                                  _halfboxprice_controller,
                                  'Half Box Price',
                                  Icons.attach_money,
                                  isNumber: true,
                                  validator: (v) =>
                                      _validateField('halfBoxPrice', v),
                                  onChanged: (value) {
                                    _formKey.currentState?.validate();
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Container(
                                height: 30,
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                                child: IconButton(
                                  tooltip: 'Remove half pricing',
                                  padding: EdgeInsets.zero,
                                  splashRadius: 20,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    Icons.remove_circle,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (dialogContext) {
                                        final colorScheme = Theme.of(
                                          dialogContext,
                                        ).colorScheme;
                                        return AlertDialog(
                                          backgroundColor: colorScheme.surface,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          title: Text(
                                            'Confirm removal',
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          content: Text(
                                            'Remove half-box pricing for this item? This cannot be undone.',
                                            style: TextStyle(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                false,
                                              ),
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    colorScheme.error,
                                                foregroundColor:
                                                    colorScheme.onError,
                                              ),
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                true,
                                              ),
                                              child: const Text('Remove'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirm != true) return;

                                    setState(() {
                                      pricingStep = 0;
                                      _removedModes.addAll({
                                        'half',
                                        'quarter',
                                        'pack',
                                      });

                                      _halfboxqty_controller.clear();
                                      _halfboxprice_controller.clear();

                                      _quarterqty_controller.clear();
                                      _quarterprice_controller.clear();

                                      _packQtyController.clear();
                                      _packprice_controller.clear();
                                    });

                                    if (widget.docId != null) {
                                      try {
                                        await context
                                            .read<ItemProvider>()
                                            .removeItemPricingMode(
                                              itemId: widget.docId!,
                                              modeId: 'half',
                                            );
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Half pricing removed',
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to remove half pricing: $e',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),

                        if (pricingStep >= 1) const SizedBox(height: 15),

                        /// QUARTER ROW
                        if (pricingStep >= 2)
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,3}$'),
                                    ),
                                  ],
                                  enabled: false,
                                  _quarterqty_controller,
                                  'Quarter Qty',
                                  Icons.inventory,
                                  isNumber: true,
                                  validator: (v) =>
                                      _validateField('quarterQty', v),
                                  onChanged: (value) {
                                    _formKey.currentState?.validate();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildField(
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}$'),
                                    ),
                                  ],
                                  _quarterprice_controller,
                                  'Quarter Price',
                                  Icons.attach_money,
                                  isNumber: true,
                                  validator: (v) =>
                                      _validateField('quarterPrice', v),
                                  onChanged: (value) {
                                    _formKey.currentState?.validate();
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Container(
                                height: 30,
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                                child: IconButton(
                                  tooltip: 'Remove quarter pricing',
                                  padding: EdgeInsets.zero,
                                  splashRadius: 20,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    Icons.remove_circle,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (dialogContext) {
                                        final colorScheme = Theme.of(
                                          dialogContext,
                                        ).colorScheme;
                                        return AlertDialog(
                                          backgroundColor: colorScheme.surface,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          title: Text(
                                            'Confirm removal',
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          content: Text(
                                            'Remove quarter pricing for this item? This cannot be undone.',
                                            style: TextStyle(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                false,
                                              ),
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    colorScheme.error,
                                                foregroundColor:
                                                    colorScheme.onError,
                                              ),
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                true,
                                              ),
                                              child: const Text('Remove'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirm != true) return;
                                    _removedModes.addAll({'quarter', 'pack'});
                                    setState(() {
                                      pricingStep = 1;
                                      _quarterqty_controller.clear();
                                      _quarterprice_controller.clear();
                                      _packQtyController.clear();
                                      _packprice_controller.clear();
                                    });

                                    if (widget.docId != null) {
                                      try {
                                        await context
                                            .read<ItemProvider>()
                                            .removeItemPricingMode(
                                              itemId: widget.docId!,
                                              modeId: 'quarter',
                                            );

                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Quarter pricing removed',
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to remove quarter pricing: $e',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),

                        if (pricingStep >= 2) const SizedBox(height: 15),

                        /// PACK ROW
                        if (pricingStep >= 3)
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}$'),
                                    ),
                                  ],
                                  _packQtyController,
                                  'Pack Qty',
                                  Icons.inventory,
                                  isNumber: true,
                                  validator: (v) =>
                                      _validateField('packQty', v),
                                  onChanged: (v) {
                                    _formKey.currentState!.validate();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildField(
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}$'),
                                    ),
                                  ],
                                  _packprice_controller,
                                  'Pack Price',
                                  Icons.attach_money,
                                  isNumber: true,
                                  validator: (v) =>
                                      _validateField('packPrice', v),
                                  onChanged: (value) {
                                    _formKey.currentState?.validate();
                                  },
                                ),
                              ),
                              SizedBox(width: 10),
                              Container(
                                height: 30,
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                                child: IconButton(
                                  tooltip: 'Remove pack pricing',
                                  padding: EdgeInsets.zero,
                                  splashRadius: 20,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    Icons.remove_circle,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (dialogContext) {
                                        final colorScheme = Theme.of(
                                          dialogContext,
                                        ).colorScheme;
                                        return AlertDialog(
                                          backgroundColor: colorScheme.surface,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          title: Text(
                                            'Confirm removal',
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          content: Text(
                                            'Remove pack pricing for this item? This cannot be undone.',
                                            style: TextStyle(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                false,
                                              ),
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    colorScheme.error,
                                                foregroundColor:
                                                    colorScheme.onError,
                                              ),
                                              onPressed: () => Navigator.pop(
                                                dialogContext,
                                                true,
                                              ),
                                              child: const Text('Remove'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirm != true) return;
                                    setState(() {
                                      pricingStep = 2;
                                      _packQtyController.clear();
                                      _packprice_controller.clear();
                                      _removedModes.add('pack');
                                    });

                                    if (widget.docId != null) {
                                      try {
                                        await context
                                            .read<ItemProvider>()
                                            .removeItemPricingMode(
                                              itemId: widget.docId!,
                                              modeId: 'pack',
                                            );

                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Pack pricing removed',
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to remove pack pricing: $e',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],

                      const SizedBox(height: 10),
                      _buildField(
                        _shelfnumberController,
                        'Shelf Number',
                        Icons.label,
                        onChanged: (v) {
                          if (v.isEmpty) {
                            return;
                          }
                        },
                        validator: (v) => null,
                      ),
                      const SizedBox(height: 10),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _productType,
                              dropdownColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: _buildDropdownDecoration(
                                'Product Type',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'product',
                                  child: Text('Product'),
                                ),
                                DropdownMenuItem(
                                  value: 'service',
                                  child: Text('Service'),
                                ),
                              ],
                              onChanged: _productTypeLocked
                                  ? null
                                  : (v) => setState(() {
                                      _productType = v;
                                      _formKey.currentState?.validate();
                                    }),
                              validator: (v) =>
                                  v == null ? 'Select product type' : null,
                            ),
                          ),

                          const SizedBox(width: 2),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: IconButton(
                              icon: Icon(
                                _productTypeLocked
                                    ? Icons.lock
                                    : Icons.lock_open,
                                color: _productTypeLocked
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).brightness ==
                                          Brightness.light
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.white24,
                              ),
                              tooltip: _productTypeLocked
                                  ? 'Unlock Product Type'
                                  : 'Lock Product Type',
                              onPressed: () => setState(
                                () => _productTypeLocked = !_productTypeLocked,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Builder(
                        builder: (context) {
                          final uniqueCategories = <String, String>{
                            for (final w in datafeed.productcategory)
                              w.productname: w.productname,
                          };
                          final safeCategoryValue =
                              uniqueCategories.containsKey(_productCategory)
                              ? _productCategory
                              : null;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DropdownSearch<String>(
                                  key: ValueKey(safeCategoryValue),
                                  selectedItem: safeCategoryValue,
                                  items: (filter, infiniteScrollProps) =>
                                      uniqueCategories.values.toList(),
                                  decoratorProps: DropDownDecoratorProps(
                                    decoration: _buildDropdownDecoration(
                                      'Product category',
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
                                        hintText: 'Search categories...',
                                        hintStyle: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        prefixIcon: const Icon(Icons.search),
                                        filled: true,
                                        fillColor: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                      ),
                                    ),
                                    menuProps: MenuProps(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                    ),
                                    itemBuilder:
                                        (
                                          context,
                                          category,
                                          isDisabled,
                                          isSelected,
                                        ) => ListTile(
                                          title: Text(
                                            category,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                  ),
                                  dropdownBuilder: (context, selectedItem) =>
                                      Text(
                                        selectedItem ?? '',
                                        style: TextStyle(
                                          color: selectedItem == null
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                        ),
                                      ),
                                  enabled: !_productCategoryLocked,
                                  onSelected: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _productCategory = value;
                                      _formKey.currentState?.validate();
                                    });
                                  },
                                  validator: (value) => value == null
                                      ? 'Select product category'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  tooltip: 'Add product category',
                                  onPressed: _productCategoryLocked
                                      ? null
                                      : _addProductCategory,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: IconButton(
                                  icon: Icon(
                                    _productCategoryLocked
                                        ? Icons.lock
                                        : Icons.lock_open,
                                    color: _productCategoryLocked
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).brightness ==
                                              Brightness.light
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Colors.white24,
                                  ),
                                  tooltip: _productCategoryLocked
                                      ? 'Unlock Product Category'
                                      : 'Lock Product Category',
                                  onPressed: () => setState(
                                    () => _productCategoryLocked =
                                        !_productCategoryLocked,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),

                          onPressed: _loading ? null : _saveItem,
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(color: Colors.white70),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          floatingActionButton:
              _enableBoxPricing &&
                  (double.tryParse(_boxQtyController.text) ?? 0) >= 1
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'add_pricing',
                        backgroundColor: Colors.green,
                        onPressed: () {
                          setState(() {
                            if (pricingStep < 3) pricingStep++;
                            _removedModes.remove(
                              const [
                                '',
                                'half',
                                'quarter',
                                'pack',
                              ][pricingStep],
                            );
                          });
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'toggle_pricing',
                        backgroundColor: Colors.blue,
                        onPressed: () {
                          setState(() => _enableBoxPricing = false);
                        },
                        child: const Icon(Icons.close),
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _imagePickerSection() {
    final colorScheme = Theme.of(context).colorScheme;
    bool hasImage =
        _logoBytes != null ||
        _logoFile != null ||
        (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Compact toggle button
        InkWell(
          onTap: () {
            setState(() => _imageExpanded = !_imageExpanded);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Row(
              children: [
                Icon(
                  hasImage ? Icons.image : Icons.add_photo_alternate,
                  color: hasImage ? Colors.green : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasImage
                        ? 'Item Image (tap to change)'
                        : 'Item Image (optional - tap to add)',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  _imageExpanded ? Icons.expand_less : Icons.expand_more,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        // Expanded content
        if (_imageExpanded) ...[
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: pickLogo,
              child: Container(
                height: 140,
                width: 140,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasImage ? Colors.green : colorScheme.outline,
                    width: hasImage ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: hasImage
                        ? Stack(
                            children: [
                              if (_logoBytes != null)
                                Image.memory(
                                  _logoBytes!,
                                  fit: BoxFit.cover,
                                  width: 140,
                                  height: 140,
                                )
                              else if (_logoFile != null)
                                Image.file(
                                  _logoFile!,
                                  fit: BoxFit.cover,
                                  width: 140,
                                  height: 140,
                                )
                              else if (_existingLogoUrl != null &&
                                  _existingLogoUrl!.isNotEmpty)
                                Image.network(
                                  _existingLogoUrl!,
                                  fit: BoxFit.cover,
                                  width: 140,
                                  height: 140,
                                ),
                            ],
                          )
                        : const Icon(
                            Icons.add_photo_alternate,
                            size: 50,
                            color: Colors.white38,
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: pickLogo,
                icon: Icon(hasImage ? Icons.edit : Icons.upload, size: 18),
                label: Text(hasImage ? 'Change' : 'Select Image'),
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
              ),
              if (hasImage) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _logoBytes = null;
                      _logoFile = null;
                      _existingLogoUrl = null;
                    });
                  },
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  TextFormField _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool enabled = true,
    bool isNumber = false,
    bool required = true,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      enabled: enabled,
      controller: controller,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _saveItem(),

      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),

      validator: (value) {
        if (validator != null) {
          return validator(value);
        }

        if (!required) return null;

        if (value == null || value.isEmpty) {
          return 'Required';
        }

        return null;
      },

      decoration: _inputDecoration(label, icon),
      onChanged: onChanged,
      inputFormatters: inputFormatters,
    );
  }

  TextFormField _buildFieldWithEnabled(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    bool enabled = true,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _saveItem(),
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      validator: validator ?? (v) => v == null || v.isEmpty ? 'Required' : null,
      decoration: _inputDecoration(label, icon),
      inputFormatters: inputFormatters,
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
      ),
      floatingLabelStyle: TextStyle(
        color: isDark ? colorScheme.onSurface : colorScheme.primary,
      ),
      prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
      ),
    );
  }

  InputDecoration _buildDropdownDecoration(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
      ),
      floatingLabelStyle: TextStyle(
        color: isDark ? colorScheme.onSurface : colorScheme.primary,
      ),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
      ),
    );
  }

  Future<void> _saveItem() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final datafeed = context.read<Datafeed>();
      final itemProvider = context.read<ItemProvider>();
      final itemName = _nameController.text.trim();
      final docId = itemProvider.itemDocumentId(datafeed.companyid, itemName);
      final imageUrl = await itemProvider.uploadItemImage(
        itemId: widget.docId ?? docId,
        file: _logoFile,
        bytes: _logoBytes,
        existingUrl: _existingLogoUrl,
        isWeb: kIsWeb,
      );
      final modes = itemProvider.buildItemModes(
        existingModes: widget.item?.modes ?? const [],
        companyType: datafeed.companytype,
        costPrice: _costController.text,
        retailPrice: _retail_price.text,
        boxQuantity: _boxQtyController.text,
        boxPrice: _wholesalePriceController.text,
        supplierPrice: _supplierPriceController.text,
        enableBoxPricing: _enableBoxPricing,
        pricingStep: pricingStep,
        halfBoxQuantity: _halfboxqty_controller.text,
        halfBoxPrice: _halfboxprice_controller.text,
        quarterQuantity: _quarterqty_controller.text,
        quarterPrice: _quarterprice_controller.text,
        packQuantity: _packQtyController.text,
        packPrice: _packprice_controller.text,
      );
      await itemProvider.saveItem(
        datafeed: datafeed,
        existingId: widget.docId,
        existingItem: widget.item,
        name: itemName,
        barcode: _barcodeController.text,
        costPrice: _costController.text,
        productType: _productType ?? '',
        productCategory: _productCategory ?? '',
        imageUrl: imageUrl ?? '',
        wholesaleMinQuantity: _wholesaleMinQtyController.text,
        supplierMinQuantity: _supplierMinQtyController.text,
        shelfNumber: _shelfnumberController.text,
        enableBoxPricing: _enableBoxPricing,
        modes: modes,
      );

      if (!mounted) return;
      if (widget.docId == null) _clearAllFields();
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.docId == null
                ? 'Item saved successfully!'
                : 'Item updated successfully!',
            style: TextStyle(color: theme.colorScheme.onPrimary),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $error',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newCategoryController.dispose();
    _barcodeController.dispose();
    _costController.dispose();
    _boxQtyController.dispose();
    _halfboxqty_controller.dispose();
    _quarterqty_controller.dispose();
    _retail_price.dispose();
    _packQtyController.dispose();
    _supplierPriceController.dispose();
    _wholesalePriceController.dispose();
    _halfboxprice_controller.dispose();
    _quarterprice_controller.dispose();
    _packprice_controller.dispose();
    _wholesaleMinQtyController.dispose();
    _supplierMinQtyController.dispose();
    _shelfnumberController.dispose();
    for (final controller in stockingControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
              // Only one child property is allowed
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
