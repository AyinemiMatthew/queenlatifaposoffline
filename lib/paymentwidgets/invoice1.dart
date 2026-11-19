import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../models/Receiptdatamodel.dart';

class ReceiptPrinter {
  static PdfPageFormat getFormat(String size) {
    switch (size.toLowerCase()) {
      case 'thermal':
      case '80mm':
        return PdfPageFormat(72.1 * PdfPageFormat.mm, 210 * PdfPageFormat.mm);
      case '58mm':
        return PdfPageFormat(58 * PdfPageFormat.mm, 210 * PdfPageFormat.mm);
      case 'a4':
      default:
        return PdfPageFormat.a4;
    }
  }

  PdfPageFormat _sanitizeFormat(PdfPageFormat format) {
    final width = (format.width.isFinite && format.width > 0)
        ? format.width
        : 72.1 * PdfPageFormat.mm;
    final height = (format.height.isFinite && format.height > 0)
        ? format.height
        : 210 * PdfPageFormat.mm;
    return PdfPageFormat(width, height);
  }

  Future<pw.Document> buildPdf(
      ReceiptData data, {
        PdfPageFormat pageFormat = PdfPageFormat.a4,
      }) async {
    pageFormat = _sanitizeFormat(pageFormat);

    final ttfRegular =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final ttfBold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final doc = pw.Document(title: data.transactionId);

    final isThermal = pageFormat.width <= 80 * PdfPageFormat.mm;
    final pageMargin = isThermal ? 0.0 : 10.0;
    final cardPadding = isThermal ? 4.0 : 14.0;
    final qrSize = (pageFormat.width - (pageMargin * 2) - (cardPadding * 2)) *
        (isThermal ? 0.25 : 0.18);

    final now = DateTime.now();
    final isChristmas = now.month == 12;
    final cashierName = data.cashier.trim();
    final receiptTitle = data.receiptName.trim().isEmpty
        ? 'OFFICIAL RECEIPT'
        : data.receiptName.toUpperCase();
    final companyName = data.companyName.trim().toUpperCase();
    final branchName = (data.branch ?? '').trim();
    final branchType = (data.branchType ?? '').trim();
    final address = (data.address ?? '').trim();

    final customerName = data.customername.trim().isEmpty
        ? 'Cash Customer'
        : data.customername.trim();
    final barcodeText = data.barcode.trim().isNotEmpty
        ? data.barcode.trim()
        : data.receiptNumber;

    pw.Widget dashedLine() {
      return pw.Text(
        '------------------------------------------------------------',
        style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey800),
        textAlign: pw.TextAlign.center,
      );
    }

    pw.Widget infoRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(font: ttfRegular, fontSize: 9)),
            pw.Text(value, style: pw.TextStyle(font: ttfRegular, fontSize: 9)),
          ],
        ),
      );
    }

    pw.Widget summaryRow(String title, double amount, {bool bold = false, double fontSize = 9, bool isNegative = false}) {
      final font = bold ? ttfBold : ttfRegular;
      final prefix = isNegative ? '-' : '';
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(title, style: pw.TextStyle(font: font, fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text('${prefix}GHS ${amount.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.symmetric(vertical: pageMargin, horizontal: pageMargin),
        build: (pw.Context context) {
          return [
            // Company Header
            pw.Center(
              child: pw.Text(
                companyName,
                style: pw.TextStyle(font: ttfBold, fontSize: 16, color: PdfColors.black),
                textAlign: pw.TextAlign.center,
              ),
            ),
            if (branchType.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  branchType,
                  style: pw.TextStyle(font: ttfRegular, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
            if (branchName.isNotEmpty && branchName != branchType) ...[
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  branchName,
                  style: pw.TextStyle(font: ttfRegular, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
            if (address.isNotEmpty) ...[
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  address,
                  style: pw.TextStyle(font: ttfRegular, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
            if (data.contact.isNotEmpty) ...[
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  'Tel: ${data.contact}',
                  style: pw.TextStyle(font: ttfRegular, fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],

            pw.SizedBox(height: 4),
            dashedLine(),
            pw.SizedBox(height: 4),

            // Official Receipt Title
            pw.Center(
              child: pw.Text(
                receiptTitle,
                style: pw.TextStyle(font: ttfBold, fontSize: 12, color: PdfColors.black),
              ),
            ),

            pw.SizedBox(height: 4),
            dashedLine(),
            pw.SizedBox(height: 4),

            // Metadata
            infoRow('Receipt No:', data.receiptNumber),
            infoRow('Date:', _formatPdfDate(data.datetime)),
            infoRow('Time:', _formatPdfTime(data.datetime)),
            infoRow('Cashier:', cashierName),
            infoRow('Customer:', customerName),

            pw.SizedBox(height: 4),
            dashedLine(),
            pw.SizedBox(height: 4),

            // Items Table Header
            pw.Row(
              children: [
                pw.Expanded(flex: 3, child: pw.Text('ITEM', style: pw.TextStyle(font: ttfBold, fontSize: 9))),
                pw.Expanded(flex: 1, child: pw.Text('QTY', style: pw.TextStyle(font: ttfBold, fontSize: 9), textAlign: pw.TextAlign.center)),
                pw.Expanded(flex: 1, child: pw.Text('PRICE', style: pw.TextStyle(font: ttfBold, fontSize: 9), textAlign: pw.TextAlign.right)),
                pw.Expanded(flex: 1, child: pw.Text('TOTAL', style: pw.TextStyle(font: ttfBold, fontSize: 9), textAlign: pw.TextAlign.right)),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Divider(color: PdfColors.black, thickness: 0.8),
            pw.SizedBox(height: 2),

            // Items List
            ...data.items.map((i) {
              final qtyText = i.qty == i.qty.roundToDouble()
                  ? i.qty.toStringAsFixed(0)
                  : i.qty.toStringAsFixed(2);
              final itemText = (i.isService || i.mode.trim().isEmpty)
                  ? i.name
                  : '${i.name} (${i.mode})';
              final lineTotal = i.qty * i.price;

              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text(itemText, style: pw.TextStyle(font: ttfRegular, fontSize: 9))),
                    pw.Expanded(flex: 1, child: pw.Text(qtyText, style: pw.TextStyle(font: ttfRegular, fontSize: 9), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 1, child: pw.Text(i.price.toStringAsFixed(2), style: pw.TextStyle(font: ttfRegular, fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 1, child: pw.Text(lineTotal.toStringAsFixed(2), style: pw.TextStyle(font: ttfRegular, fontSize: 9), textAlign: pw.TextAlign.right)),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 4),
            dashedLine(),
            pw.SizedBox(height: 4),

            summaryRow('Subtotal', data.subTotal),
            summaryRow('Discount', data.discount, isNegative: data.discount > 0),

            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.black, thickness: 1.2),
            pw.SizedBox(height: 2),

            // Payable
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('PAYABLE', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                pw.Text('GHS ${data.payable.toStringAsFixed(2)}', style: pw.TextStyle(font: ttfBold, fontSize: 11)),
              ],
            ),

            pw.SizedBox(height: 2),
            pw.Divider(color: PdfColors.black, thickness: 1.2),
            pw.SizedBox(height: 4),

            summaryRow('Paid', data.amountPaid),
            summaryRow('Change', data.change < 0 ? 0.0 : data.change, bold: true),

            pw.SizedBox(height: 4),
            dashedLine(),
            pw.SizedBox(height: 6),

            // Footer Messages
            pw.Center(
              child: pw.Text(
                isChristmas
                    ? 'Thank you for choosing $companyName. Happy Christmas!'
                    : 'Thank you for choosing $companyName!',
                style: pw.TextStyle(font: ttfRegular, fontSize: 9),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'Goods sold are not returnable.',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'POWERED BY KOLOGSOFT',
                style: pw.TextStyle(font: ttfRegular, fontSize: 7, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
            ),

            pw.SizedBox(height: 4),
            dashedLine(),
            pw.SizedBox(height: 8),

            // QR Code
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: barcodeText,
                width: qrSize,
                height: qrSize,
              ),
            ),
            if (data.dailyNumber != null) ...[
              pw.SizedBox(height: 4),
              dashedLine(),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'RECEIPT NO: #${data.dailyNumber}',
                  style: pw.TextStyle(font: ttfBold, fontSize: 14, color: PdfColors.black),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ];
        },
      ),
    );

    return doc;
  }

  String _formatPdfDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatPdfTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }
}
