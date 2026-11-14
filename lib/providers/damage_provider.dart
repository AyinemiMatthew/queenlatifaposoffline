import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:kologsoft/models/itemregmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import '../models/ReasonsModel.dart';
import '../models/damageitem.dart';
import '../models/itemmodel.dart';

class DamageProvider extends ChangeNotifier {
  DamageProvider(this.datafeed);

  final Datafeed datafeed;
  FirebaseFirestore get db => datafeed.db;

  List<damageitemmodel> damages = [];
  bool isLoading = false;

  List<Map<String, dynamic>> items = [];
  List<Mode>? itemModes;
  List<String> modeNames = [];
  ItemModel? selectedItem;
  String? selectedMode;
  String? selectedReason;
  String branchId = '';
  String branchName = '';
  double cartonsLeft = 0.0;
  double singleLeft = 0.0;
  int? editingIndex;
  bool isSaving = false;
  damageitemmodel? editing;

  double get grandTotal =>
      items.fold(0.0, (sum, item) => sum + _lineTotal(item));
  String get grandTotalText => grandTotal.toStringAsFixed(2);

  double _num(dynamic value, [double fallback = 0]) =>
      double.tryParse(value?.toString() ?? '') ?? fallback;

  double _lineTotal(Map<String, dynamic> item) =>
      _num(item['cp']) * _num(item['quantity']) * _num(item['modeqty'], 1);

  Mode _emptyMode() =>
      Mode(id: '', name: '', qty: '', cp: '', rp: '', wp: '', sp: '');

  Mode? _findMode(List<Mode>? modes, String name) {
    if (modes == null) return null;
    for (final mode in modes) {
      if (mode.name.toLowerCase() == name.toLowerCase()) return mode;
    }
    return null;
  }

  void prepare({damageitemmodel? damageToEdit}) {
    editing = damageToEdit;
    branchId = damageToEdit?.branchid ?? datafeed.branchid;
    branchName = damageToEdit?.branchname ?? datafeed.branch;
    items = [];
    itemModes = null;
    modeNames = [];
    selectedItem = null;
    selectedMode = null;
    selectedReason = null;
    cartonsLeft = 0.0;
    singleLeft = 0.0;
    editingIndex = null;
    isSaving = false;

    if (damageToEdit != null) {
      final itemMap = Map<String, dynamic>.from(damageToEdit.item);
      final keys = itemMap.keys.toList()..sort();
      items = keys
          .map((key) => Map<String, dynamic>.from(itemMap[key]))
          .toList();
    }
  }

  void changeBranch(String id, String name) {
    branchId = id;
    branchName = name;
    notifyListeners();
  }

  void selectReason(String? reason) {
    selectedReason = reason;
    notifyListeners();
  }

  Future<String> createReason(String name) async {
    final normalizedName = name.trim();
    final existing = datafeed.returnitemreasons.where(
      (reason) => reason.name.toLowerCase() == normalizedName.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first.name;

    final id = datafeed.normalizeAndSanitize(
      '${datafeed.companyid}$normalizedName',
    );
    final reason = ReasonsModel(
      name: normalizedName,
      staff: datafeed.staff,
      id: id,
      date: DateTime.now(),
      companyid: datafeed.companyid,
      company: datafeed.company,
    );

    await db.collection('return_reasons').doc(id).set(reason.toMap());
    datafeed.returnitemreasons.add(reason);
    datafeed.notifyListeners();
    return normalizedName;
  }

  void selectMode(String? mode) {
    selectedMode = mode;
    notifyListeners();
  }

  List<Mode>? _effectivePricing(ItemModel item) {
    final branchPrices = item.branchprices;
    if (branchPrices == null || !branchPrices.containsKey(branchId)) {
      return item.modes;
    }
    final raw = branchPrices[branchId]['pricing'];
    if (raw is List) {
      return raw.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return Mode.fromMap(map['id']?.toString() ?? '', map);
      }).toList();
    }
    if (raw is Map) {
      return raw.entries.map((entry) {
        final map = Map<String, dynamic>.from(entry.value as Map);
        return Mode.fromMap(entry.key.toString(), map);
      }).toList();
    }
    return item.modes;
  }

  void selectItem(ItemModel? item) {
    if (item == null) return;

    final branchBalance =
        item.branchbalance?[branchId] as Map<String, dynamic>? ?? {};
    final netPieces = (branchBalance['netpieces'] as num?)?.toDouble() ?? 0.0;
    final boxQty = _num(_findMode(item.modes, 'carton')?.qty, 1);
    final singleQty = _num(_findMode(item.modes, 'single')?.qty, 1);

    selectedItem = item;
    cartonsLeft = boxQty > 0 ? netPieces / boxQty : 0.0;
    singleLeft = singleQty > 0 ? netPieces / singleQty : 0.0;
    itemModes = _effectivePricing(item);

    if (itemModes != null && itemModes!.isNotEmpty) {
      modeNames = itemModes!
          .map((e) => e.name.isNotEmpty ? e.name : e.id)
          .toList();
      modeNames.sort((a, b) {
        if (a.toLowerCase() == 'single') return -1;
        if (b.toLowerCase() == 'single') return 1;
        return 0;
      });
      selectedMode = modeNames.first;
    } else {
      modeNames = ['Single'];
      selectedMode = 'Single';
    }
    notifyListeners();
  }

  String? addLine({
    required String barcode,
    required String itemName,
    required String costPrice,
    required String quantity,
  }) {
    final qty = _num(quantity);
    final cp = _num(costPrice);

    if (cartonsLeft <= 0) return 'No stock available for this item';
    if (selectedMode?.toLowerCase() == 'single') {
      if (qty > singleLeft) return 'Quantity exceeds available single stock';
    } else if (qty > cartonsLeft) {
      return 'Quantity exceeds available carton stock';
    }

    final mode = selectedMode == null
        ? null
        : _findMode(itemModes, selectedMode!) ?? _emptyMode();
    final modeQty = _num(mode?.qty, 1);
    final totalPieces = qty * modeQty;
    final now = DateTime.now();
    final weekNumber =
        ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;
    final carton = _findMode(itemModes, 'carton');

    final line = {
      'itemid': selectedItem?.id ?? '',
      'barcode': barcode,
      'cp': costPrice,
      'reason': selectedReason ?? '',
      'branchid': branchId,
      'branchname': branchName,
      'modeqty': mode?.qty ?? '1',
      'item': itemName,
      'mode': selectedMode ?? 'single',
      'quantity': quantity,
      'totalpieces': totalPieces,
      'supplier': datafeed.selectedSupplier?.supplier ?? '',
      'grandtotal': (cp * totalPieces).toStringAsFixed(2),
      'dateymd': DateFormat('yyyy-MM-dd').format(now),
      'day': DateFormat('EEEE').format(now),
      'week': '${now.year}.$weekNumber',
      'month': '${now.year}.${now.month}',
      'year': now.year.toString(),
      'boxpiece': carton?.qty ?? '1',
      'modes': itemModes != null
          ? {
        for (final m in itemModes!)
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

    if (editingIndex != null) {
      items[editingIndex!] = line;
      editingIndex = null;
    } else {
      items.add(line);
    }
    notifyListeners();
    return null;
  }

  void removeLine(int index) {
    items.removeAt(index);
    notifyListeners();
  }

  Map<String, dynamic> startEdit(int index) {
    final line = items[index];
    final itemId = line['itemid']?.toString() ?? '';
    if (itemId.isNotEmpty) {
      final found = datafeed.items.firstWhere(
            (i) => i.id == itemId,
        orElse: () => ItemModel.fromMap({'id': itemId}),
      );
      selectItem(found);
    }
    editingIndex = index;
    selectedMode = line['mode']?.toString() ?? '';
    selectedReason = line['reason']?.toString();
    notifyListeners();
    return line;
  }

  void resetSelection() {
    selectedItem = null;
    selectedMode = null;
    itemModes = null;
    modeNames = [];
    selectedReason = null;
    notifyListeners();
  }

  Future<({bool wasOffline, bool isEditing})?> save({
    required String saleDate,
    required void Function(Object error) onSyncError,
  }) async {
    if (items.isEmpty || isSaving) return null;
    isSaving = true;
    notifyListeners();

    try {
      final isEditing = editing != null;
      final staffPosition = datafeed.staffPosition;
      final String docId;
      final String trxId;

      if (isEditing) {
        docId = editing!.id;
        trxId = editing!.trxid!;
      } else {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final clean = RegExp(r'[^a-z0-9_]');
        docId = '${branchId}_${staffPosition}_$timestamp'
            .toLowerCase()
            .replaceAll(clean, '');
        trxId = '${staffPosition}_$timestamp'.toLowerCase().replaceAll(
          clean,
          '',
        );
      }

      final itemsMap = <String, dynamic>{
        for (int i = 0; i < items.length; i++) 'item_$i': {...items[i]},
      };

      final damage = damageitemmodel(
        id: docId,
        trxid: trxId,
        itemcount: items.length.toString(),
        item: itemsMap,
        branchid: branchId,
        branchname: branchName,
        description: '',
        createdby: isEditing ? editing!.createdby : datafeed.staff,
        createdat: isEditing ? editing!.createdat : DateTime.now(),
        staffposition: staffPosition.toString(),
        companyid: datafeed.companyid,
        company: datafeed.company,
        dateymd: saleDate,
        grandtotal: grandTotalText,
      );

      final saveFuture = db
          .collection('damageitems')
          .doc(docId)
          .set(damage.tomap(), SetOptions(merge: true));

      final wasOffline = datafeed.isOffline;
      damageitemmodel? previous;
      for (final existing in damages) {
        if (existing.id == docId) {
          previous = existing;
          break;
        }
      }

      addPendingDamage(damage);
      _finishSync(saveFuture, docId, previous, onSyncError);

      items = [];
      return (wasOffline: wasOffline, isEditing: isEditing);
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _finishSync(
      Future<void> saveFuture,
      String docId,
      damageitemmodel? previous,
      void Function(Object error) onSyncError,
      ) async {
    try {
      await saveFuture;
      markDamageSynced(docId);
    } catch (error) {
      restoreDamageAfterFailedOfflineSave(docId, previous);
      onSyncError(error);
    }
  }

  Future<void> fetchDamages({
    DateTimeRange? selectedDate,
    String? selectedBranch,
  }) async {
    isLoading = true;
    final locallyPending = damages
        .where(
          (damage) =>
      damage.pendingSync && damage.companyid == datafeed.companyid,
    )
        .toList();
    damages = locallyPending;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startDate = selectedDate?.start ?? now;
      final endDate = selectedDate?.end ?? now;

      String ymd(DateTime dt) =>
          '${dt.year.toString().padLeft(4, '0')}-'
              '${dt.month.toString().padLeft(2, '0')}-'
              '${dt.day.toString().padLeft(2, '0')}';

      final snap = await db
          .collection('damageitems')
          .where('companyid', isEqualTo: datafeed.companyid)
          .where('dateymd', isGreaterThanOrEqualTo: ymd(startDate))
          .where('dateymd', isLessThanOrEqualTo: ymd(endDate))
          .orderBy('dateymd', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      final wanted = (selectedBranch ?? '').trim().toLowerCase();

      bool matchesBranch(Map<String, dynamic> d) {
        if (wanted.isEmpty) return true;

        final root = (d['branchid'] ?? d['branchId'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (root.isNotEmpty) return root == wanted;

        final lines = d['item'];
        if (lines is Map) {
          return lines.values.any(
                (v) =>
            v is Map &&
                (v['branchid'] ?? v['branchId'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase() ==
                    wanted,
          );
        }
        return false;
      }

      final fetched = snap.docs
          .where((doc) => matchesBranch(doc.data()))
          .map(
            (doc) => damageitemmodel
            .fromfirestore(doc.data(), doc.id)
            .copyWith(pendingSync: doc.metadata.hasPendingWrites),
      )
          .toList();
      final fetchedIds = fetched.map((damage) => damage.id).toSet();
      damages = [
        ...fetched,
        ...locallyPending.where((damage) => !fetchedIds.contains(damage.id)),
      ];
    } catch (e) {
      debugPrint('Error fetching damages: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void addPendingDamage(damageitemmodel damage) {
    damages.removeWhere((existing) => existing.id == damage.id);
    damages.insert(0, damage.copyWith(pendingSync: true));
    notifyListeners();
  }

  void markDamageSynced(String id) {
    final index = damages.indexWhere((damage) => damage.id == id);
    if (index == -1) return;
    damages[index] = damages[index].copyWith(pendingSync: false);
    notifyListeners();
  }

  void restoreDamageAfterFailedOfflineSave(
      String id,
      damageitemmodel? previousDamage,
      ) {
    damages.removeWhere((damage) => damage.id == id);
    if (previousDamage != null) {
      damages.insert(0, previousDamage.copyWith(pendingSync: false));
    }
    notifyListeners();
  }

  Future<void> deleteDamage(String id) async {
    try {
      final damageRef = db.collection('damageitems').doc(id);
      final damageDoc = await damageRef.get();
      final formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
      if (damageDoc.exists) {
        await db.collection('deletedcollection').doc(id).set({
          ...damageDoc.data() as Map<String, dynamic>,
          'deleted_at': FieldValue.serverTimestamp(),
          'deleted_by': datafeed.staff,
          'deleted_email': datafeed.staffemail,
          'type': 'damages',
          'originalCollection': 'damages',
          'originalId': id,
          'datedmy': formattedDate,
        });
      }

      await damageRef.delete();
      damages.removeWhere((d) => d.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting damage item: $e');
      rethrow;
    }
  }

  void clear() {
    damages = [];
    items = [];
    notifyListeners();
  }
}