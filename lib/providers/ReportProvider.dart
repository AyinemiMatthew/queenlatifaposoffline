import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/branch.dart';
import '../models/itemregmodel.dart';
import 'Datafeed.dart';

class ReportProvider extends ChangeNotifier {
  ReportProvider(this.datafeed) {
    datafeed.addListener(_handleDatafeedChanged);
  }

  final Datafeed datafeed;

  void _handleDatafeedChanged() => notifyListeners();

  @override
  void dispose() {
    datafeed.removeListener(_handleDatafeedChanged);
    super.dispose();
  }

  FirebaseFirestore get db => datafeed.db;
  String get companyid => datafeed.companyid;
  String get company => datafeed.company;
  List<ItemModel> get items => datafeed.items;
  List<BranchModel> get branches => datafeed.branches;
  double get reorderLevel => datafeed.reorderLevel;
  String get branch => datafeed.branch;
  String get branchid => datafeed.branchid;
  String get accesslevel => datafeed.accesslevel;
  bool get canDeleteRecords => datafeed.canDeleteRecords;
  bool get isAdminLevel => datafeed.isAdminLevel;
  bool get isSalesReportBranchRestricted {
    final access = accesslevel.toLowerCase();
    return access == 'salesattendance' || access == 'sales manager';
  }

  bool isWarehouseType(String? type) =>
      (type ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') ==
      'warehouse';
  bool isSalesPointType(String? type) =>
      (type ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') ==
      'salespoint';
  List<BranchModel> get visibleStockReportBranches =>
      branches.where((branch) => !isSalesPointType(branch.branchtype)).toList();

  dynamic get selectedBranch => datafeed.selectedBranch;

  Future<void> fetchBranches() => datafeed.fetchBranches();

  List<Map<String, dynamic>> report = [];
  List<Map<String, dynamic>> stockreport = [];
  bool isloadingsalesreport = false;
  String stockReportSearchQuery = '';
  String searchQuery = '';

  void updateSearch(String value) {
    searchQuery = value;
    notifyListeners();
  }

  void updateStockReportSearch(String value) {
    stockReportSearchQuery = value;
    notifyListeners();
  }

  String _toDateOnly(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  List<Map<String, dynamic>> ledgerreport = [];
  bool isloadingledgerreport = false;
  List<Map<String, dynamic>> ledgerTransactions = [];
  String generalLedgerSearchQuery = '';

  void updateGeneralLedgerSearch(String value) {
    generalLedgerSearchQuery = value;
    notifyListeners();
  }

  Future<void> fetchgeneralledgerreport({ DateTimeRange? selectedDate, String? selectedBranch,}) async {
    try {
      isloadingledgerreport = true;
      notifyListeners();
      ledgerreport.clear();

      final now = DateTime.now();
      final start =   selectedDate?.start ?? DateTime(now.year, now.month, now.day);
      final end = selectedDate?.end ?? DateTime(now.year, now.month, now.day);

      String fmtDate(DateTime d) =>
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      final startStr = fmtDate(start);
      final endStr = fmtDate(end);
      final dayBeforeStartStr = fmtDate(
        start.subtract(const Duration(days: 1)),
      );
      final allBranches =
          selectedBranch == null || selectedBranch.trim().isEmpty;

      Query<Map<String, dynamic>> openingQuery = db
          .collection('ledgers')
          .where('companyId', isEqualTo: companyid)
          .where('date', isLessThanOrEqualTo: dayBeforeStartStr);
      if (!allBranches) {
        openingQuery = openingQuery.where(
          'branchId',
          isEqualTo: selectedBranch.trim(),
        );
      }

      Query<Map<String, dynamic>> periodQuery = db
          .collection('ledgers')
          .where('companyId', isEqualTo: companyid)
          .where('date', isGreaterThanOrEqualTo: startStr)
          .where('date', isLessThanOrEqualTo: endStr);
      if (!allBranches) {
        periodQuery = periodQuery.where(
          'branchId',
          isEqualTo: selectedBranch.trim(),
        );
      }

      final openingSnapshot = await openingQuery.get();
      final periodSnapshot = await periodQuery.get();
      final grouped = <String, Map<String, dynamic>>{};

      void ensureGroup(
        String key,
        String account,
        String branchId,
        String branchName,
      ) {
        grouped.putIfAbsent(
          key,
          () => {
            'account': account,
            'branchId': allBranches ? '' : branchId,
            'branchName': allBranches ? 'ALL BRANCHES' : branchName,
            'openingDebit': 0.0,
            'openingCredit': 0.0,
            'debit': 0.0,
            'credit': 0.0,
          },
        );
      }

      String makeKey(String account, String branchId) =>
          allBranches ? account : '${account}_$branchId';

      for (final doc in openingSnapshot.docs) {
        final data = doc.data();
        final account = (data['account'] ?? '').toString().trim().toLowerCase();
        final branchId = (data['branchId'] ?? '').toString().trim();
        final branchName = (data['branchName'] ?? '').toString();
        final amount = (data['amount'] ?? 0).toDouble();
        final type = (data['type'] ?? '').toString().toLowerCase().trim();
        final key = makeKey(account, branchId);
        ensureGroup(key, account, branchId, branchName);

        if (type == 'debit') {
          grouped[key]!['openingDebit'] =
              (grouped[key]!['openingDebit'] as double) + amount;
        } else if (type == 'credit') {
          grouped[key]!['openingCredit'] =
              (grouped[key]!['openingCredit'] as double) + amount;
        }
      }

      for (final doc in periodSnapshot.docs) {
        final data = doc.data();
        final account = (data['account'] ?? '').toString().trim().toLowerCase();
        final branchId = (data['branchId'] ?? '').toString().trim();
        final branchName = (data['branchName'] ?? '').toString();
        final amount = (data['amount'] ?? 0).toDouble();
        final type = (data['type'] ?? '').toString().toLowerCase().trim();
        final key = makeKey(account, branchId);
        ensureGroup(key, account, branchId, branchName);

        if (type == 'debit') {
          grouped[key]!['debit'] = (grouped[key]!['debit'] as double) + amount;
        } else if (type == 'credit') {
          grouped[key]!['credit'] =
              (grouped[key]!['credit'] as double) + amount;
        }
      }

      var count = 1;
      ledgerreport = grouped.values.map((group) {
        final openingDebit = group['openingDebit'] as double;
        final openingCredit = group['openingCredit'] as double;
        final debit = group['debit'] as double;
        final credit = group['credit'] as double;
        return {
          'number': count++,
          'account': group['account'],
          'branchName': group['branchName'],
          'branchId': group['branchId'],
          'openingBalance': openingDebit - openingCredit,
          'debit': debit,
          'credit': credit,
          'balance': debit - credit,
        };
      }).toList();

      ledgerreport.sort((a, b) {
        final cmp = a['account'].toString().compareTo(b['account'].toString());
        if (cmp != 0) return cmp;
        return a['branchName'].toString().toLowerCase().compareTo(
          b['branchName'].toString().toLowerCase(),
        );
      });
    } catch (e, st) {
      debugPrint("Error fetching General Ledger Report: $e\n$st");
      ledgerreport = [];
    } finally {
      isloadingledgerreport = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> filtergeneralledgerreport() {
    if (generalLedgerSearchQuery.isEmpty) return ledgerreport;
    final query = generalLedgerSearchQuery.toLowerCase();
    return ledgerreport.where((row) {
      return row['account'].toString().toLowerCase().contains(query) ||
          row['number'].toString().contains(query);
    }).toList();
  }

  Future<void> showLedgerDetailsDialog({ required DateTime startDate, required DateTime endDate, required String id, required String name, required String? branchId, }) async {
    final transactions = <Map<String, dynamic>>[];

    String formatDate(DateTime date) =>
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final startStr = formatDate(startDate);
    final endStr = formatDate(endDate);
    final accountId = id.trim().toLowerCase();
    final dayBeforeStartStr = formatDate(
      startDate.subtract(const Duration(days: 1)),
    );

    Query<Map<String, dynamic>> openingQuery = db
        .collection('ledgers')
        .where('companyId', isEqualTo: companyid)
        .where('account', isEqualTo: accountId)
        .where('date', isLessThanOrEqualTo: dayBeforeStartStr);
    if (branchId != null && branchId.trim().isNotEmpty) {
      openingQuery = openingQuery.where('branchId', isEqualTo: branchId.trim());
    }

    final openingSnap = await openingQuery.get();
    var openingDebit = 0.0;
    var openingCredit = 0.0;
    for (final doc in openingSnap.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      final type = (data['type'] ?? '').toString().toLowerCase().trim();
      if (type == 'debit') {
        openingDebit += amount;
      } else if (type == 'credit') {
        openingCredit += amount;
      }
    }

    Query<Map<String, dynamic>> query = db
        .collection('ledgers')
        .where('companyId', isEqualTo: companyid)
        .where('account', isEqualTo: accountId)
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr);
    if (branchId != null && branchId.trim().isNotEmpty) {
      query = query.where('branchId', isEqualTo: branchId.trim());
    }

    final snap = await query.get();
    final openingBalance = (openingDebit - openingCredit).abs();
    var runningBalance = openingBalance;
    transactions.add({
      'number': '',
      'account': name,
      'accountId': accountId,
      'customerName': '',
      'openingBalance': openingBalance,
      'debit': 0.0,
      'credit': 0.0,
      'balance': openingBalance,
      'date': startStr,
      'branch': '',
      'staff': '',
      'transactionId': '',
      'description': 'Opening Balance',
      'type': '',
    });

    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ad = a.data()['date'] ?? '';
        final bd = b.data()['date'] ?? '';
        return ad.compareTo(bd);
      });

    for (final doc in docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      final type = (data['type'] ?? '').toString().toLowerCase().trim();
      var debit = 0.0;
      var credit = 0.0;
      if (type == 'debit') {
        debit = amount;
        runningBalance += amount;
      } else if (type == 'credit') {
        credit = amount;
        runningBalance -= amount;
      }
      transactions.add({
        'number': '',
        'account': data['account'] ?? '',
        'accountId': data['account'] ?? '',
        'customerName': data['customerName'] ?? '',
        'openingBalance': openingBalance,
        'debit': debit,
        'credit': credit,
        'balance': runningBalance,
        'date': data['date'] ?? '',
        'branch': data['branchName'] ?? '',
        'staff': data['createdBy'] ?? '',
        'transactionId': doc.id,
        'description': data['description'] ?? '',
        'type': type,
      });
    }

    ledgerTransactions = transactions;
    notifyListeners();
  }

  List<Map<String, dynamic>> filteredshowLedgerDetailsDialog() {
    final query = generalLedgerSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return ledgerTransactions;
    return ledgerTransactions.where((transaction) {
      return (transaction['customerName'] ?? '')
              .toString()
              .toLowerCase()
              .contains(query) ||
          (transaction['account'] ?? '').toString().toLowerCase().contains(
            query,
          ) ||
          (transaction['date'] ?? '').toString().toLowerCase().contains(
            query,
          ) ||
          (transaction['transactionId'] ?? '')
              .toString()
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  Future<void> showLedgerAccountDetailsDialog({
    required DateTime startDate,
    required DateTime endDate,
    required String itemId,
    required String itemName,
    required String? branchId,
  }) async {
    final transactions = <Map<String, dynamic>>[];
    String format(DateTime date) =>
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final dates = <String>[];
    for (
      DateTime date = startDate;
      !date.isAfter(endDate);
      date = date.add(const Duration(days: 1))
    ) {
      dates.add(format(date));
    }

    final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (var i = 0; i < dates.length; i += 30) {
      final chunk = dates.skip(i).take(30).toList();
      Query<Map<String, dynamic>> query = db
          .collection('ledgers')
          .where('companyId', isEqualTo: companyid)
          .where('date', whereIn: chunk)
          .where('account', isEqualTo: itemId);
      if (branchId != null &&
          branchId.isNotEmpty &&
          branchId.toLowerCase() != 'all') {
        query = query.where('branchId', isEqualTo: branchId.trim());
      }
      final snap = await query.get();
      allDocs.addAll(snap.docs);
    }

    var balance = 0.0;
    for (final doc in allDocs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      final type = (data['type'] ?? '').toString().toLowerCase();
      if (type == 'debit') {
        balance += amount;
      } else if (type == 'credit') {
        balance -= amount;
      }
      transactions.add({
        'number': '',
        'transactionDate': data['date'] ?? '',
        'description': data['description'] ?? '',
        'debit': type == 'debit' ? amount : 0.0,
        'credit': type == 'credit' ? amount : 0.0,
        'balance': balance,
        'accountName': data['account'] ?? itemName,
        'accountId': data['account'] ?? itemId,
        'branchName': data['branchName'] ?? '',
        'branchId': data['branchId'] ?? '',
        'customerName': data['customerName'] ?? '',
        'transactionId': doc.id,
        'createdBy': data['createdBy'] ?? '',
      });
    }

    transactions.sort(
      (a, b) => a['transactionDate'].compareTo(b['transactionDate']),
    );
    ledgerTransactions = transactions;
    notifyListeners();
  }

  List<Map<String, dynamic>> filteredshowLedgerAccountDetailsDialog() {
    final query = generalLedgerSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return ledgerTransactions;
    return ledgerTransactions.where((transaction) {
      return (transaction['description'] ?? '')
              .toString()
              .toLowerCase()
              .contains(query) ||
          (transaction['transactionDate'] ?? '')
              .toString()
              .toLowerCase()
              .contains(query) ||
          (transaction['accountName'] ?? '').toString().toLowerCase().contains(
            query,
          );
    }).toList();
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double toNumber(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0.0;

  Map<String, ItemModel> get _itemById => {for (final i in items) '${i.id}': i};

  List<Map<String, dynamic>> salesItemTransactions = [];
  int _itemSalesTransactionsRequestGeneration = 0;

  Future<void> loadItemSalesTransactions({
    required DateTime startDate,
    required DateTime endDate,
    required String itemId,
    required String itemName,
    required String? branchId,
  }) async {
    final requestGeneration = ++_itemSalesTransactionsRequestGeneration;

    List<String> generateIds(DateTime start, DateTime end) {
      List<String> ids = [];
      for (
        DateTime d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))
      ) {
        final date =
            "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        ids.add(date);
      }
      return ids;
    }

    final ids = generateIds(startDate, endDate);
    final queries = <Query<Map<String, dynamic>>>[];

    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.skip(i).take(30).toList();

      queries.add(
        db
            .collection('sales')
            .where('companyId', isEqualTo: companyid)
            .where('dateymd', whereIn: chunk),
      );
    }

    await datafeed.loadQueriesCacheFirst(
      queries,
      isCurrent: () =>
          requestGeneration == _itemSalesTransactionsRequestGeneration,
      label: 'Sales item transactions',
      apply: (snapshots) {
        final List<Map<String, dynamic>> transactions = [];
        final allDocs = snapshots.expand((snapshot) => snapshot.docs);

        for (final doc in allDocs) {
          final data = doc.data();
          final items = data['items'] as Map<String, dynamic>? ?? {};

          final docTransMode = (data['transMode'] ?? '')
              .toString()
              .toLowerCase()
              .trim();
          final resolvedTransMode = docTransMode.isNotEmpty
              ? docTransMode
              : 'cash';

          // Document-level branch check
          final bool docMatchesBranch =
              branchId == null ||
              branchId.isEmpty ||
              branchId.toLowerCase() == 'all' ||
              data['branchId']?.toString().trim() == branchId.trim();

          items.forEach((key, value) {
            if (value is! Map) return;
            final itemMap = Map<String, dynamic>.from(value);

            // Match by itemid (Firestore ID) OR barcode
            final currentItemId =
                (itemMap['itemid'] ?? itemMap['itemId'] ?? itemMap['id'] ?? '')
                    .toString()
                    .trim();
            final currentBarcode = (itemMap['barcode'] ?? '').toString().trim();
            final producttype = (itemMap['producttype'] ?? '').toString();
            final pcategory = (itemMap['pcategory'] ?? '').toString();
            if (currentItemId != itemId.trim() &&
                currentBarcode != itemId.trim())
              return;

            // Item-level branch check
            final itemBranchId = (itemMap['branchid'] ?? data['branchId'] ?? '')
                .toString()
                .trim();
            final bool itemMatchesBranch =
                branchId == null ||
                branchId.isEmpty ||
                branchId.toLowerCase() == 'all' ||
                itemBranchId == branchId.trim();

            // If filtering by branch, only include if document or item specifically matches
            if (!docMatchesBranch && !itemMatchesBranch) return;

            final qty = double.tryParse(itemMap['quantity'].toString()) ?? 0;
            final price = double.tryParse(itemMap['price'].toString()) ?? 0;
            final profit = double.tryParse(itemMap['profit'].toString()) ?? 0;
            final total =
                double.tryParse(
                  itemMap['totalamount']?.toString() ??
                      itemMap['price']?.toString() ??
                      '0',
                ) ??
                0;
            final cp = double.tryParse(itemMap['cp']?.toString() ?? '0') ?? 0;
            final discount =
                double.tryParse(itemMap['discount']?.toString() ?? '0') ?? 0;

            // Return info
            final returnedQty =
                double.tryParse(
                  itemMap['returned_quantity']?.toString() ?? '0',
                ) ??
                0;
            final returnedProfit =
                double.tryParse(
                  itemMap['returned_profit']?.toString() ?? '0',
                ) ??
                0;
            final returnedDiscount =
                double.tryParse(
                  itemMap['returned_discount']?.toString() ?? '0',
                ) ??
                0;
            final returnedAmount =
                double.tryParse(
                  itemMap['returned_totalamount']?.toString() ?? '0',
                ) ??
                0;
            final returnedGrosstotalamount =
                double.tryParse(
                  itemMap['returned_grosstotalamount']?.toString() ?? '0',
                ) ??
                0;
            final isReturned =
                itemMap['status']?.toString() == 'returned' && returnedQty > 0;
            final returnedTransMode =
                (itemMap['returned_transMode'] ?? resolvedTransMode)
                    .toString()
                    .toLowerCase()
                    .trim();

            transactions.add({
              'date': data['createdAt'],
              'item': itemMap['item'] ?? '',
              'qty': qty,
              'price': price,
              'profit': profit,
              'total': total,
              'cp': cp,
              'discount': discount,
              'transMode': resolvedTransMode,
              'salesMode': itemMap['mode'] ?? '',
              'customer': data['customerName'] ?? '',
              'branch': data['branchName'] ?? '',
              'pricingMode': itemMap['pricemode'] ?? '',
              'staff': data['createdBy'] ?? '',
              'staffEmail': data['staffemail'] ?? '',
              'receipt': data['receiptNumber'] ?? '',
              'paymentStatus': data['paymentStatus'] ?? '',
              'transactionId': data['id'] ?? '',
              'isReturned': false,
              'returnedQty': 0.0,
              'returnedAmount': 0.0,
              'returnedTransMode': '',
              'isCash': resolvedTransMode == 'cash',
              'isCredit': resolvedTransMode == 'credit',
              'isCashReturn': false,
              'isCreditReturn': false,
              'pcategory': pcategory,
              'producttype': producttype,
            });

            if (isReturned) {
              transactions.add({
                'date': data['returned_updatedat'] ?? data['createdAt'],
                'item': itemMap['returned_item'] ?? itemMap['item'] ?? '',
                'qty': returnedQty,
                'price':
                    double.tryParse(
                      itemMap['returned_price']?.toString() ?? '',
                    ) ??
                    price,
                'total': returnedAmount,
                'profit': returnedProfit,
                'returnedGrosstotalamount': returnedGrosstotalamount,
                'discount': returnedDiscount,
                'cp': cp,
                'transMode': returnedTransMode,
                'salesMode': itemMap['returned_mode'] ?? itemMap['mode'] ?? '',
                'customer': data['customerName'] ?? '',
                'branch': data['branchName'] ?? '',
                'pricingMode':
                    itemMap['returned_pricemode'] ?? itemMap['pricemode'] ?? '',
                'staff': data['createdBy'] ?? '',
                'staffEmail': data['staffemail'] ?? '',
                'receipt': data['receiptNumber'] ?? '',
                'paymentStatus': 'returned',
                'transactionId': data['id'] ?? '',
                'isReturned': true,
                'returnedQty': returnedQty,
                'returnedAmount': returnedAmount,
                'returnedTransMode': returnedTransMode,
                'isCash': false,
                'isCredit': false,
                'isCashReturn': returnedTransMode == 'cash',
                'isCreditReturn': returnedTransMode == 'credit',

                'pcategory': pcategory,
                'producttype': producttype,
              });
            }
          });
        }

        salesItemTransactions = transactions;
        notifyListeners();
      },
    );
  }

  List<String> get itemTxnStaff => _distinctTxn('staff');
  List<String> get itemTxnProductTypes => _distinctTxn('producttype');
  List<String> get itemTxnCategories => _distinctTxn('pcategory');

  List<Map<String, dynamic>> filteredItemTransactions({
    String? productType,
    String? category,
    String? staff,
  }) {
    final query = searchQuery.trim().toLowerCase();

    return salesItemTransactions.where((t) {
      if (productType != null &&
          (t['producttype'] ?? '').toString() != productType)
        return false;
      if (category != null && (t['pcategory'] ?? '').toString() != category) {
        return false;
      }
      if (staff != null && (t['staff'] ?? '').toString() != staff) return false;
      if (query.isEmpty) return true;

      return const [
        'item',
        'receipt',
        'customer',
        'staff',
        'branch',
        'transMode',
        'salesMode',
      ].any((k) => (t[k] ?? '').toString().toLowerCase().contains(query));
    }).toList();
  }

  List<String> _distinctTxn(String key) =>
      (salesItemTransactions
            .map((e) => (e[key] ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList())
        ..sort();

  double reportTotalCashSales = 0.0;
  double reportTotalCreditSales = 0.0;
  double reportTotalCashReturns = 0.0;
  double reportTotalCreditReturns = 0.0;
  double reportTotalReturns = 0.0;
  double reportTotalDiscount = 0.0;
  double reportTotalDiscountReturn = 0.0;
  double reportTotalDamage = 0.0;
  double reportTotalPurchaseReturn = 0.0;
  double reportTotalProfit = 0.0;
  double reportTotalProfitReturn = 0.0;
  double reportTotalRowTotal = 0.0;
  double reportDebttotal = 0.0;
  double reportGrandTotal = 0.0;
  double reportCashAtHand = 0.0;

  List<Map<String, dynamic>> branchReport = [];
  List<Map<String, dynamic>> branchReportitem = [];
  final Map<String, List<Map<String, dynamic>>> _salesReportRawCache = {};
  bool salesReportHasVisibleData = false;
  bool salesReportOffline = false;
  int _salesReportRequestGeneration = 0;
  String? salesReportError;
  // branch-level totals
  double branchTotalCashSales = 0;
  double branchTotalCreditSales = 0;
  double branchTotalCashReturns = 0;
  double branchTotalCreditReturns = 0;
  double branchTotalReturns = 0;
  double branchTotalDiscount = 0;
  double branchTotalDiscountReturn = 0;
  double branchTotalDamage = 0;
  double branchTotalPurchaseReturn = 0;
  double branchTotalProfit = 0;
  double branchTotalProfitReturn = 0;
  double branchTotalRowTotal = 0;
  double branchGrandTotal = 0;
  double branchCashAtHand = 0;
  double branchreportDebttotal = 0;

  Future<void> fetchsalesreport({
    DateTimeRange? selectedDate,
    String? selectedBranch,
    String? productType,
    String? category,
  }) async {
    final requestGeneration = ++_salesReportRequestGeneration;
    final now = DateTime.now();
    final startStr = _toDateOnly(selectedDate?.start ?? now);
    final endStr = _toDateOnly(selectedDate?.end ?? now);
    final cacheKey = '$companyid|$startStr|$endStr';

    Query<Map<String, dynamic>> query = db
        .collection('salesSummary')
        .where('companyid', isEqualTo: companyid)
        .where('summarydate', isGreaterThanOrEqualTo: startStr)
        .where('summarydate', isLessThanOrEqualTo: endStr);

    try {
      isloadingsalesreport = true;
      salesReportError = null;
      salesReportOffline = false;
      final inMemoryRaw = _salesReportRawCache[cacheKey];
      if (_salesReportRawCache.containsKey(cacheKey)) {
        _applySalesReportData(
          inMemoryRaw!,
          selectedBranch: selectedBranch,
          productType: productType,
          category: category,
        );
        salesReportHasVisibleData = true;
        notifyListeners();
      } else {
        salesReportHasVisibleData = false;
        salesReportRaw = [];
        report.clear();
        branchReport.clear();
        notifyListeners();

        try {
          final cachedSnapshot = await query.get(
            const GetOptions(source: Source.cache),
          );
          if (requestGeneration != _salesReportRequestGeneration) return;
          if (cachedSnapshot.docs.isNotEmpty) {
            final cachedRaw = cachedSnapshot.docs
                .map((doc) => doc.data())
                .toList();
            _cacheSalesReportRaw(cacheKey, cachedRaw);
            _applySalesReportData(
              cachedRaw,
              selectedBranch: selectedBranch,
              productType: productType,
              category: category,
            );
            salesReportHasVisibleData = true;
            notifyListeners();
          }
        } on FirebaseException catch (error) {
          if (requestGeneration != _salesReportRequestGeneration) return;
          debugPrint('Sales report cache lookup failed: $error');
        }
      }

      final snapshot = await query.get(const GetOptions(source: Source.server));
      if (requestGeneration != _salesReportRequestGeneration) return;
      final raw = snapshot.docs.map((doc) => doc.data()).toList();
      _cacheSalesReportRaw(cacheKey, raw);
      _applySalesReportData(
        raw,
        selectedBranch: selectedBranch,
        productType: productType,
        category: category,
      );
      salesReportHasVisibleData = true;
    } catch (e) {
      if (requestGeneration != _salesReportRequestGeneration) return;
      debugPrint("fetchsalesreport error: $e");
      salesReportOffline = e is FirebaseException && e.code == 'unavailable';
      salesReportError = salesReportOffline
          ? null
          : 'Could not refresh the sales report.';
      if (!salesReportHasVisibleData) {
        salesReportRaw = [];
        report = [];
        branchReport = [];
        _computeReportTotals();
        _computeBranchReportTotals();
      }
    } finally {
      if (requestGeneration == _salesReportRequestGeneration) {
        isloadingsalesreport = false;
        notifyListeners();
      }
    }
  }

  void _cacheSalesReportRaw(String cacheKey, List<Map<String, dynamic>> raw) {
    _salesReportRawCache.remove(cacheKey);
    _salesReportRawCache[cacheKey] = raw;
    if (_salesReportRawCache.length > 5) {
      _salesReportRawCache.remove(_salesReportRawCache.keys.first);
    }
  }

  void _applySalesReportData(
    List<Map<String, dynamic>> raw, {
    String? selectedBranch,
    String? productType,
    String? category,
  }) {
    salesReportRaw = raw;
    _collectReportFilters(raw);
    report = raw.isEmpty ? [] : extractItems(raw, selectedBranch);
    branchReport = _buildBranchReport(
      raw,
      selectedBranch,
      productType,
      category,
    );
    _computeReportTotals();
    _computeBranchReportTotals();
  }

  void applySalesReportFilter({
    String? selectedBranch,
    String? productType,
    String? category,
  }) {
    branchReport = _buildBranchReport(
      salesReportRaw,
      selectedBranch,
      productType,
      category,
    );
    _computeBranchReportTotals();
    notifyListeners();
  }

  Map<String, dynamic> extractDebtPayments(
    List<Map<String, dynamic>> rawReport, {
    String? selectedBranch,
  }) {
    double grandTotal = 0;
    final Map<String, Map<String, dynamic>> byBranch = {};

    for (final doc in rawReport) {
      final staffSummary = doc['staffSummary'] as Map<String, dynamic>? ?? {};

      // iterate branch keys, filter if needed
      final Iterable<MapEntry<String, dynamic>> branchEntries =
          selectedBranch != null
          ? staffSummary.entries.where((e) => e.key == selectedBranch)
          : staffSummary.entries;

      for (final branchEntry in branchEntries) {
        final branchId = branchEntry.key;
        final staffMap = branchEntry.value as Map<String, dynamic>? ?? {};

        byBranch.putIfAbsent(
          branchId,
          () => {
            'branchId': branchId,
            'branchName': '',
            'total': 0.0,
            'byStaff': <String, Map<String, dynamic>>{},
          },
        );

        final branchNode = byBranch[branchId]!;
        final byStaff =
            branchNode['byStaff'] as Map<String, Map<String, dynamic>>;

        for (final staffEntry in staffMap.entries) {
          final email = staffEntry.key;
          final staffData = staffEntry.value as Map<String, dynamic>? ?? {};

          final staffName =
              staffData['staffName']?.toString() ??
              staffData['staff']?.toString() ??
              email;
          final branchName = staffData['branchName']?.toString() ?? branchId;
          final payment = (staffData['debtpayments_value'] ?? 0).toDouble();

          // update branch name from first staff entry that has it
          if ((branchNode['branchName'] as String).isEmpty) {
            branchNode['branchName'] = branchName;
          }

          byStaff.putIfAbsent(
            email,
            () => {'staffName': staffName, 'email': email, 'total': 0.0},
          );

          byStaff[email]!['total'] =
              (byStaff[email]!['total'] as double) + payment;

          branchNode['total'] = (branchNode['total'] as double) + payment;

          grandTotal += payment;
        }
      }
    }

    return {'total': grandTotal, 'byBranch': byBranch};
  }

  void _computeReportTotals() {
    reportTotalCashSales = 0;
    reportTotalCreditSales = 0;
    reportTotalCashReturns = 0;
    reportTotalCreditReturns = 0;
    reportTotalReturns = 0;
    reportTotalDiscount = 0;
    reportTotalDiscountReturn = 0;
    reportTotalDamage = 0;
    reportTotalPurchaseReturn = 0;
    reportTotalProfit = 0;
    reportTotalProfitReturn = 0;
    reportTotalRowTotal = 0;

    for (final item in report) {
      reportTotalCashSales += (item['cashSales'] ?? 0.0) as double;
      reportTotalCreditSales += (item['creditSales'] ?? 0.0) as double;
      reportTotalCashReturns += (item['cashReturns'] ?? 0.0) as double;
      reportTotalCreditReturns += (item['creditReturns'] ?? 0.0) as double;
      reportTotalReturns += (item['returns'] ?? 0.0) as double;
      reportTotalDiscount += (item['discount'] ?? 0.0) as double;
      reportTotalDiscountReturn += (item['return_discount'] ?? 0.0) as double;
      reportTotalDamage += (item['damage_value'] ?? 0.0) as double;
      reportTotalPurchaseReturn +=
          (item['purchaseReturn_value'] ?? 0.0) as double;
      reportTotalProfit += (item['profit'] ?? 0.0) as double;
      reportTotalProfitReturn += (item['return_profit'] ?? 0.0) as double;
      reportTotalRowTotal += (item['rowtotal'] ?? 0.0) as double;
    }

    reportGrandTotal = reportTotalRowTotal;
    reportCashAtHand = reportTotalCashSales - reportTotalCashReturns;
  }

  void _computeBranchReportTotals() {
    branchTotalCashSales = 0;
    branchTotalCreditSales = 0;
    branchTotalCashReturns = 0;
    branchTotalCreditReturns = 0;
    branchTotalReturns = 0;
    branchTotalDiscount = 0;
    branchTotalDiscountReturn = 0;
    branchTotalDamage = 0;
    branchTotalPurchaseReturn = 0;
    branchTotalProfit = 0;
    branchTotalProfitReturn = 0;
    branchTotalRowTotal = 0;
    branchreportDebttotal = 0;

    for (final item in branchReport) {
      branchTotalCashSales += (item['cashSales'] ?? 0.0) as double;
      branchTotalCreditSales += (item['creditSales'] ?? 0.0) as double;
      branchTotalCashReturns += (item['cashReturns'] ?? 0.0) as double;
      branchTotalCreditReturns += (item['creditReturns'] ?? 0.0) as double;
      branchTotalReturns += (item['totalReturns'] ?? 0.0) as double;
      branchTotalDiscount += (item['discount'] ?? 0.0) as double;
      reportTotalDiscountReturn += (item['return_discount'] ?? 0.0) as double;
      branchTotalDamage += (item['damage_value'] ?? 0.0) as double;
      branchTotalPurchaseReturn +=
          (item['purchaseReturn_value'] ?? 0.0) as double;
      branchTotalProfit += (item['profit'] ?? 0.0) as double;
      reportTotalProfitReturn += (item['return_profit'] ?? 0.0) as double;

      branchreportDebttotal += (item['branchdebt'] ?? 0.0) as double;
    }
    branchTotalRowTotal = branchTotalCashSales + branchTotalCreditSales;
    branchGrandTotal = branchTotalRowTotal;
    branchCashAtHand = branchTotalCashSales - branchTotalCashReturns;
  }

  List<Map<String, dynamic>> extractItems(
    List<Map<String, dynamic>> rawReport,
    String? selectedBranch,
  ) {
    final Map<String, Map<String, dynamic>> groupedItems = {};

    for (var company in rawReport) {
      final companyId = company['companyid'] ?? '';
      final companyName = company['company'] ?? '';
      final branchSummary =
          company['branchSummary'] as Map<String, dynamic>? ?? {};

      final Iterable branches = selectedBranch == null
          ? branchSummary.values
          : [branchSummary[selectedBranch]].where((b) => b != null);

      for (var branch in branches) {
        final branchItems = branch['items'] as Map<String, dynamic>? ?? {};
        final branchName = branch['branchName'] ?? '';
        final branchId = branch['branchId'] ?? '';

        for (var item in branchItems.values) {
          final itemId = (item['itemid'] ?? '').toString();
          if (itemId.isEmpty) continue;

          final itemName = item['itemName'] ?? item['barcode'] ?? '';

          final cash = (item['cash'] ?? 0).toDouble();
          final credit = (item['credit'] ?? 0).toDouble();
          final damageQty = (item['damage_qty'] ?? 0).toDouble();
          final damageValue = (item['damage_value'] ?? 0).toDouble();
          final discount = (item['discount'] ?? 0).toDouble();

          final purchaseReturnQty = (item['purchaseReturn_qty'] ?? 0)
              .toDouble();
          final purchaseReturnValue = (item['purchaseReturn_value'] ?? 0)
              .toDouble();
          final salesQty = (item['sales_qty'] ?? 0).toDouble();

          final returns = (item['salesReturn_value'] ?? 0).toDouble();
          final cashreturn = (item['cash_returns'] ?? 0).toDouble();
          final creditreturn = (item['credit_returns'] ?? 0).toDouble();
          final itemCost = (item['costof_goods'] ?? 0).toDouble();
          final salesValue = (item['sales_value'] ?? 0).toDouble();
          final profit = (item['profit'] ?? 0).toDouble();
          final returnProfit = (item['return_profit'] ?? 0).toDouble();
          final returnDiscount = (item['return_discount'] ?? 0).toDouble();

          // final totalReturns = returns > 0 ? returns : (cashreturn + creditreturn);
          final totalReturns = cashreturn + creditreturn;
          final rowtotal = (cash + credit) - totalReturns;
          final netDiscount = discount - returnDiscount;
          final netProfit = profit - returnProfit;
          groupedItems.putIfAbsent(
            itemId,
            () => {
              'item': itemName,
              'branchName': branchName,
              'branchId': branchId,
              'company': companyName,
              'companyid': companyId,
              'itemid': itemId,
              'quantity': 0.0,
              'returns': 0.0,
              'cashSales': 0.0,
              'creditSales': 0.0,
              'damage_qty': 0.0,
              'damage_value': 0.0,
              'damage': 0.0,
              'discount': 0.0,
              'purchaseReturn_qty': 0.0,
              'purchaseReturn_value': 0.0,
              'sales_qty': 0.0,
              'cashReturns': 0.0,
              'creditReturns': 0.0,
              'totalSales': 0.0,
              'totalcost': 0.0,
              'profit': 0.0,
              'rowtotal': 0.0,
              'sales_value': 0.0,
              'cost_of_goods': 0.0,
              'return_profit': 0.0,
              'return_discount': 0.0,
            },
          );

          final e = groupedItems[itemId]!;
          e['quantity'] += salesQty;
          e['cashSales'] += cash;
          e['creditSales'] += credit;
          e['damage_qty'] += damageQty;
          e['damage_value'] += damageValue;
          e['damage'] += damageValue;
          e['discount'] += netDiscount;
          e['purchaseReturn_qty'] += purchaseReturnQty;
          e['purchaseReturn_value'] += purchaseReturnValue;
          e['sales_qty'] += salesQty;
          e['cashReturns'] += cashreturn;
          e['creditReturns'] += creditreturn;
          e['returns'] += returns;
          e['totalSales'] += rowtotal;
          e['totalcost'] += itemCost;
          e['rowtotal'] += rowtotal;
          e['sales_value'] += salesValue;
          e['cost_of_goods'] += itemCost;
          e['profit'] += netProfit;

          e['return_profit'] = (e['return_profit'] ?? 0.0) + returnProfit;
          e['return_discount'] = (e['return_discount'] ?? 0.0) + returnDiscount;
        }
      }
    }

    return groupedItems.values.toList();
  }

  List<Map<String, dynamic>> filtersalesreport() {
    if (searchQuery.isEmpty) return report;
    final q = searchQuery.toLowerCase();
    return report.where((searched) {
      final item = searched['item']?.toString().toLowerCase() ?? '';
      final branchName = searched['branchName']?.toString().toLowerCase() ?? '';
      final branchId = searched['branchId']?.toString().toLowerCase() ?? '';
      final company = searched['company']?.toString().toLowerCase() ?? '';
      final itemid = searched['itemid']?.toString().toLowerCase() ?? '';
      final companyid = searched['companyid']?.toString().toLowerCase() ?? '';
      final quantity = searched['quantity']?.toString().toLowerCase() ?? '';
      final returns = searched['returns']?.toString().toLowerCase() ?? '';
      final cashSales = searched['cashSales']?.toString().toLowerCase() ?? '';
      final creditSales =
          searched['creditSales']?.toString().toLowerCase() ?? '';
      final damage_qty = searched['damage_qty']?.toString().toLowerCase() ?? '';
      final damage_value =
          searched['damage_value']?.toString().toLowerCase() ?? '';
      final discount = searched['discount']?.toString().toLowerCase() ?? '';
      final purchaseReturn_qty =
          searched['purchaseReturn_qty']?.toString().toLowerCase() ?? '';
      final purchaseReturn_value =
          searched['purchaseReturn_value']?.toString().toLowerCase() ?? '';
      final sales_qty = searched['sales_qty']?.toString().toLowerCase() ?? '';
      final cashReturns_qty =
          searched['cashReturns_qty']?.toString().toLowerCase() ?? '';
      final creditReturns_qty =
          searched['creditReturns_qty']?.toString().toLowerCase() ?? '';
      final cashReturns =
          searched['cashReturns']?.toString().toLowerCase() ?? '';
      final creditReturns =
          searched['creditReturns']?.toString().toLowerCase() ?? '';
      final totalSales = searched['totalSales']?.toString().toLowerCase() ?? '';
      final totalcost = searched['totalcost']?.toString().toLowerCase() ?? '';
      final profit = searched['profit']?.toString().toLowerCase() ?? '';
      final damage = searched['damage']?.toString().toLowerCase() ?? '';
      final rowtotal = searched['rowtotal']?.toString().toLowerCase() ?? '';
      return item.contains(q) ||
          branchName.contains(q) ||
          branchId.contains(q) ||
          company.contains(q) ||
          purchaseReturn_qty.contains(q) ||
          sales_qty.contains(q) ||
          creditReturns_qty.contains(q) ||
          purchaseReturn_value.contains(q) ||
          discount.contains(q) ||
          cashReturns_qty.contains(q) ||
          itemid.contains(q) ||
          damage_value.contains(q) ||
          quantity.contains(q) ||
          damage_qty.contains(q) ||
          cashSales.contains(q) ||
          creditSales.contains(q) ||
          companyid.contains(q) ||
          returns.contains(q) ||
          damage.contains(q) ||
          profit.contains(q) ||
          totalcost.contains(q) ||
          totalSales.contains(q) ||
          creditReturns.contains(q) ||
          cashReturns.contains(q) ||
          rowtotal.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> extractbranch(
    List<Map<String, dynamic>> rawReport,
    String? selectedBranch,
  ) {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (var company in rawReport) {
      final companyId = (company['companyid'] ?? '').toString();
      final companyName = (company['company'] ?? '').toString();
      final branchSummary =
          company['branchSummary'] as Map<String, dynamic>? ?? {};

      final Iterable<dynamic> branches = selectedBranch == null
          ? branchSummary.values
          : [branchSummary[selectedBranch]].where((b) => b != null);

      for (var branch in branches) {
        final branchId = (branch['branchId'] ?? '').toString();
        final branchName = (branch['branchName'] ?? '').toString();
        if (branchId.isEmpty) continue;

        // final cash = (branch['cash'] ?? 0).toDouble();
        final rawCash = (branch['cash'] ?? 0).toDouble();
        final credit = (branch['credit'] ?? 0).toDouble();
        final merchantmomo = (branch['merchantmomo'] ?? branch['momo'] ?? 0)
            .toDouble();
        final hubtel = (branch['hubtel'] ?? 0).toDouble();
        final card = (branch['card'] ?? 0).toDouble();
        final bank =
            (branch['bank'] ??
                    branch['bank_transfer'] ??
                    branch['bank transfer'] ??
                    0)
                .toDouble();
        final cheque = (branch['cheque'] ?? 0).toDouble();

        final cash = rawCash - (merchantmomo - hubtel - card - bank - cheque);
        final discount =
            (branch['branch_Discount'] ?? branch['branchDiscount'] ?? 0)
                .toDouble();
        final returnDiscount = (branch['branch_returnDiscount'] ?? 0)
            .toDouble();
        final profit = (branch['branch_profit'] ?? 0).toDouble();
        final returnProfit = (branch['branch_returnprofit'] ?? 0).toDouble();

        final salesQty = (branch['branchsales_qty'] ?? 0).toDouble();
        final salesValue = (branch['branchsales_value'] ?? 0).toDouble();
        final costOfGoods = (branch['branchCostof_goods'] ?? 0).toDouble();

        final txnCount = (branch['branchtransaction_count'] ?? 0).toDouble();
        double branchdebt = (branch['branchdebt'] ?? 0).toDouble();
        double cashReturns = (branch['branch_cash_returns'] ?? 0).toDouble();
        double creditReturns = (branch['branch_credit_returns'] ?? 0)
            .toDouble();
        double salesReturns = (branch['branchsalesReturn_value'] ?? 0)
            .toDouble();
        double damageQty = (branch['damage_qty'] ?? 0).toDouble();
        double damageValue = (branch['damage_value'] ?? 0).toDouble();
        double purchaseReturnQty = (branch['purchaseReturn_qty'] ?? 0)
            .toDouble();
        double purchaseReturnValue = (branch['purchaseReturn_value'] ?? 0)
            .toDouble();

        final items = branch['items'] as Map<String, dynamic>? ?? {};

        if (cashReturns == 0 && creditReturns == 0 && salesReturns == 0) {
          for (var item in items.values) {
            cashReturns += (item['cash_returns'] ?? 0).toDouble();
            creditReturns += (item['credit_returns'] ?? 0).toDouble();
            salesReturns += (item['salesReturn_value'] ?? 0).toDouble();
            damageQty += (item['damage_qty'] ?? 0).toDouble();
            damageValue += (item['damage_value'] ?? 0).toDouble();
            purchaseReturnQty += (item['purchaseReturn_qty'] ?? 0).toDouble();
            purchaseReturnValue += (item['purchaseReturn_value'] ?? 0)
                .toDouble();
          }
        }

        final totalReturns = salesReturns > 0
            ? salesReturns
            : (cashReturns + creditReturns);

        final totalSales =
            merchantmomo + hubtel + card + bank + cheque + cash + credit;
        final rowTotal = totalSales - totalReturns - discount;
        final netDiscount = discount - returnDiscount;
        final netProfit = profit - returnProfit;

        grouped.putIfAbsent(
          branchId,
          () => {
            'branchId': branchId,
            'branchName': branchName,
            'company': companyName,
            'companyid': companyId,
            'sales_qty': 0.0,
            'cashSales': 0.0,
            'creditSales': 0.0,
            'momo': 0.0,
            'merchantmomo': 0.0,
            'hubtel': 0.0,
            'card': 0.0,
            'bank': 0.0,
            'cheque': 0.0,
            'cashReturns': 0.0,
            'creditReturns': 0.0,
            'salesReturns': 0.0,
            'totalReturns': 0.0,
            'discount': 0.0,
            'damage_qty': 0.0,
            'damage_value': 0.0,
            'purchaseReturn_qty': 0.0,
            'purchaseReturn_value': 0.0,
            'sales_value': 0.0,
            'cost_of_goods': 0.0,
            'profit': 0.0,
            'totalSales': 0.0,
            'rowTotal': 0.0,
            'transaction_count': 0.0,
            'branchdebt': 0.0,
          },
        );

        final e = grouped[branchId]!;
        e['sales_qty'] = (e['sales_qty'] as double) + salesQty;
        e['cashSales'] = (e['cashSales'] as double) + cash;
        e['creditSales'] = (e['creditSales'] as double) + credit;

        e['merchantmomo'] = (e['merchantmomo'] as double) + merchantmomo;
        e['hubtel'] = (e['hubtel'] as double) + hubtel;
        e['card'] = (e['card'] as double) + card;
        e['bank'] = (e['bank'] as double) + bank;
        e['cheque'] = (e['cheque'] as double) + cheque;
        e['cashReturns'] = (e['cashReturns'] as double) + cashReturns;
        e['creditReturns'] = (e['creditReturns'] as double) + creditReturns;
        e['salesReturns'] = (e['salesReturns'] as double) + salesReturns;
        e['totalReturns'] = (e['totalReturns'] as double) + totalReturns;
        e['discount'] = (e['discount'] as double) + netDiscount;
        e['damage_qty'] = (e['damage_qty'] as double) + damageQty;
        e['damage_value'] = (e['damage_value'] as double) + damageValue;
        e['purchaseReturn_qty'] =
            (e['purchaseReturn_qty'] as double) + purchaseReturnQty;
        e['purchaseReturn_value'] =
            (e['purchaseReturn_value'] as double) + purchaseReturnValue;
        e['sales_value'] = (e['sales_value'] as double) + salesValue;
        e['cost_of_goods'] = (e['cost_of_goods'] as double) + costOfGoods;
        e['profit'] = (e['profit'] as double) + netProfit;
        e['totalSales'] = (e['totalSales'] as double) + totalSales;
        e['rowTotal'] = (e['rowTotal'] as double) + rowTotal;
        e['transaction_count'] = (e['transaction_count'] as double) + txnCount;
        e['branchdebt'] = (e['branchdebt'] as double) + branchdebt;
      }
    }

    return grouped.values.toList();
  }

  List<Map<String, dynamic>> filterbranchsalesreport() {
    if (searchQuery.isEmpty) return branchReport;

    final q = searchQuery.toLowerCase();
    return branchReport.where((row) {
      final fields = [
        row['branchName'],
        row['branchId'],
        row['company'],
        row['companyid'],
        row['sales_qty'],
        row['merchantmomo'],
        row['hubtel'],
        row['card'],
        row['bank'],
        row['cheque'],
        row['cashSales'],
        row['creditSales'],
        row['momo'],
        row['cashReturns'],
        row['creditReturns'],
        row['totalReturns'],
        row['discount'],
        row['damage_qty'],
        row['damage_value'],
        row['purchaseReturn_qty'],
        row['purchaseReturn_value'],
        row['sales_value'],
        row['cost_of_goods'],
        row['profit'],
        row['totalSales'],
        row['rowTotal'],
        row['transaction_count'],
      ];
      return fields.any(
        (f) => f?.toString().toLowerCase().contains(q) ?? false,
      );
    }).toList();
  }

  List<Map<String, dynamic>> filteredSalesBranchRows({
    int? sortColumn,
    bool sortAscending = true,
  }) {
    String norm(dynamic value) => (value ?? '').toString().toLowerCase();
    final warehouseIds = branches
        .where(
          (branch) =>
              branch.branchtype.toLowerCase().replaceAll(
                RegExp(r'[\s_\-]'),
                '',
              ) ==
              'warehouse',
        )
        .map((branch) => norm(branch.id))
        .toSet();
    final rows = filterbranchsalesreport()
        .where((row) => !warehouseIds.contains(norm(row['branchId'])))
        .toList();

    if (sortColumn == null) return rows;
    Comparable value(Map<String, dynamic> row) {
      switch (sortColumn) {
        case 1:
          return norm(row['branchName']);
        case 2:
          return _toDouble(row['cashSales']) +
              _toDouble(row['merchantmomo']) +
              _toDouble(row['card']) +
              _toDouble(row['bank']) +
              _toDouble(row['hubtel']) +
              _toDouble(row['cheque']);
        case 3:
          return _toDouble(row['creditSales']);
        case 4:
          return _toDouble(row['totalSales']);
        case 5:
          return _toDouble(row['cashReturns']) +
              _toDouble(row['creditReturns']);
        case 6:
          return _toDouble(row['discount']);
        case 7:
          return _toDouble(row['profit']);
        case 8:
          return _toDouble(row['cashSales']) - _toDouble(row['cashReturns']);
        default:
          return 0.0;
      }
    }

    rows.sort((a, b) {
      final result = Comparable.compare(value(a), value(b));
      return sortAscending ? result : -result;
    });
    return rows;
  }

  Map<String, double> salesSummaryTotals(
    List<Map<String, dynamic>> rows, {
    bool includePaymentBreakdown = false,
  }) {
    final totals = <String, double>{
      'qty': 0,
      'cash': 0,
      'credit': 0,
      'returns': 0,
      'discount': 0,
      'profit': 0,
      'total': 0,
    };
    if (includePaymentBreakdown) {
      totals.addAll({
        'merchant': 0,
        'hubtel': 0,
        'card': 0,
        'bank': 0,
        'cheque': 0,
      });
    }
    double read(Map<String, dynamic> row, String key) =>
        (row[key] ?? 0.0) as double;
    for (final row in rows) {
      totals['qty'] = totals['qty']! + read(row, 'sales_qty');
      totals['cash'] = totals['cash']! + read(row, 'cashSales');
      totals['returns'] =
          totals['returns']! +
          (includePaymentBreakdown
              ? read(row, 'totalReturns') + read(row, 'returns')
              : read(row, 'returns'));
      totals['discount'] = totals['discount']! + read(row, 'discount');
      totals['profit'] = totals['profit']! + read(row, 'profit');
      totals['total'] =
          totals['total']! +
          (includePaymentBreakdown
              ? read(row, 'rowTotal') + read(row, 'rowtotal')
              : read(row, 'rowtotal'));
      if (!includePaymentBreakdown) {
        totals['credit'] = totals['credit']! + read(row, 'creditSales');
      } else {
        for (final key in const [
          'merchant',
          'hubtel',
          'card',
          'bank',
          'cheque',
        ]) {
          final sourceKey = key == 'merchant' ? 'merchantmomo' : key;
          totals[key] = totals[key]! + read(row, sourceKey);
        }
      }
    }
    return totals;
  }

  Map<String, dynamic> aggregateItemStats(
    List<Map<String, dynamic>> transactions,
  ) {
    double cashSales = 0;
    double creditSales = 0;
    double cashReturns = 0;
    double creditReturns = 0;
    double totalDiscount = 0;
    double totalQty = 0;
    double totalCost = 0;
    double profit = 0;

    for (final transaction in transactions) {
      final total = (transaction['total'] as num?)?.toDouble() ?? 0;
      final qty = (transaction['qty'] as num?)?.toDouble() ?? 0;
      final discount = (transaction['discount'] as num?)?.toDouble() ?? 0;
      final cp = (transaction['cp'] as num?)?.toDouble() ?? 0;
      final transactionProfit =
          (transaction['profit'] as num?)?.toDouble() ?? 0;
      final returnedAmount =
          (transaction['returnedAmount'] as num?)?.toDouble() ?? 0;
      if (transaction['isReturned'] == true) {
        totalQty -= qty;
        totalDiscount -= discount;
        totalCost -= qty * cp;
        profit -= transactionProfit;
        if (transaction['isCashReturn'] == true) {
          cashReturns += returnedAmount;
        } else if (transaction['isCreditReturn'] == true) {
          creditReturns += returnedAmount;
        }
      } else {
        totalQty += qty;
        totalDiscount += discount;
        totalCost += qty * cp;
        profit += transactionProfit;
        if (transaction['isCredit'] == true) {
          creditSales += total;
        } else {
          cashSales += total;
        }
      }
    }
    final totalReturns = cashReturns + creditReturns;
    return {
      'cashSales': cashSales,
      'creditSales': creditSales,
      'cashReturns': cashReturns,
      'creditReturns': creditReturns,
      'totalReturns': totalReturns,
      'totalDiscount': totalDiscount,
      'totalQty': totalQty,
      'profit': profit,
      'total': cashSales + creditSales - totalReturns,
    };
  }

  List<Map<String, dynamic>> filterTransactionsByCategory(
    List<Map<String, dynamic>> transactions,
    String category,
  ) {
    switch (category) {
      case 'cashSales':
        return transactions
            .where((t) => t['isReturned'] != true && t['isCredit'] != true)
            .toList();
      case 'creditSales':
        return transactions
            .where((t) => t['isReturned'] != true && t['isCredit'] == true)
            .toList();
      case 'cashReturns':
        return transactions
            .where((t) => t['isReturned'] == true && t['isCashReturn'] == true)
            .toList();
      case 'creditReturns':
        return transactions
            .where(
              (t) => t['isReturned'] == true && t['isCreditReturn'] == true,
            )
            .toList();
      case 'totalReturns':
        return transactions.where((t) => t['isReturned'] == true).toList();
      case 'discount':
        return transactions
            .where((t) => ((t['discount'] as num?) ?? 0) > 0)
            .toList();
      case 'total':
      case 'profit':
      case 'qty':
      default:
        return transactions;
    }
  }

  Map<String, double> salesItemTransactionSummary(
    List<Map<String, dynamic>> transactions,
  ) {
    double cash = 0, credit = 0, cashRet = 0, creditRet = 0, returns = 0;
    double saleDisc = 0, retDisc = 0, saleQty = 0, retQty = 0;
    double saleProfit = 0, retProfit = 0;
    for (final transaction in transactions) {
      final total = toNumber(transaction['total']);
      final discount = toNumber(transaction['discount']);
      final qty = toNumber(transaction['qty']);
      final profit = toNumber(transaction['profit']);
      if (transaction['isReturned'] == true) {
        returns += total;
        if (transaction['isCashReturn'] == true) cashRet += total;
        if (transaction['isCreditReturn'] == true) creditRet += total;
        retDisc += discount;
        retQty += qty;
        retProfit += profit;
      } else {
        if (transaction['isCredit'] == true) {
          credit += total;
        } else {
          cash += total;
        }
        saleDisc += discount;
        saleQty += qty;
        saleProfit += profit;
      }
    }
    return {
      'cash': cash,
      'credit': credit,
      'cashRet': cashRet,
      'creditRet': creditRet,
      'returns': returns,
      'saleDisc': saleDisc,
      'retDisc': retDisc,
      'discount': saleDisc - retDisc,
      'saleQty': saleQty,
      'retQty': retQty,
      'qty': saleQty - retQty,
      'saleProfit': saleProfit,
      'retProfit': retProfit,
      'profit': saleProfit - retProfit,
      'net': cash + credit - returns,
      'cashAtHand': cash - cashRet,
    };
  }

  List<Map<String, dynamic>> pageReportRows(
    List<Map<String, dynamic>> rows,
    int rowsPerPage,
    int pageIndex,
  ) {
    if (rows.isEmpty) return const [];
    final pageCount = (rows.length - 1) ~/ rowsPerPage;
    final safePage = pageIndex.clamp(0, pageCount);
    final start = safePage * rowsPerPage;
    final end = (start + rowsPerPage).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  Map<String, double> stockReportValueTotals(List<Map<String, dynamic>> rows) {
    return {
      'stock': rows.fold<double>(
        0,
        (sum, row) => sum + _toDouble(row['stock_value']),
      ),
      'selling': rows.fold<double>(
        0,
        (sum, row) => sum + _toDouble(row['selling_value']),
      ),
    };
  }

  List<Map<String, dynamic>> sortBranchItemRows(
    List<Map<String, dynamic>> rows, {
    required int column,
    required bool ascending,
  }) {
    Comparable value(Map<String, dynamic> row) {
      switch (column) {
        case 1:
          return (row['item'] ?? '').toString().toLowerCase();
        case 2:
          return _d(row['sales_qty']);
        case 3:
          return (row['pcategory'] ?? row['category'] ?? '')
              .toString()
              .toLowerCase();
        case 4:
          return _d(row['cashSales']);
        case 5:
          return _d(row['momo']);
        case 6:
          return _d(row['hubtel']);
        case 7:
          return _d(row['card']);
        case 8:
          return _d(row['bank']);
        case 9:
          return _d(row['cheque']);
        case 10:
          return _d(row['creditSales']);
        case 11:
          return _d(row['cashSales']) +
              _d(row['momo']) +
              _d(row['creditSales']);
        case 12:
          return _d(row['cashReturns']) + _d(row['creditReturns']);
        case 13:
          return _d(row['discount']);
        case 14:
          return _d(row['profit']);
        case 15:
          return _d(row['cashSales']) - _d(row['cashReturns']);
        default:
          return 0;
      }
    }

    rows.sort((a, b) {
      final result = Comparable.compare(value(a), value(b));
      return ascending ? result : -result;
    });
    return rows;
  }

  Map<String, dynamic> calcGrandTotal(List<Map<String, dynamic>> rows) {
    const keys = [
      'sales_qty',
      'cashSales',
      'creditSales',
      'momo',
      'cashReturns',
      'creditReturns',
      'salesReturns',
      'totalReturns',
      'discount',
      'damage_qty',
      'damage_value',
      'purchaseReturn_qty',
      'purchaseReturn_value',
      'sales_value',
      'cost_of_goods',
      'profit',
      'totalSales',
      'rowTotal',
      'transaction_count',
    ];

    final Map<String, dynamic> totals = {
      for (var k in keys) k: 0.0,
      'branchName': 'Grand Total',
      'branchId': '',
      'company': '',
      'companyid': '',
    };

    for (var row in rows) {
      for (var k in keys) {
        totals[k] = (totals[k] as double) + ((row[k] ?? 0.0) as double);
      }
    }
    return totals;
  }

  bool isloadingbranchitem = false;
  int _branchItemsRequestGeneration = 0;

  Future<void> loadBranchItemsReport({
    required DateTime startDate,
    required DateTime endDate,
    String? branchId,
  }) async {
    final requestGeneration = ++_branchItemsRequestGeneration;
    final startStr = _toDateOnly(startDate);
    final endStr = _toDateOnly(endDate);
    final query = db
        .collection('salesSummary')
        .where('companyid', isEqualTo: companyid)
        .where('summarydate', isGreaterThanOrEqualTo: startStr)
        .where('summarydate', isLessThanOrEqualTo: endStr);

    isloadingbranchitem = true;
    notifyListeners();

    try {
      await datafeed.loadQueryCacheFirst(
        query,
        isCurrent: () => requestGeneration == _branchItemsRequestGeneration,
        label: 'Sales branch items report',
        apply: (snapshot) {
          final fetched = snapshot.docs.map((doc) => doc.data()).toList();
          branchReportitem = extractBranchItems(fetched, branchId);
          notifyListeners();
        },
      );
    } catch (e) {
      if (requestGeneration != _branchItemsRequestGeneration) return;
      debugPrint('loadBranchItemsReport error: $e');
      branchReportitem = [];
    }

    if (requestGeneration == _branchItemsRequestGeneration) {
      isloadingbranchitem = false;
      notifyListeners();
    }
  }

  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return (v as num).toDouble();
  }

  String _str(dynamic v) => v?.toString() ?? '';
  List<Map<String, dynamic>> extractBranchItems(
    List<Map<String, dynamic>> rawReport,
    String? selectedBranch,
  ) {
    // grouped by "branchId__itemId"
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final doc in rawReport) {
      final companyId = _str(doc['companyid']);
      final companyName = _str(doc['company']);

      // branchSummary keys ARE the branchIds
      final branchSummary = doc['branchSummary'] as Map<String, dynamic>? ?? {};

      for (final branchEntry in branchSummary.entries) {
        final branchKey = branchEntry.key; // e.g. "ks005yagaba"
        final branchData = branchEntry.value as Map<String, dynamic>? ?? {};

        // If a branch filter
        if (selectedBranch != null && branchKey != selectedBranch) continue;

        final branchId = _str(branchData['branchId'] ?? branchKey);
        final branchName = _str(branchData['branchName'] ?? '');

        // items map is inside the branch map
        final items = branchData['items'] as Map<String, dynamic>? ?? {};

        for (final itemEntry in items.entries) {
          final itemId = itemEntry.key;
          final itemData = itemEntry.value as Map<String, dynamic>? ?? {};

          final itemName = _str(itemData['itemName']);
          final itemBranchId = _str(itemData['branchId'] ?? branchId);
          final itemBranchName = _str(itemData['branchName'] ?? branchName);

          // Exact Firestore field names from your structure
          final cashSales = _d(itemData['cash']);
          final creditSales = _d(itemData['credit']);
          final momo = _d(itemData['momo']);
          final salesQty = _d(itemData['sales_qty']);
          final salesValue = _d(itemData['sales_value']);
          final costOfGoods = _d(itemData['costof_goods']);
          final discount = _d(itemData['discount']);
          final txnCount = _d(itemData['transaction_count']);
          final profit = _d(itemData['profit']);
          final return_profit = _d(itemData['return_profit']);
          final return_discount = _d(itemData['return_discount']);

          // Returns — default 0 if not yet in your data
          final cashReturns = _d(itemData['cash_returns']);
          final creditReturns = _d(itemData['credit_returns']);
          final salesReturns = _d(itemData['salesReturn_value']);
          final damageQty = _d(itemData['damage_qty']);
          final damageValue = _d(itemData['damage_value']);
          final purchaseReturnQty = _d(itemData['purchaseReturn_qty']);
          final purchaseReturnValue = _d(itemData['purchaseReturn_value']);
          final totalReturns = salesReturns > 0
              ? salesReturns
              : (cashReturns + creditReturns);

          // Calculations
          final totalSales = cashSales + creditSales + momo;
          final rowTotal = cashSales - cashReturns;

          final groupKey = '${branchId}__$itemId';

          grouped.putIfAbsent(
            groupKey,
            () => {
              'itemid': itemId,
              'item': itemName,
              'branchId': itemBranchId,
              'branchName': itemBranchName,
              'company': companyName,
              'companyid': companyId,
              'sales_qty': 0.0,
              'quantity': 0.0,
              'cashSales': 0.0,
              'creditSales': 0.0,
              'momo': 0.0,
              'cashReturns': 0.0,
              'creditReturns': 0.0,
              'salesReturns': 0.0,
              'returns': 0.0,
              'totalReturns': 0.0,
              'discount': 0.0,
              'damage_qty': 0.0,
              'damage_value': 0.0,
              'purchaseReturn_qty': 0.0,
              'purchaseReturn_value': 0.0,
              'sales_value': 0.0,
              'cost_of_goods': 0.0,
              'profit': 0.0,
              'return_profit': 0.0,
              'return_discount': 0.0,
              'totalSales': 0.0,
              'rowtotal': 0.0,
              'transaction_count': 0.0,
              'producttype': '',
              'pcategory': '',
            },
          );

          final e = grouped[groupKey]!;
          // Accumulate — multi-day ranges add up correctly
          e['sales_qty'] = (e['sales_qty'] as double) + salesQty;
          e['quantity'] = (e['quantity'] as double) + salesQty;
          e['cashSales'] = (e['cashSales'] as double) + cashSales;
          e['creditSales'] = (e['creditSales'] as double) + creditSales;
          e['momo'] = (e['momo'] as double) + momo;
          e['cashReturns'] = (e['cashReturns'] as double) + cashReturns;
          e['creditReturns'] = (e['creditReturns'] as double) + creditReturns;
          e['salesReturns'] = (e['salesReturns'] as double) + salesReturns;
          e['returns'] = (e['returns'] as double) + totalReturns;
          e['totalReturns'] = (e['totalReturns'] as double) + totalReturns;
          e['discount'] =
              (e['discount'] as double) + (discount - return_discount);
          e['return_discount'] =
              (e['return_discount'] as double) + return_discount;
          e['damage_qty'] = (e['damage_qty'] as double) + damageQty;
          e['damage_value'] = (e['damage_value'] as double) + damageValue;
          e['purchaseReturn_qty'] =
              (e['purchaseReturn_qty'] as double) + purchaseReturnQty;
          e['purchaseReturn_value'] =
              (e['purchaseReturn_value'] as double) + purchaseReturnValue;
          e['sales_value'] = (e['sales_value'] as double) + salesValue;
          e['cost_of_goods'] = (e['cost_of_goods'] as double) + costOfGoods;
          e['profit'] = (e['profit'] as double) + (profit - return_profit);
          e['return_profit'] = (e['return_profit'] as double) + return_profit;
          e['totalSales'] = (e['totalSales'] as double) + totalSales;
          e['rowtotal'] = (e['rowtotal'] as double) + rowTotal;
          e['transaction_count'] =
              (e['transaction_count'] as double) + txnCount;

          final pt = (itemData['producttype'] ?? '').toString().trim();
          if (pt.isNotEmpty) e['producttype'] = pt;
          final pc = (itemData['pcategory'] ?? itemData['category'] ?? '')
              .toString()
              .trim();
          if (pc.isNotEmpty) e['pcategory'] = pc;
        }
      }
    }

    return grouped.values.toList();
  }

  List<Map<String, dynamic>> filterBranchItems({
    String? productType,
    String? category,
  }) {
    final q = searchQuery.toLowerCase();
    return branchReportitem.where((item) {
      if (productType != null &&
          (item['producttype'] ?? '').toString() != productType)
        return false;
      if (category != null && (item['pcategory'] ?? '').toString() != category)
        return false;
      if (q.isEmpty) return true;
      return (item['item'] ?? '').toString().toLowerCase().contains(q) ||
          (item['branchName'] ?? '').toString().toLowerCase().contains(q) ||
          (item['itemid'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  List<String> get branchItemProductTypes =>
      branchReportitem
          .map((e) => (e['producttype'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  List<String> get branchItemCategories =>
      branchReportitem
          .map((e) => (e['pcategory'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  Map<String, double> computeBranchItemTotals(
    List<Map<String, dynamic>> filteredList,
  ) {
    double totalCashSales = 0;
    double totalCreditSales = 0;
    double totalMomo = 0;
    double totalMomoReturn = 0;
    double totalCashReturns = 0;
    double totalCreditReturns = 0;
    double totalReturns = 0;
    double totalDiscount = 0;
    double totalProfit = 0;
    double totalRowTotal = 0;
    double totalSalesQty = 0;
    double totalSalesValue = 0;
    double totalCostOfGoods = 0;
    double totalTxnCount = 0;

    for (final item in filteredList) {
      final cashSales = _d(item['cashSales']);
      final creditSales = _d(item['creditSales']);
      final momo = _d(item['momo']);
      final momoreturn = _d(item['momoreturns']);
      final cashReturns = _d(item['cashReturns']);
      final creditReturns = _d(item['creditReturns']);
      final returns = _d(item['totalReturns']);
      final discount = _d(item['discount']);
      final profit = _d(item['profit']);
      final rowtotal = _d(item['rowtotal']);
      final salesQty = _d(item['sales_qty']);
      final salesValue = _d(item['sales_value']);
      final costOfGoods = _d(item['cost_of_goods']);
      final txnCount = _d(item['transaction_count']);

      totalCashSales += cashSales;
      totalCreditSales += creditSales;
      totalMomo += momo;
      totalMomoReturn += momoreturn;
      totalCashReturns += cashReturns;
      totalCreditReturns += creditReturns;
      totalReturns += returns;
      totalDiscount += discount;
      totalProfit += profit;
      totalRowTotal += rowtotal;
      totalSalesQty += salesQty;
      totalSalesValue += salesValue;
      totalCostOfGoods += costOfGoods;
      totalTxnCount += txnCount;
    }

    final globalCashAtHand =
        (totalCashSales + totalMomo) - totalCashReturns - totalMomo;

    final grandTotal = totalRowTotal;

    return {
      'totalCashSales': totalCashSales,
      'totalCreditSales': totalCreditSales,
      'totalMomo': totalMomo,
      'totalMomoReturn': totalMomoReturn,
      'totalCashReturns': totalCashReturns,
      'totalCreditReturns': totalCreditReturns,
      'totalReturns': totalReturns,
      'totalDiscount': totalDiscount,
      'totalProfit': totalProfit,
      'totalRowTotal': totalRowTotal,
      'totalSalesQty': totalSalesQty,
      'totalSalesValue': totalSalesValue,
      'totalCostOfGoods': totalCostOfGoods,
      'totalTxnCount': totalTxnCount,
      'grandTotal': grandTotal,
      'globalCashAtHand': globalCashAtHand,
    };
  }

  List<Map<String, dynamic>> salesReportRaw = [];
  List<String> salesReportProductTypes = [];
  List<String> salesReportCategories = [];

  void _collectReportFilters(List<Map<String, dynamic>> raw) {
    final types = <String>{};
    final cats = <String>{};
    for (final doc in raw) {
      final branchSummary = doc['branchSummary'] as Map<String, dynamic>? ?? {};
      for (final b in branchSummary.values) {
        if (b is! Map) continue;
        final items = b['items'] as Map<String, dynamic>? ?? {};
        for (final it in items.values) {
          if (it is! Map) continue;
          final t = (it['producttype'] ?? '').toString().trim();
          final c = (it['pcategory'] ?? it['category'] ?? '').toString().trim();

          if (t.isNotEmpty) types.add(t);
          if (c.isNotEmpty) cats.add(c);
        }
      }
    }
    salesReportProductTypes = types.toList()..sort();
    salesReportCategories = cats.toList()..sort();
  }

  List<Map<String, dynamic>> _buildBranchReport(
    List<Map<String, dynamic>> raw,
    String? selectedBranch,
    String? productType,
    String? category,
  ) {
    if (raw.isEmpty) return [];
    if (productType != null || category != null) {
      return extractbranchByItems(raw, selectedBranch, productType, category);
    }
    return extractbranch(raw, selectedBranch);
  }

  List<Map<String, dynamic>> extractbranchByItems(
    List<Map<String, dynamic>> raw,
    String? selectedBranch,
    String? productType,
    String? category,
  ) {
    final grouped = <String, Map<String, dynamic>>{};

    for (final doc in raw) {
      final companyId = (doc['companyid'] ?? '').toString();
      final companyName = (doc['company'] ?? '').toString();
      final branchSummary = doc['branchSummary'] as Map<String, dynamic>? ?? {};

      for (final entry in branchSummary.entries) {
        final b = entry.value;
        if (b is! Map) continue;

        final branchId = (b['branchId'] ?? entry.key).toString();
        if (selectedBranch != null &&
            branchId != selectedBranch &&
            entry.key != selectedBranch) {
          continue;
        }

        final items = b['items'] as Map<String, dynamic>? ?? {};

        for (final it in items.values) {
          if (it is! Map) continue;

          final t = (it['producttype'] ?? '').toString().trim();
          final c = (it['pcategory'] ?? it['category'] ?? '').toString().trim();
          if (productType != null && t != productType) continue;
          if (category != null && c != category) continue;

          final e = grouped.putIfAbsent(
            branchId,
            () => {
              'branchId': branchId,
              'branchName': (b['branchName'] ?? '').toString(),
              'company': companyName,
              'companyid': companyId,
              'cashSales': 0.0,
              'merchantmomo': 0.0,
              'card': 0.0,
              'bank': 0.0,
              'hubtel': 0.0,
              'cheque': 0.0,
              'creditSales': 0.0,
              'cashReturns': 0.0,
              'creditReturns': 0.0,
              'totalReturns': 0.0,
              'discount': 0.0,
              'returnDiscount': 0.0,
              'profit': 0.0,
              'returnProfit': 0.0,
              'branchdebt': 0.0,
              'sales_qty': 0.0,
            },
          );

          final cashReturns = _d(it['cash_returns']);
          final creditReturns = _d(it['credit_returns']);
          final returnDiscount = _d(it['return_discount']);
          final returnProfit = _d(it['return_profit']);

          final momo = _d(it['merchantmomo'] ?? it['momo']);
          final card = _d(it['card']);
          final bank = _d(
            it['bank'] ?? it['bank_transfer'] ?? it['bank transfer'],
          );
          final cheque = _d(it['cheque']);
          final hubtel = _d(it['hubtel']);
          final rawCash = _d(it['cash']);

          final netCash = (rawCash - momo - card - bank - cheque - hubtel)
              .toDouble();

          e['cashSales'] += netCash;
          e['merchantmomo'] += momo;
          e['card'] += card;
          e['bank'] += bank;
          e['cheque'] += cheque;
          e['hubtel'] += hubtel;
          e['creditSales'] += _d(it['credit']);
          e['cashReturns'] += cashReturns;
          e['creditReturns'] += creditReturns;
          e['totalReturns'] += cashReturns + creditReturns;
          e['discount'] += _d(it['discount']) - returnDiscount;
          e['returnDiscount'] += returnDiscount;
          e['profit'] += _d(it['profit']) - returnProfit;
          e['returnProfit'] += returnProfit;
          e['sales_qty'] += _d(it['sales_qty']);
        }
      }
    }

    return grouped.values.toList();
  }

  Future<void> fetchsalesregisterreport({
    DateTimeRange? selectedDate,
    String? selectedBranch,
  }) async {
    try {
      isloadingsalesreport = true;
      notifyListeners();
      report.clear();
      final now = DateTime.now();

      final startDate = selectedDate?.start ?? now;
      final endDate = selectedDate?.end ?? now;

      final ids = datafeed.generateIds(companyid, startDate, endDate);

      final snap = await db
          .collection('salesSummary')
          .where(FieldPath.documentId, whereIn: ids)
          .get(const GetOptions(source: Source.serverAndCache));

      if (snap.docs.isNotEmpty) {
        report = snap.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        report = extractItems(report, selectedBranch);
      } else {
        report = [];
      }
    } catch (e) {
      debugPrint("Error fetching Sales salesSummary: $e");
      report = [];
    } finally {
      isloadingsalesreport = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _rawStockDocs = [];
  final Map<String, List<Map<String, dynamic>>> _stockReportRawCache = {};
  DateTime _stockStartDate = DateTime.now();
  bool isLoadingStockReport = false;
  bool stockReportHasVisibleData = false;
  bool stockReportOffline = false;
  String? stockReportError;
  int _stockReportRequestGeneration = 0;

  void applyStockBranch(String? selectedBranch) {
    if (_rawStockDocs.isEmpty) return;
    stockreport = extractstockReport(
      _rawStockDocs,
      selectedBranch,
      _stockStartDate,
    );
    notifyListeners();
  }

  Future<void> fetchstockreport({
    DateTimeRange? selectedDate,
    String? selectedBranch,
  }) async {
    final requestGeneration = ++_stockReportRequestGeneration;
    final now = DateTime.now();
    final startDate = DateTime(
      (selectedDate?.start ?? now).year,
      (selectedDate?.start ?? now).month,
      (selectedDate?.start ?? now).day,
    );
    final endDate = DateTime(
      (selectedDate?.end ?? now).year,
      (selectedDate?.end ?? now).month,
      (selectedDate?.end ?? now).day,
    );
    final startStr = _toDateOnly(startDate);
    final endStr = _toDateOnly(endDate);
    final cacheKey = '$companyid|$startStr|$endStr';
    final openingQuery = db
        .collection('stockreport')
        .where('summarydate', isLessThan: startStr)
        .where('companyid', isEqualTo: companyid);
    final currentQuery = db
        .collection('stockreport')
        .where('summarydate', isGreaterThanOrEqualTo: startStr)
        .where('summarydate', isLessThanOrEqualTo: endStr)
        .where('companyid', isEqualTo: companyid);

    try {
      isLoadingStockReport = true;
      stockReportError = null;
      stockReportOffline = false;
      final cachedRaw = _stockReportRawCache[cacheKey];
      if (cachedRaw != null) {
        _rawStockDocs = cachedRaw;
        _stockStartDate = startDate;
        stockreport = extractstockReport(cachedRaw, selectedBranch, startDate);
        stockReportHasVisibleData = true;
      } else {
        stockReportHasVisibleData = false;
        stockreport = [];
      }
      notifyListeners();

      await datafeed.loadQueryPairCacheFirst(
        openingQuery,
        currentQuery,
        isCurrent: () => requestGeneration == _stockReportRequestGeneration,
        label: 'Stock report',
        onRefreshError: (error) {
          stockReportOffline =
              error is FirebaseException && error.code == 'unavailable';
          stockReportError = stockReportOffline
              ? null
              : 'Could not refresh the stock report.';
          notifyListeners();
        },
        apply: (openingSnapshot, currentSnapshot) {
          final allDocs = [...openingSnapshot.docs, ...currentSnapshot.docs];
          final raw = allDocs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['_docId'] = doc.id;
            return data;
          }).toList();
          _rawStockDocs = raw;
          _stockStartDate = startDate;
          _stockReportRawCache.remove(cacheKey);
          _stockReportRawCache[cacheKey] = raw;
          if (_stockReportRawCache.length > 5) {
            _stockReportRawCache.remove(_stockReportRawCache.keys.first);
          }
          stockreport = raw.isEmpty
              ? []
              : extractstockReport(raw, selectedBranch, startDate);
          stockReportHasVisibleData = true;
          stockReportOffline = false;
          stockReportError = null;
          notifyListeners();
        },
      );
    } catch (e) {
      if (requestGeneration != _stockReportRequestGeneration) return;
      debugPrint('Stock report load failed: $e');
      stockReportOffline = e is FirebaseException && e.code == 'unavailable';
      stockReportError = stockReportOffline
          ? null
          : 'Could not refresh the stock report.';
      if (!stockReportHasVisibleData) stockreport = [];
    } finally {
      if (requestGeneration == _stockReportRequestGeneration) {
        isLoadingStockReport = false;
        notifyListeners();
      }
    }
  }

  List<Map<String, dynamic>> extractstockReport(
    List<Map<String, dynamic>> rawReport,
    String? selectedBranch,
    DateTime startDate,
  ) {
    final grouped = <String, Map<String, dynamic>>{};

    double getNum(dynamic v) =>
        v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

    final isCompanyView = selectedBranch == null || selectedBranch.isEmpty;
    final startStr = _toDateOnly(startDate);

    final salesPointIds = branches
        .where(
          (b) =>
              b.branchtype.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') ==
              'salespoint',
        )
        .map((b) => b.id.toLowerCase())
        .toSet();

    for (final doc in rawReport) {
      final summaryDateStr = doc['summarydate']?.toString();
      if (summaryDateStr == null || summaryDateStr.isEmpty) continue;

      final isBeforeStart = summaryDateStr.compareTo(startStr) < 0;

      final itemsRaw = doc['items'];
      if (itemsRaw is! Map<String, dynamic>) continue;

      final itemsRoot = Map<String, dynamic>.from(itemsRaw);

      Iterable<String> branchIds;
      // if (isCompanyView) {
      //   branchIds = itemsRoot.keys;
      // }
      if (isCompanyView) {
        branchIds = itemsRoot.keys.where(
          (k) => !salesPointIds.contains(k.toLowerCase()),
        );
      } else {
        if (!itemsRoot.containsKey(selectedBranch)) continue;
        branchIds = [selectedBranch];
      }

      for (final branchId in branchIds) {
        final branchItemsRaw = itemsRoot[branchId];
        if (branchItemsRaw is! Map<String, dynamic>) continue;

        final branchItems = Map<String, dynamic>.from(branchItemsRaw);
        final branchName = isCompanyView
            ? company
            : (branchItems['branchName'] ?? branchId);

        for (final entry in branchItems.entries) {
          if (entry.value is! Map<String, dynamic>) continue;

          final item = Map<String, dynamic>.from(entry.value);
          final producttype = (item['producttype'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (producttype == 'service') continue;
          // map key (entry.key)

          final itemId = item['itemId']?.toString()?.trim().isNotEmpty == true
              ? item['itemId'].toString().trim()
              : item['itemid']?.toString()?.trim().isNotEmpty == true
              ? item['itemid'].toString().trim()
              : entry.key.trim();

          if (itemId.isEmpty) continue;

          final groupKey = isCompanyView ? itemId : '${branchId}_$itemId';

          // resolve item name
          final name = item['itemName']?.toString().trim() ?? '';

          final name2 = item['item']?.toString().trim() ?? '';
          final finalName = name.isNotEmpty
              ? name
              : name2.isNotEmpty
              ? name2
              : itemId;

          //  initialize with zeros —
          grouped.putIfAbsent(
            groupKey,
            () => {
              'branchId': isCompanyView ? '' : branchId,
              'branch': branchName,
              'itemid': itemId,
              'item': finalName,
              'itemcp': item['costprice'] ?? item['cp'] ?? '',
              'itemsp': item['sellingprice'] ?? item['sp'] ?? '',
              'barcode': item['barcode'] ?? '',
              'opening_stock': 0.0,
              'newstock': 0.0,
              'sale_returns': 0.0,
              'cash_sales': 0.0,
              'sales_qty': 0.0,
              'credit_sales': 0.0,
              'purchase_returns': 0.0,
              'damages': 0.0,
              'transfer_qty': 0.0,
              'Box': 0.0,
              'cartonqty_bal': 0.0,
              '_latest_date': '',
              'transfer_recieved_qty': 0.0,
              'producttype': '',
              'pcategory': '',
              'stock_value': 0.0,
              'selling_value': 0.0,
            },
          );

          final existing = grouped[groupKey]!;

          //name/barcode
          if (existing['item'] == itemId && finalName != itemId) {
            existing['item'] = finalName;
          }
          if ((existing['barcode'] as String).isEmpty &&
              (item['barcode'] ?? '').toString().isNotEmpty) {
            existing['barcode'] = item['barcode'].toString();
          }

          if ((item['costprice'] ?? item['cp'] ?? '').toString().isNotEmpty) {
            existing['itemcp'] = item['costprice'] ?? item['cp'];
          }
          if ((item['sellingprice'] ?? item['sp'] ?? '')
              .toString()
              .isNotEmpty) {
            existing['itemsp'] = item['sellingprice'] ?? item['sp'];
          }
          if (isBeforeStart) {
            // Opening balance accumulation
            existing['opening_stock'] +=
                (getNum(item['newstock']) +
                    (isCompanyView
                        ? 0.0
                        : getNum(item['transfer_recieved_qty']))) -
                (getNum(item['sales_qty']) +
                    (isCompanyView ? 0.0 : getNum(item['transfer_qty'])) +
                    getNum(item['damage_qty']) +
                    getNum(item['purchaseReturn_qty']));
            final bpBefore = getNum(item['boxpieces']);
            if (bpBefore > 0) existing['cartonqty_bal'] = bpBefore;
          } else {
            // Current period — accumulate all fields
            existing['newstock'] += getNum(item['newstock']);
            existing['sale_returns'] += getNum(item['salesReturn_qty']);
            existing['transfer_recieved_qty'] += getNum(
              item['transfer_recieved_qty'],
            );
            existing['sales_qty'] += getNum(item['sales_qty']);

            final bp = getNum(item['boxpieces']);
            if (bp > 0) existing['cartonqty_bal'] = bp;

            existing['cash_sales'] += getNum(item['cash_sales']);
            existing['credit_sales'] += getNum(item['credit_sales']);
            existing['purchase_returns'] += getNum(item['purchaseReturn_qty']);
            existing['damages'] += getNum(item['damage_qty']);
            existing['transfer_qty'] += getNum(item['transfer_qty']);
          }

          existing['_latest_date'] = summaryDateStr;
          final bpLatest = getNum(item['boxpieces']);
          if (bpLatest > 0) existing['cartonqty_bal'] = bpLatest;

          final ptRaw = (item['producttype'] ?? '').toString().trim();
          if (ptRaw.isNotEmpty) existing['producttype'] = ptRaw;
          final pcRaw = (item['pcategory'] ?? item['category'] ?? '')
              .toString()
              .trim();
          if (pcRaw.isNotEmpty) existing['pcategory'] = pcRaw;
        }
      }
    }

    // Compute final totals
    for (final item in grouped.values) {
      item['total_stock'] =
          item['opening_stock'] +
          item['newstock'] +
          (isCompanyView ? 0.0 : item['transfer_recieved_qty']);

      item['stock_out'] =
          item['sales_qty'] +
          item['purchase_returns'] +
          item['damages'] +
          (isCompanyView ? 0.0 : item['transfer_qty']);

      item['balance_cd'] = item['total_stock'] - item['stock_out'];

      final bal = _toDouble(item['balance_cd']);
      item['stock_value'] = bal * _toDouble(item['itemcp']);
      item['selling_value'] = bal * _toDouble(item['itemsp']);
    }

    return grouped.values.toList();
  }

  List<Map<String, dynamic>> filterstockreport({
    String? productType,
    String? category,
    String? status,
  }) {
    final q = stockReportSearchQuery.toLowerCase();
    final byId = _itemById;

    return stockreport.where((s) {
      final balance = _toDouble(s['balance_cd']);
      if (status == 'Finished' && balance > 0) return false;
      if (status == 'Reorder' && !(balance > 0 && balance <= reorderLevel))
        return false;
      if (productType != null &&
          _stockField(s, 'producttype', byId) != productType)
        return false;
      if (category != null && _stockField(s, 'pcategory', byId) != category)
        return false;
      if (q.isEmpty) return true;

      return [
        s['branch'],
        s['itemid'],
        s['item'],
        s['barcode'],
        s['balance_cd'],
        s['total_stock'],
      ].any((f) => (f ?? '').toString().toLowerCase().contains(q));
    }).toList();
  }

  List<Map<String, dynamic>> filterFinishedstockreport() {
    final q = searchQuery.toLowerCase();

    return stockreport.where((s) {
      final balance = double.tryParse(s['balance_cd'].toString()) ?? 0;

      // Only include records with 0 balance
      if (balance != 0) return false;

      // If no search text, return all zero-balance records
      if (searchQuery.isEmpty) return true;

      final branch = (s['branch'] ?? '').toString().toLowerCase();
      final itemId = (s['itemid'] ?? '').toString().toLowerCase();
      final itemName = (s['item'] ?? '').toString().toLowerCase();
      final barcode = (s['barcode'] ?? '').toString().toLowerCase();
      final totalStock = (s['total_stock'] ?? '').toString().toLowerCase();

      return branch.contains(q) ||
          itemId.contains(q) ||
          itemName.contains(q) ||
          barcode.contains(q) ||
          totalStock.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> filterReOrderstockreport() {
    final q = searchQuery.toLowerCase();

    return stockreport.where((s) {
      final balance = double.tryParse(s['balance_cd'].toString()) ?? 0;

      // Only include records with balance less than 10
      if (balance >= 10) return false;

      // If no search text, return all matching records
      if (searchQuery.isEmpty) return true;

      final branch = (s['branch'] ?? '').toString().toLowerCase();
      final itemId = (s['itemid'] ?? '').toString().toLowerCase();
      final itemName = (s['item'] ?? '').toString().toLowerCase();
      final barcode = (s['barcode'] ?? '').toString().toLowerCase();
      final totalStock = (s['total_stock'] ?? '').toString().toLowerCase();

      return branch.contains(q) ||
          itemId.contains(q) ||
          itemName.contains(q) ||
          barcode.contains(q) ||
          totalStock.contains(q);
    }).toList();
  }

  String _stockField(
    Map<String, dynamic> r,
    String key,
    Map<String, ItemModel> byId,
  ) {
    final v = (r[key] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
    final it = byId['${r['itemid']}'];
    if (it == null) return '';
    return (key == 'pcategory' ? it.pcategory : it.producttype ?? '')
        .toString()
        .trim();
  }

  List<String> get stockProductTypes {
    final byId = _itemById;
    return stockreport
        .map((r) => _stockField(r, 'producttype', byId))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get stockCategories {
    final byId = _itemById;
    return stockreport
        .map((r) => _stockField(r, 'pcategory', byId))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<Map<String, dynamic>> FetchBranchBalances({
    String? branchId,
    String? search,
  }) {
    if (stockreport.isEmpty) return [];

    var result = stockreport
        .where((r) {
          if (branchId == null || branchId.isEmpty)
            return true; // all items pass
          final rBranch = (r['branchId'] ?? r['branchkey'] ?? '')
              .toString()
              .toLowerCase();
          return rBranch == branchId.toLowerCase();
        })
        .map((r) {
          final balance = _toDouble(r['balance_cd']);
          final boxpieces = _toDouble(r['cartonqty_bal']);
          final cartonBalance = boxpieces > 0 ? balance / boxpieces : 0.0;

          return {
            'item': r['item'] ?? '',
            'itemcp': r['itemcp'] ?? '',
            'itemsp': r['itemsp'] ?? '',
            'itemid': r['itemid'] ?? '',
            'branch': r['branch'] ?? '',
            'branchkey': r['branchId'] ?? '',
            'balance': balance,
            'carton_qty': boxpieces,
            'carton_balance': cartonBalance,
          };
        })
        .toList();

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result
          .where(
            (r) =>
                r['item'].toString().toLowerCase().contains(q) ||
                r['branch'].toString().toLowerCase().contains(q) ||
                r['itemid'].toString().toLowerCase().contains(q),
          )
          .toList();
    }

    return result;
  }

  Map<String, Map<String, double>> stockLevelCounts({
    String? companyId,
    String? branchId,
  }) {
    final cid = (companyId ?? companyid).trim().toLowerCase();
    final docs = _rawStockDocs
        .where(
          (d) => (d['companyid'] ?? '').toString().trim().toLowerCase() == cid,
        )
        .toList();

    Map<String, double> count(String? branch) {
      double finished = 0, reorder = 0;
      for (final s in extractstockReport(docs, branch, _stockStartDate)) {
        final bal = _toDouble(s['balance_cd']);
        if (bal <= 0) {
          finished++;
        } else if (bal <= reorderLevel) {
          reorder++;
        }
      }
      return {'finished': finished, 'reorder': reorder};
    }

    return {
      'company': count(null),
      if (branchId != null && branchId.trim().isNotEmpty)
        'branch': count(branchId),
    };
  }
}
