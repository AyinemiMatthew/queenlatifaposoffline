import 'dart:typed_data';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/itemmodel.dart';
import 'package:kologsoft/models/itemregmodel.dart';
import 'package:kologsoft/models/printbarcodemodel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_io/io.dart';

import 'Datafeed.dart';

class ItemValidationValues {
  const ItemValidationValues({
    this.costPrice = '',
    this.retailPrice = '',
    this.boxQuantity = '',
    this.boxPrice = '',
    this.supplierPrice = '',
    this.halfBoxQuantity = '',
    this.halfBoxPrice = '',
    this.quarterQuantity = '',
    this.quarterPrice = '',
    this.packQuantity = '',
    this.enableBoxPricing = false,
  });

  final String costPrice;
  final String retailPrice;
  final String boxQuantity;
  final String boxPrice;
  final String supplierPrice;
  final String halfBoxQuantity;
  final String halfBoxPrice;
  final String quarterQuantity;
  final String quarterPrice;
  final String packQuantity;
  final bool enableBoxPricing;
}

class BranchPricingValues {
  const BranchPricingValues({
    required this.companyType,
    required this.costPrice,
    required this.retailPrice,
    required this.boxQuantity,
    required this.boxPrice,
    required this.supplierPrice,
    required this.halfBoxQuantity,
    required this.halfBoxPrice,
    required this.quarterQuantity,
    required this.quarterPrice,
    required this.packQuantity,
    required this.packPrice,
    required this.enableBoxPricing,
    required this.pricingStep,
  });

  final String companyType;
  final String costPrice;
  final String retailPrice;
  final String boxQuantity;
  final String boxPrice;
  final String supplierPrice;
  final String halfBoxQuantity;
  final String halfBoxPrice;
  final String quarterQuantity;
  final String quarterPrice;
  final String packQuantity;
  final String packPrice;
  final bool enableBoxPricing;
  final int pricingStep;
}

class BranchBalanceSyncEntry {
  const BranchBalanceSyncEntry({
    required this.itemName,
    required this.balance,
    this.error,
    this.isMissingFromReport = false,
  });

  final String itemName;
  final num balance;
  final Object? error;
  final bool isMissingFromReport;

  bool get succeeded => error == null;

  String get message {
    if (!succeeded) return '✗ $itemName → Error: $error';
    if (isMissingFromReport) {
      return '⊘ $itemName → 0 pcs (not in stock report)';
    }
    return '✓ $itemName → $balance pcs';
  }
}

class BranchBalanceSyncSummary {
  const BranchBalanceSyncSummary({
    required this.entries,
    required this.successCount,
    required this.errorCount,
  });

  final List<BranchBalanceSyncEntry> entries;
  final int successCount;
  final int errorCount;
}

class ReceiptUploadRequest {
  const ReceiptUploadRequest({
    required this.datafeed,
    required this.receiptNumber,
    required this.description,
    required this.existingId,
    required this.existingReceipt,
    required this.keptReceiptUrls,
    required this.imageFiles,
    required this.imageBytes,
  });

  final Datafeed datafeed;
  final String receiptNumber;
  final String description;
  final String? existingId;
  final Map<String, dynamic>? existingReceipt;
  final List<String> keptReceiptUrls;
  final List<File> imageFiles;
  final List<Uint8List> imageBytes;
}

class ItemUploadLookups {
  const ItemUploadLookups({
    required this.itemExists,
    required this.itemModes,
    required this.categoryExists,
  });

  final Map<String, bool> itemExists;
  final Map<String, List<Mode>> itemModes;
  final Map<String, bool> categoryExists;
}

class ItemUploadWrite {
  const ItemUploadWrite({
    required this.id,
    required this.data,
    required this.update,
  });

  final String id;
  final Map<String, dynamic> data;
  final bool update;
}

class ItemProvider extends ChangeNotifier {
  ItemProvider({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  bool isLoadingBundles = false;
  List<Map<String, dynamic>> bundleView = [];
  List<ItemModel> bundleItems = [];

  static String normalizeReceiptDescription(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  String? validateReceiptImage(Uint8List bytes, String filename) {
    const maxSizeBytes = 5 * 1024 * 1024;
    if (bytes.lengthInBytes > maxSizeBytes) {
      return '"$filename" exceeds 5MB.';
    }

    final extension = filename.split('.').last.toLowerCase();
    const allowedTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
    };
    final expectedType = allowedTypes[extension];
    if (expectedType == null) {
      return '"$filename" has an unsupported extension.';
    }
    final actualType = _imageMimeType(bytes);
    if (actualType == null) return '"$filename" is not a supported image.';
    if (actualType != expectedType) {
      return '"$filename" extension does not match its image content.';
    }
    return null;
  }

  Future<String> saveReceipt(ReceiptUploadRequest request) async {
    final datafeed = request.datafeed;
    final companyName = datafeed.company.trim();
    final receiptNumber = request.receiptNumber.trim().isNotEmpty
        ? request.receiptNumber.trim()
        : 'R-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final receiptName = '$companyName - $receiptNumber';
    final docId =
        request.existingId ??
        '${_sanitize(datafeed.companyid)}_${datafeed.staffPosition}_${_sanitize(receiptNumber)}_${DateTime.now().millisecondsSinceEpoch}';

    final uploadedUrls = await _uploadReceiptImages(
      docId: docId,
      imageFiles: request.imageFiles,
      imageBytes: request.imageBytes,
    );
    final data = <String, dynamic>{
      'name': receiptName,
      'description': normalizeReceiptDescription(request.description),
      'id': docId,
      'receiptUrl': [...request.keptReceiptUrls, ...uploadedUrls],
      'companyid': datafeed.companyid,
      'branchid': datafeed.branchid,
      'branch': datafeed.branch,
      'company': datafeed.company,
      'staff': datafeed.staff,
      if (request.existingId == null) 'createdat': FieldValue.serverTimestamp(),
      if (request.existingId != null) 'updatedat': FieldValue.serverTimestamp(),
    };

    try {
      await _db
          .collection('uploadreceipt')
          .doc(docId)
          .set(data, SetOptions(merge: true));
    } catch (error) {
      await _deleteReceiptImages(uploadedUrls);
      rethrow;
    }

    final localData = {
      if (request.existingReceipt != null) ...request.existingReceipt!,
      ...data,
      if (request.existingId == null) 'createdat': DateTime.now(),
      if (request.existingId != null) 'updatedat': DateTime.now(),
    };
    datafeed.upsertReceiptCache(localData);

    final oldUrls = List<String>.from(
      request.existingReceipt?['receiptUrl'] ?? const [],
    );
    final removedUrls = oldUrls
        .where((url) => !request.keptReceiptUrls.contains(url))
        .toList();
    await _deleteReceiptImages(removedUrls);
    return docId;
  }

  Future<void> deleteReceipt({
    required Datafeed datafeed,
    required String id,
    required List<String> imageUrls,
  }) async {
    await _db.collection('uploadreceipt').doc(id).delete();
    datafeed.removeReceiptCache(id);
    await _deleteReceiptImages(imageUrls);
  }

  Future<void> deleteReceiptImages(Iterable<String> imageUrls) =>
      _deleteReceiptImages(imageUrls);

  List<Map<String, dynamic>> filterReceipts({
    required List<Map<String, dynamic>> receipts,
    required String query,
    DateTimeRange? dateRange,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final start = dateRange == null
        ? null
        : DateTime(
            dateRange.start.year,
            dateRange.start.month,
            dateRange.start.day,
          );
    final endExclusive = dateRange == null
        ? null
        : DateTime(
            dateRange.end.year,
            dateRange.end.month,
            dateRange.end.day + 1,
          );
    return receipts.where((receipt) {
      if (start != null && endExclusive != null) {
        final date = _receiptDate(receipt['createdat']);
        if (date == null ||
            date.isBefore(start) ||
            !date.isBefore(endExclusive)) {
          return false;
        }
      }
      if (normalizedQuery.isEmpty) return true;
      return [
        receipt['name'],
        receipt['description'],
        receipt['id'],
        receipt['company'],
        receipt['branchid'],
        receipt['staff'],
        receipt['receiptUrl'],
      ].any(
        (value) =>
            (value ?? '').toString().toLowerCase().contains(normalizedQuery),
      );
    }).toList();
  }

  DateTime? _receiptDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<List<String>> _uploadReceiptImages({
    required String docId,
    required List<File> imageFiles,
    required List<Uint8List> imageBytes,
  }) async {
    final urls = <String>[];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uploadCount = kIsWeb ? imageBytes.length : imageFiles.length;
    try {
      for (var index = 0; index < uploadCount; index++) {
        final bytes = kIsWeb
            ? imageBytes[index]
            : await imageFiles[index].readAsBytes();
        final contentType = _imageMimeType(bytes);
        if (contentType == null) {
          throw StateError('A selected file is no longer a supported image.');
        }
        final extension = _imageExtension(contentType);
        final fileName =
            '${docId}_${timestamp}_${index}_${Random.secure().nextInt(1 << 32)}.$extension';
        final reference = FirebaseStorage.instance.ref().child(
          'receipts/$fileName',
        );
        final metadata = SettableMetadata(contentType: contentType);
        final task = kIsWeb
            ? reference.putData(bytes, metadata)
            : reference.putFile(imageFiles[index], metadata);
        final snapshot = await task;
        urls.add(await snapshot.ref.getDownloadURL());
      }
    } catch (error) {
      await _deleteReceiptImages(urls);
      rethrow;
    }
    return urls;
  }

  Future<void> _deleteReceiptImages(Iterable<String> urls) async {
    for (final url in urls) {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
  }

  String _imageExtension(String contentType) => switch (contentType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    _ => throw StateError('Unsupported image content type.'),
  };

  String? _imageMimeType(Uint8List bytes) {
    bool startsWith(List<int> signature) {
      if (bytes.length < signature.length) return false;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[index] != signature[index]) return false;
      }
      return true;
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    if (bytes.length >= 6) {
      final signature = String.fromCharCodes(bytes.sublist(0, 6));
      if (signature == 'GIF87a' || signature == 'GIF89a') return 'image/gif';
    }
    return null;
  }

  String itemUploadDocumentId(String companyId, String name) =>
      '${_sanitize(companyId)}_${_sanitize(name)}';

  String categoryUploadDocumentId(String companyId, String category) =>
      '$companyId$category'
          .toLowerCase()
          .replaceAll(RegExp(r'[/\\]'), '_')
          .replaceAll(RegExp(r'\s+'), '_');

  Future<ItemUploadLookups> loadItemUploadLookups({
    required Iterable<String> itemIds,
    required Iterable<String> categoryIds,
  }) async {
    final itemExists = <String, bool>{};
    final itemModes = <String, List<Mode>>{};
    final categoryExists = <String, bool>{};
    final uniqueItemIds = itemIds.toSet().toList();
    final uniqueCategoryIds = categoryIds.toSet().toList();

    for (var start = 0; start < uniqueItemIds.length; start += 30) {
      final snapshots = await Future.wait(
        uniqueItemIds
            .skip(start)
            .take(30)
            .map((id) => _db.collection('itemsreg').doc(id).get()),
      );
      for (final snapshot in snapshots) {
        itemExists[snapshot.id] = snapshot.exists;
        if (!snapshot.exists) continue;
        final rawModes = snapshot.data()?['modes'];
        if (rawModes is Map) {
          itemModes[snapshot.id] = rawModes.entries
              .where((entry) => entry.value is Map)
              .map(
                (entry) => Mode.fromMap(
                  entry.key.toString(),
                  Map<String, dynamic>.from(entry.value as Map),
                ),
              )
              .toList();
        }
      }
    }

    for (var start = 0; start < uniqueCategoryIds.length; start += 30) {
      final snapshots = await Future.wait(
        uniqueCategoryIds
            .skip(start)
            .take(30)
            .map((id) => _db.collection('productcategoryreg').doc(id).get()),
      );
      for (final snapshot in snapshots) {
        categoryExists[snapshot.id] = snapshot.exists;
      }
    }

    return ItemUploadLookups(
      itemExists: itemExists,
      itemModes: itemModes,
      categoryExists: categoryExists,
    );
  }

  Future<void> saveItemUploadBatch({
    required Map<String, Map<String, dynamic>> categories,
    required List<ItemUploadWrite> items,
  }) async {
    final operations = <void Function(WriteBatch)>[
      for (final entry in categories.entries)
        (batch) => batch.set(
          _db.collection('productcategoryreg').doc(entry.key),
          entry.value,
          SetOptions(merge: true),
        ),
      for (final item in items)
        (batch) {
          final reference = _db.collection('itemsreg').doc(item.id);
          if (item.update) {
            batch.update(reference, item.data);
          } else {
            batch.set(reference, item.data);
          }
        },
    ];

    for (var start = 0; start < operations.length; start += 400) {
      final batch = _db.batch();
      for (final operation in operations.skip(start).take(400)) {
        operation(batch);
      }
      await batch.commit();
    }
  }

  Future<void> fetchBundles({
    required Datafeed datafeed,
    String? selectedBranch,
  }) async {
    isLoadingBundles = true;
    notifyListeners();
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('bundle')
          .where('companyid', isEqualTo: datafeed.companyid);
      if (selectedBranch != null && selectedBranch.isNotEmpty) {
        query = query.where('branchid', isEqualTo: selectedBranch);
      }

      final snapshot = await query.get(
        const GetOptions(source: Source.serverAndCache),
      );
      bundleView = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name'] ?? '',
          'id': doc.id,
          'companyid': data['companyid'] ?? '',
          'isActive': data['isActive'] ?? true,
          'branchid': data['branchid'] ?? '',
          'barcode': data['barcode'] ?? '',
          'producttype': data['producttype'] ?? '',
          'pcategory': data['pcategory'] ?? '',
          'company': data['company'] ?? '',
          'createdat': data['createdat'],
          'staff': data['staff'] ?? '',
          'items': data['items'] ?? [],
          'modes': data['modes'] ?? {},
        };
      }).toList();
      bundleItems = snapshot.docs
          .map((doc) => ItemModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } finally {
      isLoadingBundles = false;
      notifyListeners();
    }
  }

  void refreshBundles() => notifyListeners();

  String itemDocumentId(String companyId, String itemName) =>
      '${_sanitize(companyId)}_${_sanitize(itemName)}';

  String itemBarcode(String itemName, String barcode) =>
      (barcode.trim().isEmpty ? itemName.trim() : barcode.trim()).toLowerCase();

  String formatSplitQuantity(double quantity) =>
      quantity.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

  Future<String?> uploadItemImage({
    required String itemId,
    required File? file,
    required Uint8List? bytes,
    required String? existingUrl,
    required bool isWeb,
  }) async {
    if (file == null && bytes == null) return existingUrl;
    final ref = FirebaseStorage.instance
        .ref()
        .child('items')
        .child('$itemId.png');
    final task = isWeb
        ? ref.putData(bytes!, SettableMetadata(contentType: 'image/png'))
        : ref.putFile(file!, SettableMetadata(contentType: 'image/png'));
    final snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }

  List<ItemModel> filterItems(List<ItemModel> items, String searchQuery) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return items;

    return items.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.barcode.toLowerCase().contains(query) ||
          item.company.toLowerCase().contains(query) ||
          item.pcategory.toLowerCase().contains(query);
    }).toList();
  }

  List<ProductModel> filterBarcodeProducts(
    List<ProductModel> products,
    String searchQuery,
  ) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.company.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();
  }

  Future<Uint8List> buildBarcodePdf({
    required ProductModel product,
    required int labelCount,
    required Uint8List regularFont,
    required Uint8List boldFont,
    required Uint8List monoFont,
  }) async {
    final code = product.barcode.isNotEmpty ? product.barcode : product.name;
    final pdf = pw.Document(title: '${product.companyid} - ${product.name}');
    final baseFont = pw.Font.ttf(ByteData.sublistView(regularFont));
    final headingFont = pw.Font.ttf(ByteData.sublistView(boldFont));
    final barcodeFont = pw.Font.ttf(ByteData.sublistView(monoFont));
    const columns = 2;
    const itemWidth = 180.0;
    const itemHeight = 80.0;
    final rows = <pw.Widget>[];

    for (var index = 0; index < labelCount; index += columns) {
      rows.add(
        pw.Row(
          children: List.generate(columns, (columnIndex) {
            final itemIndex = index + columnIndex;
            if (itemIndex >= labelCount) return pw.SizedBox();
            return pw.Expanded(
              child: pw.Container(
                height: itemHeight,
                alignment: pw.Alignment.center,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: code,
                      width: itemWidth,
                      height: 40,
                      drawText: false,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '* ${code.split('').join(' ')} *',
                      style: pw.TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        font: barcodeFont,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(8),
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: headingFont),
        build: (_) => rows,
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  Future<Uint8List> buildQrCodePdf({
    required ProductModel product,
    required int labelCount,
    required Uint8List regularFont,
    required Uint8List boldFont,
  }) async {
    final code = product.barcode.isNotEmpty ? product.barcode : product.name;
    final pdf = pw.Document(title: '${product.companyid} - ${product.name}');
    const columns = 5;
    const size = 80.0;
    const horizontalSpacing = 20.0;
    const verticalSpacing = 20.0;
    final rows = <pw.Widget>[];

    for (var index = 0; index < labelCount; index += columns) {
      rows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: verticalSpacing),
          child: pw.Row(
            children: List.generate(columns, (columnIndex) {
              final itemIndex = index + columnIndex;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(right: horizontalSpacing),
                child: itemIndex < labelCount
                    ? pw.Container(
                        width: size,
                        height: size,
                        alignment: pw.Alignment.center,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: code,
                        ),
                      )
                    : pw.SizedBox(width: size),
              );
            }),
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(ByteData.sublistView(regularFont)),
          bold: pw.Font.ttf(ByteData.sublistView(boldFont)),
        ),
        build: (_) => rows,
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  bool itemHasBranchPricing(ItemModel item, String branchId) {
    final branchData = item.branchprices?[branchId];
    if (branchData is! Map) return false;
    final pricing = branchData['pricing'];
    return pricing is Map && pricing.isNotEmpty;
  }

  List<Mode> branchPricingModes(ItemModel item, String branchId) {
    final branchData = item.branchprices?[branchId];
    if (branchData is! Map || branchData['pricing'] is! Map) {
      return [];
    }
    final pricing = Map<String, dynamic>.from(branchData['pricing'] as Map);
    return pricing.entries
        .where((entry) => entry.value is Map)
        .map(
          (entry) => Mode.fromMap(
            entry.key,
            Map<String, dynamic>.from(entry.value as Map),
          ),
        )
        .toList();
  }

  List<Mode> buildBranchPricingModes({
    required List<Mode> existingModes,
    required BranchPricingValues values,
  }) {
    final modes = List<Mode>.of(existingModes);
    final cost = values.costPrice.trim();
    final boxQuantity = double.tryParse(values.boxQuantity) ?? 0;
    final businessType = values.companyType.toLowerCase().trim();
    final hasBoxQuantity = boxQuantity >= 1;
    final supportsRetail = businessType != 'wholesale';
    final supportsWholesale = businessType != 'retail';
    final wantsSingle = hasBoxQuantity && supportsRetail;
    final wantsCarton = hasBoxQuantity && supportsWholesale;

    void upsert(Mode mode) {
      final index = modes.indexWhere((candidate) => candidate.id == mode.id);
      if (index == -1) {
        modes.add(mode);
      } else {
        modes[index] = mode;
      }
    }

    void remove(String id) => modes.removeWhere((mode) => mode.id == id);

    if (wantsSingle) {
      upsert(
        Mode(
          id: 'single',
          name: 'Single',
          qty: '1',
          cp: cost,
          rp: values.retailPrice.trim(),
          wp: boxQuantity == 1
              ? values.boxPrice.trim()
              : values.retailPrice.trim(),
          sp: boxQuantity == 1
              ? values.supplierPrice.trim()
              : values.retailPrice.trim(),
        ),
      );
    } else {
      remove('single');
    }

    if (wantsCarton) {
      upsert(
        Mode(
          id: 'carton',
          name: 'Carton',
          qty: values.boxQuantity.trim(),
          cp: cost,
          rp: boxQuantity > 1
              ? values.boxPrice.trim()
              : values.retailPrice.trim(),
          wp: values.boxPrice.trim(),
          sp: values.supplierPrice.trim(),
        ),
      );
    } else {
      remove('carton');
    }

    if (hasBoxQuantity && values.enableBoxPricing) {
      final splitModes =
          <({String id, String name, String quantity, String price, int step})>[
            (
              id: 'half',
              name: 'Half Carton',
              quantity: values.halfBoxQuantity,
              price: values.halfBoxPrice,
              step: 1,
            ),
            (
              id: 'quarter',
              name: 'Quarter Carton',
              quantity: values.quarterQuantity,
              price: values.quarterPrice,
              step: 2,
            ),
            (
              id: 'pack',
              name: 'Pack',
              quantity: values.packQuantity,
              price: values.packPrice,
              step: 3,
            ),
          ];
      for (final split in splitModes) {
        if (values.pricingStep >= split.step &&
            split.quantity.trim().isNotEmpty &&
            split.price.trim().isNotEmpty) {
          upsert(
            Mode(
              id: split.id,
              name: split.name,
              qty: split.quantity.trim(),
              cp: cost,
              rp: split.price.trim(),
              wp: split.price.trim(),
              sp: split.price.trim(),
            ),
          );
        } else {
          remove(split.id);
        }
      }
    } else {
      remove('half');
      remove('quarter');
      remove('pack');
    }
    return modes;
  }

  Set<String> stockReportItemIds(Iterable<Map<String, dynamic>> stockRows) =>
      stockRows
          .map((row) => row['itemid']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

  List<ItemModel> sortBranchPriceItems({
    required List<ItemModel> items,
    required int? columnIndex,
    required bool ascending,
  }) {
    final sorted = List<ItemModel>.of(items);
    if (columnIndex == null) return sorted;
    sorted.sort((first, second) {
      final comparison = switch (columnIndex) {
        1 => first.name.toLowerCase().compareTo(second.name.toLowerCase()),
        3 => first.pcategory.toLowerCase().compareTo(
          second.pcategory.toLowerCase(),
        ),
        _ => 0,
      };
      return ascending ? comparison : -comparison;
    });
    return sorted;
  }

  List<ItemModel> itemsMissingFromStockReport({
    required Iterable<ItemModel> items,
    required Iterable<Map<String, dynamic>> stockRows,
    required String branchId,
    bool activeOnly = true,
  }) {
    final reportIds = stockReportItemIds(stockRows);
    return items.where((item) {
      return (!activeOnly || item.isActive) &&
          item.branchbalance?.containsKey(branchId) == true &&
          !reportIds.contains(item.id);
    }).toList();
  }

  Future<num> syncSingleBranchBalance({
    required Datafeed datafeed,
    required String itemId,
    required String branchId,
    bool resetToZero = false,
  }) async {
    final balance = resetToZero
        ? 0
        : await datafeed.fetchItemCurrentBalance(
            itemId: itemId,
            selectedBranch: branchId,
          );
    await _writeBranchBalance(
      datafeed: datafeed,
      itemId: itemId,
      branchId: branchId,
      balance: balance,
      merge: false,
    );
    return balance;
  }

  Future<BranchBalanceSyncSummary> syncBranchBalanceRows({
    required Datafeed datafeed,
    required String branchId,
    required Iterable<Map<String, dynamic>> stockRows,
    Iterable<ItemModel> zeroBalanceItems = const [],
    void Function(int completed, int total)? onProgress,
  }) async {
    final rows = stockRows
        .where((row) => (row['itemid'] ?? '').toString().isNotEmpty)
        .toList();
    final zeroItems = zeroBalanceItems.toList();
    final total = rows.length + zeroItems.length;
    final entries = <BranchBalanceSyncEntry>[];
    var successCount = 0;
    var completed = 0;

    Future<void> sync({
      required String itemId,
      required String itemName,
      required num balance,
      bool missingFromReport = false,
    }) async {
      try {
        await _writeBranchBalance(
          datafeed: datafeed,
          itemId: itemId,
          branchId: branchId,
          balance: balance,
          merge: true,
        );
        entries.add(
          BranchBalanceSyncEntry(
            itemName: itemName,
            balance: balance,
            isMissingFromReport: missingFromReport,
          ),
        );
        successCount++;
      } catch (error) {
        entries.add(
          BranchBalanceSyncEntry(
            itemName: itemName,
            balance: balance,
            error: error,
            isMissingFromReport: missingFromReport,
          ),
        );
      }
      completed++;
      onProgress?.call(completed, total);
    }

    for (final row in rows) {
      final itemId = row['itemid'].toString();
      await sync(
        itemId: itemId,
        itemName: row['item']?.toString() ?? itemId,
        balance: row['balance_cd'] is num
            ? row['balance_cd'] as num
            : num.tryParse(row['balance_cd']?.toString() ?? '') ?? 0,
      );
    }
    for (final item in zeroItems) {
      await sync(
        itemId: item.id,
        itemName: item.name,
        balance: 0,
        missingFromReport: true,
      );
    }
    if (successCount > 0) datafeed.notifyItemChanges();

    return BranchBalanceSyncSummary(
      entries: entries,
      successCount: successCount,
      errorCount: entries.length - successCount,
    );
  }

  Future<void> _writeBranchBalance({
    required Datafeed datafeed,
    required String itemId,
    required String branchId,
    required num balance,
    required bool merge,
  }) async {
    final reference = _db.collection('itemsreg').doc(itemId);
    if (merge) {
      await reference.set({
        'branchbalance': {
          branchId: {
            'netpieces': balance,
            'lastupdate': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));
    } else {
      await reference.update({
        FieldPath(['branchbalance', branchId, 'netpieces']): balance,
        FieldPath(['branchbalance', branchId, 'lastupdate']):
            FieldValue.serverTimestamp(),
      });
    }
    datafeed.updateLocalItemBranchBalance(
      itemId,
      branchId,
      balance,
      notify: !merge,
    );
  }

  Future<void> saveBranchPricing({
    required Datafeed datafeed,
    required ItemModel item,
    required String branchId,
    required String branchName,
    required List<Mode> modes,
    required String supplierMinimumQuantity,
    required String updatedBy,
  }) async {
    final pricing = {for (final mode in modes) mode.id: mode.toMap()};
    final branchData = <String, dynamic>{
      'name': branchName,
      'pricing': pricing,
      'sminqty': supplierMinimumQuantity.trim(),
      'updatedat': FieldValue.serverTimestamp(),
      'updatedby': updatedBy,
    };
    await _db.collection('itemsreg').doc(item.id).update({
      FieldPath(['branchprices', branchId]): branchData,
      'pricingmode': true,
    });
    _updateLocalBranchPricing(datafeed, item, branchId, branchData);
  }

  Future<void> removeBranchPricingMode({
    required Datafeed datafeed,
    required ItemModel item,
    required String branchId,
    required String modeId,
  }) async {
    final existing = item.branchprices?[branchId];
    if (existing is Map && existing.isNotEmpty) {
      await _db.collection('itemsreg').doc(item.id).update({
        FieldPath(['branchprices', branchId, 'pricing', modeId]):
            FieldValue.delete(),
      });
      final branchData = Map<String, dynamic>.from(existing);
      final pricing = Map<String, dynamic>.from(
        branchData['pricing'] as Map? ?? const {},
      )..remove(modeId);
      branchData['pricing'] = pricing;
      _updateLocalBranchPricing(datafeed, item, branchId, branchData);
    }
  }

  void _updateLocalBranchPricing(
    Datafeed datafeed,
    ItemModel item,
    String branchId,
    Map<String, dynamic> branchData,
  ) {
    final branchPrices = Map<String, dynamic>.from(item.branchprices ?? {})
      ..[branchId] = branchData;
    datafeed.updateLocalItemBranchPrices(item, branchPrices);
  }

  List<Map<String, dynamic>> filterBundles({
    required List<Map<String, dynamic>> bundles,
    required String searchQuery,
    DateTimeRange? dateRange,
  }) {
    final query = searchQuery.trim().toLowerCase();
    final start = dateRange == null
        ? null
        : DateTime(
            dateRange.start.year,
            dateRange.start.month,
            dateRange.start.day,
          );
    final end = dateRange == null
        ? null
        : DateTime(
            dateRange.end.year,
            dateRange.end.month,
            dateRange.end.day,
            23,
            59,
            59,
            999,
          );

    return bundles.where((bundle) {
      if (start != null && end != null) {
        final timestamp = bundle['createdat'];
        final createdAt = timestamp is Timestamp
            ? timestamp.toDate()
            : timestamp is DateTime
            ? timestamp
            : null;
        if (createdAt == null ||
            createdAt.isBefore(start) ||
            createdAt.isAfter(end)) {
          return false;
        }
      }

      if (query.isEmpty) return true;
      final topLevelMatch = [
        bundle['name'],
        bundle['id'],
        bundle['company'],
        bundle['branchid'],
        bundle['producttype'],
      ].any((value) => value.toString().toLowerCase().contains(query));
      if (topLevelMatch) return true;

      final rawItems = bundle['items'];
      if (rawItems is! List) return false;
      return rawItems.any((rawItem) {
        if (rawItem is! Map) return false;
        return [
          rawItem['item'],
          rawItem['itemid'],
          rawItem['mode'],
          rawItem['price'],
          rawItem['quantity'],
          rawItem['totalamount'],
          rawItem['totalpieces'],
          rawItem['barcode'],
        ].any((value) => value.toString().toLowerCase().contains(query));
      });
    }).toList();
  }

  void sortBundles({
    required List<Map<String, dynamic>> bundles,
    required int columnIndex,
    required bool ascending,
  }) {
    int compare(Map<String, dynamic> first, Map<String, dynamic> second) {
      final result = switch (columnIndex) {
        1 => _text(
          first['name'],
        ).toLowerCase().compareTo(_text(second['name']).toLowerCase()),
        2 => _firstBundleItemName(
          first,
        ).compareTo(_firstBundleItemName(second)),
        3 => _bundleTotal(first).compareTo(_bundleTotal(second)),
        4 => _bundleDate(first).compareTo(_bundleDate(second)),
        _ => 0,
      };
      return ascending ? result : -result;
    }

    bundles.sort(compare);
  }

  String _text(Object? value) => value?.toString() ?? '';

  Map<String, dynamic> _bundleItems(Map<String, dynamic> bundle) {
    final rawItems = bundle['items'];
    if (rawItems is Map) return Map<String, dynamic>.from(rawItems);
    if (rawItems is List) {
      return {
        for (var index = 0; index < rawItems.length; index++)
          '$index': rawItems[index],
      };
    }
    return {};
  }

  Map<String, dynamic> bundleItemsMap(Map<String, dynamic> bundle) =>
      _bundleItems(bundle);

  String _firstBundleItemName(Map<String, dynamic> bundle) {
    final items = _bundleItems(bundle).values;
    final first = items.isEmpty ? null : items.first;
    return first is Map ? _text(first['item']).toLowerCase() : '';
  }

  double _bundleTotal(Map<String, dynamic> bundle) =>
      _bundleItems(bundle).values.fold<double>(0, (total, rawItem) {
        if (rawItem is! Map) return total;
        return total + (double.tryParse(_text(rawItem['totalamount'])) ?? 0);
      });

  double bundleTotal(Map<String, dynamic> bundle) => _bundleTotal(bundle);

  DateTime _bundleDate(Map<String, dynamic> bundle) {
    return bundleTimestamp(bundle) ?? DateTime(1900);
  }

  DateTime bundleDate(Map<String, dynamic> bundle) => _bundleDate(bundle);

  DateTime? bundleTimestamp(Map<String, dynamic> bundle) {
    final value = bundle['createdat'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  String? validateItemField(
    String fieldName,
    String? value,
    ItemValidationValues fields,
  ) {
    if (value == null || value.isEmpty) {
      return fieldName == 'supplierMinQty' ? null : 'Required';
    }

    double number(String text, [double fallback = 0]) =>
        double.tryParse(text) ?? fallback;

    switch (fieldName) {
      case 'retailPrice':
        final retailPrice = number(value);
        final unitCost = number(fields.costPrice);
        final boxPrice = number(fields.boxPrice);
        final supplierPrice = number(fields.supplierPrice);
        final boxQty = number(fields.boxQuantity, 1);
        final boxUnitPrice = boxPrice / boxQty;
        if (retailPrice <= 0) return 'Enter a valid retail price';
        if (unitCost > 0 && retailPrice < unitCost) {
          return 'Retail price GHS$retailPrice must be greater than\n Unit Cost which is GHS${boxPrice / boxQty}';
        }
        if (boxQty > 1) {
          if (retailPrice < boxUnitPrice) {
            return 'Retail price GHS$retailPrice must be equal to \n or greater than Box unit Price GHS${boxPrice / boxQty}';
          }
          if (supplierPrice > 0 && retailPrice < supplierPrice / boxQty) {
            return 'Unit retail price GHS$retailPrice must be equal \n to or greater than Supplier Price ${supplierPrice / boxQty}';
          }
          if (retailPrice < unitCost) {
            return 'Retail price GHS$retailPrice must be greater than\n or equal to Unit Cost GHS$unitCost';
          }
        }
        return null;
      case 'costPrice':
        final costPrice = number(value);
        final retailPrice = number(fields.retailPrice);
        if (retailPrice > 0 && costPrice > retailPrice) {
          return 'Unit Cost Price GHS$costPrice must be less than Retail Price GHS$retailPrice';
        }
        return null;
      case 'boxQty':
        if (number(value) < 1) return 'Box quantity must be at least 1';
        return null;
      case 'boxPrice':
        final boxQty = number(fields.boxQuantity);
        final boxPrice = number(value);
        final boxQtyValue = number(fields.boxQuantity, 1);
        final pricePerUnit = boxQtyValue > 0 ? boxPrice / boxQtyValue : 0;
        final retailPrice = number(fields.retailPrice);
        final costPrice = number(fields.costPrice);
        if (boxQty == 1) {
          if (costPrice > boxPrice) {
            return 'Cost price  GHS$costPrice \n is more than Box Price GHS$boxPrice';
          }
          if (boxPrice > retailPrice) {
            return 'Box price  GHS$boxPrice \n can more than Retail Price GHS$retailPrice';
          }
          return null;
        }
        if (pricePerUnit > retailPrice) {
          return 'Price per unit which is GHS${boxPrice / boxQtyValue} \n Qty cannot be less than Retail Price';
        }
        if (pricePerUnit < costPrice) {
          return 'Price per unit which is GHS${boxPrice / boxQtyValue} \n Qty cannot be less than Unit Cost Price';
        }
        return null;
      case 'supplierPrice':
        final boxQty = number(fields.boxQuantity);
        if (boxQty <= 0) return null;
        final supplierPrice = number(value);
        final unitCost = number(fields.costPrice);
        final boxPrice = number(fields.boxPrice);
        final retailPrice = number(fields.retailPrice);
        if (boxQty == 1) {
          if (unitCost > supplierPrice) {
            return 'Cost price  GHS$unitCost \n is more than Supplier Price GHS$supplierPrice';
          }
          if (supplierPrice > retailPrice) {
            return 'Supplier price  GHS$supplierPrice \n is more than Retail Price GHS$retailPrice';
          }
          return null;
        }
        final minSupplierPrice = unitCost * boxQty;
        if (supplierPrice < minSupplierPrice) {
          return 'Supplier Price GHS$supplierPrice must be more\n or equal to  (${minSupplierPrice.toStringAsFixed(2)})';
        }
        if (supplierPrice > boxPrice) {
          return 'Supplier Price must be less than \n or equal to Box Price';
        }
        return null;
      case 'supplierMinQty':
        final supplierQty = double.tryParse(value);
        if (supplierQty == null || supplierQty <= 0) {
          return 'Supplier Min Qty must be greater than zero';
        }
        return null;
      case 'halfBoxQty':
        final halfQty = number(value);
        final boxQty = number(fields.boxQuantity);
        if (boxQty == 0) return null;
        final requiredHalfQty = boxQty / 2;
        if (halfQty <= 0) return 'Half Box Qty must be greater than zero';
        if (halfQty > boxQty) return 'Half Box Qty cannot exceed Box Qty';
        if ((halfQty - requiredHalfQty).abs() > 0.001) {
          return 'Half Box Qty must be $requiredHalfQty';
        }
        return null;
      case 'halfBoxPrice':
        final halfPrice = number(value);
        final boxPrice = number(fields.boxPrice);
        if (boxPrice == 0) return null;
        final requiredHalfPrice = boxPrice / 2;
        if (halfPrice > boxPrice) {
          return 'Half Box Price cannot exceed Box Price';
        }
        if (halfPrice < requiredHalfPrice) {
          return 'Half Box Price must be at least ${requiredHalfPrice.toStringAsFixed(2)}';
        }
        return null;
      case 'quarterQty':
        final quarterQty = number(value);
        final boxQty = number(fields.boxQuantity);
        final halfQty = number(fields.halfBoxQuantity);
        final packQty = number(fields.packQuantity);
        if (boxQty == 0) return null;
        final requiredQuarterQty = boxQty / 4;
        if (quarterQty <= 0) return 'Quarter Qty must be greater than zero';
        if (quarterQty > boxQty) return 'Quarter Qty cannot exceed Box Qty';
        if ((quarterQty - requiredQuarterQty).abs() > 0.001) {
          return 'Quarter Qty must be $requiredQuarterQty';
        }
        if (halfQty > 0 && quarterQty >= halfQty) {
          return 'Quarter Qty must be less than Half Qty';
        }
        if (packQty > 0 && quarterQty <= packQty) {
          return 'Quarter Qty must be greater than Pack Qty';
        }
        return null;
      case 'quarterPrice':
        final quarterPrice = number(value);
        final boxPrice = number(fields.boxPrice);
        final halfPrice = number(fields.halfBoxPrice);
        if (boxPrice == 0) return null;
        final requiredQuarterPrice = boxPrice / 4;
        if (quarterPrice > boxPrice) {
          return 'Quarter Price cannot exceed Box Price';
        }
        if (quarterPrice < requiredQuarterPrice) {
          return 'Quarter Price must be at least ${requiredQuarterPrice.toStringAsFixed(2)}';
        }
        if (halfPrice > 0 && quarterPrice >= halfPrice) {
          return 'Quarter Price must be less than Half Box Price';
        }
        return null;
      case 'packQty':
        if (!fields.enableBoxPricing) return null;
        final packQty = number(value);
        final boxQty = number(fields.boxQuantity);
        final halfQty = number(fields.halfBoxQuantity);
        final quarterQty = number(fields.quarterQuantity);
        if (packQty <= 0) return 'Pack Qty must be greater than zero';
        if (boxQty > 0 && packQty > 0 && (boxQty % packQty).abs() > 0.000001) {
          return 'Box Qty must be divisible by Pack Qty';
        }
        if (boxQty > 0 && packQty > boxQty) {
          return 'Pack Qty cannot exceed Box Qty';
        }
        if (halfQty > 0 && packQty >= halfQty) {
          return 'Pack Qty must be less than Half Qty';
        }
        if (quarterQty > 0 && packQty >= quarterQty) {
          return 'Pack Qty must be less than Quarter Qty';
        }
        return null;
      case 'packPrice':
        final packPrice = number(value);
        final boxPrice = number(fields.boxPrice);
        final boxQty = number(fields.boxQuantity);
        final packQty = number(fields.packQuantity);
        final retailPrice = number(fields.retailPrice);
        final unitCostPrice = number(fields.costPrice);
        if (boxQty == 0 || packQty == 0 || boxPrice == 0) return null;
        final unitBoxPrice = boxPrice / boxQty;
        final requiredPackPrice = packPrice / packQty;
        if (requiredPackPrice > retailPrice ||
            requiredPackPrice < unitCostPrice ||
            requiredPackPrice < unitBoxPrice) {
          return 'Please check Unit(box/cost/retail) price';
        }
        return null;
      default:
        return null;
    }
  }

  List<Mode> buildItemModes({
    required List<Mode> existingModes,
    required String companyType,
    required String costPrice,
    required String retailPrice,
    required String boxQuantity,
    required String boxPrice,
    required String supplierPrice,
    required bool enableBoxPricing,
    required int pricingStep,
    required String halfBoxQuantity,
    required String halfBoxPrice,
    required String quarterQuantity,
    required String quarterPrice,
    required String packQuantity,
    required String packPrice,
  }) {
    final modes = List<Mode>.of(existingModes);
    final boxQty = double.tryParse(boxQuantity) ?? 0;
    final hasBoxQuantity = boxQty >= 1;
    final businessType = companyType.toLowerCase().trim();

    void upsert(String id, Mode mode) {
      final index = modes.indexWhere((existing) => existing.id == id);
      if (index == -1) {
        modes.add(mode);
      } else {
        modes[index] = mode;
      }
    }

    void remove(String id) => modes.removeWhere((mode) => mode.id == id);

    final wantSingle = hasBoxQuantity && businessType != 'wholesale';
    final wantCarton = hasBoxQuantity && businessType != 'retail';
    final cp = costPrice.trim();
    final rp = retailPrice.trim();
    final wp = boxPrice.trim();
    final sp = supplierPrice.trim();

    if (wantSingle) {
      upsert(
        'single',
        Mode(
          id: 'single',
          name: 'Single',
          qty: '1',
          cp: cp,
          rp: rp,
          wp: boxQty == 1 ? wp : rp,
          sp: boxQty == 1 ? sp : rp,
        ),
      );
    } else {
      remove('single');
    }
    if (wantCarton) {
      upsert(
        'carton',
        Mode(
          id: 'carton',
          name: 'Carton',
          qty: boxQuantity.trim(),
          cp: cp,
          rp: boxQty > 1 ? wp : rp,
          wp: wp,
          sp: sp,
        ),
      );
    } else {
      remove('carton');
    }

    void splitMode({
      required int step,
      required int requiredStep,
      required String id,
      required String name,
      required String quantity,
      required String price,
    }) {
      if (hasBoxQuantity &&
          enableBoxPricing &&
          step >= requiredStep &&
          quantity.isNotEmpty &&
          price.isNotEmpty) {
        upsert(
          id,
          Mode(
            id: id,
            name: name,
            qty: quantity.trim(),
            cp: cp,
            rp: price.trim(),
            wp: price.trim(),
            sp: price.trim(),
          ),
        );
      } else {
        remove(id);
      }
    }

    splitMode(
      step: pricingStep,
      requiredStep: 1,
      id: 'half',
      name: 'Half Carton',
      quantity: halfBoxQuantity,
      price: halfBoxPrice,
    );
    splitMode(
      step: pricingStep,
      requiredStep: 2,
      id: 'quarter',
      name: 'Quarter Carton',
      quantity: quarterQuantity,
      price: quarterPrice,
    );
    splitMode(
      step: pricingStep,
      requiredStep: 3,
      id: 'pack',
      name: 'Pack',
      quantity: packQuantity,
      price: packPrice,
    );
    return modes;
  }

  Future<String> saveItem({
    required Datafeed datafeed,
    required String? existingId,
    required ItemModel? existingItem,
    required String name,
    required String barcode,
    required String costPrice,
    required String productType,
    required String productCategory,
    required String imageUrl,
    required String wholesaleMinQuantity,
    required String supplierMinQuantity,
    required String shelfNumber,
    required bool enableBoxPricing,
    required List<Mode> modes,
  }) async {
    final itemName = name.trim();
    final itemBarcode = this.itemBarcode(itemName, barcode);
    final docId = existingId ?? itemDocumentId(datafeed.companyid, itemName);

    final nameQuery = await _db
        .collection('itemsreg')
        .where('companyid', isEqualTo: datafeed.companyid)
        .where('name', isEqualTo: itemName)
        .limit(1)
        .get();
    if (nameQuery.docs.isNotEmpty && nameQuery.docs.first.id != docId) {
      throw ItemProviderException(
        'An item with name "$itemName" already exists for this company',
      );
    }
    if (itemBarcode.isNotEmpty) {
      final barcodeQuery = await _db
          .collection('itemsreg')
          .where('companyid', isEqualTo: datafeed.companyid)
          .where('barcode', isEqualTo: itemBarcode)
          .limit(1)
          .get();
      if (barcodeQuery.docs.isNotEmpty && barcodeQuery.docs.first.id != docId) {
        throw ItemProviderException(
          'An item with barcode "$itemBarcode" already exists',
        );
      }
    }

    final docRef = _db.collection('itemsreg').doc(docId);
    if (existingId == null) {
      final now = DateTime.now();
      final weekNumber =
          ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;
      final item = ItemModel(
        id: docId,
        name: itemName,
        barcode: itemBarcode,
        cp: costPrice.trim(),
        retailmarkup: '',
        wholesalemarkup: '',
        retailprice: '',
        wholesaleprice: '',
        producttype: productType,
        pricingmode: false,
        pcategory: productCategory,
        warehouse: '',
        openingstock: '',
        company: datafeed.company,
        companyid: datafeed.companyid,
        imageurl: imageUrl,
        modes: modes,
        createdat: now,
        updatedby: null,
        updatedat: null,
        wminqty: wholesaleMinQuantity,
        sminqty: supplierMinQuantity,
        staff: datafeed.staff,
        modemore: enableBoxPricing,
        deletedat: null,
        deletedby: null,
        day: DateFormat('EEEE').format(now),
        week: '${now.year}.$weekNumber',
        month: '${now.year}.${now.month}',
        year: '${now.year}',
        shelfnumber: shelfNumber,
      );
      final data = item.toMap()..['createdat'] = FieldValue.serverTimestamp();
      await docRef.set(data, SetOptions(merge: true));
      return docId;
    }

    await docRef.update({
      'name': itemName,
      'barcode': itemBarcode,
      'cp': costPrice.trim(),
      'producttype': productType,
      'pcategory': productCategory,
      'imageurl': imageUrl,
      'modes': {for (final mode in modes) mode.id: mode.toMap()},
      'wminqty': wholesaleMinQuantity,
      'sminqty': supplierMinQuantity,
      'modemore': enableBoxPricing,
      'updatedat': FieldValue.serverTimestamp(),
      'updatedby': datafeed.staff,
      'shelfnumber': shelfNumber,
    });
    return existingItem?.id ?? docId;
  }

  String _sanitize(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  Future<void> deleteItem({
    required Datafeed datafeed,
    required String id,
  }) async {
    final docRef = _db.collection('itemsreg').doc(id);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      final data = snapshot.data();
      if (data == null) {
        throw ItemProviderException(
          'The item could not be read before deletion.',
        );
      }
      await _db.collection('deletedcollection').add({
        ...data,
        'originalCollection': 'itemsreg',
        'originalId': id,
        'type': 'itemsreg',
        'status': 'deleted',
        'branchid': datafeed.branchid,
        'deleted_at': FieldValue.serverTimestamp(),
        'deleted_by': datafeed.staff,
        'deleted_email': datafeed.staffemail,
        'companyid': datafeed.companyid,
        'datedmy': DateFormat('dd-MM-yyyy').format(DateTime.now()),
      });
      await docRef.delete();
    }
    datafeed.items.removeWhere((item) => item.id == id);
    datafeed.notifyListeners();
  }

  Future<void> setItemActive({
    required Datafeed datafeed,
    required String docId,
    required bool newStatus,
  }) async {
    final index = datafeed.items.indexWhere((item) => item.id == docId);
    if (index != -1) {
      datafeed.items[index] = datafeed.items[index].copyWith(
        isActive: newStatus,
      );
      datafeed.notifyListeners();
    }
    try {
      await _db.collection('itemsreg').doc(docId).update({
        'isActive': newStatus,
      });
    } catch (_) {
      if (index != -1) {
        datafeed.items[index] = datafeed.items[index].copyWith(
          isActive: !newStatus,
        );
        datafeed.notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> setBundleActive({
    required String docId,
    required bool newStatus,
  }) async {
    final index = bundleView.indexWhere((bundle) => bundle['id'] == docId);
    if (index != -1) {
      bundleView[index]['isActive'] = newStatus;
      notifyListeners();
    }
    try {
      await _db.collection('bundle').doc(docId).update({'isActive': newStatus});
    } catch (_) {
      if (index != -1) {
        bundleView[index]['isActive'] = !newStatus;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> updateBundleName({
    required Datafeed datafeed,
    required String bundleId,
    required String newName,
    required List<Map<String, dynamic>> items,
  }) async {
    final duplicateQuery = await _db
        .collection('bundle')
        .where('name', isEqualTo: newName)
        .where('companyid', isEqualTo: datafeed.companyid)
        .limit(2)
        .get();
    if (duplicateQuery.docs.any((doc) => doc.id != bundleId)) {
      throw const ItemProviderException(
        'A bundle with this name already exists',
      );
    }

    final updatedItems = items
        .map((item) => {...item, 'bundleName': newName})
        .toList();
    await _db.collection('bundle').doc(bundleId).update({
      'name': newName,
      'barcode': newName,
      'items': updatedItems,
    });

    final index = bundleView.indexWhere((bundle) => bundle['id'] == bundleId);
    if (index != -1) {
      bundleView[index]
        ..['name'] = newName
        ..['barcode'] = newName
        ..['items'] = updatedItems;
      bundleItems = bundleView
          .map((bundle) => ItemModel.fromMap(bundle))
          .toList();
      notifyListeners();
    }
    return updatedItems;
  }

  Future<Map<String, dynamic>> saveBundle({
    required Datafeed datafeed,
    required String name,
    required String? existingId,
    required bool isActive,
    required List<Map<String, dynamic>> items,
    Object? originalCreatedAt,
  }) async {
    final bundleName = name.trim();
    if (bundleName.isEmpty) {
      throw const ItemProviderException('Enter bundle name before saving');
    }
    if (items.isEmpty) {
      throw const ItemProviderException(
        'Add at least one item to preview before saving',
      );
    }

    final duplicateQuery = await _db
        .collection('bundle')
        .where('name', isEqualTo: bundleName)
        .where('companyid', isEqualTo: datafeed.companyid)
        .limit(2)
        .get();
    if (duplicateQuery.docs.any((doc) => doc.id != existingId)) {
      throw const ItemProviderException(
        'A bundle with this name already exists',
      );
    }

    final now = DateTime.now();
    final weekNumber =
        ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;
    final docId =
        existingId ??
        '${_sanitize(datafeed.companyid)}_${datafeed.staffPosition}_${_sanitize(bundleName)}';
    final bundleDoc = <String, dynamic>{
      'name': bundleName,
      'id': docId,
      'isActive': isActive,
      'companyid': datafeed.companyid,
      'branchid': datafeed.branchid,
      'barcode': bundleName,
      'producttype': 'bundle',
      'pcategory': bundleName,
      'isHamper': true,
      'day': DateFormat('EEEE').format(now),
      'week': '${now.year}.$weekNumber',
      'month': '${now.year}.${now.month}',
      'year': '${now.year}',
      'company': datafeed.company,
      'createdat': FieldValue.serverTimestamp(),
      'staff': datafeed.staff,
      'items': items
          .map((item) => {...item, 'bundleName': bundleName})
          .toList(),
    };

    await _db.collection('bundle').doc(docId).set(bundleDoc);

    final localDoc = Map<String, dynamic>.from(bundleDoc)
      ..['createdat'] = existingId == null ? null : originalCreatedAt;
    final index = bundleView.indexWhere((bundle) => bundle['id'] == docId);
    if (index == -1) {
      bundleView.add(localDoc);
    } else {
      bundleView[index] = localDoc;
    }
    bundleItems = bundleView
        .map((bundle) => ItemModel.fromMap(bundle))
        .toList();
    notifyListeners();
    return localDoc;
  }

  Future<void> deleteBundle({
    required Datafeed datafeed,
    required String id,
  }) async {
    final bundleRef = _db.collection('bundle').doc(id);
    final bundleDoc = await bundleRef.get();
    if (bundleDoc.exists) {
      final data = bundleDoc.data();
      if (data == null) {
        throw const ItemProviderException(
          'The bundle could not be read before deletion.',
        );
      }
      await _db.collection('deletedbundles').doc(id).set({
        ...data,
        'deleted_at': FieldValue.serverTimestamp(),
        'deleted_by': datafeed.staff,
        'deleted_email': datafeed.staffemail,
        'type': 'bundle',
        'originalCollection': 'bundle',
        'originalId': id,
        'datedmy': DateFormat('dd-MM-yyyy').format(DateTime.now()),
      });
    }
    await bundleRef.delete();
    bundleView.removeWhere((bundle) => bundle['id'] == id);
    bundleItems.removeWhere((bundle) => bundle.id == id);
    notifyListeners();
  }

  Future<void> removeItemPricingMode({
    required String itemId,
    required String modeId,
  }) => _db.collection('itemsreg').doc(itemId).update({
    'modes.$modeId': FieldValue.delete(),
  });
}

class ItemProviderException implements Exception {
  const ItemProviderException(this.message);

  final String message;

  @override
  String toString() => message;
}
