//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:intl/intl.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
//
// Future<void> printSalesStaffTransactionsPdf({
//   required String staffName,
//   required List<Map<String, dynamic>> sales,
//   String companyName      = '',
//   String branchName       = 'All Branches',
//   DateTimeRange? dateRange,
// }) async {
//   final ttfRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
//   final ttfBold    = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
//   final pdf = pw.Document(
//     title: '$companyName Sales Staff Transactions Report',
//     theme: pw.ThemeData.withFont(
//   base: ttfRegular,
//     bold: ttfBold,
//     italic: ttfRegular,
//     boldItalic: ttfBold,
//   ),
//   );
//
//
//
//   const accent   = PdfColor.fromInt(0xFF1565C0);
//   const headerBg = PdfColor.fromInt(0xFF1E3A5F);
//   const rowAlt   = PdfColor.fromInt(0xFFF0F4FA);
//   const white    = PdfColors.white;
//   const dark     = PdfColor.fromInt(0xFF0D1B2A);
//
//   double totalAmount   = 0;
//   double totalDiscount = 0;
//   for (final s in sales) {
//     totalAmount   += (s['amount']   ?? 0).toDouble();
//     totalDiscount += (s['discount'] ?? 0).toDouble();
//   }
//
//   pw.TextStyle boldWhite(double size) =>
//       pw.TextStyle(font: ttfBold, color: white, fontWeight: pw.FontWeight.bold, fontSize: size);
//
//   pw.TextStyle cellStyle({bool bold = false, PdfColor? color}) => pw.TextStyle(
//     font: ttfRegular,
//
//     fontSize: 8,
//     color: color ?? dark,
//     fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
//   );
//
//   final headers = [
//     '#', 'Date', 'Receipt', 'Customer',
//     'Items', 'Amount', 'Discount',
//     'Payment', 'Branch', 'Mode',
//   ];
//   final widths = [
//     20.0, 75.0, 75.0, 75.0,
//     30.0, 55.0, 50.0,
//     50.0, 55.0, 40.0,
//   ];
//
//   const int rowsPerPage = 20;
//   final pageCount = (sales.length / rowsPerPage).ceil().clamp(1, 9999);
//
//   for (int pageIdx = 0; pageIdx < pageCount; pageIdx++) {
//     final pageRows = sales
//         .skip(pageIdx * rowsPerPage)
//         .take(rowsPerPage)
//         .toList();
//     final isLastPage = pageIdx == pageCount - 1;
//
//     pdf.addPage(
//       pw.Page(
//         pageFormat: PdfPageFormat.a4.landscape,
//         margin: const pw.EdgeInsets.all(24),
//         build: (ctx) => pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//
//             //Header banner
//             pw.Container(
//               width: double.infinity,
//               padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//               decoration: pw.BoxDecoration(
//                 color: headerBg,
//                 borderRadius: pw.BorderRadius.circular(6),
//               ),
//               child: pw.Row(
//                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                 children: [
//                   pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.start,
//                     children: [
//                       pw.Text(companyName.toUpperCase(), style: boldWhite(14)),
//                       pw.SizedBox(height: 2),
//                       pw.Text('Sales Staff Transactions Report',
//                           style: pw.TextStyle(
//                               color: PdfColors.blueGrey200, fontSize: 9)),
//                       pw.SizedBox(height: 2),
//                       pw.Text('Staff: ${staffName.toUpperCase()}',
//                           style: boldWhite(9)),
//                     ],
//                   ),
//                   pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.end,
//                     children: [
//                       pw.Text('Branch: $branchName', style: boldWhite(9)),
//                       pw.SizedBox(height: 2),
//                       if (dateRange != null)
//                         pw.Text(
//                           'Period: ${DateFormat('d MMM y').format(dateRange.start)}'
//                               ' - ${DateFormat('d MMM y').format(dateRange.end)}',
//                           style: pw.TextStyle(
//                               color: PdfColors.blueGrey200,font: ttfRegular, fontSize: 8),
//                         ),
//                       pw.Text(
//                         'Generated: ${DateFormat('d MMMM y').format(DateTime.now())}',
//                         style: pw.TextStyle(
//                             color: PdfColors.blueGrey200,font: ttfRegular, fontSize: 8),
//                       ),
//                       pw.Text('Page ${pageIdx + 1} of $pageCount',
//                           style: pw.TextStyle(
//                               color: PdfColors.blueGrey200,font: ttfRegular, fontSize: 8)),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//
//             pw.SizedBox(height: 10),
//
//             // ── Summary bar
//             pw.Container(
//               width: double.infinity,
//               padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: pw.BoxDecoration(
//                 color: accent,
//                 borderRadius: pw.BorderRadius.circular(4),
//               ),
//               child: pw.Wrap(
//                 spacing: 24,
//                 children: [
//                   pw.Text('Total Transactions: ${sales.length}',
//                       style: boldWhite(9)),
//                   pw.Text(
//                       'Total Amount: GHC ${totalAmount.toStringAsFixed(2)}',
//                       style: boldWhite(9)),
//                   pw.Text(
//                       'Total Discount: GHC ${totalDiscount.toStringAsFixed(2)}',
//                       style: boldWhite(9)),
//                 ],
//               ),
//             ),
//
//             pw.SizedBox(height: 6),
//
//             // ── Table
//             pw.Table(
//               columnWidths: {
//                 for (int i = 0; i < widths.length; i++)
//                   i: pw.FixedColumnWidth(widths[i]),
//               },
//               border: pw.TableBorder(
//                 horizontalInside: pw.BorderSide(
//                     color: PdfColors.blueGrey100, width: 0.5),
//                 bottom: pw.BorderSide(
//                     color: PdfColors.blueGrey200, width: 0.5),
//               ),
//               children: [
//
//                 // Column headers
//                 pw.TableRow(
//                   decoration: pw.BoxDecoration(color: headerBg),
//                   children: headers.map((h) => pw.Padding(
//                     padding: const pw.EdgeInsets.symmetric(
//                         horizontal: 4, vertical: 6),
//                     child: pw.Text(h,
//                         style: boldWhite(8),
//                         textAlign: pw.TextAlign.center),
//                   )).toList(),
//                 ),
//
//                 // Data rows
//                 ...pageRows.asMap().entries.map((entry) {
//                   final rowNum = pageIdx * rowsPerPage + entry.key + 1;
//                   final s      = entry.value;
//                   final isAlt  = entry.key.isOdd;
//
//
//                   String formattedDate = '';
//                   try {
//                     final date = (s['datetime'] as Timestamp).toDate();
//                     formattedDate =
//                         DateFormat('yyyy-MM-dd  hh:mm a').format(date);
//                   } catch (_) {
//                     formattedDate = s['datetime']?.toString() ?? '';
//                   }
//
//                   final amount   = (s['amount']   ?? 0).toDouble();
//                   final discount = (s['discount'] ?? 0).toDouble();
//
//                   final cells = [
//                     '$rowNum',
//                     formattedDate,
//                     '${s['receipt']  ?? ''}',
//                     '${s['customer'] ?? ''}',
//                     '${s['items']    ?? ''}',
//                     'GHC ${amount.toStringAsFixed(2)}',
//                     'GHC ${discount.toStringAsFixed(2)}',
//                     '${s['payment']  ?? ''}',
//                     '${s['branch']   ?? ''}',
//                     '${s['mode']     ?? ''}',
//                   ];
//
//                   return pw.TableRow(
//                     decoration: isAlt
//                         ? const pw.BoxDecoration(color: rowAlt)
//                         : null,
//                     children: cells.asMap().entries.map((e) => pw.Padding(
//                       padding: const pw.EdgeInsets.symmetric(
//                           horizontal: 4, vertical: 5),
//                       child: pw.Text(
//                         e.value,
//                         style: cellStyle(bold: e.key == 5),
//                         textAlign: (e.key == 1 || e.key == 2 ||
//                             e.key == 3 || e.key == 7 ||
//                             e.key == 8 || e.key == 9)
//                             ? pw.TextAlign.left
//                             : pw.TextAlign.right,
//                       ),
//                     )).toList(),
//                   );
//                 }),
//
//                 // Totals row on last page
//                 if (isLastPage)
//                   pw.TableRow(
//                     decoration: const pw.BoxDecoration(color: headerBg),
//                     children: [
//                       pw.Padding(padding: const pw.EdgeInsets.all(4),
//                           child: pw.Text('', style: boldWhite(7))),
//                       pw.Padding(padding: const pw.EdgeInsets.all(4),
//                           child: pw.Text('TOTAL', style: boldWhite(8))),
//                       pw.Padding(padding: const pw.EdgeInsets.all(4),
//                           child: pw.Text('', style: boldWhite(7))),
//                       pw.Padding(padding: const pw.EdgeInsets.all(4),
//                           child: pw.Text('', style: boldWhite(7))),
//                       pw.Padding(padding: const pw.EdgeInsets.all(4),
//                           child: pw.Text('', style: boldWhite(7))),
//                       pw.Padding(
//                         padding: const pw.EdgeInsets.all(4),
//                         child: pw.Text(
//                           'GHC ${totalAmount.toStringAsFixed(2)}',
//                           style: boldWhite(8),
//                           textAlign: pw.TextAlign.right,
//                         ),
//                       ),
//                       pw.Padding(
//                         padding: const pw.EdgeInsets.all(4),
//                         child: pw.Text(
//                           'GHC ${totalDiscount.toStringAsFixed(2)}',
//                           style: boldWhite(8),
//                           textAlign: pw.TextAlign.right,
//                         ),
//                       ),
//                       pw.Padding(padding: const pw.EdgeInsets.all(4),
//                           child: pw.Text('', style: boldWhite(7))),
//                       pw.Padding(padding: const pw.EdgeInsets.all(4),
//                           child: pw.Text('', style: boldWhite(7))),
//                       pw.Padding(padding: const pw.EdgeInsets.all(4),
//                           child: pw.Text('', style: boldWhite(7))),
//                     ],
//                   ),
//               ],
//             ),
//
//             pw.Spacer(),
//
//             // ── Footer
//             pw.Divider(color: PdfColors.blueGrey200, thickness: 0.5),
//             pw.Row(
//               mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//               children: [
//                 pw.Text('Confidential - $companyName',
//                     style: pw.TextStyle(
//                         fontSize: 7, font: ttfRegular, color: PdfColors.blueGrey400)),
//                 pw.Text('${staffName.toUpperCase()} | Sales Transactions',
//                     style: pw.TextStyle(
//                         fontSize: 7, font: ttfRegular, color: PdfColors.blueGrey400)),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   await Printing.layoutPdf(
//     onLayout: (_) async => pdf.save(),
//     name: '${staffName}_sales_${DateTime.now().millisecondsSinceEpoch}.pdf',
//   );
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> printSalesStaffTransactionsPdf({
  required String staffName,
  required List<Map<String, dynamic>> sales,
  String companyName = '',
  String branchName = 'All Branches',
  DateTimeRange? dateRange,
  String? paymentFilter, // e.g. "Cash" when a chip filter is active
}) async {
  final ttfRegular =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final ttfBold =
  pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

  final nf = NumberFormat('#,##0.00');
  String money(double v) => 'GHC ${nf.format(v)}';

  double num_(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;

  DateTime resolveDate(Map<String, dynamic> s) {
    final d = s['datetime'];
    if (d is Timestamp) return d.toDate();
    return DateTime.tryParse(s['date']?.toString() ?? '') ?? DateTime.now();
  }

  int itemCount(dynamic items) {
    if (items is Map) return items.length;
    if (items is List) return items.length;
    return 0;
  }

  String methodName(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('momo')) return 'Merchant MoMo';
    if (m.contains('hubtel')) return 'Hubtel';
    if (m.contains('card')) return 'Card';
    if (m.contains('bank')) return 'Bank Transfer';
    if (m.contains('cheque')) return 'Cheque';
    if (m.contains('cash')) return 'Cash';
    if (m.isEmpty) return 'Other';
    return m[0].toUpperCase() + m.substring(1);
  }

  // ── Totals
  double totalAmount = 0, totalPaid = 0, totalDiscount = 0;
  final byMethod = <String, double>{};

  for (final s in sales) {
    totalAmount += num_(s['amount']);
    totalPaid += num_(s['amountPaid']);
    totalDiscount += num_(s['discount']);

    final pays = s['payments'];
    var counted = false;
    if (pays is List) {
      for (final p in pays) {
        if (p is! Map) continue;
        if (p['status'] == false) continue; // skip failed payments
        final amt = num_(p['amount']);
        if (amt == 0) continue;
        final name = methodName((p['method'] ?? '').toString());
        byMethod[name] = (byMethod[name] ?? 0) + amt;
        counted = true;
      }
    }
    // fallback for sales without a payments list
    if (!counted) {
      final label = (s['payment'] ?? '').toString();
      final paid = num_(s['amountPaid']);
      if (label.isNotEmpty && paid > 0) {
        final name = methodName(label);
        byMethod[name] = (byMethod[name] ?? 0) + paid;
      }
    }
  }

  final payments = byMethod.entries.where((e) => e.value > 0).toList();
  final half = (payments.length / 2).ceil();
  final leftPay = payments.take(half).toList();
  final rightPay = payments.skip(half).toList();

  // ── Table
  final headers = [
    '#', 'DATE', 'RECEIPT', 'CUSTOMER', 'ITEMS',
    'AMOUNT', 'AMOUNT PAID', 'DISCOUNT', 'PAYMENT',
  ];
  final flex = <double>[3, 15, 14, 14, 6, 11, 11, 9, 11];
  // columns aligned left: date, receipt, customer, payment
  bool isLeft(int c) => c == 1 || c == 2 || c == 3 || c == 8;

  final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  final rows = <List<String>>[
    for (int i = 0; i < sales.length; i++)
      [
        '${i + 1}',
        dateFmt.format(resolveDate(sales[i])),
        '${sales[i]['receipt'] ?? ''}',
        '${sales[i]['customer'] ?? ''}',
        '${itemCount(sales[i]['items'])}',
        nf.format(num_(sales[i]['amount'])),
        nf.format(num_(sales[i]['amountPaid'])),
        nf.format(num_(sales[i]['discount'])),
        '${sales[i]['payment'] ?? ''}',
      ],
  ];

  final totalsRow = [
    '', 'TOTAL', '', '', '',
    nf.format(totalAmount),
    nf.format(totalPaid),
    nf.format(totalDiscount),
    '',
  ];

  pw.Widget cell(String text, int col, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: pw.Text(
      text,
      textAlign: isLeft(col) || col == 0
          ? pw.TextAlign.left
          : pw.TextAlign.right,
      style: pw.TextStyle(font: bold ? ttfBold : ttfRegular, fontSize: 9),
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

  // ── Period: full month, day, year and time
  String period() {
    if (dateRange == null) return 'All dates';
    final f = DateFormat('dd MMMM yyyy, hh:mm a');
    return '${f.format(dateRange.start)}  -  ${f.format(dateRange.end)}';
  }

  final pdf = pw.Document(title: '$companyName Staff Transactions');

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
                pw.Text(companyName.toUpperCase(),
                    style: pw.TextStyle(font: ttfBold, fontSize: 22)),
                pw.SizedBox(height: 2),
                pw.Text('Branch: $branchName',
                    style: pw.TextStyle(
                        font: ttfRegular,
                        fontSize: 11,
                        color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text('Staff: ${staffName.toUpperCase()}',
                    style: pw.TextStyle(font: ttfBold, fontSize: 10)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('STAFF TRANSACTIONS',
                    style: pw.TextStyle(font: ttfBold, fontSize: 18)),
                pw.SizedBox(height: 4),
                pw.Text(period(),
                    style: pw.TextStyle(font: ttfRegular, fontSize: 10)),
                if (paymentFilter != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('Payment: $paymentFilter',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 10)),
                ],
              ],
            ),
          ],
        ),

        // ── Payment method totals in the heading (plain rows, no box)
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
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
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
                  top: pw.BorderSide(color: PdfColors.black, width: 0.8),
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
              '${staffName.toUpperCase()} - $companyName',
              style: pw.TextStyle(
                  font: ttfRegular, fontSize: 9, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (_) async => pdf.save(),
    name: '${staffName}_sales_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
}