import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import 'sales_report_shared.dart';
import 'sales_staff_models.dart';
import 'sales_staff_transactions_page.dart';

class SalesStaffSummaryPage extends StatefulWidget {
  final String branchId;
  final String branchName;
  final DateTimeRange? dateRange;

  const SalesStaffSummaryPage({
    super.key,
    required this.branchId,
    required this.branchName,
    required this.dateRange,
  });

  @override
  State<SalesStaffSummaryPage> createState() => _SalesStaffSummaryPageState();
}

class _SalesStaffSummaryPageState extends State<SalesStaffSummaryPage> {
  bool get _isLightTheme => srIsLightTheme(context);
  Color get _bg => srBackgroundColor(context);
  Color get _bar => srCardColor(context);
  Color get _field => _isLightTheme
      ? Theme.of(context).colorScheme.surfaceContainerHighest
      : srCardColor(context);
  Color get _textColor => srTextColor(context);
  Color get _mutedTextColor => srMutedTextColor(context);
  Color get _borderColor => srBorderColor(context);
  Color get _accentColor => srAccentColor(context);

  late final Datafeed _provider;
  late final String _previousSearch;
  final _searchCtrl = TextEditingController();
  final _hh = ScrollController();
  final _vv = ScrollController();
  final Set<String> _selectedMethods = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _provider = context.read<Datafeed>();
    _previousSearch = _provider.searchQuery;
    Future.microtask(_load);
  }

  Future<void> _load() async {
    _provider.updateSearch('');
    try {
      final now = DateTime.now();
      final id = widget.branchId.trim().toLowerCase();
      await _provider.loadSalesStaffSummary(
        startDate: widget.dateRange?.start ?? now,
        endDate: widget.dateRange?.end ?? now,
        shouldFilterByBranch: id.isNotEmpty && id != 'all',
        selectedBranchId: id,
      );
    } catch (e) {
      debugPrint('Staff summary error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    // restore the Sales Report search so it doesn't filter this list
    Future.microtask(() => _provider.updateSearch(_previousSearch));
    _searchCtrl.dispose();
    _hh.dispose();
    _vv.dispose();
    super.dispose();
  }

  void _openTransactions(StaffRow r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalesStaffTransactionsPage(
          staffName: r.staff,
          staffEmail: r.email,
          branchId: widget.branchId,
          branchLabel: widget.branchName,
          dateRange: widget.dateRange,
        ),
      ),
    );
  }

  List<StaffRow> _rows(Datafeed p) => p
      .filteredSalesStaffRows()
      .map((m) => StaffRow.fromMap(Map<String, dynamic>.from(m)))
      .toList();

  String _fmtPeriod(DateTimeRange? d) {
    final f = DateFormat('dd MMMM yyyy, hh:mm a');
    if (d == null) return f.format(DateTime.now());
    return '${f.format(d.start)}  -  ${f.format(d.end)}';
  }

 
  Future<void> _printStaffSummary(
    List<StaffRow> rows,
    List<PayMethod> pdfMethods,
  ) async {
    final nf = NumberFormat('#,##0.00');
    String money(double v) => 'GHS ${nf.format(v)}';

    final ttfRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final ttfBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );

    double sum(double Function(StaffRow) f) =>
        rows.fold(0.0, (a, r) => a + f(r));

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
      3,
      16,
      11,
      11,
      10,
      10,
      11,
      ...pdfMethods.map((_) => 10.0),
      10,
      11,
    ];

    final pdfRows = <List<String>>[
      for (int i = 0; i < rows.length; i++)
        [
          '${i + 1}',
          rows[i].staff,
          f2(rows[i].cashSales),
          f2(rows[i].creditSales),
          f2(rows[i].returns),
          f2(rows[i].discount),
          f2(rows[i].debtTotal),
          for (final m in pdfMethods) f2(rows[i].methodTotal(m)),
          f2(rows[i].profit),
          f2(rows[i].cashAtHand),
        ],
    ];

    final totalsRow = <String>[
      '',
      'TOTAL',
      f2(sum((r) => r.cashSales)),
      f2(sum((r) => r.creditSales)),
      f2(sum((r) => r.returns)),
      f2(sum((r) => r.discount)),
      f2(sum((r) => r.debtTotal)),
      for (final m in pdfMethods) f2(sum((r) => r.methodTotal(m))),
      f2(sum((r) => r.profit)),
      f2(sum((r) => r.cashAtHand)),
    ];

    // payments shown in heading: only what is NOT already a table column
    final payments = <MapEntry<String, double>>[
      MapEntry('Cash', sum((r) => r.cashSales + r.debtCash)),
      for (final m in kPayMethods)
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
          font: bold ? ttfBold : ttfRegular,
          fontSize: fontSize,
        ),
      ),
    );

    pw.Widget payRow(String label, double value, {bool right = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            mainAxisAlignment: right
                ? pw.MainAxisAlignment.end
                : pw.MainAxisAlignment.start,
            children: [
              pw.Text(
                '$label:  ',
                style: pw.TextStyle(font: ttfBold, fontSize: 10),
              ),
              pw.Text(
                money(value),
                style: pw.TextStyle(font: ttfRegular, fontSize: 10),
              ),
            ],
          ),
        );

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: wide ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _provider.company.toString().toUpperCase(),
                    style: pw.TextStyle(font: ttfBold, fontSize: 22),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Branch: ${widget.branchName}',
                    style: pw.TextStyle(
                      font: ttfRegular,
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
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
                    _fmtPeriod(widget.dateRange),
                    style: pw.TextStyle(font: ttfRegular, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
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
          pw.Table(
            columnWidths: {
              for (var i = 0; i < flex.length; i++)
                i: pw.FlexColumnWidth(flex[i]),
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
              ...pdfRows.map(
                (r) => pw.TableRow(
                  children: [for (var c = 0; c < r.length; c++) cell(r[c], c)],
                ),
              ),
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
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(
                  font: ttfRegular,
                  fontSize: 9,
                  color: PdfColors.grey500,
                ),
              ),
              pw.Text(
                'Staff Summary - ${_provider.company}',
                style: pw.TextStyle(
                  font: ttfRegular,
                  fontSize: 9,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ----------------------------- UI -----------------------------

  Widget _breakdownCell({
    required double shown,
    required String title,
    required Map<String, double> lines,
    required String totalLabel,
    required double total,
  }) {
    return Tooltip(
      message: tipText(lines, totalLabel, total),
      child: InkWell(
        onTap: () =>
            showBreakdownDialog(context, title, lines, totalLabel, total),
        child: Text(
          f2(shown),
          style: TextStyle(
            color: _textColor,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _mobileList(List<StaffRow> rows, List<PayMethod> active) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final r = rows[index];
        return InkWell(
          onTap: () => _openTransactions(r),
          child: Card(
            color: _field,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${index + 1}',
                    style: TextStyle(
                      color: _mutedTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.staff,
                    style: TextStyle(
                      color: _isLightTheme
                          ? Theme.of(context).colorScheme.primary
                          : Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      miniStatTap(
                        context,
                        'Cash Sales',
                        f2(r.cashSales),
                        onTap: () => showBreakdownDialog(
                          context,
                          'Cash Sales Breakdown',
                          r.cashSalesLines,
                          'All Payment Methods',
                          r.allSales,
                        ),
                      ),
                      miniStatString(
                        context,
                        'Credit Sales',
                        f2(r.creditSales),
                      ),
                      miniStatTap(
                        context,
                        'Returns',
                        f2(r.returns),
                        onTap: () => showBreakdownDialog(
                          context,
                          'Returns Breakdown',
                          r.returnsLines,
                          'Total Returns',
                          r.returns,
                        ),
                      ),
                      miniStatTap(
                        context,
                        'Discount',
                        f2(r.discount),
                        onTap: () => showBreakdownDialog(
                          context,
                          'Discount Breakdown',
                          r.discountLines,
                          'Total Discount',
                          r.discount,
                        ),
                      ),
                      miniStatTap(
                        context,
                        'Debt Payment',
                        f2(r.debtTotal),
                        onTap: () => showBreakdownDialog(
                          context,
                          'Debt Payment Breakdown',
                          r.debtLines,
                          'Total',
                          r.debtTotal,
                        ),
                      ),
                      for (final m in active)
                        miniStatTap(
                          context,
                          m.label,
                          f2(r.methodTotal(m)),
                          onTap: () => showBreakdownDialog(
                            context,
                            '${m.label} Breakdown',
                            {
                              'Sales': r.sales[m.id] ?? 0,
                              'Debt Payment': r.debt[m.id] ?? 0,
                            },
                            'Total',
                            r.methodTotal(m),
                          ),
                        ),
                      miniStatString(context, 'Profit', f2(r.profit)),
                      miniStatTap(
                        context,
                        'Cash @ Hand',
                        f2(r.cashAtHand),
                        onTap: () => showBreakdownDialog(
                          context,
                          'Cash @ Hand Breakdown',
                          r.cashAtHandLines,
                          'Calculated Total',
                          r.calcCashAtHand,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _desktopTable(List<StaffRow> rows, List<PayMethod> active) {
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
    final flex = <int>[
      3,
      16,
      12,
      12,
      11,
      11,
      13,
      ...active.map((_) => 12),
      11,
      13,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = headers.length * 105.0 + 32;
        final tableWidth = constraints.maxWidth > contentWidth
            ? constraints.maxWidth
            : contentWidth;

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
                        alignment: i >= 2
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: cells[i],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        Widget plain(String v) => Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _textColor),
        );

        Widget hover(
          double shown,
          String title,
          Map<String, double> lines,
          String totalLabel,
          double total,
        ) => _breakdownCell(
          shown: shown,
          title: title,
          lines: lines,
          totalLabel: totalLabel,
          total: total,
        );

        return RawScrollbar(
          controller: _hh,
          thumbVisibility: true,
          trackVisibility: true,
          thumbColor: _isLightTheme
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFF415A77),
          trackColor: _isLightTheme ? _field : const Color(0xFF22304A),
          trackBorderColor: _bar,
          thickness: 10,
          radius: const Radius.circular(8),
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _hh,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: _bar,
                    child: rowOf([
                      for (final h in headers)
                        Text(
                          h,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                    ]),
                  ),
                  Divider(height: 1, color: _borderColor),
                  Expanded(
                    child: RawScrollbar(
                      controller: _vv,
                      thumbVisibility: true,
                      trackVisibility: true,
                      thumbColor: _isLightTheme
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFF415A77),
                      trackColor: _isLightTheme
                          ? _field
                          : const Color(0xFF22304A),
                      trackBorderColor: _bar,
                      thickness: 10,
                      radius: const Radius.circular(8),
                      scrollbarOrientation: ScrollbarOrientation.right,
                      child: ListView.builder(
                        controller: _vv,
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          return InkWell(
                            onTap: () => _openTransactions(r),
                            child: rowOf(
                              [
                                plain('${i + 1}'),
                                plain(r.staff),
                                hover(
                                  r.cashSales,
                                  'Cash Sales Breakdown',
                                  r.cashSalesLines,
                                  'All Payment Methods',
                                  r.allSales,
                                ),
                                plain(f2(r.creditSales)),
                                hover(
                                  r.returns,
                                  'Returns Breakdown',
                                  r.returnsLines,
                                  'Total Returns',
                                  r.returns,
                                ),
                                hover(
                                  r.discount,
                                  'Discount Breakdown',
                                  r.discountLines,
                                  'Total Discount',
                                  r.discount,
                                ),
                                hover(
                                  r.debtTotal,
                                  'Debt Payment Breakdown',
                                  r.debtLines,
                                  'Total',
                                  r.debtTotal,
                                ),
                                for (final m in active)
                                  hover(
                                    r.methodTotal(m),
                                    '${m.label} Breakdown',
                                    {
                                      'Sales': r.sales[m.id] ?? 0,
                                      'Debt Payment': r.debt[m.id] ?? 0,
                                    },
                                    'Total',
                                    r.methodTotal(m),
                                  ),
                                plain(f2(r.profit)),
                                hover(
                                  r.cashAtHand,
                                  'Cash @ Hand Breakdown',
                                  r.cashAtHandLines,
                                  'Calculated Total',
                                  r.calcCashAtHand,
                                ),
                              ],
                              decoration: BoxDecoration(
                                color: _isLightTheme ? Colors.white : null,
                                border: Border(
                                  bottom: BorderSide(
                                    color: _borderColor,
                                    width: 0.5,
                                  ),
                                ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, provider, _) {
        final rows = _rows(provider);
        final active = kPayMethods
            .where((m) => _selectedMethods.contains(m.id))
            .toList();
        final isSmall = MediaQuery.sizeOf(context).width < 600;

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bar,
            elevation: 0,
            iconTheme: IconThemeData(color: _textColor),
            title: Text(
              '${widget.branchName.toUpperCase()} - STAFF TRANSACTIONS SUMMARY',
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Show payment method columns',
                color: _field,
                icon: Icon(
                  Icons.filter_list,
                  color: active.isNotEmpty ? _accentColor : _textColor,
                ),
                onSelected: (id) => setState(() {
                  _selectedMethods.contains(id)
                      ? _selectedMethods.remove(id)
                      : _selectedMethods.add(id);
                }),
                itemBuilder: (_) => [
                  for (final m in kPayMethods)
                    CheckedPopupMenuItem<String>(
                      value: m.id,
                      checked: _selectedMethods.contains(m.id),
                      child: Text(m.label, style: TextStyle(color: _textColor)),
                    ),
                ],
              ),
              IconButton(
                tooltip: 'Print / Download',
                icon: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: _textColor,
                  size: 20,
                ),
                onPressed: rows.isEmpty
                    ? null
                    : () async {
                        try {
                          await _printStaffSummary(rows, active);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Print failed: $e')),
                            );
                          }
                        }
                      },
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    provider.updateSearch(val);
                    setState(() {});
                  },
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search staff...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              provider.updateSearch('');
                              setState(() {});
                            },
                          ),
                    filled: true,
                    fillColor: _field,
                    border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              if (active.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final m in active)
                          InputChip(
                            label: Text(
                              m.label,
                              style: TextStyle(color: _textColor, fontSize: 12),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            deleteIconColor: _mutedTextColor,
                            onDeleted: () =>
                                setState(() => _selectedMethods.remove(m.id)),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(color: _textColor),
                      )
                    : rows.isEmpty
                    ? Center(
                        child: Text(
                          'No transactions found',
                          style: TextStyle(color: _mutedTextColor),
                        ),
                      )
                    : isSmall
                    ? _mobileList(rows, active)
                    : _desktopTable(rows, active),
              ),
            ],
          ),
        );
      },
    );
  }
}
