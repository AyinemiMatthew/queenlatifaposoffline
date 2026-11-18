import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'Datafeed.dart';

enum SyncLevel { success, warning, error }

class SyncOutcome {
  final String message;
  final SyncLevel level;
  final bool showErrors;

  const SyncOutcome(this.message, this.level, {this.showErrors = false});
}

class StockSyncProvider extends ChangeNotifier {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  static const String _itemsCollection = 'itemsreg';
  static const int _apiPageSize = 500;
  static const int _maxRetries = 3;

  bool _disposed = false;

  bool syncing = false;

  int currentPage = 0;
  int totalPages = 0;
  int totalItemsReported = 0;

  int rowsProcessed = 0;
  int itemsCreated = 0;
  int itemsUpdated = 0;
  int rowsSkipped = 0;

  final List<String> _errors = [];
  List<String> get errors => List.unmodifiable(_errors);

  String fileInfo = 'Ready to load stock data from API.';

  double get progress =>
      totalPages == 0 ? 0 : (currentPage / totalPages).clamp(0.0, 1.0);

  bool get hasRun => rowsProcessed > 0 || syncing;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------

  String sanitize(String input) => input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  /// Handles 160, 160.0, "160.0" and viewer artifacts like "160.0JS:160".
  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final cleaned = v.toString().replaceAll(RegExp(r'JS:.*$'), '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  String _str(dynamic v) => (v ?? '').toString().trim();

  String _branchSlug(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  String _branchKey(String companyId, String branchName) =>
      '${companyId.toLowerCase()}${_branchSlug(branchName)}';

  Map<String, dynamic> _branchEntry({
    required String branchName,
    required dynamic balance,
    required double cost,
    required String staff,
  }) {
    final qty = _num(balance);
    return {
      'name': branchName,
      'quantity': qty,
      'netpieces': qty,
      'stockin_pieces': qty,
      'stock_value': qty * cost,
      'lastupdate': FieldValue.serverTimestamp(),
      'updatedby': staff,
    };
  }

  Timestamp _parseCreated(dynamic date, dynamic time) {
    final d = _str(date);
    final t = _str(time);
    final parsed = DateTime.tryParse(t.isEmpty ? d : '$d $t');
    return Timestamp.fromDate(parsed ?? DateTime.now());
  }

  String _weekOf(DateTime dt) {
    final start = DateTime(dt.year, 1, 1);
    return (((dt.difference(start).inDays + start.weekday - 1) ~/ 7) + 1)
        .toString();
  }

  // ---------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _fetchPage(int page) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'fetchStockPage',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        );
        final result =
        await callable.call({'page': page, 'limit': _apiPageSize});
        final decoded = Map<String, dynamic>.from(result.data as Map);
        if (decoded['success'] == false) {
          throw decoded['message']?.toString() ?? 'API reported failure.';
        }
        print('Fetched page $page successfully.');
        return decoded;
      } catch (e) {
        lastError = e;
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    throw 'Page $page failed after $_maxRetries attempts: $lastError';
  }

  Future<void> _acknowledgeApiStockIds(List<String> ids) async {
    final recordIds = ids.where((id) => id.trim().isNotEmpty).toList();
    if (recordIds.isEmpty) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'ackItems',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final result = await callable.call({'ids': recordIds});
      final data = Map<String, dynamic>.from(result.data as Map);

      final updated = (data['updated'] as num?)?.toInt() ?? 0;
      debugPrint('CALLBACK: updated $updated of ${recordIds.length} ids');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('CALLBACK ERROR: ${e.code} ${e.message}');
      throw 'Acknowledgment failed: ${e.message}';
    }
  }


  /// Returns null if a sync is already running.
  Future<SyncOutcome?> syncStockFromApi(Datafeed datafeed) async {
    if (syncing) return null;

    await datafeed.getdata();

    final companyId = datafeed.companyid.trim();
    final companyName = datafeed.company;

    if (companyId.isEmpty) {
      return const SyncOutcome(
        'No company context found. Please log in again.',
        SyncLevel.error,
      );
    }

    syncing = true;
    currentPage = 0;
    totalPages = 0;
    totalItemsReported = 0;
    rowsProcessed = 0;
    itemsCreated = 0;
    itemsUpdated = 0;
    rowsSkipped = 0;
    _errors.clear();
    fileInfo = 'Loading stock data from API...';
    notifyListeners();

    try {
      var page = 1;

      var savedCount = 0;
      var acknowledgedCount = 0;
      while (true) {
        final body = await _fetchPage(page);

        totalPages = (body['total_pages'] as num?)?.toInt() ?? page;

        totalItemsReported = (body['total_items'] as num?)?.toInt() ?? 0;

        final rawRows = body['data'];

        if (rawRows is! List || rawRows.isEmpty) break;

        currentPage = page;
        fileInfo = 'Processing page $page of $totalPages...';
        notifyListeners();

        // Filter records with a positive balance.
        final validRows = rawRows
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .where((row) {
          final balanceData = row['balance'];

          if (balanceData is! Map) return false;

          return balanceData.values.any((value) {
            final amount = value is num
                ? value.toDouble()
                : double.tryParse(value?.toString() ?? '') ?? 0.0;

            return amount > 0;
          });
        }).toList();

        if (validRows.isNotEmpty) {
          List<String> savedIds = [];

          try {
            savedIds = await _savePage(
              rows: validRows,
              datafeed: datafeed,
              companyId: companyId,
              companyName: companyName,
            );

            savedCount += validRows.length;
          } catch (e) {
            _errors.add('Page $page: $e');
          }

          // Acknowledge only what was saved. A failure here is reported
          // separately so a saved page isn't shown as failed.
          if (savedIds.isNotEmpty) {
            try {
              await _acknowledgeApiStockIds(savedIds);
              acknowledgedCount += savedIds.length;
            } catch (e) {
              _errors.add('Page $page acknowledgment: $e');
            }
          }
        }
        rowsProcessed += rawRows.length;

        notifyListeners();

        if (page >= totalPages) break;
        page++;
      }

      fileInfo = 'Done. $itemsCreated created, $itemsUpdated updated, '
          '$rowsSkipped skipped,$acknowledgedCount acknowledged, ${_errors.length} page error(s).';
      notifyListeners();

      return SyncOutcome(
        _errors.isEmpty
            ? 'Synced ${itemsCreated + itemsUpdated} items to $_itemsCollection.'
            : 'Synced with ${_errors.length} error(s).',
        _errors.isEmpty ? SyncLevel.success : SyncLevel.warning,
        showErrors: _errors.isNotEmpty,
      );
    } catch (error) {
      fileInfo = 'API sync failed.';
      print('Stock API sync failed: $error');
      return SyncOutcome('Stock API sync failed: $error', SyncLevel.error);
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<List<String>> _savePage({
    required List<Map<String, dynamic>> rows,
    required Datafeed datafeed,
    required String companyId,
    required String companyName,
  }) async {
    final Map<String, Map<String, dynamic>> docs = {};

    for (final row in rows) {
      final name = _str(row['name']);
      if (name.isEmpty) {
        rowsSkipped++;
        continue;
      }

      final rowCompany = datafeed.companyid.trim();
      if (rowCompany.isNotEmpty &&
          rowCompany.toLowerCase() != companyId.toLowerCase()) {
        rowsSkipped++;
        continue;
      }

      final itemId = _str(row['id']);
      var barcode = _str(row['barcode']);
      if (barcode.toLowerCase() == name.toLowerCase()) {
        barcode = name.toLowerCase();
      }

      // ---- modes ----
      final modes = <String, dynamic>{};
      final boxPieces = _num(row['boxpieces']);
      final rawModes = row['modes'];
      if (rawModes is List) {
        for (final m in rawModes.whereType<Map>()) {
          final modeName = _str(m['mode']);
          if (modeName.isEmpty) continue;
          modes[modeName] = {
            'id': modeName,
            'name': modeName,
            'qty': _num(m['quantity']),
            'sp': _num(m['sprice']),
            'wp': _num(m['wprice']),
            'rp': _num(m['price']),
            'cp': _num(m['cprice']),
            'barcode': barcode,
          };
        }
      }
      final hasSingle =
      modes.keys.any((k) => k.trim().toLowerCase() == 'single');

      if (!hasSingle) {
        final retail = _num(row['selling_price']);
        final wholesale = _num(row['wselling_price']);

        modes['Single'] = {
          'id': 'Single',
          'name': 'Single',
          'qty': 1,
          'sp': retail,
          'wp': retail,
          'rp': retail,
          'cp': _num(row['cost_price']),
          'barcode': barcode,
        };
      }
      final staffName = datafeed.staff;
      final cost = _num(row['cost_price']);
      final branchbalance = <String, dynamic>{};

      void addBranch(String branchName, dynamic bal) {
        final bn = branchName.trim();
        if (bn.isEmpty) return;
        branchbalance[_branchKey(companyId, bn)] = _branchEntry(
          branchName: bn,
          balance: bal,
          cost: cost,
          staff: staffName,
        );
      }

      final balanceField = row['balance'];

      if (balanceField is Map) {
        balanceField.forEach((branchName, bal) {
          addBranch(_str(branchName), bal);
        });
      } else {
        final ownBranch = _str(row['branch']);
        if (ownBranch.isNotEmpty) addBranch(ownBranch, balanceField);
      }

      final created = _parseCreated(row['date'], row['time']);
      final createdDt = created.toDate();

      final data = <String, dynamic>{
        'id': _str(row['id']),
        'name': name,
        'company': companyName,
        'companyid': companyId,
        'barcode': barcode,
        'pcategory': _str(row['category']),
        'producttype': _str(row['product_type']).isEmpty
            ? 'product'
            : _str(row['product_type']),
        'imageurl': _str(row['image']),
        'cp': _num(row['cost_price']),
        'retailprice': _num(row['selling_price']),
        'wholesaleprice': _num(row['wselling_price']),
        'retailmarkup': _str(row['rmarkup']),
        'wholesalemarkup': _str(row['wmarkup']),
        'sminqty': _str(row['sqty']),
        'wminqty': _str(row['wsaleqty']),
        'warehouse': _str(row['warehouse']),
        'staff': _str(row['staff']),
        'branchbalance': branchbalance,
        'modes': modes,
        'modemore': modes.length > 1 || boxPieces > 1,
        'day': createdDt.day.toString(),
        'week': _weekOf(createdDt),
        'month': createdDt.month.toString(),
        'year': createdDt.year.toString(),
        '_createdFromSource': created,
      };

      final existing = docs[itemId];
      if (existing == null) {
        docs[itemId] = data;
      } else {
        (existing['branchbalance'] as Map<String, dynamic>)
            .addAll(branchbalance);
        (existing['modes'] as Map<String, dynamic>).addAll(modes);
        if ((existing['barcode'] as String).isEmpty && barcode.isNotEmpty) {
          existing['barcode'] = barcode;
        }
      }
    }

    //if (docs.isEmpty) return;

    final col = db.collection(_itemsCollection);
    final snaps = await Future.wait(docs.keys.map((id) => col.doc(id).get()));
    final existingIds = {
      for (final s in snaps)
        if (s.exists) s.id,
    };

    final batch = db.batch();
    final staffName = datafeed.staff;

    docs.forEach((id, data) {
      final isNew = !existingIds.contains(id);
      final sourceCreated = data.remove('_createdFromSource');

      final payload = <String, dynamic>{
        ...data,
        'updatedat': FieldValue.serverTimestamp(),
        'updatedby': staffName,
        'lastModified': FieldValue.serverTimestamp(),
        if (isNew) ...{
          'createdat': sourceCreated,
          'isActive': true,
          'isHamper': false,
        },
      };

      batch.set(col.doc(id), payload, SetOptions(merge: true));
      isNew ? itemsCreated++ : itemsUpdated++;
      print(payload);
    });

    await batch.commit();
    return docs.keys.toList();
  }
}