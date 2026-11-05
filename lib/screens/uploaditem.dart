import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/itemmodel.dart';
import '../models/itemregmodel.dart';
import '../providers/Datafeed.dart';
import '../services/sales_import_service.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
class ItemUploadPage extends StatefulWidget {
  const ItemUploadPage({super.key});

  @override
  State<ItemUploadPage> createState() => _ItemUploadPageState();
}

class _ItemUploadPageState extends State<ItemUploadPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  final SalesImportService _shared = SalesImportService();

  static const List<String> requiredCsvHeaders = [
    'name',
    'barcode',
    'category',
    'type',
    'cost',
    'retail',
    'boxQty',
    'boxPrice',
    'supplierPrice',
    'supplierMinQty',
    'halfQty',
    'halfPrice',
    'quarterQty',
    'quarterPrice',
    'packQty',
    'packPrice',
  ];

  List<Map<String, String>> previewData = [];
  List<String> headers = [];


  static const List<int> _xlsxMagic = [0x50, 0x4B, 0x03, 0x04];
  static const List<int> _xlsMagic  = [0xD0, 0xCF, 0x11, 0xE0];
  bool loading = false;
  int currentIndex = 0;
  List<String> rowStatus = [];

  bool _paused = false;
  bool _cancelled = false;
  Completer<void>? _pauseCompleter;
  bool _uploadInFlight = false;
  static const int _uiUpdateInterval = 200;


  String? _progressKey;

  final int maxSize = 1 * 1024 * 1024;
  String fileInfo = '';
  static const int _maxCsvFileSizeMB = 300;
  static const int _maxCsvWebFileSizeMB = 25;
  static const int _maxExcelFileSizeMB = 5;
  static const int _maxRows = 50000;
  static const int _writeBatchSize = 400;
  static const int _previewPageSize = 50;
  int _previewPage = 0;


  String? _validateFile(String filename, int sizeBytes, String extension) {
    final sizeMB = sizeBytes / (1024 * 1024);
    final capMB = extension == 'csv'
        ? (kIsWeb ? _maxCsvWebFileSizeMB : _maxCsvFileSizeMB)
        : _maxExcelFileSizeMB;

    if (sizeMB > capMB) {
      return 'File exceeds ${capMB}MB limit${extension != 'csv' ? ' (Excel files must load fully into memory)' : ''}.';
    }

    if (!['csv', 'xlsx', 'xls'].contains(extension)) {
      return 'Unsupported file type: .$extension';
    }

    return null;
  }

  bool _looksLikeBinary(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return _matchesMagic(bytes, [0x4D, 0x5A]) ||
        _matchesMagic(bytes, [0x7F, 0x45, 0x4C, 0x46]) ||
        _matchesMagic(bytes, _xlsxMagic) ||
        _matchesMagic(bytes, _xlsMagic);
  }

  bool _matchesMagic(Uint8List bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  String _sanitizeCell(String value) => _shared.sanitizeCell(value);


  String _progressKeyFor(String companyId, String fileName, int fileBytes, int rowCount) {
    return 'itemUploadProgress:$companyId:$fileName:$fileBytes:$rowCount';
  }

  Future<Set<String>> _loadPersistedSuccessDocIds(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return {};
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _addPersistedSuccessDocIds(Iterable<String> newDocIds) async {
    final key = _progressKey;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = (jsonDecode(prefs.getString(key) ?? '[]') as List).cast<String>().toSet();
      existing.addAll(newDocIds);
      await prefs.setString(key, jsonEncode(existing.toList()));
    } catch (_) {
      // Best-effort — local persistence is a convenience, not a
      // correctness requirement; the in-memory upload still succeeds.
    }
  }

  Future<void> _forgetPersistedProgress() async {
    final key = _progressKey;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Forget saved progress?',
          style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurface),
        ),
        content: Text(
          'This clears the local record of which rows in this file were already uploaded. '
              'Rows are safe to re-upload either way — each one overwrites the same item record '
              'rather than creating a duplicate — this only affects how much work gets skipped '
              'and re-checked next time.',
          style: TextStyle(
            color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Forget it',
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (key != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < rowStatus.length; i++) {
        rowStatus[i] = 'pending';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleared saved upload history — this file will be treated as new.')),
    );
  }


  Future<void> _waitIfPaused() async {
    while (_paused && !_cancelled) {
      _pauseCompleter ??= Completer<void>();
      await _pauseCompleter!.future;
    }
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      if (!_paused) {
        _pauseCompleter?.complete();
        _pauseCompleter = null;
      }
    });
  }

  void _cancelUpload() {
    _cancelled = true;
    if (_paused) {
      _paused = false;
      _pauseCompleter?.complete();
      _pauseCompleter = null;
    }
    setState(() {});
  }

  //PICK FILE


  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: kIsWeb,
      withReadStream: !kIsWeb,
    );

    if (result == null) return;

    final file = result.files.first;
    final extension = file.name.split('.').last.toLowerCase();

    final validationError = _validateFile(file.name, file.size, extension);
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    try {
      if (extension == 'csv') {
        if (file.readStream != null) {
          await _parseCsvStream(file.readStream!, file.name, file.size);
        } else if (file.bytes != null) {
          if (_looksLikeBinary(file.bytes!)) {
            throw 'File "${file.name}" does not appear to be a valid CSV.';
          }
          await _parseCsvStream(Stream.value(file.bytes!), file.name, file.size);
        } else {
          throw 'Could not read file contents.';
        }
      } else {
        Uint8List excelBytes;
        if (file.bytes != null) {
          excelBytes = file.bytes!;
        } else if (file.readStream != null) {
          final builder = BytesBuilder();
          await for (final chunk in file.readStream!) {
            builder.add(chunk);
          }
          excelBytes = builder.toBytes();
        } else {
          throw 'Could not read file contents.';
        }

        if (extension == 'xlsx' && !_matchesMagic(excelBytes, _xlsxMagic)) {
          throw 'File "${file.name}" is not a valid Excel (.xlsx) file.';
        }
        if (extension == 'xls' && !_matchesMagic(excelBytes, _xlsMagic)) {
          throw 'File "${file.name}" is not a valid Excel (.xls) file.';
        }

        await _parseExcelBytes(excelBytes, file.name, file.size);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _parseCsvStream(Stream<List<int>> stream, String filename, int fileSizeBytes) async {
    List<String> tempHeaders = [];
    List<Map<String, String>> tempData = [];
    bool headerParsed = false;
    String delimiter = ',';
    bool rowLimitHit = false;

    final lineStream = stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final rawLine in lineStream) {
      if (rawLine.trim().isEmpty) continue;

      if (!headerParsed) {
        delimiter = _detectCsvDelimiter(rawLine);
        tempHeaders = _parseCsvLine(rawLine, delimiter)
            .map((h) => _sanitizeCell(_cleanNullLiteral(h)))
            .toList();
        headerParsed = true;
        continue;
      }

      if (tempData.length >= _maxRows) {
        rowLimitHit = true;
        break;
      }

      final cols = _parseCsvLine(rawLine, delimiter);
      final rowMap = <String, String>{};
      for (int j = 0; j < tempHeaders.length; j++) {
        final raw = j < cols.length ? cols[j] : '';
        rowMap[tempHeaders[j]] = _sanitizeCell(_cleanNullLiteral(raw));
      }
      tempData.add(rowMap);
    }

    if (!headerParsed) throw 'CSV file is empty';

    await _finishParsing(tempHeaders, tempData, filename, fileSizeBytes, rowLimitHit);
  }

  Future<void> _parseExcelBytes(Uint8List bytes, String filename, int fileSizeBytes) async {
    final excelFile = excel_lib.Excel.decodeBytes(bytes);
    if (excelFile.tables.isEmpty) throw 'Excel file has no sheets';

    final sheet = excelFile.tables.values.first;
    if (sheet.maxRows < 2) throw 'Excel file has no data rows';

    final tempHeaders = sheet.rows.first
        .map((cell) => _sanitizeCell(_cleanNullLiteral(cell?.value?.toString() ?? '')))
        .where((h) => h.isNotEmpty)
        .toList();

    final tempData = <Map<String, String>>[];
    bool rowLimitHit = false;

    for (int r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.every((cell) => (cell?.value?.toString().trim() ?? '').isEmpty)) continue;

      if (tempData.length >= _maxRows) {
        rowLimitHit = true;
        break;
      }

      final rowMap = <String, String>{};
      for (int c = 0; c < tempHeaders.length; c++) {
        final cell = c < row.length ? row[c] : null;
        rowMap[tempHeaders[c]] = _sanitizeCell(_cleanNullLiteral(cell?.value?.toString() ?? ''));
      }
      tempData.add(rowMap);
    }

    if (tempData.isEmpty) throw 'No data rows found.';

    await _finishParsing(tempHeaders, tempData, filename, fileSizeBytes, rowLimitHit);
  }

  Future<void> _finishParsing(
      List<String> parsedHeaders,
      List<Map<String, String>> parsedRows,
      String filename,
      int fileSizeBytes,
      bool rowLimitHit,
      ) async {
    List<String> finalHeaders = parsedHeaders;
    List<Map<String, String>> finalData = parsedRows;
    bool autoMapped = false;

    final legacyMapped = _mapLegacyItemRows(parsedHeaders, parsedRows);
    if (legacyMapped != null) {
      finalHeaders = requiredCsvHeaders;
      finalData = legacyMapped;
      autoMapped = true;
    }

    final missing = requiredCsvHeaders.where((x) => !finalHeaders.any((h) => h.toLowerCase() == x.toLowerCase()))
        .toList();

    if (missing.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Missing columns: ${missing.join(', ')}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    if (finalData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No data rows found.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

   final companyId = mounted ? context.read<Datafeed>().companyid : '';
    final progressKey = _progressKeyFor(companyId, filename, fileSizeBytes, finalData.length);
    final persistedDocIds = await _loadPersistedSuccessDocIds(progressKey);
    final nameKey = finalHeaders.firstWhere(
          (h) => h.toLowerCase() == 'name',
      orElse: () => 'name',
    );

    int restoredCount = 0;

    if (mounted) {
      setState(() {
        headers = finalHeaders;
        previewData = finalData;
        rowStatus = List.filled(previewData.length, 'pending', growable: true);
        if (persistedDocIds.isNotEmpty && companyId.isNotEmpty) {
          for (int i = 0; i < previewData.length; i++) {
            final name = previewData[i][nameKey]?.trim() ?? '';
            if (name.isEmpty) continue;
            if (persistedDocIds.contains(_buildItemDocId(companyId, name))) {
              rowStatus[i] = 'success';
              restoredCount++;
            }
          }
        }
        _progressKey = progressKey;
        _previewPage = 0;
        fileInfo = autoMapped
            ? '$filename • ${previewData.length} rows • auto-mapped from a legacy export format'
            : '$filename • ${previewData.length} rows';
      });
    }

    if (restoredCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Found $restoredCount row(s) from this file already uploaded on this device — they\'ll be skipped.',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (rowLimitHit && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File exceeds $_maxRows row limit. Only the first $_maxRows rows were loaded.'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
    if (autoMapped && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detected a different column layout and auto-mapped it to the item format.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  String _cleanNullLiteral(String value) =>
      value.trim().toLowerCase() == 'null' ? '' : value;

  String _detectCsvDelimiter(String headerLine) {
    const delimiters = [',', ';', '\t'];
    var delimiter = ',';
    var highestCount = -1;
    for (final candidate in delimiters) {
      var count = 0;
      var inQuotes = false;
      for (var i = 0; i < headerLine.length; i++) {
        final char = headerLine[i];
        if (char == '"') {
          if (inQuotes && i + 1 < headerLine.length && headerLine[i + 1] == '"') {
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (!inQuotes && char == candidate) {
          count++;
        }
      }
      if (count > highestCount) {
        highestCount = count;
        delimiter = candidate;
      }
    }
    return delimiter;
  }

  List<String> _parseCsvLine(String line, String delimiter) {
    final columns = <String>[];
    final value = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          value.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && char == delimiter) {
        columns.add(value.toString());
        value.clear();
      } else {
        value.write(char);
      }
    }

    columns.add(value.toString());
    return columns;
  }

  int _findHeaderIndex(List<String> headers, List<String> candidates) {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');

    final normalizedCandidates = candidates.map(normalize).toSet();
    return headers.indexWhere((header) => normalizedCandidates.contains(normalize(header)));
  }

  List<Map<String, String>>? _mapLegacyItemRows(  List<String> sourceHeaders, List<Map<String, String>> sourceRows, ) {
    final lower = sourceHeaders.map((h) => h.toLowerCase()).toList();
    final hasSignature = ['selling_price', 'cost_price', 'product_type']
        .every((h) => lower.contains(h));
    if (!hasSignature) return null;

    final nameIdx = _findHeaderIndex(sourceHeaders, ['name', 'item', 'itemname', 'productname']);
    final barcodeIdx = _findHeaderIndex(sourceHeaders, ['barcode']);
    final categoryIdx = _findHeaderIndex(sourceHeaders, ['category', 'product_category', 'pcategory']);
    final typeIdx = _findHeaderIndex(sourceHeaders, ['product_type', 'type', 'producttype']);
    final costIdx = _findHeaderIndex(sourceHeaders, ['cost_price', 'cost', 'cp']);
    final retailIdx = _findHeaderIndex(sourceHeaders, ['selling_price', 'retail', 'price', 'rp']);

    if (nameIdx == -1 || costIdx == -1 || retailIdx == -1) return null;

    String cellByHeader(Map<String, String> row, int idx) {
      if (idx == -1) return '';
      final header = sourceHeaders[idx];
      return row[header] ?? '';
    }

    final mapped = <Map<String, String>>[];
    for (final row in sourceRows) {
      final name = cellByHeader(row, nameIdx).trim();
      if (name.isEmpty) continue;

      mapped.add({
        'name': name,
        'barcode': cellByHeader(row, barcodeIdx).trim(),
        'category': cellByHeader(row, categoryIdx).trim(),
        'type': cellByHeader(row, typeIdx).trim().isEmpty
            ? 'product'
            : cellByHeader(row, typeIdx).trim(),
        'cost': cellByHeader(row, costIdx).trim(),
        'retail': cellByHeader(row, retailIdx).trim(),
        'boxQty': '',
        'boxPrice': '',
        'supplierPrice': '',
        'supplierMinQty': '',
        'halfQty': '',
        'halfPrice': '',
        'quarterQty': '',
        'quarterPrice': '',
        'packQty': '',
        'packPrice': '',
      });
    }

    return mapped;
  }

  String? _validateRowField( String fieldName,  String? value, {
    required String cost,
    required String retail,
    required String boxQty,
    required String boxPrice,
    required String supplierPrice,
    required String halfQty,
    required String halfPrice,
    required String quarterQty,
    required String quarterPrice,
    required String packQty,
    required String packPrice,
    required bool enableBoxPricing,
  }) {
    if (value == null || value.isEmpty) {
      if (fieldName == 'supplierMinQty') return null;
      return 'Required';
    }

    switch (fieldName) {
      case 'retailPrice':
        final retailPrice = double.tryParse(value) ?? 0;
        final unitCost = double.tryParse(cost) ?? 0;
        final bPrice = double.tryParse(boxPrice) ?? 0;
        final sPrice = double.tryParse(supplierPrice) ?? 0;
        final bQty = double.tryParse(boxQty) ?? 1;
        final boxUnitPrice = bQty > 0 ? bPrice / bQty : 0;

        if (retailPrice <= 0) return 'Enter a valid retail price';
        if (unitCost > 0 && retailPrice < unitCost) {
          return 'Retail price GHS$retailPrice must be greater than Unit Cost which is GHS${bPrice / bQty}';
        }
        if (bQty > 1) {
          if (retailPrice < boxUnitPrice) {
            return 'Retail price GHS$retailPrice must be equal to or greater than Box unit Price GHS${bPrice / bQty}';
          }
          if (sPrice > 0 && retailPrice < (sPrice / bQty)) {
            return 'Unit retail price GHS$retailPrice must be equal to or greater than Supplier Price ${sPrice / bQty}';
          }
          if (retailPrice < unitCost) {
            return 'Retail price GHS$retailPrice must be greater than or equal to Unit Cost GHS$unitCost';
          }
        }
        return null;

      case 'costPrice':
        final costPrice = double.tryParse(value) ?? 0;
        final retailPrice = double.tryParse(retail) ?? 0;
        if (retailPrice > 0 && costPrice > retailPrice) {
          return 'Unit Cost Price GHS$costPrice must be less than Retail Price GHS$retailPrice';
        }
        return null;

      case 'boxQty':
        final bq = double.tryParse(value) ?? 0;
        if (bq < 1) return 'Box quantity must be at least 1';
        return null;

      case 'boxPrice':
        final bQty = double.tryParse(boxQty) ?? 0;
        double bPrice = double.tryParse(value) ?? 0;
        double bQtyVal = double.tryParse(boxQty) ?? 1;
        double pricePerUnit = bQtyVal > 0 ? bPrice / bQtyVal : 0;
        double retailPrice = double.tryParse(retail) ?? 0;
        double costPrice = double.tryParse(cost) ?? 0;

        if (bQty == 1) {
          if (costPrice > bPrice) {
            return 'Cost price GHS$costPrice is more than Box Price GHS$bPrice';
          }
          if (bPrice > retailPrice) {
            return 'Box price GHS$bPrice can more than Retail Price GHS$retailPrice';
          }
          return null;
        }
        if (pricePerUnit > retailPrice) {
          return 'Price per unit which is GHS${bPrice / bQtyVal} Qty cannot be less than Retail Price';
        }
        if (pricePerUnit < costPrice) {
          return 'Price per unit which is GHS${bPrice / bQtyVal} Qty cannot be less than Unit Cost Price';
        }
        return null;

      case 'supplierPrice':
        final bQty = double.tryParse(boxQty) ?? 0;
        if (bQty <= 0) return null;

        final sPrice = double.tryParse(value) ?? 0;
        final unitCost = double.tryParse(cost) ?? 0;
        final bPrice = double.tryParse(boxPrice) ?? 0;
        final retailPrice = double.tryParse(retail) ?? 0;
        double costPrice = double.tryParse(cost) ?? 0;

        if (bQty == 1) {
          if (costPrice > sPrice) {
            return 'Cost price GHS$costPrice is more than Supplier Price GHS$sPrice';
          }
          if (sPrice > retailPrice) {
            return 'Supplier price GHS$sPrice is more than Retail Price GHS$retailPrice';
          }
          return null;
        }
        final minSupplierPrice = unitCost * bQty;
        if (sPrice < minSupplierPrice) {
          return 'Supplier Price GHS$sPrice must be more or equal to (${minSupplierPrice.toStringAsFixed(2)})';
        }
        if (sPrice > bPrice) {
          return 'Supplier Price must be less than or equal to Box Price';
        }
        return null;

      case 'supplierMinQty':
        final supplierQty = double.tryParse(value);
        if (supplierQty == null || supplierQty <= 0) {
          return 'Supplier Min Qty must be greater than zero';
        }
        return null;

      case 'halfBoxQty':
        final halfBoxQty = double.tryParse(value) ?? 0;
        final bq = double.tryParse(boxQty) ?? 0;
        if (bq == 0) return null;
        final requiredHalfQty = bq / 2;
        if (halfBoxQty <= 0) return 'Half Box Qty must be greater than zero';
        if (halfBoxQty > bq) return 'Half Box Qty cannot exceed Box Qty';
        if ((halfBoxQty - requiredHalfQty).abs() > 0.001) {
          return 'Half Box Qty must be $requiredHalfQty';
        }
        return null;

      case 'halfBoxPrice':
        final halfBoxPrice = double.tryParse(value) ?? 0;
        final bPrice = double.tryParse(boxPrice) ?? 0;
        if (bPrice == 0) return null;
        final requiredHalfPrice = bPrice / 2;
        if (halfBoxPrice > bPrice) return 'Half Box Price cannot exceed Box Price';
        if (halfBoxPrice < requiredHalfPrice) {
          return 'Half Box Price must be at least ${requiredHalfPrice.toStringAsFixed(2)}';
        }
        return null;

      case 'quarterQty':
        final quarterQtyVal = double.tryParse(value) ?? 0;
        final bq = double.tryParse(boxQty) ?? 0;
        final hq = double.tryParse(halfQty) ?? 0;
        final pq = double.tryParse(packQty) ?? 0;
        if (bq == 0) return null;
        final requiredQuarterQty = bq / 4;
        if (quarterQtyVal <= 0) return 'Quarter Qty must be greater than zero';
        if (quarterQtyVal > bq) return 'Quarter Qty cannot exceed Box Qty';
        if ((quarterQtyVal - requiredQuarterQty).abs() > 0.001) {
          return 'Quarter Qty must be $requiredQuarterQty';
        }
        if (hq > 0 && quarterQtyVal >= hq) return 'Quarter Qty must be less than Half Qty';
        if (pq > 0 && quarterQtyVal <= pq) return 'Quarter Qty must be greater than Pack Qty';
        return null;

      case 'quarterPrice':
        final quarterPriceVal = double.tryParse(value) ?? 0;
        final bPrice = double.tryParse(boxPrice) ?? 0;
        final halfBoxPrice = double.tryParse(halfPrice) ?? 0;
        if (bPrice == 0) return null;
        final requiredQuarterPrice = bPrice / 4;
        if (quarterPriceVal > bPrice) return 'Quarter Price cannot exceed Box Price';
        if (quarterPriceVal < requiredQuarterPrice) {
          return 'Quarter Price must be at least ${requiredQuarterPrice.toStringAsFixed(2)}';
        }
        if (halfBoxPrice > 0 && quarterPriceVal >= halfBoxPrice) {
          return 'Quarter Price must be less than Half Box Price';
        }
        return null;

      case 'packQty':
        if (!enableBoxPricing) return null;

        final packQtyVal = double.tryParse(value) ?? 0;
        final bq = double.tryParse(boxQty) ?? 0;
        final hq = double.tryParse(halfQty) ?? 0;
        final qq = double.tryParse(quarterQty) ?? 0;

        if (packQtyVal <= 0) return 'Pack Qty must be greater than zero';
        if (bq > 0 &&
            (bq % packQtyVal).abs() > 0.000001) {
          return 'Box Qty must be divisible by Pack Qty';
        }
        if (bq > 0 && packQtyVal > bq) return 'Pack Qty cannot exceed Box Qty';
        if (hq > 0 && packQtyVal >= hq) return 'Pack Qty must be less than Half Qty';
        if (qq > 0 && packQtyVal >= qq) return 'Pack Qty must be less than Quarter Qty';
        return null;

      case 'packPrice':
        final packPriceVal = double.tryParse(value) ?? 0;
        final bPrice = double.tryParse(boxPrice) ?? 0;
        final bQty = double.tryParse(boxQty) ?? 0;
        final pQty = double.tryParse(packQty) ?? 0;
        final retailPrice = double.tryParse(retail) ?? 0;
        final unitCostPrice = double.tryParse(cost) ?? 0;

        if (bQty == 0 || pQty == 0 || bPrice == 0) return null;
        final unitBoxPrice = bPrice / bQty;
        final requiredPackPrice = packPriceVal / pQty;
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
  //  UPLOAD

  String _normalizeProductType(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.startsWith('serv')) return 'service';
    return 'product';
  }

  String _sanitizeForDocId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  String _buildItemDocId(String companyId, String name) =>
      '${_sanitizeForDocId(companyId)}_${_sanitizeForDocId(name)}';

  String _buildCategoryDocId(String companyId, String category) {
    return '$companyId$category'
        .toLowerCase()
        .replaceAll(RegExp(r'[/\\]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  Future<void> upload() async {
    if (_uploadInFlight) return;
    _uploadInFlight = true;
    try {
      if (previewData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data available to upload')),
          );
        }
        return;
      }

      if (rowStatus.length == previewData.length && rowStatus.every((s) => s == 'success')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('All rows in this file are already uploaded.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final datafeed = context.read<Datafeed>();
      final companyId = datafeed.companyid;

    final bool isResume = rowStatus.length == previewData.length && rowStatus.contains('success');

      setState(() {
        loading = true;
        currentIndex = 0;
        _paused = false;
        _cancelled = false;
        if (rowStatus.length != previewData.length) {
          rowStatus = List.filled(previewData.length, 'pending', growable: true);
        } else {
          for (int i = 0; i < rowStatus.length; i++) {
            if (rowStatus[i] != 'success') rowStatus[i] = 'pending';
          }
        }
      });

      final pendingIndices = <int>[
        for (int i = 0; i < previewData.length; i++)
          if (rowStatus[i] != 'success') i,
      ];

      if (isResume && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Resuming — skipping ${previewData.length - pendingIndices.length} already-uploaded row(s).',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }

      String normalizeKey(String key) {
        return headers.firstWhere(
              (h) => h.toLowerCase() == key.toLowerCase(),
          orElse: () => key,
        );
      }

      final itemDocCache = <String, bool>{};
      final itemDocModes = <String, List<Mode>>{};
      final categoryDocCache = <String, bool>{};
      final processedItemIds = <String>{};
      final processedCategoryIds = <String>{};
      final rowDocId = <int, String>{};

      const int lookupBatchSize = 30;

      try {
        final itemIds = <String>{};
        final categoryIds = <String>{};

        for (final i in pendingIndices) {
          final row = previewData[i];
          final name = row[normalizeKey('name')]?.trim() ?? '';
          if (name.isNotEmpty) {
            itemIds.add(_buildItemDocId(companyId, name));
          }
          final rawCategory = row[normalizeKey('category')]?.trim() ?? '';
          final category = rawCategory.toLowerCase() == 'choose an option' ? '' : rawCategory;
          if (category.isNotEmpty) {
            categoryIds.add(_buildCategoryDocId(companyId, category));
          }
        }

        final itemIdList = itemIds.toList();
        for (int start = 0; start < itemIdList.length; start += lookupBatchSize) {
          final end = (start + lookupBatchSize).clamp(0, itemIdList.length);
          final chunk = itemIdList.sublist(start, end);
          final snaps = await Future.wait(
            chunk.map((id) => db.collection('itemsreg').doc(id).get()),
          );
          for (int k = 0; k < chunk.length; k++) {
            itemDocCache[chunk[k]] = snaps[k].exists;
            final modes = snaps[k].data()?['modes'];
            if (modes is Map) {
              itemDocModes[chunk[k]] = modes.entries
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

        final categoryIdList = categoryIds.toList();
        for (int start = 0; start < categoryIdList.length; start += lookupBatchSize) {
          final end = (start + lookupBatchSize).clamp(0, categoryIdList.length);
          final chunk = categoryIdList.sublist(start, end);
          final snaps = await Future.wait(
            chunk.map((id) => db.collection('productcategoryreg').doc(id).get()),
          );
          for (int k = 0; k < chunk.length; k++) {
            categoryDocCache[chunk[k]] = snaps[k].exists;
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not check existing items: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        setState(() => loading = false);
        return;
      }

      int categoriesCreated = 0;
      int itemsCreated = 0;
      int itemsUpdated = 0;

      WriteBatch batch = db.batch();
      int pendingInBatch = 0;
      final batchRowIndices = <int>[];

      Future<void> flushBatch() async {
        if (pendingInBatch == 0) return;
        try {
          await batch.commit();
          for (final idx in batchRowIndices) {
            rowStatus[idx] = 'success';
          }
          // Best-effort: remember these on-device so a re-pick of this same
          // file (after a crash/restart) skips them too.
          unawaited(_addPersistedSuccessDocIds(
            batchRowIndices.map((idx) => rowDocId[idx]).whereType<String>(),
          ));
        } catch (e) {
          for (final idx in batchRowIndices) {
            rowStatus[idx] = 'error: $e';
          }
        }
        batch = db.batch();
        pendingInBatch = 0;
        batchRowIndices.clear();
        if (mounted) setState(() {});
      }

      for (final i in pendingIndices) {
        if (!mounted || _cancelled) break;
        await _waitIfPaused();
        if (!mounted || _cancelled) break;

        currentIndex = i;
        final row = previewData[i];

        try {
          final name = row[normalizeKey('name')]?.trim() ?? '';
          final barcode = row[normalizeKey('barcode')]?.trim().toLowerCase() ?? '';
          final rawCategory = row[normalizeKey('category')]?.trim() ?? '';
          final category = rawCategory.toLowerCase() == 'choose an option' ? '' : rawCategory;
          final type = _normalizeProductType(row[normalizeKey('type')]?.trim() ?? '');
          final cost = row[normalizeKey('cost')]?.trim() ?? '';
          final retail = row[normalizeKey('retail')]?.trim() ?? '';
          final boxQty = row[normalizeKey('boxQty')]?.trim() ?? '';
          final boxPrice = row[normalizeKey('boxPrice')]?.trim() ?? '';
          final supplierPrice = row[normalizeKey('supplierPrice')]?.trim() ?? '';
          final supplierMinQty = row[normalizeKey('supplierMinQty')]?.trim() ?? '';
          final halfQty = row[normalizeKey('halfQty')]?.trim() ?? '';
          final halfPrice = row[normalizeKey('halfPrice')]?.trim() ?? '';
          final quarterQty = row[normalizeKey('quarterQty')]?.trim() ?? '';
          final quarterPrice = row[normalizeKey('quarterPrice')]?.trim() ?? '';
          final packQty = row[normalizeKey('packQty')]?.trim() ?? '';
          final packPrice = row[normalizeKey('packPrice')]?.trim() ?? '';

          if (name.isEmpty || cost.isEmpty || retail.isEmpty) {
            throw 'Required fields missing at row ${i + 2}';
          }

          final double? costVal = double.tryParse(cost);
          final double? retailVal = double.tryParse(retail);
          if (costVal == null || retailVal == null || costVal < 0 || retailVal < 0) {
            throw 'Invalid cost/retail numbers at row ${i + 2}';
          }

          if (boxQty.isEmpty) {
            throw 'Required box quantity missing at row ${i + 2}';
          }

          final hasHalfPricing = halfQty.isNotEmpty || halfPrice.isNotEmpty;
          final hasQuarterPricing =
              quarterQty.isNotEmpty || quarterPrice.isNotEmpty;
          final hasPackPricing = packQty.isNotEmpty || packPrice.isNotEmpty;
          if (hasHalfPricing && (halfQty.isEmpty || halfPrice.isEmpty)) {
            throw 'Half carton pricing requires both halfQty and halfPrice at row ${i + 2}';
          }
          if (hasQuarterPricing &&
              (quarterQty.isEmpty || quarterPrice.isEmpty)) {
            throw 'Quarter carton pricing requires both quarterQty and quarterPrice at row ${i + 2}';
          }
          if (hasPackPricing && (packQty.isEmpty || packPrice.isEmpty)) {
            throw 'Pack pricing requires both packQty and packPrice at row ${i + 2}';
          }
          if (hasQuarterPricing && !hasHalfPricing) {
            throw 'Half carton pricing is required before quarter pricing at row ${i + 2}';
          }
          if (hasPackPricing && (!hasHalfPricing || !hasQuarterPricing)) {
            throw 'Half and quarter pricing are required before pack pricing at row ${i + 2}';
          }

          final hasBoxQuantity = (double.tryParse(boxQty) ?? 0) >= 1;
          final validationChecks = <String, String>{
            'costPrice': cost,
            'retailPrice': retail,
            'boxQty': boxQty,
            'boxPrice': boxPrice,
            'supplierPrice': supplierPrice,
            if (supplierMinQty.isNotEmpty) 'supplierMinQty': supplierMinQty,
            if (hasHalfPricing) 'halfBoxQty': halfQty,
            if (hasHalfPricing) 'halfBoxPrice': halfPrice,
            if (hasQuarterPricing) 'quarterQty': quarterQty,
            if (hasQuarterPricing) 'quarterPrice': quarterPrice,
            if (hasPackPricing) 'packQty': packQty,
            if (hasPackPricing) 'packPrice': packPrice,
          };

          for (final entry in validationChecks.entries) {
            final error = _validateRowField(
              entry.key,
              entry.value,
              cost: cost,
              retail: retail,
              boxQty: boxQty,
              boxPrice: boxPrice,
              supplierPrice: supplierPrice,
              halfQty: halfQty,
              halfPrice: halfPrice,
              quarterQty: quarterQty,
              quarterPrice: quarterPrice,
              packQty: packQty,
              packPrice: packPrice,
              enableBoxPricing: hasBoxQuantity,
            );
            if (error != null) {
              throw '$error at row ${i + 2}';
            }
          }

          final docId = _buildItemDocId(companyId, name);
          rowDocId[i] = docId;
          final isUpdate = (itemDocCache[docId] ?? false) || processedItemIds.contains(docId);

          if (category.isNotEmpty) {
            final categoryDocId = _buildCategoryDocId(companyId, category);
            final categoryExists = (categoryDocCache[categoryDocId] ?? false) ||
                processedCategoryIds.contains(categoryDocId);
            if (!categoryExists) {
              final categoryRef = db.collection('productcategoryreg').doc(categoryDocId);
              batch.set(categoryRef, {
                'id': categoryDocId,
                'productname': category,
                'companyid': companyId,
                'companyId': companyId,
                'company': datafeed.company,
                'staff': datafeed.staff,
                'createdat': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              pendingInBatch++;
              processedCategoryIds.add(categoryDocId);
              categoriesCreated++;
            }
          }

          final double boxQtyVal = double.parse(boxQty);
          final bool hasBoxPricing = boxQtyVal >= 1;
          final businessType = datafeed.companytype.toLowerCase().trim();
          final supportsRetail = businessType != 'wholesale';
          final supportsWholesale = businessType != 'retail';
          final wantSingle = hasBoxPricing && supportsRetail;
          final wantCarton = hasBoxPricing && supportsWholesale;

          final modes = List<Mode>.from(itemDocModes[docId] ?? const []);

          void upsertMode(String id, Mode newMode) {
            final index = modes.indexWhere((mode) => mode.id == id);
            if (index == -1) {
              modes.add(newMode);
            } else {
              modes[index] = newMode;
            }
          }

          void removeMode(String id) =>
              modes.removeWhere((mode) => mode.id == id);

          if (wantSingle) {
            upsertMode(
              'single',
              Mode(
                id: 'single',
                name: 'Single',
                qty: '1',
                cp: cost,
                rp: retail,
                wp: boxQtyVal == 1 ? boxPrice : retail,
                sp: boxQtyVal == 1 ? supplierPrice : retail,
              ),
            );
          } else {
            removeMode('single');
          }

          if (wantCarton) {
            upsertMode(
              'carton',
              Mode(
                id: 'carton',
                name: 'Carton',
                qty: boxQty,
                cp: cost,
                rp: boxQtyVal > 1 ? boxPrice : retail,
                wp: boxPrice,
                sp: supplierPrice,
              ),
            );
          } else {
            removeMode('carton');
          }

          if (hasBoxPricing) {
            if (hasHalfPricing) {
              upsertMode(
                'half',
                Mode(
                  id: 'half',
                  name: 'Half Carton',
                  qty: halfQty,
                  cp: cost,
                  rp: halfPrice,
                  wp: halfPrice,
                  sp: halfPrice,
                ),
              );
            } else {
              removeMode('half');
            }

            if (hasQuarterPricing) {
              upsertMode(
                'quarter',
                Mode(
                  id: 'quarter',
                  name: 'Quarter Carton',
                  qty: quarterQty,
                  cp: cost,
                  rp: quarterPrice,
                  wp: quarterPrice,
                  sp: quarterPrice,
                ),
              );
            } else {
              removeMode('quarter');
            }

            if (hasPackPricing) {
              upsertMode(
                'pack',
                Mode(
                  id: 'pack',
                  name: 'Pack',
                  qty: packQty,
                  cp: cost,
                  rp: packPrice,
                  wp: packPrice,
                  sp: packPrice,
                ),
              );
            } else {
              removeMode('pack');
            }
          } else {
            removeMode('half');
            removeMode('quarter');
            removeMode('pack');
          }
          itemDocModes[docId] = modes;

          if (isUpdate) {
            final docRef = db.collection('itemsreg').doc(docId);
            final updateData = <String, dynamic>{
              'name': name,
              'barcode': barcode,
              'cp': cost,
              'producttype': type,
              'pcategory': category,
              'modes': {for (final m in modes) m.id: m.toMap()},
              'sminqty': supplierMinQty,
              'modemore': hasBoxPricing,
              'updatedat': FieldValue.serverTimestamp(),
              'updatedby': datafeed.staff,
            };
            batch.update(docRef, updateData);
            batchRowIndices.add(i);
            pendingInBatch++;
            itemsUpdated++;
          } else {
            final item = ItemModel(
              id: docId,
              name: name,
              barcode: barcode,
              cp: cost,
              retailmarkup: '',
              wholesalemarkup: '',
              retailprice: '',
              wholesaleprice: '',
              producttype: type,
              pricingmode: false,
              pcategory: category,
              warehouse: '',
              openingstock: '',
              company: datafeed.company,
              companyid: companyId,
              imageurl: '',
              modes: modes,
              createdat: DateTime.now(),
              updatedby: null,
              updatedat: null,
              wminqty: '',
              sminqty: supplierMinQty,
              staff: datafeed.staff,
              modemore: hasBoxPricing,
              deletedat: null,
              deletedby: null,
            );

            final docRef = db.collection('itemsreg').doc(docId);
            batch.set(docRef, item.toMap()..['createdat'] = FieldValue.serverTimestamp());
            batchRowIndices.add(i);
            pendingInBatch++;
            itemsCreated++;
          }

          processedItemIds.add(docId);

          if (pendingInBatch >= _writeBatchSize) {
            await flushBatch();
          }
        } catch (e) {
          rowStatus[i] = 'error: $e';
        }

        if ((i % _uiUpdateInterval == 0 || i == pendingIndices.last) && mounted) {
          setState(() {});
        }
      }

      await flushBatch();

      if (categoriesCreated > 0) {
        try {
          await datafeed.fetchproductcategory();
        } catch (_) {}
      }

      setState(() {
        loading = false;
      });

      if (mounted) {
        if (_cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload cancelled: $successCount succeeded, $pendingCount left pending.'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        } else {
          final parts = <String>[];
          if (itemsCreated > 0) parts.add('$itemsCreated new item${itemsCreated == 1 ? '' : 's'} added');
          if (itemsUpdated > 0) parts.add('$itemsUpdated existing item${itemsUpdated == 1 ? '' : 's'} updated');
          if (categoriesCreated > 0) parts.add('$categoriesCreated new categor${categoriesCreated == 1 ? 'y' : 'ies'} registered');
          if (parts.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(parts.join(' • ')),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
        }
      }
    } finally {
      _uploadInFlight = false;
    }
  }
  int get successCount => rowStatus.where((s) => s == 'success').length;
  int get errorCount => rowStatus.where((s) => s.startsWith('error')).length;
  int get pendingCount => rowStatus.where((s) => s == 'pending').length;

  //  PROGRESS %
  double get progress =>  previewData.isEmpty ? 0 : currentIndex / previewData.length;

  //  SAMPLE CSV

  void showSample() async {
    final datafeed = Provider.of<Datafeed>(context, listen: false);
    final sampleUrl = datafeed.sampleUrl;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Sample CSV Format',
          style: TextStyle(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Required Columns:',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'name, barcode, category, type, cost, retail, boxQty, boxPrice, supplierPrice, supplierMinQty, halfQty, halfPrice, quarterQty, quarterPrice, packQty, packPrice',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Example Row:',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Coke 1L,123456,Drinks,product,5,7,12,72,65,2,6,36,3,18,2,14',
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              ///  DOWNLOAD BUTTON

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(dialogContext).colorScheme.secondary,
                      Theme.of(dialogContext).colorScheme.primary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  onPressed: sampleUrl.isEmpty
                      ? null
                      : () async {
                    final uri = Uri.parse(sampleUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not open download link.'),
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
                  icon: Icon(
                    Icons.download_rounded,
                    color: Theme.of(dialogContext).colorScheme.onPrimary,
                  ),
                  label: Text(
                    "Download Sample CSV",
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.onPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                    foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
                    shadowColor: Theme.of(dialogContext).colorScheme.primary.withValues(alpha: 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
        ],
      ),
    );
  }
  void _showErrorsDialog() {
    if (errorCount == 0) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
          title: Text(
            'Upload Errors',
            style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurface),
          ),
          content: Text(
            'No errors.',
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    // Editable fields: every known column, so whichever one caused a row
    // to fail can be fixed here directly.
    final editHeaders = headers.isNotEmpty
        ? headers
        : (previewData.isNotEmpty ? previewData.first.keys.toList() : <String>[]);

    // Controllers are kept alive for the whole life of this dialog and
    // re-synced (rows added/removed) after every retry, instead of being
    // built once — that's what lets correcting and retrying happen
    // entirely on this page, in a loop, without closing it.
    final controllers = <int, Map<String, TextEditingController>>{};

    List<int> currentErrorIndices() => [
      for (int i = 0; i < rowStatus.length; i++)
        if (rowStatus[i].startsWith('error')) i,
    ];

    void syncControllers(List<int> errorIndices) {
      controllers.removeWhere((rowIndex, fieldMap) {
        final stillErroring = errorIndices.contains(rowIndex);
        if (!stillErroring) {
          for (final c in fieldMap.values) {
            c.dispose();
          }
        }
        return !stillErroring;
      });
      for (final rowIndex in errorIndices) {
        controllers.putIfAbsent(
          rowIndex,
              () => {
            for (final h in editHeaders) h: TextEditingController(text: previewData[rowIndex][h] ?? ''),
          },
        );
      }
    }

    void disposeControllers() {
      for (final fieldMap in controllers.values) {
        for (final c in fieldMap.values) {
          c.dispose();
        }
      }
    }

    syncControllers(currentErrorIndices());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          bool retrying = false;

          Future<void> applyAndRetry() async {
            final errorIndices = currentErrorIndices();
            setState(() {
              for (final rowIndex in errorIndices) {
                final fieldMap = controllers[rowIndex];
                if (fieldMap == null) continue;
                for (final h in editHeaders) {
                  previewData[rowIndex][h] = fieldMap[h]!.text;
                }
                // So the status chip flips from red to pending right away,
                // even before the retry pass actually runs.
                rowStatus[rowIndex] = 'pending';
              }
            });
            setDialogState(() => retrying = true);
            await upload();
            final remaining = currentErrorIndices();
            syncControllers(remaining);
            if (!mounted || !dialogContext.mounted) return;
            setDialogState(() => retrying = false);
            if (remaining.isEmpty) {
              disposeControllers();
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(
                  content: const Text('All corrected rows uploaded successfully.'),
                  backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                ),
              );
            }
          }

          final errorIndices = currentErrorIndices();

          return AlertDialog(
            backgroundColor: Theme.of(dialogContext).colorScheme.surface,
            title: Text('Fix ${errorIndices.length} Row Error${errorIndices.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurface,
                )),
            content: SizedBox(
              width: 640,
              height: 480,
              child: retrying
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(dialogContext).colorScheme.secondary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Retrying corrected rows…',
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                itemCount: errorIndices.length,
                separatorBuilder: (_, _) => Divider(
                  color: Theme.of(dialogContext).colorScheme.outlineVariant,
                  height: 32,
                ),
                itemBuilder: (_, listIndex) {
                  final rowIndex = errorIndices[listIndex];
                  final message = rowStatus[rowIndex].replaceFirst('error: ', '');
                  final fieldMap = controllers[rowIndex]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Row ${rowIndex + 2}',
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: editHeaders.map((h) {
                          return SizedBox(
                            width: 220,
                            child: TextField(
                              controller: fieldMap[h],
                              style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurface, fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                labelText: h,
                                labelStyle: TextStyle(
                                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                filled: true,
                                fillColor: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: retrying
                    ? null
                    : () {
                  disposeControllers();
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.secondary,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onSecondary,
                ),
                onPressed: retrying ? null : applyAndRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retrying ? 'Retrying…' : 'Apply Corrections & Retry'),
              ),
            ],
          );
        },
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    final datafeed = context.read<Datafeed>();
    Future.microtask(datafeed.getSampleUrl);
  }
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isTablet = MediaQuery.of(context).size.width >= 768 &&
        MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Text(
          'Bulk Item Upload',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        actions: [
          if (!loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                onPressed: showSample,
                tooltip: 'View format help',
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== FILE PICKER SECTION =====
                  _buildFilePickerSection(isMobile),

                  if (previewData.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select a CSV or Excel file to begin',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],

                  const SizedBox(height: 24),
                  // ===== FILE INFO CARD =====
                  _buildFileInfoCard(),
                  const SizedBox(height: 24),

                  // STATUS SUMMARY
                  _buildStatusSummary(),
                  const SizedBox(height: 24),

                  // PROGRESS BAR
                  _buildProgressSection(),
                  const SizedBox(height: 24),

                  // DATA TABLE — hidden once an upload is actively running;
                  // only the progress section (success/total + pause) is
                  // shown while `loading` is true. It returns once the run
                  // finishes (success, stopped-while-paused, or cancelled).
                  if (!loading) ...[
                    _buildDataTableSection(isMobile, isTablet),
                    const SizedBox(height: 24),
                  ],

                  // ===== ACTION BUTTONS
                  _buildActionButtons(isMobile),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickerSection(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_open,
                color: previewData.isNotEmpty
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select File',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supported formats: CSV, XLSX, XLS (Max 1MB)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: loading ? null : pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text(
                'Pick File',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File Details',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fileInfo,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (successCount > 0)
            TextButton(
              onPressed: _forgetPersistedProgress,
              child: Text(
                'Forget saved progress',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary() {
    return Row(
      children: [
        _buildStatusCard('Success', successCount),
        const SizedBox(width: 12),
        _buildStatusCard('Errors', errorCount),
        const SizedBox(width: 12),
        _buildStatusCard('Pending', pendingCount),
      ],
    );
  }

  Widget _buildStatusCard(String label, int count) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = label == 'Errors'
        ? colorScheme.error
        : label == 'Pending'
        ? colorScheme.secondary
        : colorScheme.primary;

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            statusColor.withValues(alpha: 0.06),
            colorScheme.surface,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.45),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                color: statusColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final total = previewData.length;
    final label = _cancelled
        ? 'Cancelling… — $successCount of $total uploaded'
        : _paused
        ? 'Paused — $successCount of $total uploaded${errorCount > 0 ? ', $errorCount error(s)' : ''}'
        : loading
        ? '$successCount of $total uploaded${errorCount > 0 ? ' • $errorCount error(s) so far' : ''}'
        : 'Row $currentIndex of $total';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              loading ? 'Success $successCount / $total' : 'Upload Progress',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              _paused
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        if (loading) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cancelled ? null : _togglePause,
                  icon: Icon(
                    _paused ? Icons.play_arrow : Icons.pause,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  label: Text(
                    _paused ? 'Resume' : 'Pause',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cancelled ? null : _cancelUpload,
                  icon: Icon(
                    Icons.stop,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    _cancelled ? 'Cancelling…' : 'Cancel',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }


  Widget _buildDataTableSection(bool isMobile, bool isTablet) {
    final start = _previewPage * _previewPageSize;
    final end = (start + _previewPageSize).clamp(0, previewData.length);
    final totalPages = (previewData.length / _previewPageSize).ceil().clamp(1, 999999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateColor.resolveWith(
                    (_) => Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  headingRowHeight: 56,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 48,
                  headingTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  columns: [
                    const DataColumn(label: SizedBox(width: 80, child: Text('#'))),
                    ...headers.take(isMobile ? 3 : isTablet ? 6 : 10).map(
                          (h) => DataColumn(
                        label: SizedBox(width: 100, child: Text(h, overflow: TextOverflow.ellipsis)),
                      ),
                    ),
                    const DataColumn(label: SizedBox(width: 80, child: Text('Status'))),
                  ],
                  rows: List.generate(end - start, (offset) {
                    final index = start + offset;
                    final row = previewData[index];
                    final status = rowStatus[index];

                    final isError = status.startsWith('error');

                    return DataRow(
                      color: WidgetStateColor.resolveWith(
                        (_) => isError
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.surface,
                      ),
                      cells: [
                        DataCell(
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...headers.take(isMobile ? 3 : isTablet ? 6 : 10).map(
                              (h) => DataCell(
                            Text(
                              (row[h] ?? '').length > 20 ? (row[h] ?? '').substring(0, 20) : (row[h] ?? ''),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Tooltip(
                            message: status,
                            child: Wrap(
                              children: [
                                if (status == 'success')
                                  Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 16,
                                  )
                                else if (status.startsWith('error'))
                                  Icon(
                                    Icons.error,
                                    color: Theme.of(context).colorScheme.error,
                                    size: 16,
                                  )
                                else if (status == 'processing')
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.schedule,
                                      color: Theme.of(context).colorScheme.secondary,
                                      size: 16,
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        if (previewData.length > _previewPageSize)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${start + 1}-$end of ${previewData.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _previewPage > 0 ? () => setState(() => _previewPage--) : null,
                      icon: Icon(
                        Icons.chevron_left,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Page ${_previewPage + 1} of $totalPages',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                    IconButton(
                      onPressed: end < previewData.length ? () => setState(() => _previewPage++) : null,
                      icon: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
  Widget _buildActionButtons(bool isMobile) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        if (previewData.isNotEmpty && !loading)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              setState(() {
                previewData.clear();
                headers.clear();
                rowStatus.clear();
                fileInfo = '';
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
        if (errorCount > 0)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _showErrorsDialog,
            icon: const Icon(Icons.error_outline),
            label: Text('View Errors ($errorCount)'),
          ),
        SizedBox(
          width: isMobile ? double.infinity : null,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: loading
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.secondary,
              foregroundColor: loading
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: 12,
              ),
            ),
            onPressed: (loading || previewData.isEmpty) ? null : upload,
            icon: loading
                ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            )
                : const Icon(Icons.cloud_upload),
            label: Text(
              loading ? 'Uploading...' : 'Start Upload',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

}
