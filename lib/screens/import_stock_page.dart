import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/mode.dart';
import '../providers/Datafeed.dart';
import '../providers/StockProvider.dart';

class ImportStockPage extends StatefulWidget {
  const ImportStockPage({super.key});

  @override
  State<ImportStockPage> createState() => _ImportStockPageState();
}

class _ImportRow {
  final Map<String, String> rawData;

  String itemName;
  String barcode;
  double unitCostPrice;
  double retailPrice;
  double boxQuantity;
  double boxPrice;
  double halfBoxQty;
  double halfBoxPrice;
  double quarterQty;
  double quarterPrice;
  double supplierPrice;
  double supplierMinQty;
  String productType;
  String productCategory;
  double stockQuantity;

  bool isValid;
  String validationError;

  _ImportRow({
    required this.rawData,
    required this.itemName,
    required this.barcode,
    required this.unitCostPrice,
    required this.retailPrice,
    required this.boxQuantity,
    required this.boxPrice,
    required this.halfBoxQty,
    required this.halfBoxPrice,
    required this.quarterQty,
    required this.quarterPrice,
    required this.supplierPrice,
    required this.supplierMinQty,
    required this.productType,
    required this.productCategory,
    required this.stockQuantity,
    this.isValid = true,
    this.validationError = '',
  });
}

class _ImportStockPageState extends State<ImportStockPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _selectedBranchId;
  String _selectedBranchName = '';

  String? _fileName;
  List<_ImportRow> _parsedRows = [];
  bool _isLoading = false;
  bool _isImporting = false;
  int _importProgress = 0;
  int _totalToImport = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final datafeed = Provider.of<Datafeed>(context, listen: false);
      datafeed.fetchBranches();
      if (datafeed.branches.isNotEmpty) {
        final b = datafeed.branches.firstWhere(
          (br) => br.id == datafeed.branchid,
          orElse: () => datafeed.branches.first,
        );
        setState(() {
          _selectedBranchId = b.id;
          _selectedBranchName = b.branchname;
        });
      }
    });
  }

  // --- Excel Template Generator ---
  Future<void> _downloadTemplate() async {
    try {
      final excel = xls.Excel.createExcel();
      final sheet = excel['Stock_Import_Template'];
      excel.delete('Sheet1');

      final headers = [
        'Item Name',
        'Barcode',
        'Unit Cost Price',
        'Retail Price',
        'Box Quantity',
        'Box Price',
        'Half Box Qty',
        'Half Box Price',
        'Quarter Qty',
        'Quarter Price',
        'Supplier Price',
        'Supplier Min Quantity',
        'Product Type',
        'Product Category',
        'Stock Quantity'
      ];

      sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());

      // Sample Row
      sheet.appendRow([
        xls.TextCellValue('Sample Paracetamol 500mg'),
        xls.TextCellValue('503928172635'),
        xls.TextCellValue('12.50'),
        xls.TextCellValue('18.00'),
        xls.TextCellValue('24'),
        xls.TextCellValue('280.00'),
        xls.TextCellValue('12'),
        xls.TextCellValue('145.00'),
        xls.TextCellValue('6'),
        xls.TextCellValue('75.00'),
        xls.TextCellValue('14.00'),
        xls.TextCellValue('5'),
        xls.TextCellValue('product'),
        xls.TextCellValue('Pharmaceuticals'),
        xls.TextCellValue('100'),
      ]);

      final bytes = excel.encode();
      if (bytes != null) {
        await FileSaver.instance.saveFile(
          name: 'Stock_Import_Template',
          bytes: Uint8List.fromList(bytes),
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Template downloaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- File Picker & Parser ---
  Future<void> _pickAndParseFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('Could not read file bytes.');
      }

      setState(() {
        _isLoading = true;
        _fileName = file.name;
        _parsedRows.clear();
      });

      List<Map<String, String>> rawRows = [];

      final ext = file.extension?.toLowerCase() ?? '';
      if (ext == 'csv') {
        final content = utf8.decode(bytes);
        rawRows = _parseCsv(content);
      } else {
        rawRows = _parseExcel(bytes);
      }

      final parsed = _convertRawRowsToImportRows(rawRows);

      setState(() {
        _parsedRows = parsed;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parsed ${_parsedRows.length} rows from ${file.name}'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error parsing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getCellValue(dynamic cellValue) {
    if (cellValue == null) return '';
    final str = cellValue.toString().trim();
    if (str.isEmpty) return '';

    if (str.contains('value:')) {
      final idx = str.indexOf('value:');
      var val = str.substring(idx + 6).trim();
      if (val.endsWith(')')) {
        val = val.substring(0, val.length - 1).trim();
      }
      if ((val.startsWith('"') && val.endsWith('"')) ||
          (val.startsWith("'") && val.endsWith("'"))) {
        val = val.substring(1, val.length - 1).trim();
      }
      return val;
    }

    return str;
  }

  List<Map<String, String>> _parseCsv(String content) {
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) return [];

    final headers = lines.first.split(',').map((h) => _cleanHeader(h)).toList();
    final rows = <Map<String, String>>[];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final values = line.split(',');
      final row = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        final val = j < values.length ? values[j].trim() : '';
        row[headers[j]] = val;
      }
      rows.add(row);
    }
    return rows;
  }

  List<Map<String, String>> _parseExcel(Uint8List bytes) {
    final excel = xls.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];

    final sheet = excel.tables.values.first;
    if (sheet.maxRows < 2) return [];

    final headerRow = sheet.rows.first;
    final headers = headerRow
        .map((cell) => _cleanHeader(cell?.value))
        .toList();

    final rows = <Map<String, String>>[];

    for (int i = 1; i < sheet.maxRows; i++) {
      final rowCells = sheet.rows[i];
      if (rowCells.isEmpty) continue;

      final row = <String, String>{};
      bool hasData = false;

      for (int j = 0; j < headers.length; j++) {
        final cellVal = j < rowCells.length ? _getCellValue(rowCells[j]?.value) : '';
        if (cellVal.trim().isNotEmpty) hasData = true;
        row[headers[j]] = cellVal.trim();
      }

      if (hasData) {
        rows.add(row);
      }
    }
    return rows;
  }

  String _cleanHeader(dynamic header) {
    final str = _getCellValue(header);
    return str
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  List<_ImportRow> _convertRawRowsToImportRows(List<Map<String, String>> rawRows) {
    final List<_ImportRow> result = [];

    for (final raw in rawRows) {
      final Map<String, String> cleanMap = {};
      for (final entry in raw.entries) {
        final cleanK = entry.key.replaceAll(RegExp(r'[^a-z0-9]'), '');
        cleanMap[cleanK] = entry.value.trim();
      }

      String getVal(List<String> keys, [String fallback = '']) {
        for (final k in keys) {
          final cleanK = k.replaceAll(RegExp(r'[^a-z0-9]'), '');
          final val = cleanMap[cleanK];
          if (val != null && val.isNotEmpty) return val;
        }
        for (final k in keys) {
          final cleanK = k.replaceAll(RegExp(r'[^a-z0-9]'), '');
          for (final entry in cleanMap.entries) {
            if (entry.key.contains(cleanK) && entry.value.isNotEmpty) {
              return entry.value;
            }
          }
        }
        return fallback;
      }

      final itemName = getVal(['itemname', 'name', 'item', 'productname', 'description']);
      final barcode = getVal(['barcode', 'bar_code', 'upc', 'code']);
      final cpStr = getVal(['unitcostprice', 'costprice', 'cost', 'cp', 'unitcost']);
      final rpStr = getVal(['retailprice', 'sellingprice', 'price', 'sp', 'unitprice']);
      final boxQtyStr = getVal(['boxquantity', 'boxqty', 'cartonqty', 'cartonquantity', 'boxpieces']);
      final boxPriceStr = getVal(['boxprice', 'box_price', 'cartonprice', 'carton_price']);
      final halfQtyStr = getVal(['halfboxqty', 'halfqty', 'halfboxquantity']);
      final halfPriceStr = getVal(['halfboxprice', 'halfprice']);
      final qtrQtyStr = getVal(['quarterqty', 'quarterboxqty', 'quarterquantity']);
      final qtrPriceStr = getVal(['quarterprice', 'quarterboxprice']);
      final suppPriceStr = getVal(['supplierprice', 'supplier_price', 'supplier', 'supprice', 'suppliermprice', 'wholesaleprice', 'wp']);
      final suppMinQtyStr = getVal(['supplierminquantity', 'supplierminqty', 'minqty', 'sminqty']);
      final typeStr = getVal(['producttype', 'product_type', 'product type', 'type', 'prodtype', 'kind'], 'product');
      final catStr = getVal(['productcategory', 'product_category', 'product category', 'category', 'pcategory', 'itemcategory', 'cat'], 'General');
      final stockQtyStr = getVal(['stockquantity', 'stockqty', 'quantity', 'openingstock', 'qty']);

      final unitCost = double.tryParse(cpStr) ?? 0.0;
      final retailPrice = double.tryParse(rpStr) ?? 0.0;
      final boxQty = double.tryParse(boxQtyStr) ?? 0.0;
      final boxPrice = double.tryParse(boxPriceStr) ?? 0.0;
      final halfQty = double.tryParse(halfQtyStr) ?? 0.0;
      final halfPrice = double.tryParse(halfPriceStr) ?? 0.0;
      final qtrQty = double.tryParse(qtrQtyStr) ?? 0.0;
      final qtrPrice = double.tryParse(qtrPriceStr) ?? 0.0;
      final suppPrice = double.tryParse(suppPriceStr) ?? 0.0;
      final suppMinQty = double.tryParse(suppMinQtyStr) ?? 1.0;
      final stockQty = double.tryParse(stockQtyStr) ?? 0.0;

      final normType = (typeStr.toLowerCase().contains('service') || typeStr.toLowerCase().contains('srv')) ? 'service' : 'product';
      final normCat = catStr.trim().isNotEmpty ? catStr.trim() : 'General';

      String error = '';
      if (itemName.isEmpty) {
        error = 'Item name is required.';
      }

      result.add(
        _ImportRow(
          rawData: raw,
          itemName: itemName,
          barcode: barcode,
          unitCostPrice: unitCost,
          retailPrice: retailPrice,
          boxQuantity: boxQty,
          boxPrice: boxPrice,
          halfBoxQty: halfQty,
          halfBoxPrice: halfPrice,
          quarterQty: qtrQty,
          quarterPrice: qtrPrice,
          supplierPrice: suppPrice,
          supplierMinQty: suppMinQty,
          productType: normType,
          productCategory: normCat,
          stockQuantity: stockQty,
          isValid: error.isEmpty,
          validationError: error,
        ),
      );
    }
    return result;
  }

  // --- Import Action ---
  Future<void> _executeImport() async {
    if (_selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a target branch to stock into.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final validRows = _parsedRows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid items to import.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final datafeed = Provider.of<Datafeed>(context, listen: false);
    final companyId = datafeed.companyid;
    final companyName = datafeed.company;
    final staffName = datafeed.staff.isNotEmpty ? datafeed.staff : 'System Admin';
    final targetBranchId = _selectedBranchId!;
    final targetBranchName = _selectedBranchName;

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _totalToImport = validRows.length;
    });

    try {
      final now = DateTime.now();
      final todayDateStr = DateFormat('yyyy-MM-dd').format(now);
      final transactionId = 'IMP_${now.millisecondsSinceEpoch}';

      final List<Map<String, dynamic>> stockTxItems = [];
      double grandGrossTotal = 0.0;
      int count = 0;

      WriteBatch batch = _db.batch();
      int batchOps = 0;

      for (final row in validRows) {
        // Generate or clean barcode
        final rawBarcode = row.barcode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
        final cleanBarcode = rawBarcode.isNotEmpty
            ? rawBarcode.toLowerCase()
            : 'IMP${now.millisecondsSinceEpoch}_$count';

        final docId = '${companyId.toLowerCase()}_$cleanBarcode';

        final double boxSellingPrice = row.boxPrice > 0 ? row.boxPrice : row.supplierPrice;
        final double supplierPriceVal = row.supplierPrice > 0 ? row.supplierPrice : row.boxPrice;

        // Construct Modes
        final List<Mode> modeList = [
          Mode(
            id: 'single',
            name: 'Single',
            qty: '1',
            cp: row.unitCostPrice.toStringAsFixed(2),
            rp: row.retailPrice.toStringAsFixed(2),
            sp: row.retailPrice.toStringAsFixed(2),
            wp: supplierPriceVal > 0 ? supplierPriceVal.toStringAsFixed(2) : row.retailPrice.toStringAsFixed(2),
          ),
        ];

        if (row.boxQuantity > 0 || row.boxPrice > 0) {
          final boxQtyVal = row.boxQuantity > 0 ? row.boxQuantity : 1.0;
          modeList.add(
            Mode(
              id: 'carton',
              name: 'carton',
              qty: boxQtyVal.toStringAsFixed(0),
              cp: (row.unitCostPrice * boxQtyVal).toStringAsFixed(2),
              rp: boxSellingPrice.toStringAsFixed(2),
              wp: boxSellingPrice.toStringAsFixed(2),
              sp: supplierPriceVal.toStringAsFixed(2),
            ),
          );
        }

        if (row.halfBoxQty > 0) {
          modeList.add(
            Mode(
              id: 'half',
              name: 'Half Box',
              qty: row.halfBoxQty.toStringAsFixed(0),
              cp: (row.unitCostPrice * row.halfBoxQty).toStringAsFixed(2),
              rp: row.halfBoxPrice.toStringAsFixed(2),
              sp: row.halfBoxPrice.toStringAsFixed(2),
              wp: row.halfBoxPrice.toStringAsFixed(2),
            ),
          );
        }

        if (row.quarterQty > 0) {
          modeList.add(
            Mode(
              id: 'quarter',
              name: 'Quarter Box',
              qty: row.quarterQty.toStringAsFixed(0),
              cp: (row.unitCostPrice * row.quarterQty).toStringAsFixed(2),
              rp: row.quarterPrice.toStringAsFixed(2),
              sp: row.quarterPrice.toStringAsFixed(2),
              wp: row.quarterPrice.toStringAsFixed(2),
            ),
          );
        }

        final bool hasBoxModes = row.boxQuantity > 0 || row.halfBoxQty > 0 || row.quarterQty > 0;

        final itemRef = _db.collection('itemsreg').doc(docId);

        // Batched Set/Merge on itemsreg (fast atomic batch, works for new and existing docs)
        final Map<String, dynamic> itemMap = {
          'id': docId,
          'name': row.itemName,
          'barcode': row.barcode.toLowerCase(),
          'cp': row.unitCostPrice.toStringAsFixed(2),
          'retailmarkup': '0',
          'wholesalemarkup': '0',
          'retailprice': row.retailPrice.toStringAsFixed(2),
          'wholesaleprice': row.supplierPrice.toStringAsFixed(2),
          'producttype': row.productType,
          'pricingmode': false,
          'isActive': true,
          'pcategory': row.productCategory,
          'warehouse': '',
          'openingstock': row.stockQuantity.toStringAsFixed(0),
          'company': companyName,
          'companyid': companyId,
          'imageurl': '',
          'createdat': FieldValue.serverTimestamp(),
          'updatedat': FieldValue.serverTimestamp(),
          'updatedby': staffName,
          'staff': staffName,
          'wminqty': row.supplierMinQty.toStringAsFixed(0),
          'sminqty': row.supplierMinQty.toStringAsFixed(0),
          'modemore': hasBoxModes,
          'modes': {for (var m in modeList) m.id: m.toMap()},
          // 'branchbalance.$targetBranchId.quantity': FieldValue.increment(row.stockQuantity),
          // 'branchbalance.$targetBranchId.netpieces': FieldValue.increment(row.stockQuantity),
          // 'branchbalance.$targetBranchId.openingstock': FieldValue.increment(row.stockQuantity),
          // 'branchbalance.$targetBranchId.stock_value': FieldValue.increment(row.stockQuantity * row.unitCostPrice),
          // 'branchbalance.$targetBranchId.name': targetBranchName,
          // 'branchbalance.$targetBranchId.updatedby': staffName,
          // 'branchbalance.$targetBranchId.lastupdate': FieldValue.serverTimestamp(),
        };

        //batch.set(itemRef, itemMap, SetOptions(merge: true));
        batchOps++;

        // Build stock transaction item entry (mirroring newstock.dart)
        final unitCostPrice = row.unitCostPrice ?? 0.0;
        final stockQuantity = row.stockQuantity ?? 0.0;

        final getunitcp = stockQuantity > 0 &&
            stockQuantity.isFinite &&
            unitCostPrice.isFinite
            ? unitCostPrice / stockQuantity
            : 0.0;
        //final getunitcp =  row.unitCostPrice/row.stockQuantity;
        final itemTotalValue = row.stockQuantity * getunitcp;
        grandGrossTotal += itemTotalValue;

        stockTxItems.add({
          'itemid': docId,
          'item': row.itemName,
          'barcode': row.barcode.toLowerCase(),
          'quantity': row.stockQuantity,
          'pieces': row.stockQuantity,
          'boxpieces': row.boxQuantity > 0 ? row.boxQuantity : 1,
          'price': getunitcp,
          'selling_price': row.retailPrice,
          'total': itemTotalValue,
          'cp': getunitcp,
          'sp': row.retailPrice,
          'originalcp': getunitcp,
          'oldPieces': 0,
        });

        // Audit stocking log
        final stockingRef = _db.collection('stocking').doc();
        batch.set(stockingRef, {
          'id': stockingRef.id,
          'itemid': docId,
          'item': row.itemName,
          'barcode': row.barcode.toLowerCase(),
          'branchid': targetBranchId,
          'branchname': targetBranchName,
          'quantity': row.stockQuantity,
          'pieces': row.stockQuantity,
          'cp': getunitcp,
          'sp': getunitcp,
          'stock_value': itemTotalValue,
          'type': 'import',
          'companyid': companyId,
          'staff': staffName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batchOps++;

        count++;

        if (batchOps >= 400) {
          await batch.commit();
          batch = _db.batch();
          batchOps = 0;
        }

        if (mounted) {
          setState(() {
            _importProgress = count;
          });
        }
      }

      if (batchOps > 0) {
        await batch.commit();
      }

      // Save stock_transactions document (mirroring newstock.dart)
      int weekNumber(DateTime date) {
        final firstDayOfYear = DateTime(date.year, 1, 1);
        final days = date.difference(firstDayOfYear).inDays;
        return ((days + firstDayOfYear.weekday) / 7).ceil();
      }

      final Map<String, dynamic> stockTxDoc = {
        'docid': transactionId,
        'transactionid': transactionId,
        'companyid': companyId,
        'companyname': companyName,
        'branchid': targetBranchId,
        'branchname': targetBranchName,
        'staffbranchid': targetBranchId,
        'staffbranchname': targetBranchName,
        'waybill': 'IMPORT_${now.millisecondsSinceEpoch}',
        'suppliername': companyName,
        'supplierid': companyId,
        'purchasetype': 'opening balance',
        'invoicedate': Timestamp.fromDate(now),
        'items': stockTxItems,
        'gross': grandGrossTotal,
        'discount': 0.0,
        'tax': 0.0,
        'netval': grandGrossTotal,
        'date': todayDateStr,
        'year': now.year.toString(),
        'month': '${now.year}.${now.month}',
        'week': '${now.year}.${weekNumber(now)}',
        'day': DateFormat('EEEE').format(now),
        'createdby': staffName,
        'createdAt': FieldValue.serverTimestamp(),
        'createdat': FieldValue.serverTimestamp(),
      };

      await _db
          .collection('stock_transactions')
          .doc(transactionId)
          .set(stockTxDoc, SetOptions(merge: true));

      // Sync transaction to stock report & dashboard stats (mirroring newstock.dart)
     // await stockProvider.syncTransactionToReport(transactionId);

      setState(() {
        _isImporting = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1B263B),
            title: const Text('Import & Stocking Complete!', style: TextStyle(color: Colors.greenAccent)),
            content: Text(
              'Successfully registered and stocked $count items into $targetBranchName.\nTransaction ID: $transactionId',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _parsedRows.clear();
                    _fileName = null;
                  });
                },
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final datafeed = Provider.of<Datafeed>(context);

    // Fetch branches if empty
    if (datafeed.branches.isEmpty) {
      datafeed.fetchBranches();
    }

    // Deduplicate branches by ID
    final Map<String, dynamic> uniqueMap = {};
    for (var b in datafeed.branches) {
      if (b.id.toString().trim().isNotEmpty && !uniqueMap.containsKey(b.id)) {
        uniqueMap[b.id] = b;
      }
    }
    final uniqueBranches = uniqueMap.values.toList();

    // Validate selected branch ID
    if (uniqueBranches.isNotEmpty) {
      if (_selectedBranchId == null || !uniqueMap.containsKey(_selectedBranchId)) {
        final currentBranch = uniqueBranches.firstWhere(
          (b) => b.id == datafeed.branchid,
          orElse: () => uniqueBranches.first,
        );
        _selectedBranchId = currentBranch.id;
        _selectedBranchName = currentBranch.branchname;
      }
    }

    final filteredRows = _parsedRows.where((r) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return r.itemName.toLowerCase().contains(q) ||
          r.barcode.toLowerCase().contains(q) ||
          r.productCategory.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF101624),
      appBar: AppBar(
        title: const Text(
          'STOCK & ITEM IMPORTATION',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1B263B),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.file_open_outlined, size: 16),
            label: const Text('Browse File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: _isLoading ? null : _pickAndParseFile,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              side: const BorderSide(color: Colors.blueAccent, width: 0.8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Template', style: TextStyle(fontSize: 12)),
            onPressed: _downloadTemplate,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1100,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Target Branch Selection Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B263B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Select Target Branch for Stocking',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: (uniqueBranches.any((b) => b.id == _selectedBranchId))
                            ? _selectedBranchId
                            : (uniqueBranches.isNotEmpty ? uniqueBranches.first.id : null),
                        dropdownColor: const Color(0xFF22304A),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Stocking Target Branch',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF22304A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: uniqueBranches.map((b) {
                          return DropdownMenuItem<String>(
                            value: b.id,
                            child: Text(
                              '${b.branchname} (${b.branchtype})',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: uniqueBranches.isEmpty
                            ? null
                            : (val) {
                                if (val == null) return;
                                final b = uniqueBranches.firstWhere((br) => br.id == val);
                                setState(() {
                                  _selectedBranchId = val;
                                  _selectedBranchName = b.branchname;
                                });
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_isImporting) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B263B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orangeAccent),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Importing & Stocking: $_importProgress / $_totalToImport items...',
                          style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: _totalToImport > 0 ? _importProgress / _totalToImport : 0,
                          backgroundColor: Colors.white12,
                          color: Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Preview Table Section
                if (_parsedRows.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '2. Review & Confirm Data (${_parsedRows.length} items parsed)',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: const Text('Import & Stock Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: _isImporting ? null : _executeImport,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search parsed items...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1B263B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      color: const Color(0xFF1B263B),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFF22304A)),
                        dataRowColor: WidgetStateProperty.all(const Color(0xFF1B263B)),
                      columns: const [
                        DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Item Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Barcode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Cost Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Retail Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Box Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Box Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Half Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Half Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Qtr Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Qtr Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Supplier Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Min Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Stock Qty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredRows.map((r) {
                        return DataRow(
                          cells: [
                            DataCell(
                              r.isValid
                                  ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                                  : Tooltip(
                                      message: r.validationError,
                                      child: const Icon(Icons.error, color: Colors.red, size: 18),
                                    ),
                            ),
                            DataCell(Text(r.itemName, style: const TextStyle(color: Colors.white, fontSize: 12))),
                            DataCell(Text(r.barcode.isEmpty ? 'AUTO-GEN' : r.barcode, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text('GHS ${r.unitCostPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text('GHS ${r.retailPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                            DataCell(Text(r.boxQuantity.toStringAsFixed(0), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text('GHS ${r.boxPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text(r.halfBoxQty.toStringAsFixed(0), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text('GHS ${r.halfBoxPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text(r.quarterQty.toStringAsFixed(0), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text('GHS ${r.quarterPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text('GHS ${r.supplierPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text(r.supplierMinQty.toStringAsFixed(0), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text(r.productCategory, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            DataCell(Text(r.stockQuantity.toStringAsFixed(0), style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
