import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class OfflineSalesQueue {
  static const _boxName = 'offlineSalesQueue';
  static const _timestampSecondsKey = '__offlineTimestampSeconds';
  static const _timestampNanosecondsKey = '__offlineTimestampNanoseconds';

  Future<Box<String>>? _boxFuture;
  final Set<String> _syncingCompanies = {};

  Future<Box<String>> _openBox() {
    return _boxFuture ??= Hive.openBox<String>(_boxName);
  }

  Future<void> saveLocally({
    required String companyId,
    required String saleId,
    required Map<String, dynamic> saleData,
    List<String> momoTransactionIds = const [],
  }) async {
    final box = await _openBox();
    final record = <String, dynamic>{
      'companyId': companyId,
      'saleData': _encodeValue(saleData),
      'momoTransactionIds': momoTransactionIds,
    };
    await box.put(saleId, jsonEncode(record));
    unawaited(_syncSafely(FirebaseFirestore.instance, companyId));
  }

  Future<void> _syncSafely(
    FirebaseFirestore firestore,
    String companyId,
  ) async {
    try {
      await syncPendingSales(firestore, companyId);
    } catch (error, stackTrace) {
      debugPrint('Could not start offline sale sync: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> syncPendingSales(
    FirebaseFirestore firestore,
    String companyId,
  ) async {
    if (companyId.isEmpty || !_syncingCompanies.add(companyId)) return;

    try {
      final box = await _openBox();
      for (final saleId in box.keys.toList()) {
        final encodedRecord = box.get(saleId);
        if (encodedRecord == null) continue;

        try {
          final record = Map<String, dynamic>.from(
            jsonDecode(encodedRecord) as Map,
          );
          if (record['companyId'] != companyId) continue;

          final saleData = _decodeValue(record['saleData']);
          if (saleData is! Map<String, dynamic>) {
            throw const FormatException('Queued sale data is not a map.');
          }

          await firestore
              .collection('sales')
              .doc(saleId)
              .set(saleData, SetOptions(merge: true));
          await _syncMomoTransactions(
            firestore,
            record['momoTransactionIds'] as List<dynamic>? ?? const [],
            saleId,
            companyId,
          );
          await box.delete(saleId);
          debugPrint('Offline sale $saleId synced successfully.');
        } catch (error, stackTrace) {
          debugPrint('Could not sync offline sale $saleId: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    } finally {
      _syncingCompanies.remove(companyId);
    }
  }

  Future<void> _syncMomoTransactions(
    FirebaseFirestore firestore,
    List<dynamic> transactionIds,
    String saleId,
    String companyId,
  ) async {
    for (final transactionId in transactionIds) {
      final query = await firestore
          .collection('momo')
          .where('transactionId', isEqualTo: transactionId)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        throw StateError('MOMO transaction $transactionId was not found.');
      }
      await query.docs.first.reference.update({
        'status': 'saved',
        'salesid': saleId,
        'companyid': companyId,
        'updatedAt': Timestamp.now(),
      });
    }
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {
        _timestampSecondsKey: value.seconds,
        _timestampNanosecondsKey: value.nanoseconds,
      };
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _encodeValue(nestedValue)),
      );
    }
    if (value is Iterable) {
      return value.map(_encodeValue).toList();
    }
    return value;
  }

  dynamic _decodeValue(dynamic value) {
    if (value is Map) {
      if (value.length == 2 &&
          value.containsKey(_timestampSecondsKey) &&
          value.containsKey(_timestampNanosecondsKey)) {
        return Timestamp(
          value[_timestampSecondsKey] as int,
          value[_timestampNanosecondsKey] as int,
        );
      }
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _decodeValue(nestedValue)),
      );
    }
    if (value is List) {
      return value.map(_decodeValue).toList();
    }
    return value;
  }
}
