import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/screens/requestinvoice.dart';
import 'package:provider/provider.dart';
import 'itemreg.dart';

class StockRequest extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? data;

  const StockRequest({super.key, this.docId, this.data});

  @override
  State<StockRequest> createState() => _StockRequestState();
}

class _StockRequestState extends State<StockRequest> {
  final _formkey = GlobalKey<FormState>();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  String? _selectedStockMode;
  List<String> _stockMode = [];
  String? _selectedPriceMode;
  Map<String, dynamic>? _itemModes;
  bool _loading = false;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  Map<String, dynamic>? _selectedItem;
  String _searchQuery = '';
  bool hasbranchprices = false;
  Map<String, dynamic> branchData = {};
  Map<String, dynamic> currentBranchPrice = {};
  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> branchbalance = {};
  Map<String, dynamic>? _branchbalancelist;
  Map<String, dynamic> currentBranchBalance = {};
  double itembalance = 0;
  @override
  void initState() {
    super.initState();
    _barcodeController.addListener(_onBarcodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<Datafeed>(context, listen: false);
      provider.fetchBranches();
      if (widget.data != null && widget.data!.containsKey('items')) {
        final rawItems = widget.data!['items'];
        if (rawItems is List) {
          _items.addAll(rawItems.map((e) => Map<String, dynamic>.from(e)));
        }
      }
    });
  }

  void showSnackBarMessage(
    String message, {
    Color backgroundColor = Colors.black87,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    _barcodeController.removeListener(_onBarcodeChanged);
    _barcodeController.dispose();
    _itemController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _onBarcodeChanged() {
    setState(() {
      _searchQuery = _barcodeController.text.trim();
      _showSuggestions = _searchQuery.isNotEmpty;
    });
  }

  _selectItem(Map<String, dynamic> item) {
    setState(() {
      try {
        final provider = Provider.of<Datafeed>(context, listen: false);
        final branchid = provider.selectedBranch?.id;
        _selectedItem = item;
        _barcodeController.text = item['barcode'] ?? '';
        _itemController.text = item['name'] ?? '';

        _itemModes = item['modes'] as Map<String, dynamic>?;

        _stockMode = provider.normalizeModes(_itemModes);

        _selectedStockMode = _stockMode.isNotEmpty ? _stockMode.first : null;

        //get balancaes
        branchbalance = item['branchbalance'];
        _branchbalancelist = branchbalance[branchid];
        if (_branchbalancelist != null) {
          itembalance =
              (_branchbalancelist?['netpieces'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {
        debugPrint("Error : $e");
        _stockMode = ['Single', 'Box'];
        _selectedStockMode = _stockMode.first;
      }

      _updatePrice();

      _showSuggestions = false;
      _suggestions = [];
    });
  }

  void _updatePrice() {
    if (_itemModes == null || _selectedStockMode == null) {
      _priceController.text = '0';
      return;
    }

    // Find the mode data by matching the name
    Map<String, dynamic>? selectedModeData;
    for (var entry in _itemModes!.entries) {
      final modeData = entry.value as Map<String, dynamic>?;
      if (modeData?['name'] == _selectedStockMode) {
        selectedModeData = modeData;
        break;
      }
    }

    if (selectedModeData != null) {
      // Set price based on retail/wholesale selection
      String price = '0';
      if (_selectedPriceMode == 'Retail') {
        price =
            selectedModeData['rp']?.toString() ??
            selectedModeData['retailprice']?.toString() ??
            '0';
      } else if (_selectedPriceMode == 'Wholesale') {
        price =
            selectedModeData['wp']?.toString() ??
            selectedModeData['wholesaleprice']?.toString() ??
            '0';
      } else {
        // Default to retail price
        price =
            selectedModeData['rp']?.toString() ??
            selectedModeData['retailprice']?.toString() ??
            '0';
      }

      _priceController.text = price;
    }
  }

  bool hasBalance = false;
  bool _checkItemBalance(double balance, double qty) {
    final isEnough = balance >= qty;

    setState(() {
      hasBalance = isEnough;
    });

    if (!isEnough) {
      showSnackBarMessage(
        'Insufficient balance',
        backgroundColor: Colors.redAccent,
      );
    }

    return isEnough;
  }

  void _addItem() {
    if (_formkey.currentState!.validate()) {
      setState(() {
        final double quantity =
            double.tryParse(_quantityController.text.trim()) ?? 0;
        final double price =
            double.tryParse(_priceController.text.trim())?.toDouble() ?? 0.0;
        // Determine mode quantity (pieces per selected mode) - default to 1 when missing
        double modeQty = 1;
        if (_itemModes != null && _selectedStockMode != null) {
          Map<String, dynamic>? selectedModeData;
          for (var entry in _itemModes!.entries) {
            final modeData = entry.value as Map<String, dynamic>?;
            if (modeData?['name'] == _selectedStockMode) {
              selectedModeData = modeData;
              break;
            }
          }

          if (selectedModeData != null) {
            final dynamic qVal = selectedModeData['qty'] ?? 1;
            if (qVal is num) {
              modeQty = qVal.toDouble();
            } else {
              modeQty = double.tryParse(qVal.toString()) ?? 1.0;
            }
          }
        }

        // pieces = modeQty * entered quantity
        final double pieces = modeQty * quantity;
        _checkItemBalance(itembalance, pieces);
        if (!hasBalance) return;
        final double total = price * quantity;
        String itemId = _selectedItem!['id'];

        final existingIndex = _items.indexWhere(
          (item) => item['itemid'] == itemId,
        );
        if (existingIndex != -1) {
          showSnackBarMessage(
            'Item already requested. Please edit the existing entry.',
            backgroundColor: Colors.redAccent,
          );

          return;
        }

        _items.add({
          'item': _itemController.text.trim(),
          'requestedquantity': quantity,
          'price': price,
          'total': total,
          'mode': _selectedStockMode ?? '',
          'modeqty': modeQty,
          'requestedpieces': pieces,
          'barcode': _barcodeController.text.trim(),
          'itemid': _selectedItem != null ? _selectedItem!['id'] ?? '' : '',
          'supplystatus': 'pending',
          'suppliedpieces': 0,
          'suppliedquantity': 0,
        });

        _itemController.clear();
        _quantityController.clear();
        _barcodeController.clear();
        _priceController.clear();
      });
    }
  }

  ({double gross}) _calculateTotals() {
    double baseTotal = 0.0;

    for (final it in _items) {
      final double price = (it['price'] as num?)?.toDouble() ?? 0.0;
      final double qty = (it['requestedquantity'] as num?)?.toDouble() ?? 0.0;
      baseTotal += price * qty;
    }

    return (gross: baseTotal);
  }

  bool _saved = false;
  Future updatewarehouse(String warehouseid) async {
    final Map<String, dynamic> warehouseData = {
      'stockrequest': true,
      'requestdate': Timestamp.fromDate(DateTime.now()),
    };
    await FirebaseFirestore.instance
        .collection('branches')
        .doc(warehouseid)
        .set(warehouseData, SetOptions(merge: true));
  }

  Future<void> _saveRecords() async {
    final provider = Provider.of<Datafeed>(context, listen: false);
    final requestwarehouseid = provider.selectedBranch?.id;

    if (_items.isEmpty) {
      showSnackBarMessage(
        'No items to save',
        backgroundColor: Colors.redAccent,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final totals = _calculateTotals();
      final docid =
          "${provider.branchid}${DateTime.now().millisecondsSinceEpoch}${provider.staffPosition}";
      final Map<String, dynamic> docData = {
        'items': _items,
        'gross': totals.gross,
        'status': 'pending',
        'createdby': provider.staff,
        'company': provider.company,
        'companyid': provider.companyid,
        'branch': provider.branch,
        'branchid': provider.branchid,
        'warehousename': provider.selectedBranch?.branchname,
        'warehouseid': provider.selectedBranch?.id,
        'requestid': docid,
        'createdat': Timestamp.fromDate(DateTime.now()),
      };
      await FirebaseFirestore.instance
          .collection('stock_request')
          .doc(docid)
          .set(docData, SetOptions(merge: true));
      await updatewarehouse(requestwarehouseid!);

      if (!mounted) return;
      setState(() {
        _saved = true;
      });
      showSnackBarMessage(
        'Records saved sucessfuly',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      showSnackBarMessage('Save failed: $e', backgroundColor: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        _formkey.currentState?.validate();
      }
    } catch (e) {
      if (mounted) {
        showSnackBarMessage(
          'Error opening scanner: $e',
          backgroundColor: Colors.redAccent,
        );
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefix,
    String? hint,
    Widget? suffix,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      hintText: hint,
      hintStyle: TextStyle(color: colors.onSurfaceVariant),
      prefixIcon: prefix != null
          ? Icon(prefix, color: colors.onSurfaceVariant)
          : null,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary),
      ),
      fillColor: colors.surfaceContainerHighest,
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Stock Request')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 8.0,
            top: 20,
            right: 8,
            bottom: 20,
          ),
          child: Column(
            children: [
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final provider = Provider.of<Datafeed>(
                      context,
                      listen: false,
                    );
                    final isSmallScreen = constraints.maxWidth < 900;
                    final double itemWidth = isSmallScreen
                        ? constraints.maxWidth
                        : (constraints.maxWidth / 2) - 24;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: Container(
                            color: colors.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "REQUEST FORM",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  Divider(color: colors.outlineVariant),
                                  const SizedBox(height: 15),
                                  Form(
                                    key: _formkey,
                                    child: Column(
                                      children: [
                                        DropdownButtonFormField<String>(
                                          value:
                                              provider.branches
                                                  .where(
                                                    (b) =>
                                                        b.branchtype !=
                                                        'Sales Point',
                                                  )
                                                  .any(
                                                    (b) =>
                                                        b.id ==
                                                        provider
                                                            .selectedBranch
                                                            ?.id,
                                                  )
                                              ? provider.selectedBranch?.id
                                              : null,
                                          dropdownColor:
                                              colors.surfaceContainerHighest,
                                          style: TextStyle(
                                            color: colors.onSurface,
                                          ),
                                          decoration: _inputDecoration(
                                            label: 'Branch',
                                            prefix: Icons.business,
                                          ),
                                          items: provider.branches
                                              .where(
                                                (branch) =>
                                                    branch.branchtype !=
                                                    'Sales Point',
                                              )
                                              .map((branches) {
                                                final isUserBranch =
                                                    branches.id ==
                                                    provider.branchid;
                                                return DropdownMenuItem<String>(
                                                  value: branches.id,
                                                  enabled: !isUserBranch,
                                                  child: Text(
                                                    branches.branchname,
                                                    style: TextStyle(
                                                      color: isUserBranch
                                                          ? colors
                                                                .onSurfaceVariant
                                                          : colors.onSurface,
                                                    ),
                                                  ),
                                                );
                                              })
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null)
                                              provider.selectBranch(val);
                                          },
                                          validator: (val) {
                                            if (val == null) {
                                              return 'Please select warehouse/branch';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: _barcodeController,
                                                style: TextStyle(
                                                  color: colors.onSurface,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Barcode',
                                                  labelStyle: TextStyle(
                                                    color:
                                                        colors.onSurfaceVariant,
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
                                                          color: colors
                                                              .outlineVariant,
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: colors.primary,
                                                        ),
                                                      ),
                                                  fillColor: colors
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
                                                color: colors
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: colors.outlineVariant,
                                                ),
                                              ),
                                              child: IconButton(
                                                icon: Icon(
                                                  Icons.qr_code_scanner,
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                                onPressed: _scanBarcode,
                                                tooltip: 'Scan Barcode/QR Code',
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_showSuggestions)
                                          StreamBuilder<
                                            List<Map<String, dynamic>>
                                          >(
                                            stream: provider.itemsStream(
                                              collectionName: 'itemsreg',
                                            ),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData) {
                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    top: 4,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: colors.primary,
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                );
                                              }

                                              final allDocs = snapshot.data!;
                                              final filteredDocs = allDocs
                                                  .where((doc) {
                                                    final data =
                                                        doc
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >;
                                                    final name =
                                                        (data['name'] ?? '')
                                                            .toString()
                                                            .toLowerCase();
                                                    final barcode =
                                                        (data['barcode'] ?? '')
                                                            .toString()
                                                            .toLowerCase();
                                                    final query = _searchQuery
                                                        .toLowerCase();
                                                    return name.contains(
                                                          query,
                                                        ) ||
                                                        barcode.contains(query);
                                                  })
                                                  .take(10)
                                                  .toList();

                                              if (filteredDocs.isEmpty)
                                                return const SizedBox.shrink();

                                              return Container(
                                                margin: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colors
                                                      .surfaceContainerHighest,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: colors.primary
                                                        .withOpacity(0.3),
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: colors.shadow
                                                          .withOpacity(0.2),
                                                      blurRadius: 8,
                                                      offset: Offset(0, 4),
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
                                                      filteredDocs.length,
                                                  itemBuilder: (context, index) {
                                                    final doc =
                                                        filteredDocs[index];
                                                    final item =
                                                        doc
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >;
                                                    item['id'] = doc['id'];

                                                    return ListTile(
                                                      dense: true,
                                                      leading: Icon(
                                                        Icons.inventory_2,
                                                        color: colors.primary,
                                                        size: 20,
                                                      ),
                                                      title: Text(
                                                        item['name'] ?? '',
                                                        style: TextStyle(
                                                          color:
                                                              colors.onSurface,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        'Barcode: ${item['barcode']} | Retail: GHS ${item['retailprice']} }',
                                                        style: TextStyle(
                                                          color: colors
                                                              .onSurfaceVariant,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                      trailing: Icon(
                                                        Icons.arrow_forward_ios,
                                                        color: colors
                                                            .onSurfaceVariant,
                                                        size: 14,
                                                      ),
                                                      onTap: () =>
                                                          _selectItem(item),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: _itemController,
                                          style: TextStyle(
                                            color: colors.onSurface,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Item',
                                            labelStyle: TextStyle(
                                              color: colors.onSurfaceVariant,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: colors.outlineVariant,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: colors.primary,
                                              ),
                                            ),
                                            fillColor:
                                                colors.surfaceContainerHighest,
                                            filled: true,
                                          ),
                                          validator: (value) =>
                                              value == null || value.isEmpty
                                              ? 'Item required'
                                              : null,
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: DropdownButtonFormField<String>(
                                                value: _selectedStockMode,
                                                dropdownColor: colors
                                                    .surfaceContainerHighest,
                                                style: TextStyle(
                                                  color: colors.onSurface,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Mode',
                                                  labelStyle: TextStyle(
                                                    color:
                                                        colors.onSurfaceVariant,
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
                                                          color: colors
                                                              .outlineVariant,
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: colors.primary,
                                                        ),
                                                      ),
                                                  fillColor: colors
                                                      .surfaceContainerHighest,
                                                  filled: true,
                                                ),
                                                items: _stockMode.isEmpty
                                                    ? null
                                                    : _stockMode.map((type) {
                                                        return DropdownMenuItem<
                                                          String
                                                        >(
                                                          value: type,
                                                          child: Text(type),
                                                        );
                                                      }).toList(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedStockMode = value;
                                                    //_updatePrice();
                                                  });
                                                },
                                                validator: (value) =>
                                                    value == null
                                                    ? 'Please select item mode'
                                                    : null,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: TextFormField(
                                                readOnly: false,
                                                controller: _quantityController,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r'^\d*\.?\d*$'),
                                                  ),
                                                ],
                                                style: TextStyle(
                                                  color: colors.onSurface,
                                                ),
                                                decoration: InputDecoration(
                                                  labelText: 'Quantity',
                                                  labelStyle: TextStyle(
                                                    color:
                                                        colors.onSurfaceVariant,
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
                                                          color: colors
                                                              .outlineVariant,
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: colors.primary,
                                                        ),
                                                      ),
                                                  fillColor: colors
                                                      .surfaceContainerHighest,
                                                  filled: true,
                                                ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Enter quantity';
                                                  }
                                                  final qty = double.tryParse(
                                                    value,
                                                  );
                                                  if (qty == null) {
                                                    return 'Quantity must be a number';
                                                  }
                                                  if (qty < 0.5) {
                                                    return 'Quantity must be greater than 0.5';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Divider(color: colors.outlineVariant),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            if (!_saved)
                                              SizedBox(
                                                width: 150,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        colors.primary,
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
                                                  onPressed: _loading
                                                      ? null
                                                      : _addItem,
                                                  child: Text(
                                                    "Add Record",
                                                    style: TextStyle(
                                                      color: colors.onPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            SizedBox(
                                              width: 150,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      colors.primary,
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
                                                onPressed: () {
                                                  setState(() {
                                                    _itemController.clear();
                                                    _priceController.clear();
                                                    _quantityController.clear();
                                                    _barcodeController.clear();
                                                    _selectedStockMode = null;
                                                    _saved = false;
                                                    _loading = false;
                                                    _barcodeController.text =
                                                        '';
                                                    _showSuggestions = false;
                                                    _searchQuery = '';
                                                  });
                                                },
                                                child: Text(
                                                  "Reset",
                                                  style: TextStyle(
                                                    color: colors.onPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 150,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      colors.secondaryContainer,
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
                                                onPressed: () {
                                                  setState(() {
                                                    _items.clear();
                                                    _itemController.clear();
                                                    _priceController.clear();
                                                    _quantityController.clear();
                                                    _barcodeController.clear();
                                                    _selectedStockMode = null;
                                                    _saved = false;
                                                    _loading = false;
                                                    _barcodeController.text =
                                                        '';
                                                    _showSuggestions = false;
                                                    _searchQuery = '';
                                                    provider.selectedwarehouse =
                                                        null;
                                                  });
                                                },
                                                child: Text(
                                                  "New Transaction",
                                                  style: TextStyle(
                                                    color: colors
                                                        .onSecondaryContainer,
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
                        isSmallScreen
                            ? MobileSalesPreview(
                                items: _items,
                                onSave: _saveRecords,
                                onNewTransaction: _saveRecords,
                                onDeleteItem: (index) {
                                  setState(() {
                                    _items.removeAt(index);
                                  });
                                },
                                loading: _loading,
                                saveditems: _saved,
                              )
                            : _buildStockTable(itemWidth),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockTable(double itemWidth) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: itemWidth,
      child: Container(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "REQUEST PREVIEW",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              Divider(color: colors.outlineVariant),
              const SizedBox(height: 15),
              Table(
                border: TableBorder.all(color: colors.outlineVariant),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  // 4: FlexColumnWidth(1),
                  6: FlexColumnWidth(1),
                  7: FlexColumnWidth(1), // extra column for delete
                },
                children: [
                  _tableRow([
                    "#",
                    "Item",
                    "Mode",
                    "Qty",
                    //"Pieces",
                    "Total",
                    "Action",
                  ], isHeader: true),
                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final priceText = (item['price'] != null)
                        ? (item['price'] as double).toStringAsFixed(2)
                        : '0.00';
                    final totalText = (item['total'] != null)
                        ? (item['total'] as double).toStringAsFixed(2)
                        : '0.00';

                    return TableRow(
                      children: [
                        _cell((idx + 1).toString()),
                        _cell(item['item']?.toString() ?? ''),
                        _cell(item['mode']?.toString() ?? ''),
                        _cell(
                          item['requestedquantity']?.toString() ?? '0',
                          alignRight: true,
                        ),
                        // _cell(item['pieces']?.toString() ?? '0', alignRight: true),
                        _cell(totalText, alignRight: true),
                        _saved
                            ? const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text("Confirm Delete"),
                                        content: const Text(
                                          "Are you sure you want to delete this item?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      setState(() {
                                        _items.removeAt(idx);
                                      });
                                    }
                                  },
                                ),
                              ),
                      ],
                    );
                  }).toList(),
                  (() {
                    return _tableRow(["", "", "", "", "", ""]);
                  })(),
                  (() {
                    final totals = _calculateTotals();
                    return _tableRow([
                      "",
                      "Grand Total",
                      "",
                      "",
                      //"",
                      totals.gross!.toStringAsFixed(2),
                      "",
                    ]);
                  })(),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_saved)
                      SizedBox(
                        width: 150,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _loading
                              ? null
                              : () async {
                                  setState(() => _loading = true);
                                  await _saveRecords();
                                  if (mounted) setState(() => _loading = false);
                                },
                          child: _loading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: colors.onPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "SAVE RECORDS",
                                  style: TextStyle(color: colors.onPrimary),
                                ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    if (_saved)
                      SizedBox(
                        width: 150,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final totals = _calculateTotals();
                              await printRecords(context, _items, totals.gross);
                            } catch (e) {
                              showSnackBarMessage(
                                'Error generating PDF: $e',
                                backgroundColor: Colors.redAccent,
                              );
                            }
                          },
                          icon: const Icon(Icons.print),
                          label: const Text('PRINT'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.primary),
                            foregroundColor: colors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _tableRow(List<String> cells, {bool isHeader = false}) {
    final colors = Theme.of(context).colorScheme;
    return TableRow(
      children: cells.asMap().entries.map((entry) {
        final index = entry.key;
        final text = entry.value;

        TextAlign align;
        if (isHeader) {
          align = TextAlign.center;
        } else if ([4, 5, 6, 7, 8].contains(index)) {
          align = TextAlign.right;
        } else {
          align = TextAlign.left;
        }

        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            text,
            textAlign: align,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _cell(String text, {bool alignRight = false}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(color: colors.onSurface),
      ),
    );
  }
}

class MobileSalesPreview extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback? onSave;
  final VoidCallback? onNewTransaction;
  final void Function(int index)? onDeleteItem;
  final bool loading;
  final bool saveditems;

  const MobileSalesPreview({
    super.key,
    required this.items,
    this.onSave,
    this.onNewTransaction,
    this.onDeleteItem,
    this.loading = false,
    this.saveditems = false,
  });

  @override
  State<MobileSalesPreview> createState() => _MobileSalesPreviewState();
}

class _MobileSalesPreviewState extends State<MobileSalesPreview> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Request Preview",
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(color: colors.outlineVariant, height: 20),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => Divider(color: colors.outlineVariant),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _cartItem(
                name: item['item'] ?? '',
                price: (item['price'] ?? 0.0).toDouble(),
                qty: double.tryParse(item['requestedquantity'].toString()) ?? 0,
                mode: item['mode'] ?? "",
                total: (item['total'] ?? 0.0).toDouble(),
                onDelete: widget.saveditems
                    ? null
                    : () => widget.onDeleteItem?.call(index),
              );
            },
          ),

          Divider(color: colors.outlineVariant),
          _row(
            "Total",
            "GHS ${widget.items.fold(0.0, (sum, item) => sum + (item['total'] ?? 0.0)).toStringAsFixed(2)}",
            bold: true,
          ),
          const SizedBox(height: 18),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!widget.saveditems)
                _actionBtn("SAVE RECORDS", colors.primary, widget.onSave),
              if (widget.saveditems)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () async {
                    await printRecords(
                      context,
                      widget.items,
                      widget.items.fold(
                        0.0,
                        (sum, item) => sum + (item['total'] ?? 0.0),
                      ),
                    );
                  },
                  child: Text(
                    "Print",
                    style: TextStyle(color: colors.onPrimary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cartItem({
    required String name,
    required double price,
    required double qty,
    required String mode,
    required double total,
    VoidCallback? onDelete,
  }) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: onDelete,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(name, "GHS ${price.toStringAsFixed(2)}"),
              _line("Mode", mode),
              _line("Qty", "$qty"),
              _line("Total", "GHS ${total.toStringAsFixed(2)}"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(String left, String right) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        left,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      Text(
        right,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
    ],
  );

  Widget _row(String label, String value, {bool bold = false}) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(String text, Color color, VoidCallback? onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: widget.loading ? null : onTap,
      child: widget.loading
          ? SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
