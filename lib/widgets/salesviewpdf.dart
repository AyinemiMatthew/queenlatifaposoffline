

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/Receiptdatamodel.dart';
import '../models/salesmodel.dart';
import '../paymentwidgets/PDFprints/print_service.dart';
import '../paymentwidgets/invoice1.dart';
import '../paymentwidgets/receipt_formatter.dart';
import '../providers/Datafeed.dart';
import '../providers/SalesProvider.dart';


Future<void> _sendToPrinter(dynamic doc, ReceiptData receiptData, String docId) async {
  final isWindowsDesktop =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  if (isWindowsDesktop) {
    final printer = await PrintService.getSavedPrinter();
    if (printer == null) {
      throw Exception('No printer selected for silent Windows printing.');
    }
    final width = receiptWidthForPrinter(printer);
    final rawResult = await PrintService.printRaw(
      printerName: printer,
      text: buildRawReceiptText(receiptData, width: width),
    );
    if (!rawResult.success) {
      final pdfResult =
      await PrintService.printPdf(printerName: printer, pdf: doc);
      if (!pdfResult.success) {
        throw Exception(
          'Windows print failed: ${rawResult.errorMessage ?? 'Raw print failed'}. '
              'PDF fallback failed: ${pdfResult.errorMessage ?? 'Unknown error'}.',
        );
      }
    }
  } else {
    await Printing.layoutPdf(
      name: docId,
      onLayout: (format) async => doc.save(),
    );
  }
}


Future<void> printSalesModelReceipt(BuildContext context, SalesModel sv) async {
  final datafeed = context.read<Datafeed>();
  final salesProvider = context.read<SalesProvider>();

  try {

    final itemMaps = Map<String, dynamic>.from(sv.items ?? {}).values.whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m)).toList();

    final receiptItems = itemMaps.map((e) {
      return ReceiptItem(
        name: e['item']?.toString() ?? '',
        qty: double.tryParse(e['quantity'].toString()) ?? 0,
        price: double.tryParse(e['price'].toString()) ?? 0,
        mode: e['mode']?.toString() ?? '',
        isService: (e['producttype']?.toString().toLowerCase().trim() ?? '') == 'service',
        branch: e['branchname']?.toString(),
      );
    }).toList();


    final payable = itemMaps.fold<double>(0,(sum, e) => sum + (double.tryParse(e['totalamount']?.toString() ?? '0') ?? 0), );
    final discount = (sv.discount ?? 0).toDouble();

    final created = sv.createdAt;
    final saleDate = created is Timestamp ? created.toDate() : DateTime.now();

    final receiptData = ReceiptData(
      cashier: sv.createdBy ?? datafeed.staff,
      barcode: sv.receiptNumber,
      items: receiptItems,
      companyName: sv.companyname.isNotEmpty ? sv.companyname : datafeed.company,
      transactionId: sv.id,
      contact: datafeed.branchphone,
      customername: (sv.customerName ?? '').isEmpty ? 'Cash Customer' : sv.customerName!,
      datetime: saleDate,
      email: datafeed.companyemail,
      receiptNumber: sv.receiptNumber,
      dailyNumber: sv.dailyreceiptno,
      paymentMethod: sv.transMode,
      vatPercent: 15,
      vatInclusiveAmount: payable,
      vatAmount: salesProvider.calculateVatFromInclusive(payable),
      payable: payable,
      amountPaid: (sv.amountPaid ?? payable).toDouble(),
      discount: discount,
      subTotal: payable + discount,
      change: (sv.change ?? 0).toDouble(),
      branch: sv.branchName,
      address: datafeed.branchaddress,
      receiptName: 'DUPLICATE RECEIPT',
      Customertin: '',
      Suppliertin: '',
      branchType: sv.branchType,
    );

    final doc = await ReceiptPrinter.build(
      receiptData,
      format: ReceiptPrinter.roll80,
    );

    await _sendToPrinter(doc, receiptData, sv.id);


  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e',style: TextStyle(color: Colors.white),), backgroundColor: Colors.red),
      );
    }
  }
}