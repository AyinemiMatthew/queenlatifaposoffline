import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/salesmodel.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../models/Receiptdatamodel.dart';
import '../paymentwidgets/invoice1.dart';
import '../providers/cashier_provider.dart';
import '../providers/Datafeed.dart';

class PrintPreviewWidget extends StatefulWidget {
  final SalesModel invoiceData;
  final bool showPrintButton;

  const PrintPreviewWidget({
    super.key,
    required this.invoiceData,
    this.showPrintButton = true,
  });

  @override
  State<PrintPreviewWidget> createState() => _PrintPreviewWidgetState();
}

class _PrintPreviewWidgetState extends State<PrintPreviewWidget> {
  bool _isGeneratingPdf = false;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  Future<void> _generateAndPrint() async {
    setState(() => _isGeneratingPdf = true);
    final colorScheme = Theme.of(context).colorScheme;

    try {
      final doc = await ReceiptPrinter.build(
        ReceiptData(
          cashier: widget.invoiceData.printedby ?? '',
          barcode: widget.invoiceData.receiptNumber,
          items: widget.invoiceData.items.entries.map((entry) {
            final e = entry.value;
            return ReceiptItem(
              name: (e['item'] ?? '').toString(),
              qty: double.tryParse(e['quantity'].toString()) ?? 0,
              price: double.tryParse(e['price'].toString()) ?? 0,
              mode: (e['mode'] ?? '').toString(),
              branch: e['branchname']?.toString(),
              isService:
                  (e['producttype']?.toString().toLowerCase().trim() ?? '') ==
                  'service',
            );
          }).toList(),
          companyName: widget.invoiceData.companyname,
          contact: (widget.invoiceData.customerPhone ?? '').toString(),
          customername: widget.invoiceData.customerName ?? '',
          datetime: DateTime.now(),
          receiptNumber: widget.invoiceData.receiptNumber,
          dailyNumber: widget.invoiceData.dailyreceiptno,
          paymentMethod: widget.invoiceData.transMode,
          payable: widget.invoiceData.totalamount,
          amountPaid: widget.invoiceData.amountPaid,
          discount: 0.0,
          subTotal: widget.invoiceData.totalamount,
          change: widget.invoiceData.change,
          receiptName: 'OFFICIAL RECEIPT',
          email: '',
          vatPercent: 0,
          vatInclusiveAmount: 0,
          vatAmount: 0,
          Customertin: '',
          Suppliertin: '',
          branchType: widget.invoiceData.branchType,
        ),
        format: ReceiptPrinter.roll80,
      );

      await Printing.layoutPdf(
        name: widget.invoiceData.receiptNumber,
        format: ReceiptPrinter.roll80,
        usePrinterSettings: false,
        onLayout: (_) async => doc.save(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: colorScheme.onTertiary),
                const SizedBox(width: 12),
                const Expanded(child: Text('Invoice sent to printer')),
              ],
            ),
            backgroundColor: colorScheme.tertiary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: colorScheme.onError),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to print: $e')),
              ],
            ),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  List<Map<String, dynamic>> _parseItems(dynamic itemsData) {
    List<Map<String, dynamic>> items = [];

    if (itemsData == null) return items;

    if (itemsData is Map) {
      itemsData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          items.add(value);
        }
      });
    } else if (itemsData is List) {
      items = List<Map<String, dynamic>>.from(itemsData);
    }

    // Sort items by key to maintain consistent order
    items.sort((a, b) {
      final aKey = a['itemkey'] ?? '';
      final bKey = b['itemkey'] ?? '';
      return aKey.compareTo(bKey);
    });

    return items;
  }

  int _calculateTotalPieces(List<Map<String, dynamic>> items) {
    int total = 0;
    for (var item in items) {
      total += int.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.invoiceData;
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = colorScheme.surface;
    final cardColor = colorScheme.surfaceContainerHighest;
    final textColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurfaceVariant;
    final successColor = colorScheme.tertiary;
    final warningColor = colorScheme.secondary;
    final items = _parseItems(data.items);
    final createdAt =
        (data.createdAt as Timestamp?)?.toDate() ?? DateTime.now();
    final totalAmount = (data.totalamount as num?)?.toDouble() ?? 0;
    final change = (data.change as num?)?.toDouble() ?? 0;
    final provider = Provider.of<CashierProvider>(context, listen: false);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Print Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back to Home',
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.backspace_outlined,
                            color: colorScheme.onPrimaryContainer,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.branchName ?? 'Business Name',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            data.branchType ?? 'Sales Point',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (widget.showPrintButton)
                    ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _generateAndPrint,
                      icon: _isGeneratingPdf
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.print),
                      label: Text(
                        _isGeneratingPdf ? 'Generating...' : 'Print Invoice',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Invoice Title
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'SALES INVOICE',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Invoice Info Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPreviewInfoRow(
                            'Receipt No:',
                            data.receiptNumber ?? 'N/A',
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                          _buildPreviewInfoRow(
                            'Date:',
                            _dateFormat.format(createdAt),
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                          _buildPreviewInfoRow(
                            'Time:',
                            _timeFormat.format(createdAt),
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                          _buildPreviewInfoRow(
                            'Payment Mode:',
                            (data.transMode ?? 'N/A').toUpperCase(),
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 20),

                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildPreviewInfoRow(
                            'Customer:',
                            data.customerName ?? 'Walk-in Customer',
                            alignRight: true,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                          ),

                          if (data.customerPhone != null &&
                              data.customerPhone.toString().isNotEmpty)
                            _buildPreviewInfoRow(
                              'Phone:',
                              data.customerPhone!,
                              alignRight: true,
                              textColor: textColor,
                              secondaryTextColor: secondaryTextColor,
                            ),

                          _buildPreviewInfoRow(
                            'Cashier:',
                            provider.staff ?? 'System',
                            alignRight: true,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                          ),

                          _buildPreviewInfoRow(
                            'Status:',
                            (data.paymentStatus ?? 'pending').toUpperCase(),
                            alignRight: true,
                            status: true,
                            statusColor: data.paymentStatus == 'paid'
                                ? successColor
                                : warningColor,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Items Table Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _TablePreviewHeaderCell(
                        'Item',
                        textColor: textColor,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: _TablePreviewHeaderCell(
                        'Qty',
                        align: TextAlign.center,
                        textColor: textColor,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: _TablePreviewHeaderCell(
                        'Mode',
                        align: TextAlign.center,
                        textColor: textColor,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: _TablePreviewHeaderCell(
                        'Price',
                        align: TextAlign.right,
                        textColor: textColor,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: _TablePreviewHeaderCell(
                        'Total',
                        align: TextAlign.right,
                        textColor: textColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Items List
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: colorScheme.outlineVariant),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final itemTotal =
                        double.tryParse(
                          item['totalamount']?.toString() ?? '0',
                        ) ??
                        0;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['item'] ?? 'Unknown Item',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                ),
                                if (item['barcode'] != null)
                                  Text(
                                    'Barcode: ${item['barcode']}',
                                    style: TextStyle(
                                      color: secondaryTextColor.withOpacity(
                                        0.7,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              item['quantity']?.toString() ?? '0',
                              style: TextStyle(color: textColor, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item['mode'] ?? 'unit',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'GHS ${double.tryParse(item['price']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                              style: TextStyle(color: textColor, fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'GHS ${itemTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: successColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Summary Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                  border: Border(
                    top: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LEFT SIDE - TOTAL ITEMS / TOTAL PIECES
                    Expanded(
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Total Items: ',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${data.itemCount ?? items.length}',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Total Pieces: ',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${_calculateTotalPieces(items)}',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // TOTAL AMOUNT
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: successColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.attach_money,
                              color: successColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'GHS ${totalAmount.toStringAsFixed(2)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: successColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: successColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: successColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Summary',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Status: ',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (data.paymentStatus == 'paid'
                                            ? successColor
                                            : warningColor)
                                        .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                (data.paymentStatus ?? 'pending').toUpperCase(),
                                style: TextStyle(
                                  color: data.paymentStatus == 'paid'
                                      ? successColor
                                      : warningColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Change:',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'GHS ${change.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: change > 0 ? successColor : textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Footer
              Center(
                child: Column(
                  children: [
                    Text(
                      'Thank you for your business!',
                      style: TextStyle(color: secondaryTextColor, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generated: ${_dateTimeFormat.format(DateTime.now())}',
                      style: TextStyle(
                        color: secondaryTextColor.withOpacity(0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewInfoRow(
    String label,
    String value, {
    bool alignRight = false,
    bool status = false,
    Color? statusColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: alignRight
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
              height: 1.1,
            ),
          ),

          const SizedBox(width: 5),

          Flexible(
            child: status
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          statusColor?.withOpacity(0.2) ??
                          Theme.of(
                            context,
                          ).colorScheme.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      value,
                      softWrap: true,
                      textAlign: alignRight ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        color:
                            statusColor ??
                            Theme.of(context).colorScheme.secondary,
                        fontSize: 11,
                        height: 1.05,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Text(
                    value,
                    softWrap: true,
                    textAlign: alignRight ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Helper widget for table headers in preview
class _TablePreviewHeaderCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  final Color? textColor;

  const _TablePreviewHeaderCell(
    this.text, {
    this.align = TextAlign.left,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        color: textColor ?? colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      textAlign: align,
    );
  }
}

extension DateTimeFormatting on DateTime {
  String get ddMMMyyyy => DateFormat('dd MMM yyyy').format(this);
  String get hhmmA => DateFormat('hh:mm a').format(this);
  String get ddMMMyyyyHHmm => DateFormat('dd MMM yyyy, hh:mm a').format(this);
}
