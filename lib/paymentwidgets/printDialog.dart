
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/paymentwidgets/PDFprints/print_service.dart';
import 'package:kologsoft/paymentwidgets/receipt_formatter.dart';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/Receiptdatamodel.dart';
import '../models/itemregmodel.dart';
import '../models/paymentMethod.dart';
import '../models/salesmodel.dart';
import '../providers/Datafeed.dart';
import '../providers/SalesProvider.dart';
import 'invoice1.dart';


Future<void> printReceipt({
  required BuildContext context,
  required List salesItems,
  ItemModel? selectedItem,
  bool isProcessing = false,
}) async {

  if (salesItems.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No items to print'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  final ValueNotifier<String> processState = ValueNotifier("idle");
  bool _isSaving = false;
  final datafeed = Provider.of<Datafeed>(context, listen: false);
  final salesProvider = Provider.of<SalesProvider>(context, listen: false);
  final isLightTheme = Theme.of(context).brightness == Brightness.light;

  final bool shouldPrint =  datafeed.canPrint ;
      //|| datafeed.branchtype == "Sales Branch";
  final allowed = datafeed.allowedPaymentMethods.map((e) => e.toString().trim().toLowerCase())
      .where((e) => e.isNotEmpty).toSet();

  if (allowed.isNotEmpty && !allowed.contains('cash')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cash payment is not enabled for this user.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }


  final isService =
      (selectedItem?.producttype ?? '').toLowerCase().trim() == 'service';

  if (!isService &&  datafeed.stockCheckEnabled&&
      !await salesProvider.validateCartStockOnSave(context, salesItems, datafeed)) {
    return;
  }
  final amountPaidController = TextEditingController(
    text: salesProvider.calculateTaxableTotal().toStringAsFixed(2),
  );

  String? _selectedPrinter;
  List<String> _availablePrinters = [];
  String? _savedPrinter;

  // Load printer info
  Future<void> _loadPrinterInfo() async {
    final saved = await PrintService.getSavedPrinter();
    final all = await PrintService.getPrinters();
    _savedPrinter = saved;
    _availablePrinters = all;
    _selectedPrinter ??= saved ?? (all.isNotEmpty ? all.first : null);
  }

  if (shouldPrint)
  _loadPrinterInfo();

   showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final dialogColors = Theme.of(context).colorScheme;
        final total = salesProvider.calculateTaxableTotal();
        final enteredAmount = double.tryParse(amountPaidController.text) ?? 0;
        final change = enteredAmount - total;

        return AlertDialog(
          backgroundColor: dialogColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Amount Paid',
            style: TextStyle(color: dialogColors.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total: GHS ${total.toStringAsFixed(2)}',
                style: TextStyle(
                  color: dialogColors.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: amountPaidController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: TextStyle(color: dialogColors.onSurface, fontSize: 20),
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'Amount Paid by Customer',
                  labelStyle: TextStyle(
                    color: dialogColors.onSurfaceVariant,
                  ),
                  prefixText: 'GHS ',
                  prefixStyle: const TextStyle(
                    color: Colors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: dialogColors.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.green,
                      width: 2,
                    ),
                  ),
                  fillColor: dialogColors.surfaceContainerHighest,
                  filled: true,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dialogColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: change >= 0 ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Change:',
                      style: TextStyle(
                        color: change >= 0
                            ? (isLightTheme
                                  ? Colors.green.shade800
                                  : Colors.green.shade200)
                            : (isLightTheme
                                  ? Colors.red.shade800
                                  : Colors.red.shade200),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'GHS ${change.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: change >= 0
                            ? (isLightTheme
                                  ? Colors.green.shade800
                                  : Colors.greenAccent)
                            : (isLightTheme
                                  ? Colors.red.shade800
                                  : Colors.redAccent),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ---- Printer Selection Card ----
              if (shouldPrint) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: dialogColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dialogColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.print_outlined,
                          color: dialogColors.secondary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Printer',
                          style: TextStyle(
                            color: dialogColors.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedPrinter ?? '— Select printer',
                      style: TextStyle(
                        color: dialogColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    if (_selectedPrinter != null &&
                        _selectedPrinter == _savedPrinter) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(76, 175, 80, 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'SAVED',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ]
            ],
          ),
          actions: [
            if (shouldPrint)
            TextButton(
              onPressed: () async {
                if (_availablePrinters.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No printers found'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final selected = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    title: Text(
                      'Select Printer',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _availablePrinters
                            .map((p) => ListTile(
                              title: Text(
                                p,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: _selectedPrinter == p
                                  ? const Icon(Icons.check,
                                      color: Colors.green)
                                  : null,
                              onTap: () => Navigator.pop(context, p),
                            ))
                            .toList(),
                      ),
                    ),
                  ),
                );
                if (selected != null) {
                  setState(() {
                    _selectedPrinter = selected;
                    PrintService.savePrinter(selected);
                  });
                }
              },
              child: Text(
                'Change Printer',
                style: TextStyle(color: dialogColors.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text( 'Cancel',
                style: TextStyle(color: dialogColors.onSurfaceVariant),
              ),
            ),


            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              onPressed: _isSaving ? null : () async {

                if (_isSaving || processState.value == "loading") return;

                _isSaving = true;
                setState(() => processState.value = "loading");

                try {
                  final amount =
                      double.tryParse(amountPaidController.text) ?? 0;

                  final total = salesProvider.calculateTaxableTotal();
                  final totalDiscount = salesProvider.calculateDiscountTotal();

                  if (amount < total) {
                    salesProvider.showMessage(context, '...', Colors.red);
                    _isSaving = false;
                    processState.value = "idle";
                    return;
                  }

                  if (!context.mounted) return;

                  final change = amount - total;

                  if (datafeed.isOffline && datafeed.stockCheckEnabled) {
                    salesProvider.showMessage(
                      context,
                      'Sales with stock checking require an internet connection.',
                      Colors.orange,
                    );
                    _isSaving = false;
                    processState.value = "idle";
                    return;
                  }

                  if (!isService && datafeed.stockCheckEnabled) {
                    final ensureSalesWarehouseSelected =
                    salesProvider.ensureSalesWarehouseSelected(
                      context,
                      datafeed,
                      selectedItem,
                      requireItemSelection: false,
                    );

                    final isValid = await salesProvider.validateCartStockOnSave(
                      context, salesItems, datafeed,);

                    if (!ensureSalesWarehouseSelected || !isValid) {
                      return;
                    }
                  }
                  final companyId = datafeed.companyid;
                  final staffPosition = datafeed.staffPosition;
                  final timestamp = DateTime.now().millisecondsSinceEpoch;

                  final receiptNumber = '$staffPosition$timestamp';
                  final docId = '${companyId}_${staffPosition}_$timestamp';

                  final itemsMap = <String, dynamic>{};
                  for (int i = 0; i < salesItems.length; i++) {
                    itemsMap['item_$i'] = salesItems[i];
                  }
                  final now1 = DateTime.now();

                  final now = Timestamp.fromDate(DateTime.now());


                  final day = DateFormat('EEEE').format(now1); // Wednesday

                  final year = now1.year.toString(); // 2026

                  final month = '${now1.year}.${now1.month}'; // 2026.5

                  final weekNumber =
                      ((now1.difference(DateTime(now1.year, 1, 1)).inDays) / 7).floor() + 1;

                  final week = '${now1.year}.$weekNumber';
                  final queuedOffline = datafeed.isOffline;
                  final dailyNumber = queuedOffline
                      ? null
                      : await datafeed.nextDailyReceiptNumber(
                          datafeed.branchid,
                        );

                  final saleData = SalesModel(
                    id: docId,
                    companyId: companyId,
                    companyname: datafeed.company,
                    branchId: datafeed.branchid,
                    branchName: datafeed.branch,
                    address: datafeed.branchaddress,
                    staffPosition: staffPosition,
                    receiptNumber: receiptNumber,
                    receiptby: datafeed.staff,
                    receiptat: now,
                    day: day,
                    week: week,
                    month: month,
                    year: year,
                    payments: [
                      PaymentMethodModel(
                        amount: amount,
                        paymentmethod: 'cash',
                        accountName: 'cash',
                        accountNumber: 'cash',
                        status: true,
                        reference: 'cash',
                      ).toMap()
                    ],
                    transMode: 'cash',
                    paymentStatus: 'paid',
                    items: itemsMap,
                    discount: totalDiscount,
                   // totalamount: total,
                    totalamount: salesProvider.calculateGrossTotal(),
                    amountPaid: amount,
                    change: change,
                    itemCount: salesItems.length,
                    isreturned: false,
                    createdAt: now,
                    createdBy: datafeed.staff,
                    pricingtype: datafeed.branchtype,
                    branchType:  datafeed.branchtype,
                    approvedby: datafeed.staff,
                    printedby: shouldPrint ? datafeed.staff : '',
                    printedat: shouldPrint ? now : null,
                    stockCheckedAt: queuedOffline ? null : now,
                    stockCheckStatus:
                        queuedOffline && !datafeed.stockCheckEnabled
                        ? 'approved'
                        : null,
                    timestamp: timestamp,
                    printed:  shouldPrint,
                    reciepted: true,
                    customerId: 'cash',
                    customerName: 'cash customer',
                    customerPhone: 'cash',
                    staffemail: datafeed.staffemail,
                    receiptbyemail: datafeed.staffemail,

                    dateymd: context.read<SalesProvider>().saleDate,
                    supplystatus: false,
                    dailyreceiptno: dailyNumber,

                  );

                  if (queuedOffline) {
                    await datafeed.offlineSalesQueue.saveLocally(
                      companyId: companyId,
                      saleId: docId,
                      saleData: saleData.toMap(),
                    );
                  } else {
                    await FirebaseFirestore.instance
                        .collection('sales')
                        .doc(docId)
                        .set(saleData.toMap());
                  }

                  if (!queuedOffline) {
                    final skipCheck = !datafeed.stockCheckEnabled ||
                        salesProvider.isServiceOnlySale(salesProvider.salesItems);
                    final approved = await salesProvider.ensureSaleApproved(
                      context,
                      docId,
                      skipStockCheck: skipCheck,
                    );
                    if (!approved) return;
                  }

                  if (shouldPrint &&
                      (!queuedOffline || !datafeed.stockCheckEnabled)) {
                    final receiptItems = salesItems.map((e) {
                    return ReceiptItem(
                      name: e['item'] ?? '',
                      qty: double.tryParse(e['quantity'].toString()) ?? 0,
                      price: double.tryParse(e['price'].toString()) ?? 0,
                      mode: e['mode'] ?? '',
                      isService: (e['producttype']?.toString().toLowerCase().trim() ?? '') == 'service',
                      branch: e['branchname']?.toString(),
                    );
                  }).toList();

                  final pageFormat = ReceiptPrinter.roll80;

                  final receiptData = ReceiptData(
                    cashier: datafeed.staff,
                    barcode: receiptNumber,
                    items: receiptItems,
                    companyName: datafeed.company,
                    transactionId: docId,
                    contact: datafeed.branchphone,
                    customername: 'Cash Customer',
                    datetime: DateTime.now(),
                    email: datafeed.companyemail,
                    receiptNumber: receiptNumber,
                    paymentMethod: 'cash',
                    vatPercent: 15,
                    vatInclusiveAmount: salesProvider.amountPayable(),
                    vatAmount: salesProvider.calculateVatFromInclusive(total),
                    payable: salesProvider.amountPayable(),
                    amountPaid: amount,
                    discount: totalDiscount,
                    subTotal: total,
                    change: change,
                    branch: datafeed.branch,
                    address: datafeed.branchaddress,
                    receiptName: 'OFFICIAL RECEIPT',
                    Customertin: '',
                    Suppliertin: '',
                    dailyNumber: dailyNumber,
                  );

                  final doc = await ReceiptPrinter.build(
                    receiptData,
                    format: pageFormat,
                  );

                  final isWindowsDesktop = !kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.windows;

                  if (isWindowsDesktop) {
                    if (_selectedPrinter == null) {
                      salesProvider.showMessage(
                        context,
                        'No printer selected for silent Windows printing.',
                        Colors.red,
                      );
                    } else {
                      final width = receiptWidthForPrinter(_selectedPrinter);
                      final rawReceipt = buildRawReceiptText(receiptData, width: width);
                      final rawResult = await PrintService.printRaw(
                        printerName: _selectedPrinter!,
                        text: rawReceipt,
                      );

                      if (!rawResult.success) {
                        final pdfResult = await PrintService.printPdf(
                          printerName: _selectedPrinter!,
                          pdf: doc,
                        );
                        if (!pdfResult.success) {
                          salesProvider.showMessage(
                            context,
                            'Windows print failed: ${rawResult.errorMessage ?? 'Raw text print failed'}. PDF fallback failed: ${pdfResult.errorMessage ?? 'Unknown error'}.',
                            Colors.red,
                          );
                        }
                      }
                    }
                  } else {
                    await Printing.layoutPdf(
                      name: docId,
                      format: ReceiptPrinter.roll80,
                      usePrinterSettings: false,
                      onLayout: (_) async => doc.save(),
                    );
                  }
              }
              if (!context.mounted) return;

                  context.read<SalesProvider>().clearCurrentCart();

                  Navigator.pop(context);

                  salesProvider.showMessage(
                    context,
                    queuedOffline
                        ? 'Sale saved safely on this device; waiting for internet to sync. Receipt: $receiptNumber'
                        : shouldPrint
                        ? 'Receipt printed: $receiptNumber'
                        : 'Sale saved: $receiptNumber',
                    queuedOffline ? Colors.orange : Colors.green,
                  );
                } catch (e) {
                  salesProvider.showMessage(
                    context,
                    'Error: $e',
                    Colors.red,
                  );
                } finally {

                  _isSaving = false;
                  if (context.mounted) {
                    setState(() => processState.value = "idle");
                  } else {
                    processState.value = "idle";
                  }
                }
              },

              child: ValueListenableBuilder(
                valueListenable: processState,
                builder: (context, value, _) {
                  if (value == "loading") {
                    return const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  return const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
            if (shouldPrint)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              onPressed: _isSaving ? null : () async {

                if (_isSaving || processState.value == "loadinga4") return;

                _isSaving = true;
                setState(() => processState.value = "loadinga4");

                try {

                  final amount =  double.tryParse(amountPaidController.text) ?? 0;

                  final total = salesProvider.calculateTaxableTotal();
                  final totalDiscount = salesProvider.calculateDiscountTotal();

                  if (amount < total) {
                    salesProvider.showMessage(context, '...', Colors.red);
                    _isSaving = false;
                    processState.value = "idle";
                    return;
                  }

                  if (!context.mounted) return;

                  final change = amount - total;

                  if (datafeed.isOffline && datafeed.stockCheckEnabled) {
                    salesProvider.showMessage(
                      context,
                      'Sales with stock checking require an internet connection.',
                      Colors.orange,
                    );
                    _isSaving = false;
                    processState.value = "idle";
                    return;
                  }


                  if (!isService&& datafeed.stockCheckEnabled) {
                    final ensureSalesWarehouseSelected =
                    salesProvider.ensureSalesWarehouseSelected(
                      context,
                      datafeed,
                      selectedItem,
                      requireItemSelection: false,
                    );

                    final isValid =  await salesProvider.validateCartStockOnSave(
                      context,
                      salesItems,
                      datafeed,
                    );

                    if (!ensureSalesWarehouseSelected || !isValid) {
                      return;
                    }
                  }
                  final companyId = datafeed.companyid;
                  final staffPosition = datafeed.staffPosition;
                  final timestamp = DateTime.now().millisecondsSinceEpoch;

                  final receiptNumber = '$staffPosition$timestamp';
                  final docId = '${companyId}_${staffPosition}_$timestamp';

                  final itemsMap = <String, dynamic>{};
                  for (int i = 0; i < salesItems.length; i++) {
                    itemsMap['item_$i'] = salesItems[i];
                  }
                  final now1 = DateTime.now();

                  final now = Timestamp.fromDate(DateTime.now());


                  final day = DateFormat('EEEE').format(now1); // Wednesday

                  final year = now1.year.toString(); // 2026

                  final month = '${now1.year}.${now1.month}'; // 2026.5

                  final weekNumber =
                      ((now1.difference(DateTime(now1.year, 1, 1)).inDays) / 7).floor() + 1;

                  final week = '${now1.year}.$weekNumber';

                  final queuedOffline = datafeed.isOffline;
                  final dailyNumber = queuedOffline
                      ? null
                      : await datafeed.nextDailyReceiptNumber(
                          datafeed.branchid,
                        );
                  final saleData = SalesModel(
                    id: docId,
                    companyId: companyId,
                    companyname: datafeed.company,
                    branchId: datafeed.branchid,
                    branchName: datafeed.branch,
                    address: datafeed.branchaddress,
                    staffPosition: staffPosition,
                    receiptNumber: receiptNumber,
                    receiptby: datafeed.staff,
                    receiptat: now,
                    day: day,
                    week: week,
                    month: month,
                    year: year,
                    payments: [
                      PaymentMethodModel(
                        amount: amount,
                        paymentmethod: 'cash',
                        accountName: 'cash',
                        accountNumber: 'cash',
                        status: true,
                        reference: 'cash',
                      ).toMap()
                    ],
                    supplystatus: false,
                    transMode: 'cash',
                    paymentStatus: 'paid',
                    items: itemsMap,
                    discount: totalDiscount,

                    totalamount: salesProvider.calculateGrossTotal(),
                    amountPaid: amount,
                    change: change,
                    itemCount: salesItems.length,
                    isreturned: false,
                    createdAt: now,
                    createdBy: datafeed.staff,
                    pricingtype: datafeed.branchtype,

                    approvedby: datafeed.staff,
                    printedby: datafeed.staff,
                    printedat: now,
                    stockCheckedAt: queuedOffline ? null : now,
                    stockCheckStatus:
                        queuedOffline && !datafeed.stockCheckEnabled
                        ? 'approved'
                        : null,
                    timestamp: timestamp,
                    printed: true,
                    reciepted: true,
                    customerId: 'cash',
                    customerName: 'cash customer',
                    customerPhone: 'cash',
                    staffemail: datafeed.staffemail,
                    receiptbyemail: datafeed.staffemail,
                    dateymd: context.read<SalesProvider>().saleDate,
                    branchType:  datafeed.branchtype,
                    dailyreceiptno: dailyNumber,

                  );

                  if (queuedOffline) {
                    await datafeed.offlineSalesQueue.saveLocally(
                      companyId: companyId,
                      saleId: docId,
                      saleData: saleData.toMap(),
                    );
                  } else {
                    await FirebaseFirestore.instance
                        .collection('sales')
                        .doc(docId)
                        .set(saleData.toMap());
                  }
                  if (!queuedOffline) {
                    final skipCheck = !datafeed.stockCheckEnabled ||
                        salesProvider.isServiceOnlySale(salesProvider.salesItems);
                    final approved = await salesProvider.ensureSaleApproved(
                      context,
                      docId,
                      skipStockCheck: skipCheck,
                    );
                    if (!approved) return;
                  }

                  if (shouldPrint) {
                    final receiptItems = salesItems.map((e) {
                    return ReceiptItem(
                      name: e['item'] ?? '',
                      qty: double.tryParse(e['quantity'].toString()) ?? 0,
                      price: double.tryParse(e['price'].toString()) ?? 0,
                      mode: e['mode'] ?? '',
                      isService: (e['producttype']?.toString().toLowerCase().trim() ?? '') == 'service',
                      branch: e['branchname']?.toString(),
                    );
                  }).toList();

                  final pageFormat = PdfPageFormat.a4;
                   final receiptData = ReceiptData(
                    cashier: datafeed.staff,
                    barcode: receiptNumber,
                    items: receiptItems,
                    companyName: datafeed.company,
                    transactionId: docId,
                    contact: datafeed.branchphone,
                    customername: 'Cash Customer',
                    datetime: DateTime.now(),
                    email: datafeed.companyemail,
                    receiptNumber: receiptNumber,
                    paymentMethod: 'cash',
                    vatPercent: 15,
                    vatInclusiveAmount: salesProvider.amountPayable(),
                    vatAmount: salesProvider.calculateVatFromInclusive(total),
                    payable: salesProvider.amountPayable(),
                    amountPaid: amount,
                    discount: totalDiscount,
                    subTotal: total,
                    change: change,
                    branch: datafeed.branch,
                    address: datafeed.branchaddress,
                    receiptName: 'OFFICIAL RECEIPT',
                    Customertin: '',
                    Suppliertin: '',
                    dailyNumber: dailyNumber,

                  );

                  final doc = await ReceiptPrinter.build(
                    receiptData,
                    format: pageFormat,
                  );


                  final isWindowsDesktop = !kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.windows;

                  if (isWindowsDesktop) {
                    if (_selectedPrinter == null) {
                      salesProvider.showMessage(
                        context,
                        'No printer selected for silent Windows printing.',
                        Colors.red,
                      );
                    } else {
                      final pdfResult = await PrintService.printPdf(
                        printerName: _selectedPrinter!,
                        pdf: doc,
                      );
                      if (!pdfResult.success) {
                        salesProvider.showMessage(
                          context,
                          'A4 print failed: ${pdfResult.errorMessage ?? 'Unknown error'}.',
                          Colors.red,
                        );
                      }
                    }
                  } else {
                    await Printing.layoutPdf(
                      name: docId,
                      format: pageFormat,
                      onLayout: (_) async => doc.save(),
                    );
                  }
                  }
                  if (!context.mounted) return;

                  context.read<SalesProvider>().clearCurrentCart();

                  Navigator.pop(context);

                  salesProvider.showMessage(
                    context,
                    queuedOffline
                        ? 'Sale saved safely on this device; waiting for internet to sync. Receipt: $receiptNumber'
                        : 'Receipt printed: $receiptNumber',
                    queuedOffline ? Colors.orange : Colors.green,
                  );
                } catch (e) {
                  salesProvider.showMessage(
                    context,
                    'Error: $e',
                    Colors.red,
                  );
                } finally {

                  _isSaving = false;
                  if (context.mounted) {
                    setState(() => processState.value = "idle");
                  } else {
                    processState.value = "idle";
                  }
                }
              },

              child: ValueListenableBuilder(
                valueListenable: processState,
                builder: (context, value, _) {
                  if (value == "loadinga4") {
                    return const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  return const Text(
                    'A4 print',
                    style: TextStyle(color: Colors.white),
                  );
                },
              ),
            )
          ],
        );
      },
    ),
  );
}
