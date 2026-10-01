import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../providers/Datafeed.dart';
import 'staffreportsalespdf.dart';

class SalesStaffDialogs {
  final hh = ScrollController();   // was _hhController
  final vv = ScrollController();   // was _vvController
  final h  = ScrollController();   // was _hController
  final v  = ScrollController();   // was _vController
  bool _canManageFilters(Datafeed value) => value.canDeleteRecords;

  DateTimeRange get _todayRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: today, end: today);
  }
  void dispose() { hh.dispose(); vv.dispose(); h.dispose(); v.dispose(); }

  /// Staff summary for ONE branch (the old showSalesStaffDialog)
  Future<void> showStaffSummary(
      BuildContext context, {
        required DateTimeRange? dateRange,
        required String branchId,
        required String branchName,
      }) async {
    // ... paste body of showSalesStaffDialog here ...
  }

  /// Staff's transactions (the old showSalesStaffTransactionsDialog)
  Future<void> showStaffTransactions(
      BuildContext context, {
        required DateTimeRange? dateRange,
        required String? branchId,
        required String branchLabel,
        required String staffName,
        required String staffEmail,
      }) async {
    // ... paste body here ...
  }
}