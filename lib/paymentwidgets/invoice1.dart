

import 'package:flutter/services.dart' show rootBundle;
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/Datafeed.dart';
import 'package:provider/provider.dart';
import '../models/Receiptdatamodel.dart';

String _qty(double q) =>
    q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

class ReceiptPrinter {
  static String _money(double v) => v.toStringAsFixed(2);
  static String _gh(double v) => 'GHS ${_money(v)}';
  static String _two(int n) => n.toString().padLeft(2, '0');


  static const PdfPageFormat roll80 = PdfPageFormat(
    72.1 * PdfPageFormat.mm,
    double.infinity,
    marginAll: 0,
  );

  static PdfPageFormat getFormat(String size) {
    switch (size.toLowerCase()) {
      case 'thermal':
      case '80mm':
      case '58mm':
        return roll80;
      default:
        return PdfPageFormat.a4;
    }
  }

  static Future<pw.Document> build(
      ReceiptData data, {
        required PdfPageFormat format,
      }) async {
    final reg =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    final mute = PdfColor.fromHex('#555555');

    String _cap(String s) => s.trim().split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');

    final isRoll = format.height == double.infinity;
    const pageMargin = 24.0;
    final usable =
    isRoll ? format.availableWidth : format.width - pageMargin * 2;
    final s = (usable / 198).clamp(1.0, 1.6).toDouble();

    pw.TextStyle st(double size, {bool b = false, PdfColor? color}) =>
        pw.TextStyle(
            font: b ? bold : reg,
            fontSize: size * s,
            color: color ?? PdfColors.black);

    //data
    final isSalesPoint =
        (data.branchType ?? '').trim().toLowerCase() == 'sales point';
    final title = data.receiptName.trim().isEmpty
        ? 'SALES RECEIPT'
        : data.receiptName.toUpperCase();
    final company = data.companyName.trim().toUpperCase();
    final branch = (data.branch ?? '').trim();
    final address = (data.address ?? '').trim();
    final cashier = _cap(data.cashier.trim().split(' ').first);
    final customer = data.customername.trim().isEmpty
        ? 'Cash Customer'
        : data.customername.trim();
    final barcodeText = data.barcode.trim().isNotEmpty
        ? data.barcode.trim()
        : data.receiptNumber;
    final when = data.datetime;
    final units = data.items.fold<double>(0, (a, i) => a + i.qty.toDouble());
    final change = data.change < 0 ? 0.0 : data.change.toDouble();
    final isChristmas = DateTime.now().month == 12;


    String itemName(dynamic i) {
      return (i.isService || i.mode.trim().isEmpty)
          ? i.name.toString()
          : '${i.name} (${i.mode})';
    }

    String itemWarehouse(dynamic i) {
      if (!isSalesPoint) return '';
      final wh = (i.branch ?? '').toString().trim();
      return wh.isEmpty ? '' : '($wh)';
    }
    pw.Widget dashed() => pw.Divider(
        height: 6, thickness: 0.6, borderStyle: pw.BorderStyle.dashed);
    pw.Widget solid() => pw.Divider(height: 10, thickness: 1.6);

    pw.Widget centered(String t,
        {double size = 8.5, bool b = false, PdfColor? c}) =>
        pw.Center(
            child: pw.Text(t,
                style: st(size, b: b, color: c),
                textAlign: pw.TextAlign.center));

    pw.Widget kv(String a, String v, {double size = 8.5, bool b = false}) =>
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(a, style: st(size, b: b)),
            pw.Text(v, style: st(size, b: b)),
          ],
        );

    pw.Widget cols(String a, String q, String p, String t,
        {bool b = false, double size = 8.5}) =>
        pw.Row(children: [
          pw.Expanded(child: pw.Text(a, style: st(size, b: b))),
          pw.SizedBox(
              width: 20 * s,
              child: pw.Text(q,
                  style: st(size, b: b), textAlign: pw.TextAlign.right)),
          pw.SizedBox(width: 5 * s),
          pw.SizedBox(
              width: 40 * s,
              child: pw.Text(p,
                  style: st(size, b: b), textAlign: pw.TextAlign.right)),
          pw.SizedBox(width: 5 * s),
          pw.SizedBox(
              width: 46 * s,
              child: pw.Text(t,
                  style: st(size, b: b), textAlign: pw.TextAlign.right)),
        ]);

    //content
    final content = <pw.Widget>[
      centered(company, size: 15, b: true),
      if (branch.isNotEmpty) centered(branch, size: 8, c: mute),
      for (final line in address.split('\n'))
        if (line.trim().isNotEmpty) centered(line),
      if (data.contact.trim().isNotEmpty) centered('Tel: ${data.contact}'),
      dashed(),
      centered(title, size: 10, b: true),
      dashed(),
      kv('Receipt No:', data.receiptNumber),
      kv('Date:', '${_two(when.day)}/${_two(when.month)}/${when.year}'),
      kv('Time:',
          '${_two(when.hour)}:${_two(when.minute)}:${_two(when.second)}'),
      kv('Cashier:', cashier),
      kv('Customer:', customer),
      dashed(),
      cols('ITEM', 'QTY', 'PRICE', 'TOTAL', b: true, size: 8),
      pw.Divider(height: 4, thickness: 0.6),

      for (final i in data.items)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              cols(
                itemName(i),
                _qty(i.qty.toDouble()),
                _money(i.price.toDouble()),
                _money(i.qty.toDouble() * i.price.toDouble()),
                b: true,
              ),
              if (itemWarehouse(i).isNotEmpty)
                pw.Text(itemWarehouse(i), style: st(7, color: mute)),
            ],
          ),
        ),
      dashed(),
      kv('Subtotal', _gh(data.subTotal.toDouble())),
      kv('Discount', '-${_gh(data.discount.toDouble())}'),
      solid(),
      kv('PAYABLE', _gh(data.payable.toDouble()), size: 11, b: true),
      solid(),
      kv('Paid', _gh(data.amountPaid.toDouble())),
      kv('Change', _gh(change), b: true),
      dashed(),
      centered(isChristmas
          ? 'Thank you for choosing ${data.companyName.trim()}. Happy Christmas!'
          : 'Thank you for choosing ${data.companyName.trim()}!'),
      if (data.companyName.toLowerCase() == 'farmertribe')
        centered(
          'Exchanges accepted within 7 days. No cash refund.',
          size: 8,
          c: mute,
        )
      else
        centered(
          'Goods sold are not returnable.',
          size: 8,
          c: mute,
        ),
      pw.SizedBox(height: 1),
      centered('POWERED BY KOLOGSOFT', size: 7, c: mute),
      dashed(),
      pw.SizedBox(height: 1),
      pw.Center(
        child: pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: barcodeText,
          width: 30,
          height: 30,
          drawText: false,
          color: PdfColors.black,
        ),
      ),
      dashed(),
      if ((data.dailyNumber ?? '').isNotEmpty)
        kv('RECEIPT NO:', '#${data.dailyNumber}',size: 16, b: true),
    ];

    final doc = pw.Document(title: data.transactionId);

    if (isRoll) {
      doc.addPage(pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(4),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: content,
        ),
      ));
    } else {
      doc.addPage(pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(pageMargin),
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        build: (context) => content,
      ));
    }
    return doc;
  }
}