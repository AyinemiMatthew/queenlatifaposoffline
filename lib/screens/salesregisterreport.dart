
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../providers/Datafeed.dart';
import '../widgets/staffreportsalespdf.dart';

  class SalesRegister extends StatefulWidget {
    const SalesRegister({super.key});

    @override
    State<SalesRegister> createState() => _SalesRegisterState();
  }

  class _SalesRegisterState extends State<SalesRegister> {
    String searchQuery = '';
    late final TextEditingController searchController;
    DateTimeRange? selectedDate;
    String? _selectedBranch;


    late final ScrollController _vController;
    late final ScrollController _hController;
    late final ScrollController _vvController;
    late final ScrollController _hhController;

    // Scroll controllers for the main report table.
    late final ScrollController _tableVController;
    late final ScrollController _tableHController;

    bool _isSearching = false;
    final FocusNode _searchFocusNode = FocusNode();
    final GlobalKey _branchKey = GlobalKey();


    bool _canManageFilters(Datafeed value) => value.canDeleteRecords;

    DateTimeRange get _todayRange {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return DateTimeRange(start: today, end: today);
    }


    @override
    void initState() {
      super.initState();

      _vController = ScrollController();
      _hController = ScrollController();
      _vvController = ScrollController();
      _hhController = ScrollController();
      _tableVController = ScrollController();
      _tableHController = ScrollController();
      searchController = TextEditingController();

      Future.microtask(() async {
        if (!mounted) return;

        final provider = context.read<Datafeed>();
        await provider.fetchBranches();

        final canManage = _canManageFilters(provider);

        if (!canManage) {
          _selectedBranch = provider.branchid;
          selectedDate = _todayRange;
        }

        await provider.fetchsalesregister(
          selectedDate: selectedDate,
          selectedBranch: _selectedBranch,
        );
      });
    }

    @override
    void dispose() {
      _vController.dispose();
      _hController.dispose();
      _vvController.dispose();
      _hhController.dispose();
      _tableVController.dispose();
      _tableHController.dispose();
      searchController.dispose();
      _searchFocusNode.dispose();
      super.dispose();
    }


    Future<void> _applyFilters() async {
      await context.read<Datafeed>().fetchsalesregister(
        selectedDate: selectedDate,
        selectedBranch: _selectedBranch == 'All' ? null : _selectedBranch,
      );
    }

    void _showDateRangePicker() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF101624),
            title: const Text('Select Date Range', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            height: 400,
            width: 320,
            child: SfDateRangePicker(
              backgroundColor: const Color(0xFF0F172A),
              headerStyle: const DateRangePickerHeaderStyle(
                backgroundColor: Color(0xFF1E293B),
                textAlign: TextAlign.center,
                textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
              ),
              monthViewSettings: const DateRangePickerMonthViewSettings(
                viewHeaderStyle: DateRangePickerViewHeaderStyle(
                  textStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                ),
              ),
              monthCellStyle: DateRangePickerMonthCellStyle(
                textStyle: const TextStyle(color: Colors.white),
                todayTextStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                weekendTextStyle: const TextStyle(color: Colors.white60),
                disabledDatesTextStyle: const TextStyle(color: Colors.white24),
              ),
              selectionColor: Colors.blueAccent,
              startRangeSelectionColor: Colors.blueAccent,
              endRangeSelectionColor: Colors.blueAccent,
              rangeSelectionColor: Colors.blueAccent.withOpacity(0.15),
              todayHighlightColor: Colors.blueAccent,
              selectionTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                if (args.value is PickerDateRange) {
                  final range = args.value as PickerDateRange;
                  setState(() {
                    selectedDate = DateTimeRange(
                      start: range.startDate!,
                      end: range.endDate ?? range.startDate!,
                    );
                  });
                }
              },
              selectionMode: DateRangePickerSelectionMode.range,
              initialSelectedRange:
              selectedDate != null ? PickerDateRange(selectedDate!.start, selectedDate!.end) : null,
            ),
          ),
            actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => selectedDate = null);
                await _applyFilters();
              },
              child: const Text('Clear', style: TextStyle(color: Color(0xFF9CA3AF))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
    }

    String _formatDateRange() {
      if (selectedDate == null) return 'All dates';
      return '${DateFormat('dd MMM yyyy').format(selectedDate!.start)} - '
          '${DateFormat('dd MMM yyyy').format(selectedDate!.end)}';
    }

    String capitalize(String? text) {
      if (text == null || text.isEmpty) return '';
      return text[0].toUpperCase() + text.substring(1);
    }

    bool get _isTodayActive {
      if (selectedDate == null) return false;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(selectedDate!.start.year, selectedDate!.start.month, selectedDate!.start.day);
      final end = DateTime(selectedDate!.end.year, selectedDate!.end.month, selectedDate!.end.day);
      return start == today && end == today;
    }

    void _toggleToday() {
      setState(() {
        selectedDate = _isTodayActive ? null : _todayRange;
      });
      _applyFilters();
    }

    void _openSearch() {
      setState(() => _isSearching = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }

    void _closeSearch(Datafeed value) {
      setState(() {
        _isSearching = false;
        searchController.clear();
      });
      value.updateSearch('');
    }

    void _showBranchMenu(BuildContext context, Datafeed value) {
      final RenderBox button = _branchKey.currentContext!.findRenderObject() as RenderBox;
      final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
      final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

      final position = RelativeRect.fromRect(
        Rect.fromLTWH(buttonPosition.dx, buttonPosition.dy + button.size.height, button.size.width, 0),
        Offset.zero & overlay.size,
      );

      showMenu<String?>(
        context: context,
        position: position,
        color: const Color(0xFF1B263B),
        items: [
          const PopupMenuItem<String?>(
            value: '__ALL__',
            child: Text('All Branches', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          ...{for (final b in value.branches) b.id: b}
              .values.where((b) => b.branchname != 'Warehouse')
              .where((b) => b.id != null && b.id!.isNotEmpty)
              .map(
                (b) => PopupMenuItem<String?>(
                  value: b.id!,
              child: Text(b.branchname, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
        ],
      ).then((selected) {
        if (selected == null) return;
        setState(() {
          _selectedBranch = selected == '__ALL__' ? null : selected;
        });
        _applyFilters();
      });
    }

    String _branchLabel(Datafeed value) {
      if (!_canManageFilters(value)) return value.branch;
      if (_selectedBranch == null) return 'All Branches';
      final matches = value.branches.where((b) => b.id == _selectedBranch);
      if (matches.isEmpty) return 'All Branches';
      return matches.first.branchname;
    }


    List<Map<String, dynamic>> _groupByBranch(List<dynamic> list) {
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final raw in list) {
        final item = raw as Map;
        final branchName = item['branchName']?.toString() ?? 'Unknown';
        final branchId = (item['branchId'] ?? item['branchid'] ?? branchName).toString();

        final row = grouped.putIfAbsent(branchId, () => {
          'branchId': branchId,
          'branchName': branchName,
          'cashSales': 0.0,
          'merchantmomo': 0.0,
          'hubtel': 0.0,
          'card': 0.0,
          'bank': 0.0,
          'cheque': 0.0,
          'cashReturns': 0.0,
          'creditSales': 0.0,
          'creditReturns': 0.0,
          'cashDiscount': 0.0,
          'creditDiscount': 0.0,
          'damages': 0.0,
          'profit': 0.0,
          'debtPayment': 0.0,
          'cashAtHand': 0.0,
        });

        for (final k in const [
          'cashSales',
          'merchantmomo',
          'hubtel',
          'card',
          'bank',
          'cheque',
          'cashReturns',
          'creditSales',
          'creditReturns',
          'cashDiscount',
          'creditDiscount',
          'damages',
          'profit',
          'debtPayment',
          'cashAtHand',
        ]) {
          row[k] = (row[k] as double) + ((item[k] ?? 0) as num).toDouble();
        }
      }

      final rows = grouped.values.toList();
      rows.sort((a, b) => (a['branchName'] as String).compareTo(b['branchName'] as String));
      return rows;
    }

    Map<String, double> _grandTotals(List<Map<String, dynamic>> branchRows) {
      final totals = <String, double>{
        'cashSales': 0.0,
        'cashReturns': 0.0,
        'creditSales': 0.0,
        'creditReturns': 0.0,
        'cashDiscount': 0.0,
        'creditDiscount': 0.0,
        'damages': 0.0,
        'profit': 0.0,
        'debtPayment':0.0,
        'cashAtHand': 0.0,
      };
      for (final row in branchRows) {
        for (final k in totals.keys.toList()) {
          totals[k] = totals[k]! + (row[k] as double);
        }
      }
      return totals;
    }

    String _cashAtHandTooltip({
      required double cashSales,
      required double cashReturns,
    //  required double damages,
      required double cashAtHand,
    }) {
      return 'Cash Sales: ${cashSales.toStringAsFixed(2)}\n'
          'Cash Returns: -${cashReturns.toStringAsFixed(2)}\n'
        //  'Damages: -${damages.toStringAsFixed(2)}\n\n'
          'Cash @ Hand: ${cashAtHand.toStringAsFixed(2)}';
    }

    String _fmtPeriod(dynamic d) {
      final f = DateFormat('dd MMMM yyyy, hh:mm a');
      if (d is DateTimeRange) return '${f.format(d.start)}  -  ${f.format(d.end)}';
      if (d is DateTime) return f.format(d);
      return d?.toString() ?? '-';
    }



    Future<void> _printMainReport(Datafeed provider, List<Map<String, dynamic>> branchRows, Map<String, double> grandTotals) async {
      String fmt(dynamic v) {
        if (v == null) return '0.00';
        final d = double.tryParse(v.toString()) ?? 0.0;
        return d.toStringAsFixed(2);
      }

      String t(double v) => v.toStringAsFixed(2);

      final nf = NumberFormat('#,##0.00');
      String money(double v) => 'GHC ${nf.format(v)}';

      final ttfRegular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      final ttfBold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));


      var staffRows = <_StaffRow>[];
      try {
        final now = DateTime.now();
        final start = selectedDate?.start ?? now;
        final end = selectedDate?.end ?? now;

        final branch = _selectedBranch?.trim() ?? '';
        final filterByBranch = branch.isNotEmpty && branch.toLowerCase() != 'all';

        await provider.loadSalesStaffSummary(
          startDate: start,
          endDate: end,
          shouldFilterByBranch: filterByBranch,
          selectedBranchId: branch.toLowerCase(),
        );

        staffRows = provider
            .filteredSalesStaffRows()
            .map((m) => _StaffRow.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      } catch (e) {
        debugPrint('Payment totals error: $e');
      }

      double sum(double Function(_StaffRow) f) =>
          staffRows.fold(0.0, (a, r) => a + f(r));

      // Payments = what was actually received per method (sales + debt payments).
      final payments = <MapEntry<String, double>>[
        MapEntry('Cash', sum((r) => r.cashSales + r.debtCash)),
        for (final m in _kPayMethods) MapEntry(m.label, sum((r) => r.methodTotal(m))),
        MapEntry('Debt Payments', sum((r) => r.debtTotal)),
      ].where((e) => e.value > 0).toList();

      final rows = branchRows.asMap().entries.map((entry) {
        final i = entry.key + 1;
        final item = entry.value;
        final returns = (item['cashReturns'] as double) + (item['creditReturns'] as double);
        final discount = (item['cashDiscount'] as double) + (item['creditDiscount'] as double);
        return [
          '$i',
          item['branchName']?.toString() ?? '',
          fmt(item['cashSales']),
          fmt(item['merchantmomo']),
          fmt(item['hubtel']),
          fmt(item['card']),
          fmt(item['bank']),
          fmt(item['cheque']),
          fmt(item['creditSales']),
          fmt(returns),
          fmt(discount),
          fmt(item['profit']),
          fmt(item['debtPayment']),
          fmt(item['cashAtHand']),
        ];
      }).toList();

      final totalReturns = grandTotals['cashReturns']! + grandTotals['creditReturns']!;
      final totalDiscount = grandTotals['cashDiscount']! + grandTotals['creditDiscount']!;

      final headers = [
        '#', 'BRANCH', 'CASH SALES', 'MOMO', 'HUBTEL', 'CARD', 'BANK', 'CHEQUE',
        'CREDIT SALES',
        'RETURNS', 'DISCOUNT', 'PROFIT','DEBT PAYMENT', 'CASH @ HAND',
      ];
      final widths = [
        22.0, 70.0, 60.0, 55.0, 55.0, 55.0, 55.0, 55.0,
        60.0, 55.0, 55.0, 50.0, 55.0, 60.0,
      ];

      final totalsRow = [
        '',
        'TOTAL',
        t(grandTotals['cashSales']!),
        t(_paymentTotal(branchRows, 'merchantmomo')),
        t(_paymentTotal(branchRows, 'hubtel')),
        t(_paymentTotal(branchRows, 'card')),
        t(_paymentTotal(branchRows, 'bank')),
        t(_paymentTotal(branchRows, 'cheque')),
        t(grandTotals['creditSales']!),
        t(totalReturns),
        t(totalDiscount),
        t(grandTotals['profit']!),
        t(grandTotals['debtPayment']!),
        t(grandTotals['cashAtHand']!),
      ];

      pw.Widget cell(String text, int col, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 5),
        child: pw.Text(
          text,
          textAlign: col < 2 ? pw.TextAlign.left : pw.TextAlign.right,
          style: pw.TextStyle(font: bold ? ttfBold : ttfRegular, fontSize: 10),
        ),
      );


      pw.Widget payRow(String label, double value, {bool right = false}) =>
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              mainAxisAlignment:
              right ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
              children: [
                pw.Text('$label:  ', style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                pw.Text(money(value),
                    style: pw.TextStyle(font: ttfRegular, fontSize: 10)),
              ],
            ),
          );

      // split payments into left / right columns like the receipt heading
      final half = (payments.length / 2).ceil();
      final leftPay = payments.take(half).toList();
      final rightPay = payments.skip(half).toList();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context ctx) => [
            // ── Heading
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      provider.company.toString().toUpperCase(),
                      style: pw.TextStyle(font: ttfBold, fontSize: 22),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Branch: ${_branchLabel(provider)}',
                      style: pw.TextStyle(
                          font: ttfRegular, fontSize: 11, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'SALES REGISTER',
                      style: pw.TextStyle(font: ttfBold, fontSize: 18),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _fmtPeriod(selectedDate),
                      style: pw.TextStyle(font: ttfRegular, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),

            // ── Payments received, in the heading (plain rows, no box)
            if (payments.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [for (final e in leftPay) payRow(e.key, e.value)],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        for (final e in rightPay)
                          payRow(e.key, e.value, right: true),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            pw.SizedBox(height: 14),

            // ── Table: only header line and totals line
            pw.Table(
              columnWidths: {
                for (var i = 0; i < widths.length; i++)
                  i: pw.FlexColumnWidth(widths[i]),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey, width: 0.8),
                    ),
                  ),
                  children: [
                    for (var i = 0; i < headers.length; i++)
                      cell(headers[i], i, bold: true),
                  ],
                ),
                ...rows.map((r) => pw.TableRow(
                  children: [
                    for (var c = 0; c < r.length; c++) cell(r[c], c),
                  ],
                )),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey, width: 0.8),
                    ),
                  ),
                  children: [
                    for (var c = 0; c < totalsRow.length; c++)
                      cell(totalsRow[c], c, bold: true),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            // ── Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                      font: ttfRegular, fontSize: 9, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Sales Register - ${provider.company}',
                  style: pw.TextStyle(
                      font: ttfRegular, fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    }

    Future<void> _printStaffSummary({ required Datafeed provider, required List<_StaffRow> rows, required List<_PayMethod> pdfMethods,  String? branchName,  }) async {
      final nf = NumberFormat('#,##0.00');
      String money(double v) => 'GHC ${nf.format(v)}';

      final ttfRegular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
      final ttfBold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

      double sum(double Function(_StaffRow) f) => rows.fold(0.0, (a, r) => a + f(r));

      // ── Table
      final headers = <String>[
        '#',
        'STAFF',
        'CASH ',
        'CREDIT ',
        'RETURNS',
        'DISCOUNT',
        'DEBT',
        ...pdfMethods.map((m) => m.pdfLabel.toUpperCase()),
        'PROFIT',
        'CASH@HAND',
      ];

      final flex = <double>[
        3, 16, 11, 11, 10, 10, 11,
        ...pdfMethods.map((_) => 10.0),
        10, 11,
      ];

      final pdfRows = <List<String>>[
        for (int i = 0; i < rows.length; i++)
          [
            '${i + 1}',
            rows[i].staff,
            _f(rows[i].cashSales),
            _f(rows[i].creditSales),
            _f(rows[i].returns),
            _f(rows[i].discount),
            _f(rows[i].debtTotal),
            for (final m in pdfMethods) _f(rows[i].methodTotal(m)),
            _f(rows[i].profit),
            _f(rows[i].cashAtHand),
          ],
      ];

      final totalsRow = <String>[
        '',
        'TOTAL',
        _f(sum((r) => r.cashSales)),
        _f(sum((r) => r.creditSales)),
        _f(sum((r) => r.returns)),
        _f(sum((r) => r.discount)),
        _f(sum((r) => r.debtTotal)),
        for (final m in pdfMethods) _f(sum((r) => r.methodTotal(m))),
        _f(sum((r) => r.profit)),
        _f(sum((r) => r.cashAtHand)),
      ];

      // ── Payments in the heading: only what is NOT already a table column.
      final payments = <MapEntry<String, double>>[
        MapEntry('Cash', sum((r) => r.cashSales + r.debtCash)),
        for (final m in _kPayMethods)
          if (!pdfMethods.any((p) => p.id == m.id))
            MapEntry(m.label, sum((r) => r.methodTotal(m))),
      ].where((e) => e.value > 0).toList();

      final half = (payments.length / 2).ceil();
      final leftPay = payments.take(half).toList();
      final rightPay = payments.skip(half).toList();

      final wide = headers.length > 10;
      final fontSize = wide ? 8.5 : 10.0;

      pw.Widget cell(String text, int col, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: pw.Text(
          text,
          textAlign: col < 2 ? pw.TextAlign.left : pw.TextAlign.right,
          style: pw.TextStyle(
              font: bold ? ttfBold : ttfRegular, fontSize: fontSize),
        ),
      );

      pw.Widget payRow(String label, double value, {bool right = false}) =>
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              mainAxisAlignment:
              right ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
              children: [
                pw.Text('$label:  ',
                    style: pw.TextStyle(font: ttfBold, fontSize: 10)),
                pw.Text(money(value),
                    style: pw.TextStyle(font: ttfRegular, fontSize: 10)),
              ],
            ),
          );

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: wide ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context ctx) => [
            // ── Heading
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      provider.company.toString().toUpperCase(),
                      style: pw.TextStyle(font: ttfBold, fontSize: 22),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Branch: ${branchName ?? _branchLabel(provider)}',
                      style: pw.TextStyle(
                          font: ttfRegular, fontSize: 11, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'STAFF SUMMARY',
                      style: pw.TextStyle(font: ttfBold, fontSize: 18),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _fmtPeriod(selectedDate),
                      style: pw.TextStyle(font: ttfRegular, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),

            // ── Payments received in the heading (plain rows, no box)
            if (payments.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [for (final e in leftPay) payRow(e.key, e.value)],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        for (final e in rightPay)
                          payRow(e.key, e.value, right: true),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            pw.SizedBox(height: 14),

            // ── Table: only header line and totals line
            pw.Table(
              columnWidths: {
                for (var i = 0; i < flex.length; i++) i: pw.FlexColumnWidth(flex[i]),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey, width: 0.8),
                    ),
                  ),
                  children: [
                    for (var i = 0; i < headers.length; i++)
                      cell(headers[i], i, bold: true),
                  ],
                ),
                ...pdfRows.map((r) => pw.TableRow(
                  children: [
                    for (var c = 0; c < r.length; c++) cell(r[c], c),
                  ],
                )),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey, width: 0.8),
                    ),
                  ),
                  children: [
                    for (var c = 0; c < totalsRow.length; c++)
                      cell(totalsRow[c], c, bold: true),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            // ── Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                      font: ttfRegular, fontSize: 9, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Staff Summary - ${provider.company}',
                  style: pw.TextStyle(
                      font: ttfRegular, fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    }




    @override
    Widget build(BuildContext context) {
      return Consumer<Datafeed>(
        builder: (context, value, child) {
          final canManage = _canManageFilters(value);
          final resultList = value.filterfetchsalesregister();
          final branchRows = _groupByBranch(resultList);
          final grandTotals = _grandTotals(branchRows);
          final totalReturns = grandTotals['cashReturns']! + grandTotals['creditReturns']!;
          final totalDiscount = grandTotals['cashDiscount']! + grandTotals['creditDiscount']!;

          return Scaffold(
            backgroundColor: const Color(0xFF101624),
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: AppBar(
                backgroundColor: const Color(0xFF1B263B),
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                titleSpacing: 12,
                title: _isSearching
                    ? Row(
                  children: [
                    IconButton(
                      tooltip: 'Close search',
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 21),
                      onPressed: () => _closeSearch(value),
                    ),
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: TextField(
                            controller: searchController,
                            focusNode: _searchFocusNode,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            cursorColor: Colors.white,
                            decoration: const InputDecoration(
                              hintText: 'Search sales register...',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                            onChanged: (text) {
                              setState(() {});
                              value.updateSearch(text);
                            },
                          ),
                        ),
                      ),
                    ),
                    if (searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear, color: Colors.white, size: 20),
                        onPressed: () {
                          setState(() => searchController.clear());
                          value.updateSearch('');
                          _searchFocusNode.requestFocus();
                        },
                      ),
                  ],
                )
                    : Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sales Register',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),

                    // Branch: editable for privileged roles, read-only label otherwise.
                    if (canManage)
                      InkWell(
                        key: _branchKey,
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showBranchMenu(context, value),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.store_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _branchLabel(value),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.store_outlined, color: Colors.white54, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _branchLabel(value),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                    // Date: editable for privileged roles, fixed to "Today" otherwise.
                    if (canManage)
                      IconButton(
                        tooltip: _formatDateRange(),
                        icon: Icon(Icons.date_range,
                            color: _isTodayActive || selectedDate != null
                                ? const Color(0xFF6366F1)
                                : Colors.white,
                            size: 21),
                        onPressed: _showDateRangePicker,
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Today',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),

                    if (canManage)
                      IconButton(
                        tooltip: _isTodayActive ? 'Showing today' : 'Jump to today',
                        icon: Icon(Icons.today,
                            color: _isTodayActive ? const Color(0xFF6366F1) : Colors.white, size: 20),
                        onPressed: _toggleToday,
                      ),

                    IconButton(
                      tooltip: 'Search',
                      icon: const Icon(Icons.search, color: Colors.white, size: 21),
                      onPressed: _openSearch,
                    ),
                    IconButton(
                      tooltip: 'Print',
                      icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 20),
                      onPressed: () => _printMainReport(value, branchRows, grandTotals),
                    ),
                  ],
                ),
              ),
            ),
            body: value.isloadingsalesregister
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : branchRows.isEmpty
                ? const Center(
              child: Text('No Sales register found', style: TextStyle(color: Colors.white70)),
            )
                : Align(
              alignment: Alignment.topCenter,
                  child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Scrollbar(
                  controller: _tableVController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableVController,
                    child: Scrollbar(
                      controller: _tableHController,
                      thumbVisibility: true,
                      notificationPredicate: (notif) => notif.depth == 1,
                      child: SingleChildScrollView(
                        controller: _tableHController,
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFF1B263B)),
                          dataRowColor:
                          WidgetStateProperty.resolveWith((states) => const Color(0xFF101C2E)),
                          headingTextStyle:
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          dataTextStyle: const TextStyle(color: Colors.white70),
                          columnSpacing: 24,
                          dividerThickness: 0.7,
                          showCheckboxColumn: false,
                          columns: const [
                            DataColumn(label: Text('#')),
                            DataColumn(label: Text('Branch')),
                            DataColumn(label: Text('Cash Sales'), numeric: true),
                            DataColumn(label: Text('MoMo'), numeric: true),
                            DataColumn(label: Text('Hubtel'), numeric: true),
                            DataColumn(label: Text('Card'), numeric: true),
                            DataColumn(label: Text('Bank'), numeric: true),
                            DataColumn(label: Text('Cheque'), numeric: true),
                            DataColumn(label: Text('Credit Sales'), numeric: true),
                            DataColumn(label: Text('Returns'), numeric: true),
                            DataColumn(label: Text('Discount'), numeric: true),
                            DataColumn(label: Text('Profit'), numeric: true),
                            DataColumn(label: Text('Debt Payment'), numeric: true),
                            DataColumn(label: Text('Cash @ Hand'), numeric: true),
                          ],
                          rows: [
                            ...branchRows.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final branchName = item['branchName']?.toString() ?? '';
                              final branchId = item['branchId']?.toString() ?? branchName;

                              final cashSales = item['cashSales'] as double;
                              final merchantmomo = (item['merchantmomo'] ?? 0) as double;
                              final hubtel = (item['hubtel'] ?? 0) as double;
                              final card = (item['card'] ?? 0) as double;
                              final bank = (item['bank'] ?? 0) as double;
                              final cheque = (item['cheque'] ?? 0) as double;
                              final creditSales = item['creditSales'] as double;
                              final cashReturns = item['cashReturns'] as double;
                              final creditReturns = item['creditReturns'] as double;
                              final cashDiscount = item['cashDiscount'] as double;
                              final creditDiscount = item['creditDiscount'] as double;
                              final damages = item['damages'] as double;
                              final profit = item['profit'] as double;
                              final debtPayment = item['debtPayment'] as double;
                              final cashAtHand = item['cashAtHand'] as double;

                              final returns = cashReturns + creditReturns;
                              final discount = cashDiscount + creditDiscount;

                              return DataRow(
                                onSelectChanged: (_) => showSalesStaffDialog(
                                  context,
                                  branchId: branchId,
                                  branchName: branchName,
                                ),
                                cells: [
                                  DataCell(Text('${index + 1}')),
                                  DataCell(Text(branchName,
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.w500))),
                                  DataCell(Text(cashSales.toStringAsFixed(2))),
                                  DataCell(Text(merchantmomo.toStringAsFixed(2))),
                                  DataCell(Text(hubtel.toStringAsFixed(2))),
                                  DataCell(Text(card.toStringAsFixed(2))),
                                  DataCell(Text(bank.toStringAsFixed(2))),
                                  DataCell(Text(cheque.toStringAsFixed(2))),
                                  DataCell(Text(creditSales.toStringAsFixed(2))),
                                  DataCell(
                                    Tooltip(
                                      message: 'Cash Returns: ${cashReturns.toStringAsFixed(2)}\n'
                                          'Credit Returns: ${creditReturns.toStringAsFixed(2)}\n\n'
                                          'Total Returns: ${returns.toStringAsFixed(2)}',
                                      child: Text(returns.toStringAsFixed(2),
                                          style: const TextStyle(decoration: TextDecoration.underline)),
                                    ),
                                  ),
                                  DataCell(
                                    Tooltip(
                                      message: 'Cash Discount: ${cashDiscount.toStringAsFixed(2)}\n'
                                          'Credit Discount: ${creditDiscount.toStringAsFixed(2)}\n\n'
                                          'Total Discount: ${discount.toStringAsFixed(2)}',
                                      child: Text(discount.toStringAsFixed(2),
                                          style: const TextStyle(decoration: TextDecoration.underline)),
                                    ),
                                  ),
                                  DataCell(Text(profit.toStringAsFixed(2),
                                      style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text(debtPayment.toStringAsFixed(2))),
                                  DataCell(
                                    Tooltip(
                                      message: _cashAtHandTooltip(
                                        cashSales: cashSales,
                                        cashReturns: cashReturns,
                                      //  damages: damages,
                                        cashAtHand: cashAtHand,
                                      ),
                                      child: Text(cashAtHand.toStringAsFixed(2),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline)),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            DataRow(
                              color: WidgetStateProperty.all(const Color(0xFF1B263B)),
                              cells: [
                                const DataCell(SizedBox()),
                                const DataCell(Text('GRAND TOTAL',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataCell(Text(grandTotals['cashSales']!.toStringAsFixed(2),
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold))),
                                DataCell(Text(_paymentTotal(branchRows, 'merchantmomo').toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold))),
                                DataCell(Text(_paymentTotal(branchRows, 'hubtel').toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold))),
                                DataCell(Text(_paymentTotal(branchRows, 'card').toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold))),
                                DataCell(Text(_paymentTotal(branchRows, 'bank').toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold))),
                                DataCell(Text(_paymentTotal(branchRows, 'cheque').toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold))),
                                DataCell(Text(grandTotals['creditSales']!.toStringAsFixed(2),
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold))),
                                DataCell(
                                  Tooltip(
                                    message:
                                    'Cash Returns: ${grandTotals['cashReturns']!.toStringAsFixed(2)}\n'
                                        'Credit Returns: ${grandTotals['creditReturns']!.toStringAsFixed(2)}\n\n'
                                        'Total Returns: ${totalReturns.toStringAsFixed(2)}',
                                    child: Text(totalReturns.toStringAsFixed(2),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline)),
                                  ),
                                ),
                                DataCell(
                                  Tooltip(
                                    message:
                                    'Cash Discount: ${grandTotals['cashDiscount']!.toStringAsFixed(2)}\n'
                                        'Credit Discount: ${grandTotals['creditDiscount']!.toStringAsFixed(2)}\n\n'
                                        'Total Discount: ${totalDiscount.toStringAsFixed(2)}',
                                    child: Text(totalDiscount.toStringAsFixed(2),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline)),
                                  ),
                                ),
                                DataCell(Text(grandTotals['profit']!.toStringAsFixed(2),
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold))),

                                DataCell(Text(grandTotals['debtPayment']!.toStringAsFixed(2),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataCell(
                                  Tooltip(
                                    message: _cashAtHandTooltip(
                                      cashSales: grandTotals['cashSales']!,
                                      cashReturns: grandTotals['cashReturns']!,
                                    //  damages: grandTotals['damages']!,
                                      cashAtHand: grandTotals['cashAtHand']!,
                                    ),
                                    child: Text(grandTotals['cashAtHand']!.toStringAsFixed(2),
                                        style: const TextStyle(
                                            color: Colors.lightBlueAccent,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                                ),
                              ),
                ),
          );
        },
      );
    }



    Future<void> showSalesStaffDialog( BuildContext context, { String? branchId, String? branchName, }) async {showDialog( context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final provider = Provider.of<Datafeed>(context, listen: false);

      try {
        final now = DateTime.now();
        final startDate = selectedDate?.start ?? now;
        final endDate = selectedDate?.end ?? now;

        final effectiveBranch = branchId ?? _selectedBranch;
        final shouldFilterByBranch = effectiveBranch != null &&
            effectiveBranch.trim().isNotEmpty &&
            effectiveBranch.toLowerCase() != 'all';
        final selectedBranchId = effectiveBranch?.trim().toLowerCase() ?? '';

        await provider.loadSalesStaffSummary(
          startDate: startDate,
          endDate: endDate,
          shouldFilterByBranch: shouldFilterByBranch,
          selectedBranchId: selectedBranchId,
        );
      } catch (e) {
        debugPrint("Error: $e");
      }

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      // Payment-method columns the user has added through the filter.
      final selectedMethods = <String>{};

      List<Widget> dialogRows(Map<String, double> lines, String totalLabel, double total) => [
        for (final e in lines.entries) _row(e.key, e.value),
        const Divider(),
        _row(totalLabel, total, bold: true),
      ];

      void openBreakdown(BuildContext ctx, String title, Map<String, double> lines, String totalLabel,
          double total) {
        showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: dialogRows(lines, totalLabel, total),
            ),
          ),
        );
      }

      showDialog(
        context: context,
        builder: (dialogContext) {
          final isSmallScreen = MediaQuery.of(dialogContext).size.width < 600;

          return Consumer<Datafeed>(
            builder: (context, provider, _) {
              final rows = provider
                  .filteredSalesStaffRows()
                  .map((m) => _StaffRow.fromMap(Map<String, dynamic>.from(m)))
                  .toList();

              return StatefulBuilder(
                builder: (context, setLocal) {
                  final active = _kPayMethods.where((m) => selectedMethods.contains(m.id)).toList();

             
                  final headers = <String>[
                    '#',
                    'Staff',
                    'Cash Sales',
                    'Credit Sales',
                    'Returns',
                    'Discount',
                    'Debt Payment',
                    ...active.map((m) => m.label),
                    'Profit',
                    'Cash @ Hand',
                  ];
                  final flex = <int>[3, 16, 12, 12, 11, 11, 13, ...active.map((_) => 12), 11, 13];

                  return AlertDialog(
                    backgroundColor: const Color(0xFF101624),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    insetPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 40,
                      vertical: 12,
                    ),
                    title: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                branchName != null
                                    ? '${branchName.toUpperCase()} — STAFF TRANSACTIONS SUMMARY'
                                    : 'STAFF TRANSACTIONS SUMMARY',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (val) => provider.updateSearch(val),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "Search staff...",
                                  hintStyle: const TextStyle(color: Colors.white54),
                                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                                  filled: true,
                                  fillColor: const Color(0xFF1A2235),
                                    border: const OutlineInputBorder(
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            PopupMenuButton<String>(
                              tooltip: 'Show payment method columns',
                              color: const Color(0xFF1A2235),
                              onSelected: (id) => setLocal(() {
                                selectedMethods.contains(id)
                                    ? selectedMethods.remove(id)
                                    : selectedMethods.add(id);
                              }),
                              itemBuilder: (_) => [
                                for (final m in _kPayMethods)
                                  CheckedPopupMenuItem<String>(
                                    value: m.id,
                                    checked: selectedMethods.contains(m.id),
                                    child: Text(m.label, style: const TextStyle(color: Colors.white)),
                                  ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A2235),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.filter_list, color: Colors.white70, size: 18),
                                    SizedBox(width: 6),
                                    Text('Payment Methods', style: TextStyle(color: Colors.white70)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (active.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final m in active)
                                  InputChip(
                                    label: Text(m.label,
                                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                                    backgroundColor: const Color(0xFF22304A),
                                    deleteIconColor: Colors.white70,
                                    onDeleted: () => setLocal(() => selectedMethods.remove(m.id)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    content: SizedBox(
                      width: MediaQuery.of(dialogContext).size.width * 0.95,
                      child: rows.isEmpty
                          ? const Text("No transactions found", style: TextStyle(color: Colors.white70))
                          : isSmallScreen
                      // Mobile cards
                          ? ListView.builder(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final r = rows[index];
                          return InkWell(
                            onTap: () => showSalesStaffTransactionsDialog(
                              context,
                              staffName: r.staff,
                              staffEmail: r.email,
                            ),
                            child: Card(
                              color: const Color(0xFF1A2235),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('#${index + 1}',
                                        style: const TextStyle(
                                            color: Colors.white70, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text(r.staff,
                                        style: const TextStyle(
                                            color: Colors.amberAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _miniStatstringTap('Cash Sales', _f(r.cashSales),
                                            onTap: () => openBreakdown(
                                                context,
                                                'Cash Sales Breakdown',
                                                r.cashSalesLines,
                                                'All Payment Methods',
                                                r.allSales)),
                                        _miniStatstring('Credit Sales', _f(r.creditSales)),
                                        _miniStatstringTap('Returns', _f(r.returns),
                                            onTap: () => openBreakdown(context, 'Returns Breakdown',
                                                r.returnsLines, 'Total Returns', r.returns)),
                                        _miniStatstringTap('Discount', _f(r.discount),
                                            onTap: () => openBreakdown(context, 'Discount Breakdown',
                                                r.discountLines, 'Total Discount', r.discount)),
                                        _miniStatstringTap('Debt Payment', _f(r.debtTotal),
                                            onTap: () => openBreakdown(
                                                context,
                                                'Debt Payment Breakdown',
                                                r.debtLines,
                                                'Total',
                                                r.debtTotal)),
                                        for (final m in active)
                                          _miniStatstringTap(m.label, _f(r.methodTotal(m)),
                                              onTap: () => openBreakdown(
                                                  context,
                                                  '${m.label} Breakdown',
                                                  {
                                                    'Sales': r.sales[m.id] ?? 0,
                                                    'Debt Payment': r.debt[m.id] ?? 0,
                                                  },
                                                  'Total',
                                                  r.methodTotal(m))),
                                        _miniStatstring('Profit', _f(r.profit)),
                                        _miniStatstringTap('Cash @ Hand', _f(r.cashAtHand),
                                            onTap: () => openBreakdown(
                                                context,
                                                'Cash @ Hand Breakdown',
                                                r.cashAtHandLines,
                                                'Calculated Total',
                                                r.calcCashAtHand)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      )
                      //Desktop
                          : LayoutBuilder(
                        builder: (context, constraints) {
                          final double contentWidth = headers.length * 105.0 + 32;
                          final double tableWidth =
                          constraints.maxWidth > contentWidth ? constraints.maxWidth : contentWidth;

                          Widget rowOf(List<Widget> cells, {BoxDecoration? decoration}) {
                            return Container(
                              decoration: decoration,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              constraints: const BoxConstraints(minHeight: 44, maxHeight: 60),
                              alignment: Alignment.center,
                              child: Row(
                                children: [
                                  for (int i = 0; i < cells.length; i++)
                                    Expanded(
                                      flex: flex[i],
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Align(
                                          alignment:
                                          i >= 2 ? Alignment.centerRight : Alignment.centerLeft,
                                          child: cells[i],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }

                          Widget plain(String v) => Text(v,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70));

                          Widget hover(double shown, String title, Map<String, double> lines,
                              String totalLabel, double total) =>
                              _breakdownCell(
                                tooltipMessage: _tip(lines, totalLabel, total),
                                displayValue: _f(shown),
                                dialogTitle: title,
                                dialogRows: dialogRows(lines, totalLabel, total),
                              );

                          return RawScrollbar(
                            controller: _hhController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            thumbColor: const Color(0xFF415A77),
                            trackColor: const Color(0xFF22304A),
                            trackBorderColor: const Color(0xFF1B263B),
                            thickness: 10,
                            radius: const Radius.circular(8),
                            scrollbarOrientation: ScrollbarOrientation.bottom,
                            child: SingleChildScrollView(
                              controller: _hhController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      color: const Color(0xFF1E2A3D),
                                      child: rowOf([
                                        for (final h in headers)
                                          Text(h,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13)),
                                      ]),
                                    ),
                                    const Divider(
                                        height: 1, color: Color(0xFF475569)),
                                    Expanded(
                                      child: RawScrollbar(
                                        controller: _vvController,
                                        thumbVisibility: true,
                                        trackVisibility: true,
                                        thumbColor: const Color(0xFF415A77),
                                        trackColor: const Color(0xFF22304A),
                                        trackBorderColor: const Color(0xFF1B263B),
                                        thickness: 10,
                                        radius: const Radius.circular(8),
                                        scrollbarOrientation: ScrollbarOrientation.right,
                                        child: ListView.builder(
                                          controller: _vvController,
                                          itemCount: rows.length,
                                          itemBuilder: (context, i) {
                                            final r = rows[i];
                                            return InkWell(
                                              onTap: () => showSalesStaffTransactionsDialog(
                                                context,
                                                staffName: r.staff,
                                                staffEmail: r.email,
                                              ),
                                              child: rowOf(
                                                [
                                                  plain('${i + 1}'),
                                                  plain(r.staff),
                                                  hover(r.cashSales, 'Cash Sales Breakdown',
                                                      r.cashSalesLines, 'All Payment Methods', r.allSales),
                                                  plain(_f(r.creditSales)),
                                                  hover(r.returns, 'Returns Breakdown',
                                                      r.returnsLines, 'Total Returns', r.returns),
                                                  hover(r.discount, 'Discount Breakdown',
                                                      r.discountLines, 'Total Discount', r.discount),
                                                  hover(r.debtTotal, 'Debt Payment Breakdown',
                                                      r.debtLines, 'Total', r.debtTotal),
                                                  for (final m in active)
                                                    hover(
                                                        r.methodTotal(m),
                                                        '${m.label} Breakdown',
                                                        {
                                                          'Sales': r.sales[m.id] ?? 0,
                                                          'Debt Payment': r.debt[m.id] ?? 0,
                                                        },
                                                        'Total',
                                                        r.methodTotal(m)),
                                                  plain(_f(r.profit)),
                                                  hover(r.cashAtHand, 'Cash @ Hand Breakdown',
                                                      r.cashAtHandLines, 'Calculated Total',
                                                      r.calcCashAtHand),
                                                ],
                                                decoration: const BoxDecoration(
                                                  border:
                                                  Border(bottom: BorderSide(color: Colors.white10)),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => _printStaffSummary(
                          provider: provider,
                          rows: rows,
                          pdfMethods:
                          _kPayMethods.where((m) => selectedMethods.contains(m.id)).toList(),
                          branchName: branchName,
                        ),
                        child: const Text('Print / Download',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text("Close", style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      );
    }


    Future<void> showSalesStaffTransactionsDialog( BuildContext context, { required String staffName,  required String staffEmail,   }) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final provider = Provider.of<Datafeed>(context, listen: false);

      try {
        final now = DateTime.now();
        final startDate = selectedDate?.start ?? now;
        final endDate = selectedDate?.end ?? now;

        await provider.loadSalesStaffTransactions(
          startDate: startDate,
          endDate: endDate,
          staffName: staffName,
          staffEmail: staffEmail,
          companyId: provider.companyid,
          selectedBranch: _selectedBranch,
        );
      } catch (e) {
        debugPrint(e.toString());
      }

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      var transactionPage = 0;
      showDialog(
        context: context,
        builder: (dialogContext) {
          final isSmallScreen = MediaQuery.of(dialogContext).size.width < 600;
          bool searchExpanded = false;

          // null = no payment filter applied (show everything).
          String? paymentFilter;


          final paymentOptions = <_PaymentFilterOption>[
            const _PaymentFilterOption('All', null, Icons.apps_rounded),
            const _PaymentFilterOption('Cash', 'cash', Icons.payments_outlined),
            const _PaymentFilterOption('Credit', 'credit', Icons.payments_outlined),
            const _PaymentFilterOption('MoMo', 'momo', Icons.smartphone_outlined),
            const _PaymentFilterOption('Card', 'card', Icons.credit_card_outlined),
            const _PaymentFilterOption('Hubtel', 'hubtel', Icons.account_balance_wallet_outlined),
            const _PaymentFilterOption('Cheque', 'cheque', Icons.receipt_long_outlined),
            const _PaymentFilterOption('Bank', 'bank', Icons.account_balance_outlined),
          ];


          bool matchesPayment(Map<String, dynamic> t, String keyword) {
            if ((t['payment']?.toString().toLowerCase() ?? '').contains(keyword)) return true;
            final payments = t['payments'];
            if (payments is List) {
              for (final p in payments) {
                if (p is Map && (p['method']?.toString().toLowerCase() ?? '').contains(keyword)) {
                  return true;
                }
              }
            }
            return false;
          }

          return StatefulBuilder(
            builder: (context, setModalState) {
              return Consumer<Datafeed>(
                builder: (context, provider, _) {
                  final allSales = provider.filteredSalesStaffTransactions();
                  final displayedSales = paymentFilter == null
                      ? allSales
                      : allSales
                      .where((t) => matchesPayment(Map<String, dynamic>.from(t), paymentFilter!))
                      .toList();
                    const rowsPerPage = 10;
                    final totalPages = displayedSales.isEmpty
                      ? 1
                      : ((displayedSales.length - 1) ~/ rowsPerPage) + 1;
                    final pagedSales = displayedSales
                      .skip(transactionPage * rowsPerPage)
                      .take(rowsPerPage)
                      .toList();

                  DateTime resolveDate(Map<String, dynamic> t) {
                    final datetime = t['datetime'];
                    if (datetime is Timestamp) return datetime.toDate();
                    return DateTime.tryParse(t['date']?.toString() ?? '') ?? DateTime.now();
                  }

                  Map<String, dynamic> resolveItems(Map<String, dynamic> t) {
                    final raw = t['items'];
                    if (raw is Map) return Map<String, dynamic>.from(raw);
                    return {};
                  }

                  Widget miniStat(String label, String value) => _miniStatstring(label, value);

                  Widget kv(String label, String value) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 110,
                              child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
                          Expanded(
                              child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                        ],
                      ),
                    );
                  }

                  void showItemsPopup(String receipt, List<_ItemLine> lines) {
                    Widget rowOf(_ItemLine line) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration:
                        BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.name,
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            kv('Barcode', line.barcode),
                           // kv('Category', line.pcategory),
                           // kv('Type', line.productType),
                            kv('Mode', line.mode),
                          //  kv('MQty', line.modeQty),
                            kv('Qty', '${line.qty}'),
                          //  kv('BoxPiece', line.boxpiece),
                          //  kv('Pieces', '${line.totalPieces}'),
                            kv('PriceMode', capitalize(line.priceMode)),
                            kv('Price', line.price.toStringAsFixed(2)),
                         //   kv('CP', line.cp.toStringAsFixed(2)),
                            kv('Disc', line.discount.toStringAsFixed(2)),
                          //  kv('Total', line.grossTotalAmount.toStringAsFixed(2)),
                            kv('Amount', line.totalAmount.toStringAsFixed(2)),
                            kv('Profit', line.profit.toStringAsFixed(2)),
                          ],
                        ),
                      );
                    }

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF101624),
                        title: Text(receipt, style: const TextStyle(color: Colors.white70)),
                        content: SizedBox(
                          width: 1000,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = MediaQuery.of(context).size.width < 600;
                              if (lines.isEmpty) {
                                return const Text('No item detail', style: TextStyle(color: Colors.white70));
                              }
                              if (isMobile) {
                                return SizedBox(
                                  width: double.infinity,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: lines.length,
                                    itemBuilder: (context, i) => rowOf(lines[i]),
                                  ),
                                );
                              }
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columnSpacing: 10,
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
                                    dataRowColor: WidgetStateProperty.all(const Color(0xFF101624)),
                                    columns: const [
                                      DataColumn(label: Text('Item', style: TextStyle(color: Colors.white))),
                                      DataColumn(label: Text('Barcode', style: TextStyle(color: Colors.white))),
                                     // DataColumn(label: Text('Category', style: TextStyle(color: Colors.white))),
                                   //   DataColumn(label: Text('Type', style: TextStyle(color: Colors.white))),
                                      DataColumn(label: Text('Mode', style: TextStyle(color: Colors.white))),
                                   //   DataColumn( label: Text('Mode Qty', style: TextStyle(color: Colors.white)),                                          numeric: true),
                                      DataColumn(
                                          label: Text('Qty', style: TextStyle(color: Colors.white)),
                                          numeric: true),
                                    //  DataColumn(label: Text('Box/Piece', style: TextStyle(color: Colors.white))),
                                    //  DataColumn(label: Text('Pieces', style: TextStyle(color: Colors.white)),                         numeric: true),
                                      DataColumn(
                                          label: Text('Price Mode', style: TextStyle(color: Colors.white))),
                                      DataColumn(
                                          label: Text('Price', style: TextStyle(color: Colors.white)),
                                          numeric: true),
                                    //  DataColumn( label: Text('Cost Price', style: TextStyle(color: Colors.white)), numeric: true),
                                      DataColumn(
                                          label: Text('Discount', style: TextStyle(color: Colors.white)),
                                          numeric: true),
                                      // DataColumn(
                                      //     label: Text('Gross Total', style: TextStyle(color: Colors.white)),
                                      //     numeric: true),
                                      DataColumn(
                                          label: Text('Amount', style: TextStyle(color: Colors.white)),
                                          numeric: true),
                                      DataColumn(
                                          label: Text('Profit', style: TextStyle(color: Colors.white)),
                                          numeric: true),
                                    ],
                                    rows: lines.map((line) {
                                      const s = TextStyle(color: Colors.white70);
                                      return DataRow(cells: [
                                        DataCell(Text(line.name, style: const TextStyle(color: Colors.white))),
                                        DataCell(Text(line.barcode, style: s)),
                                      //  DataCell(Text(line.pcategory, style: s)),
                                      //  DataCell(Text(line.productType, style: s)),
                                        DataCell(Text(line.mode, style: s)),
                                      //  DataCell(Text(line.modeQty, style: s)),
                                        DataCell(Text('${line.qty}', style: s)),
                                       // DataCell(Text(line.boxpiece, style: s)),
                                       // DataCell(Text('${line.totalPieces}', style: s)),
                                        DataCell(Text(capitalize(line.priceMode), style: s)),
                                        DataCell(Text(line.price.toStringAsFixed(2), style: s)),
                                      //  DataCell(Text(line.cp.toStringAsFixed(2), style: s)),
                                        DataCell(Text(line.discount.toStringAsFixed(2), style: s)),
                                       // DataCell(Text(line.grossTotalAmount.toStringAsFixed(2), style: s)),
                                        DataCell(Text(line.totalAmount.toStringAsFixed(2), style: s)),
                                        DataCell(Text(line.profit.toStringAsFixed(2), style: s)),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close', style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    );
                  }

                  void showPaymentPopup(
                      String receipt, {
                        required List<_PaymentLine> payments,
                        required String paymentStatus,
                        required double amountPaid,
                        required double totalAmount,
                      }) {
                    Widget rowOf(_PaymentLine p) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration:
                        BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(capitalize(p.method),
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            kv('Account Name', p.accountName),
                            kv('Account Number', p.accountNumber),
                            kv('Reference', p.reference),
                            kv('Amount', p.amount.toStringAsFixed(2)),
                            Row(
                              children: [
                                const Text('Status: ', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Text(p.status ? 'Success' : 'Failed',
                                    style: TextStyle(
                                        color: p.status ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF101624),
                        title: Text(receipt, style: const TextStyle(color: Colors.amberAccent)),
                        content: SizedBox(
                          width: 700,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 24,
                                  runSpacing: 8,
                                  children: [
                                    _miniStatstring('Total Amount', totalAmount.toStringAsFixed(2)),
                                    _miniStatstring('Amount Paid', amountPaid.toStringAsFixed(2)),
                                    _miniStatstring('Payment Status', capitalize(paymentStatus)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text('PAYMENT BREAKDOWN',
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2)),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final isMobile = MediaQuery.of(context).size.width < 600;
                                    if (payments.isEmpty) {
                                      return const Text('No payment detail',
                                          style: TextStyle(color: Colors.white70));
                                    }
                                    if (isMobile) {
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: payments.length,
                                        itemBuilder: (context, i) => rowOf(payments[i]),
                                      );
                                    }
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
                                        dataRowColor: WidgetStateProperty.all(const Color(0xFF101624)),
                                        columns: const [
                                          DataColumn(label: Text('Method', style: TextStyle(color: Colors.white))),
                                          DataColumn(
                                              label: Text('Account Name', style: TextStyle(color: Colors.white))),
                                          DataColumn(
                                              label:
                                              Text('Account Number', style: TextStyle(color: Colors.white))),
                                          DataColumn(
                                              label: Text('Reference', style: TextStyle(color: Colors.white))),
                                          DataColumn(
                                              label: Text('Amount', style: TextStyle(color: Colors.white)),
                                              numeric: true),
                                          DataColumn(label: Text('Status', style: TextStyle(color: Colors.white))),
                                        ],
                                        rows: payments.map((p) {
                                          return DataRow(cells: [
                                            DataCell(Text(capitalize(p.method),
                                                style: const TextStyle(color: Colors.white))),
                                            DataCell(Text(p.accountName,
                                                style: const TextStyle(color: Colors.white70))),
                                            DataCell(Text(p.accountNumber,
                                                style: const TextStyle(color: Colors.white70))),
                                            DataCell(Text(p.reference,
                                                style: const TextStyle(color: Colors.white70))),
                                            DataCell(Text(p.amount.toStringAsFixed(2),
                                                style: const TextStyle(color: Colors.white70))),
                                            DataCell(Text(p.status ? 'Success' : 'Failed',
                                                style: TextStyle(
                                                    color: p.status ? Colors.greenAccent : Colors.redAccent))),
                                          ]);
                                        }).toList(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close', style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    );
                  }

                  Widget buildTitle() {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: searchExpanded
                          ? Row(
                        key: const ValueKey('search-expanded'),
                        children: [
                          Expanded(
                            child: TextField(
                              autofocus: true,
                              onChanged: (val) {
                                setModalState(() => transactionPage = 0);
                                provider.updateSearch(val);
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Search...",
                                hintStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: const Color(0xFF1A2235),
                                border: const OutlineInputBorder(
                                  borderSide: BorderSide.none),
                                contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setModalState(() {
                              searchExpanded = false;
                              provider.updateSearch('');
                            }),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      )
                          : Row(
                        key: const ValueKey('search-collapsed'),
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('$staffName SALES TRANSACTIONS',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                          ),
                          TextButton(
                            onPressed: () => setModalState(() => searchExpanded = true),
                            child: const Text('Search', style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    );
                  }


                  Widget buildPaymentFilterBar() {
                    return SizedBox(
                      height: 40,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          scrollbars: false,
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                          },
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              for (final opt in paymentOptions) ...[
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => setModalState(() {
                                    paymentFilter = opt.value;
                                    transactionPage = 0;
                                  }),
                                  child: Container(
                                    padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: paymentFilter == opt.value
                                          ? const Color(0xFF6366F1)
                                          : Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(opt.icon, size: 16, color: Colors.white),
                                        const SizedBox(width: 6),
                                        Text(opt.label,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return AlertDialog(
                    backgroundColor: const Color(0xFF101624),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    insetPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 24,
                      vertical: 12,
                    ),
                    title: buildTitle(),
                    content: SizedBox(
                      width: double.maxFinite,
                        height: MediaQuery.sizeOf(context).height *
                          (isSmallScreen ? 0.68 : 0.82),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: buildPaymentFilterBar(),
                          ),
                          Expanded(
                            child: displayedSales.isEmpty
                                ? const Center(
                                child: Text("No transactions found", style: TextStyle(color: Colors.white70)))
                                : isSmallScreen
                                ? ListView.builder(
                              itemCount: pagedSales.length,
                              itemBuilder: (context, index) {
                                final t = pagedSales[index];
                                final no = transactionPage * rowsPerPage + index + 1;
                                final datee = resolveDate(t);
                                final formattedDate =
                                DateFormat('yyyy-MM-dd – hh:mm a').format(datee);
                                final receipt = t['receipt'] ?? '';
                                final customer = t['customer'] ?? '';
                                final amount = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
                                final amountPaid =
                                    double.tryParse(t['amountPaid']?.toString() ?? '0') ?? 0.0;
                                final discount =
                                    double.tryParse(t['discount']?.toString() ?? '0') ?? 0.0;
                                final itemMap = resolveItems(t);
                                final itemLines = _parseItemLines(t['items']);

                                return Card(
                                  color: const Color(0xFF1A2235),
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('#$no',
                                                style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.bold)),
                                            Text(formattedDate,
                                                style: const TextStyle(
                                                    color: Colors.white60, fontSize: 12)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(receipt.toString(),
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            miniStat("Customer", customer.toString()),
                                            miniStat("Amount", amount.toStringAsFixed(2)),
                                            // Tappable: opens the payment-method breakdown.
                                            _miniStatstringTap(
                                              "Amount Paid",
                                              amountPaid.toStringAsFixed(2),
                                              onTap: () => showPaymentPopup(
                                                receipt.toString(),
                                                payments: _parsePaymentLines(t['payments']),
                                                paymentStatus: (t['paymentStatus'] ?? '').toString(),
                                                amountPaid: amountPaid,
                                                totalAmount: amount,
                                              ),
                                            ),
                                            miniStat("Discount", discount.toStringAsFixed(2)),
                                            _miniStatstringTap(
                                              "Items",
                                              '${itemMap.length}',
                                              onTap: () =>
                                                  showItemsPopup(receipt.toString(), itemLines),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                                : LayoutBuilder(
                              builder: (context, constraints) {
                                // #, Date, Receipt, Customer, Items, Amount, Amount Paid, Discount
                                // (Payment is the filter bar above, not a column.)
                                const widths = [30, 170, 150, 190, 90, 90, 90, 80];
                                const gap = 15.0;
                                final double contentWidth =
                                    widths.reduce((a, b) => a + b) + (widths.length - 1) * gap + 32;
                                final double tableWidth = constraints.maxWidth > contentWidth
                                    ? constraints.maxWidth
                                    : contentWidth;

                                Widget rowOf(List<Widget> cells) {
                                  return Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: Color(0xFF475569), width: 0.7),
                                      ),
                                    ),
                                    padding:
                                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    constraints: const BoxConstraints(minHeight: 46, maxHeight: 64),
                                    alignment: Alignment.center,
                                    child: Row(
                                      children: [
                                        for (int i = 0; i < cells.length; i++) ...[
                                          SizedBox(width: widths[i].toDouble(), child: cells[i]),
                                          if (i != cells.length - 1) const SizedBox(width: gap),
                                        ],
                                      ],
                                    ),
                                  );
                                }

                                Widget headerCell(String label, {bool alignRight = false}) {
                                  return Text(
                                    label,
                                    textAlign: alignRight ? TextAlign.right : TextAlign.left,
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold),
                                  );
                                }

                                return RawScrollbar(
                                  controller: _hController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  thumbColor: const Color(0xFF415A77),
                                  trackColor: const Color(0xFF22304A),
                                  trackBorderColor: const Color(0xFF1B263B),
                                  thickness: 10,
                                  radius: const Radius.circular(8),
                                  scrollbarOrientation: ScrollbarOrientation.bottom,
                                  child: SingleChildScrollView(
                                    controller: _hController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: tableWidth,
                                      height:
                                      constraints.maxHeight.isFinite ? constraints.maxHeight : null,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            color: const Color(0xFF1E2A3D),
                                            child: rowOf([
                                              headerCell('#'),
                                              headerCell('Date'),
                                              headerCell('Receipt'),
                                              headerCell('Customer'),
                                              headerCell('Items'),
                                              headerCell('Amount', alignRight: true),
                                              headerCell('Amount Paid', alignRight: true),
                                              headerCell('Discount', alignRight: true),
                                            ]),
                                          ),
                                          Expanded(
                                            child: RawScrollbar(
                                              controller: _vController,
                                              thumbVisibility: true,
                                              trackVisibility: true,
                                              thumbColor: const Color(0xFF415A77),
                                              trackColor: const Color(0xFF22304A),
                                              trackBorderColor: const Color(0xFF1B263B),
                                              thickness: 10,
                                              radius: const Radius.circular(8),
                                              scrollbarOrientation: ScrollbarOrientation.right,
                                              child: ListView.builder(
                                                controller: _vController,
                                                itemCount: pagedSales.length,
                                                itemBuilder: (context, i) {
                                                  final s = pagedSales[i];
                                                  final date = resolveDate(s);
                                                  final formattedDate = DateFormat('yyyy-MM-dd – hh:mm a')
                                                      .format(date);
                                                  final amountRow =
                                                      double.tryParse(s['amount']?.toString() ?? '0') ??
                                                          0.0;
                                                  final amountPaidRow = double.tryParse(
                                                      s['amountPaid']?.toString() ?? '0') ??
                                                      0.0;
                                                  final discountRow = double.tryParse(
                                                      s['discount']?.toString() ?? '0') ??
                                                      0.0;
                                                  final receiptRow = (s['receipt'] ?? '').toString();
                                                  final itemMapRow = resolveItems(s);
                                                  final itemLinesRow = _parseItemLines(s['items']);

                                                  return rowOf([
                                                    Text('${transactionPage * rowsPerPage + i + 1}',
                                                        style: const TextStyle(color: Colors.white70)),
                                                    Text(formattedDate,
                                                        style: const TextStyle(color: Colors.white70)),
                                                    InkWell(
                                                      onTap: () async {
                                                        await Clipboard.setData(
                                                            ClipboardData(text: receiptRow));
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                                content: Text('Receipt copied')));
                                                      },
                                                      child: Text(receiptRow,
                                                          style: const TextStyle(
                                                              color: Colors.white70,
                                                              decoration: TextDecoration.underline)),
                                                    ),
                                                    Text('${s['customer'] ?? ''}',
                                                        style: const TextStyle(color: Colors.white70)),
                                                    InkWell(
                                                      onTap: () =>
                                                          showItemsPopup(receiptRow, itemLinesRow),
                                                      child: Text('${itemMapRow.length}',
                                                          style: const TextStyle(
                                                              color: Colors.white70,
                                                              decoration: TextDecoration.underline)),
                                                    ),
                                                    Text(amountRow.toStringAsFixed(2),
                                                        textAlign: TextAlign.right,
                                                        style: const TextStyle(color: Colors.white70)),
                                                    // Amount Paid doubles as the trigger for the
                                                    // payment-method breakdown, since Payment is no
                                                    // longer its own column.
                                                    InkWell(
                                                      onTap: () => showPaymentPopup(
                                                        receiptRow,
                                                        payments: _parsePaymentLines(s['payments']),
                                                        paymentStatus:
                                                        (s['paymentStatus'] ?? '').toString(),
                                                        amountPaid: amountPaidRow,
                                                        totalAmount: amountRow,
                                                      ),
                                                      child: Text(amountPaidRow.toStringAsFixed(2),
                                                          textAlign: TextAlign.right,
                                                          style: const TextStyle(
                                                              color: Colors.white70,
                                                              decoration: TextDecoration.underline)),
                                                    ),
                                                    Text(discountRow.toStringAsFixed(2),
                                                        textAlign: TextAlign.right,
                                                        style: const TextStyle(color: Colors.white70)),
                                                  ]);
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          await printSalesStaffTransactionsPdf(
                            staffName: staffName,
                            sales: displayedSales,
                            companyName: provider.company,
                            branchName: _branchLabel(provider),
                            dateRange: selectedDate,
                            paymentFilter: paymentFilter == null
                                ? null
                                : paymentOptions
                                .firstWhere((o) => o.value == paymentFilter)
                                .label,
                          );
                        },
                        child: const Text('Print/download',
                            style: TextStyle(color: Colors.blueAccent)),
                      ),
                      TextButton(
                        onPressed: transactionPage > 0
                            ? () => setModalState(() => transactionPage--)
                            : null,
                        child: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '${transactionPage + 1}/$totalPages',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: transactionPage < totalPages - 1
                            ? () => setModalState(() => transactionPage++)
                            : null,
                        child: const Icon(Icons.chevron_right),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      );
    }



    double _paymentTotal(List<Map<String, dynamic>> rows, String key) {
      return rows.fold<double>(
        0,
        (total, row) => total + ((row[key] ?? 0) as num).toDouble(),
      );
    }

    Widget _miniStatstring(String title, dynamic value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text(value.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    Widget _row(String label, num value, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 24),
            Text(value.toStringAsFixed(2),
                style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );
    }

    Widget _miniStatstringTap(
        String label,
        String value, {
          VoidCallback? onTap,
        }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF22304A), borderRadius: BorderRadius.circular(6)),
          child: Text("$label: $value",
              style: const TextStyle(color: Colors.white70, decoration: TextDecoration.underline)),
        ),
      );
    }

    Widget _breakdownCell({
      required String tooltipMessage,
      required String displayValue,
      required String dialogTitle,
      required List<Widget> dialogRows,
    }) {
      return Tooltip(
        message: tooltipMessage,
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(dialogTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: dialogRows,
                ),
              ),
            );
          },
          child: Text(displayValue,
              style: const TextStyle(color: Colors.white70, decoration: TextDecoration.underline)),
        ),
      );
    }
  }


  double _n(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
  String _f(double v) => v.toStringAsFixed(2);

  class _PayMethod {
    final String id, label, pdfLabel, salesKey, debtKey;
    const _PayMethod(this.id, this.label, this.pdfLabel, this.salesKey, this.debtKey);
  }

  const _kPayMethods = <_PayMethod>[
    _PayMethod('momo', 'Merchant MoMo', 'MoMo', 'merchantmomo', 'debtmerchantmomo'),
    _PayMethod('hubtel', 'Hubtel', 'Hubtel', 'hubtel', 'debthubtel'),
    _PayMethod('card', 'Card', 'Card', 'card', 'debtcard'),
    _PayMethod('bank', 'Bank Transfer', 'Bank', 'bank', 'debtbank'),
    _PayMethod('cheque', 'Cheque', 'Cheque', 'cheque', 'debtcheque'),
    _PayMethod('credit', 'Credit', 'Credit', 'credit', 'debtcredit'),
  ];

  class _StaffRow {
    final String staff, email;
    final double cashSales, creditSales, cashReturns, creditReturns;
    final double cashDiscount, creditDiscount, profit, debtCash, cashAtHand;
    final Map<String, double> sales; // payment method id -> sales amount
    final Map<String, double> debt; // payment method id -> debt payment amount

    _StaffRow({
      required this.staff,
      required this.email,
      required this.cashSales,
      required this.creditSales,
      required this.cashReturns,
      required this.creditReturns,
      required this.cashDiscount,
      required this.creditDiscount,
      required this.profit,
      required this.debtCash,
      required this.cashAtHand,
      required this.sales,
      required this.debt,
    });

    factory _StaffRow.fromMap(Map<String, dynamic> t) => _StaffRow(
      staff: (t['staff'] ?? '').toString(),
      email: (t['staffEmail'] ?? '').toString(),
      cashSales: _n(t['cashSales']),
      creditSales: _n(t['creditSales']),
      cashReturns: _n(t['cashReturns']),
      creditReturns: _n(t['creditReturns']),
      cashDiscount: _n(t['cashDiscount']),
      creditDiscount: _n(t['creditDiscount']),
      profit: _n(t['profit']),
      debtCash: _n(t['debtpayment_cash']),
      cashAtHand: _n(t['cashAtHand']),
      sales: {for (final m in _kPayMethods) m.id: _n(t[m.salesKey])},
      debt: {for (final m in _kPayMethods) m.id: _n(t[m.debtKey])},
    );

    double get returns => cashReturns + creditReturns;
    double get discount => cashDiscount + creditDiscount;
    double get debtTotal => debtCash + debt.values.fold(0.0, (a, b) => a + b);
    double get allSales => cashSales + sales.values.fold(0.0, (a, b) => a + b);
    double get calcCashAtHand => cashSales + debtCash - cashReturns;
    double methodTotal(_PayMethod m) => (sales[m.id] ?? 0) + (debt[m.id] ?? 0);

    Map<String, double> get cashSalesLines => {
      'Cash': cashSales,
      for (final m in _kPayMethods) m.label: sales[m.id] ?? 0,
    };
    Map<String, double> get returnsLines => {
      'Cash Return': cashReturns,
      'Credit Return': creditReturns,
    };
    Map<String, double> get discountLines => {
      'Cash Discount': cashDiscount,
      'Credit Discount': creditDiscount,
    };
    Map<String, double> get debtLines => {
      'Cash': debtCash,
      for (final m in _kPayMethods) m.label: debt[m.id] ?? 0,
    };
    Map<String, double> get cashAtHandLines => {
      'Cash Sales': cashSales,
      'Cash Debt Payment (+)': debtCash,
      'Cash Returns (−)': cashReturns,
    };
  }

  String _tip(Map<String, double> lines, String totalLabel, double total) {
    final b = StringBuffer();
    lines.forEach((k, v) => b.writeln('$k: ${_f(v)}'));
    b.writeln();
    b.write('$totalLabel: ${_f(total)}');
    return b.toString();
  }



  class _PaymentFilterOption {
    final String label;
    final String? value;
    final IconData icon;

    const _PaymentFilterOption(this.label, this.value, this.icon);
  }

  class _ItemLine {
    final String name;
    final num qty;
    final String barcode;
    final String boxpiece;
    final double cp;
  final double discount;
  final double grossTotalAmount;
  final String mode;
  final String modeQty;
  final String pcategory;
  final double price;
  final String priceMode;
  final String productType;
  final double profit;
  final double totalAmount;
  final num totalPieces;

  _ItemLine({
    required this.name,
    required this.qty,
    this.barcode = '',
    this.boxpiece = '',
    this.cp = 0.0,
    this.discount = 0.0,
    this.grossTotalAmount = 0.0,
    this.mode = '',
    this.modeQty = '',
    this.pcategory = '',
    this.price = 0.0,
    this.priceMode = '',
    this.productType = '',
    this.profit = 0.0,
    this.totalAmount = 0.0,
    this.totalPieces = 0,
  });
}

class _PaymentLine {
  final String accountName;
  final String accountNumber;
  final double amount;
  final String method;
  final String reference;
  final bool status;

  _PaymentLine({
    required this.accountName,
    required this.accountNumber,
    required this.amount,
    required this.method,
    required this.reference,
    required this.status,
  });
}

List<_PaymentLine> _parsePaymentLines(dynamic paymentsField) {
  final lines = <_PaymentLine>[];
  if (paymentsField is! List) return lines;

  for (final value in paymentsField) {
    if (value is! Map) continue;
    lines.add(_PaymentLine(
      accountName: (value['accountName'] ?? '').toString(),
      accountNumber: (value['accountNumber'] ?? '').toString(),
      amount: double.tryParse(value['amount']?.toString() ?? '0') ?? 0.0,
      method: (value['method'] ?? '').toString(),
      reference: (value['reference'] ?? '').toString(),
      status: value['status'] == true,
    ));
  }
  return lines;
}

List<_ItemLine> _parseItemLines(dynamic itemsField) {
  final lines = <_ItemLine>[];

  double d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
  num n(dynamic v) {
    final s = v?.toString() ?? '0';
    return num.tryParse(s) ?? 0;
  }

  void addEntry(dynamic value, String fallbackName) {
    if (value is! Map) return;
    final name = (value['item'] ?? value['name'] ?? fallbackName).toString();
    final rawQty = value['quantity'] ?? value['qty'] ?? 0;
    final qty = rawQty is num ? rawQty : num.tryParse(rawQty.toString()) ?? 0;

    lines.add(_ItemLine(
      name: name,
      qty: qty,
      barcode: (value['barcode'] ?? '').toString(),
      boxpiece: (value['boxpiece'] ?? '').toString(),
      cp: d(value['cp']),
      discount: d(value['discount']),
      grossTotalAmount: d(value['grosstotalamount']),
      mode: (value['mode'] ?? '').toString(),
      modeQty: (value['modeqty'] ?? '').toString(),
      pcategory: (value['pcategory'] ?? '').toString(),
      price: d(value['price']),
      priceMode: (value['pricemode'] ?? '').toString(),
      productType: (value['producttype'] ?? '').toString(),
      profit: d(value['profit']),
      totalAmount: d(value['totalamount']),
      totalPieces: n(value['totalpieces']),
    ));
  }

  if (itemsField is Map) {
    for (final entry in itemsField.entries) {
      addEntry(entry.value, entry.key.toString());
    }
  } else if (itemsField is List) {
    for (final value in itemsField) {
      addEntry(value, '');
    }
  }

  return lines;
}