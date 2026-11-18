import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/salesmodel.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/Receiptdatamodel.dart';
import '../paymentwidgets/invoice1.dart';
import '../providers/cashier_provider.dart';

class PrintPreviewWidget extends StatefulWidget {
  final SalesModel invoiceData;
  final bool showPrintButton;
  final bool autoPrint;

  const PrintPreviewWidget({
    super.key,
    required this.invoiceData,
    this.showPrintButton = true,
    this.autoPrint = false,
  });

  @override
  State<PrintPreviewWidget> createState() => _PrintPreviewWidgetState();
}

class _PrintPreviewWidgetState extends State<PrintPreviewWidget> {
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoPrint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateAndPrint();
      });
    }
  }

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  // ===========================================================================
  // DARK BLUE POS THEME
  // ===========================================================================

  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF0D2A3C);
  static const Color surfaceLight = Color(0xFF12354B);
  static const Color panel = Color(0xFF1E3A5A);
  static const Color panelDark = Color(0xFF172F4A);

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;

  static const Color border = Color(0x1AFFFFFF);
  static const Color borderStrong = Color(0x2AFFFFFF);

  static const Color tableHeader = Color(0xFF1E3A5A);
  static const Color tableRow = Color(0xFF0D2A3C);
  static const Color tableRowAlt = Color(0xFF102F44);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);

  // ===========================================================================
  // PRINT
  // ===========================================================================

  Future<void> _generateAndPrint() async {
    setState(() => _isGeneratingPdf = true);

    try {
      final provider =
      Provider.of<CashierProvider>(context, listen: false);

      final generator = ReceiptPrinter();

      final doc = await generator.buildPdf(
        ReceiptData(
          cashier: provider.staff,
          barcode: widget.invoiceData.receiptNumber,
          items: widget.invoiceData.items.entries.map((entry) {
            final e = entry.value;

            return ReceiptItem(
              name: e['item'] ?? '',
              qty: double.tryParse(e['quantity'].toString()) ?? 0,
              price: double.tryParse(e['price'].toString()) ?? 0,
              mode: e['mode'].toString(),
              branch: e['branchname'].toString(),
            );
          }).toList(),
          companyName: widget.invoiceData.companyname,
          contact: provider.companyphone.isNotEmpty
              ? provider.companyphone
              : (provider.branchphone.isNotEmpty
              ? provider.branchphone
              : (widget.invoiceData.customerPhone?.toString() ?? '')),
          customername:
          widget.invoiceData.customerName ?? 'Cash Customer',
          datetime: DateTime.now(),
          receiptNumber: widget.invoiceData.receiptNumber,
          dailyNumber: widget.invoiceData.dailyNumber,
          paymentMethod: widget.invoiceData.transMode,
          payable: widget.invoiceData.totalamount,
          amountPaid: widget.invoiceData.amountPaid,
          discount: widget.invoiceData.discount ?? 0.0,
          subTotal: widget.invoiceData.totalamount + (widget.invoiceData.discount ?? 0.0),
          change: widget.invoiceData.change,
          branch: widget.invoiceData.branchName,
          branchType: widget.invoiceData.branchType,
          receiptName: 'OFFICIAL RECEIPT',
          email: '',
          vatPercent: 0,
          vatInclusiveAmount: 0,
          vatAmount: 0,
          Customertin: '',
          Suppliertin: '',
        ),
        pageFormat: ReceiptPrinter.getFormat('80mm'),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Invoice sent to printer'),
                ),
              ],
            ),
            backgroundColor: success,
            behavior: SnackBarBehavior.floating,
            elevation: 4,
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
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Failed to print: $e'),
                ),
              ],
            ),
            backgroundColor: primaryDark,
            behavior: SnackBarBehavior.floating,
            elevation: 4,
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

  // ===========================================================================
  // DATA HELPERS
  // ===========================================================================

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

    items.sort((a, b) {
      final aKey = a['itemkey'] ?? '';
      final bKey = b['itemkey'] ?? '';

      return aKey.compareTo(bKey);
    });

    return items;
  }

  int _calculateTotalPieces(List<Map<String, dynamic>> items) {
    int total = 0;

    for (final item in items) {
      total +=
          int.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
    }

    return total;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final data = widget.invoiceData;

    final items = _parseItems(data.items);

    final createdAt =
        data.createdAt?.toDate() ?? DateTime.now();

    final totalAmount =
        (data.totalamount as num?)?.toDouble() ?? 0;

    final change =
        (data.change as num?)?.toDouble() ?? 0;

    final amountPaid =
        (data.amountPaid as num?)?.toDouble() ?? 0;

    final provider =
    Provider.of<CashierProvider>(context, listen: false);

    final bool isPaid =
        data.paymentStatus.toLowerCase() == 'paid';

    return Scaffold(
      backgroundColor: background,

      // ======================================================================
      // APP BAR
      // ======================================================================

      appBar: AppBar(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: textPrimary,
            ),
          ),
        ),

        titleSpacing: 8,

        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: Colors.white.withOpacity(.08),
                ),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),

            const SizedBox(width: 11),

            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Preview',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Sales transaction',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          if (widget.showPrintButton)
            Padding(
              padding: const EdgeInsets.only(
                right: 16,
                top: 8,
                bottom: 8,
              ),
              child: ElevatedButton.icon(
                onPressed:
                _isGeneratingPdf ? null : _generateAndPrint,

                icon: _isGeneratingPdf
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.print_rounded,
                  size: 17,
                ),

                label: Text(
                  _isGeneratingPdf
                      ? 'Preparing...'
                      : 'Print Invoice',
                ),

                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  primary.withOpacity(.45),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),

      // ======================================================================
      // BODY
      // ======================================================================

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1000,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderStrong,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.30),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [

                    // ========================================================
                    // INVOICE HEADER
                    // ========================================================

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        28,
                        26,
                        28,
                        24,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              constraints.maxWidth < 550;

                          if (compact) {
                            return Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _buildBusinessHeader(data),
                                const SizedBox(height: 22),
                                _buildInvoiceIdentity(data),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child:
                                _buildBusinessHeader(data),
                              ),
                              const SizedBox(width: 20),
                              _buildInvoiceIdentity(data),
                            ],
                          );
                        },
                      ),
                    ),

                    Container(
                      height: 1,
                      color: border,
                    ),

                    // ========================================================
                    // TRANSACTION INFORMATION
                    // ========================================================

                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              constraints.maxWidth < 650;

                          if (compact) {
                            return Column(
                              children: [
                                _buildInfoSection(
                                  title: 'TRANSACTION',
                                  children: [
                                    _buildInfoLine(
                                      'Receipt No.',
                                      data.receiptNumber,
                                    ),
                                    _buildInfoLine(
                                      'Date',
                                      _dateFormat.format(
                                        createdAt,
                                      ),
                                    ),
                                    _buildInfoLine(
                                      'Time',
                                      _timeFormat.format(
                                        createdAt,
                                      ),
                                    ),
                                    _buildInfoLine(
                                      'Payment',
                                      data.transMode
                                          .toUpperCase(),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                Container(
                                  height: 1,
                                  color: border,
                                ),

                                const SizedBox(height: 24),

                                _buildInfoSection(
                                  title: 'CUSTOMER',
                                  children: [
                                    _buildInfoLine(
                                      'Customer',
                                      data.customerName ??
                                          'Walk-in Customer',
                                    ),
                                    if (data.customerPhone !=
                                        null &&
                                        data.customerPhone
                                            .toString()
                                            .isNotEmpty)
                                      _buildInfoLine(
                                        'Phone',
                                        data.customerPhone!
                                            .toString(),
                                      ),
                                    _buildInfoLine(
                                      'Cashier',
                                      provider.staff,
                                    ),
                                    _buildInfoLine(
                                      'Status',
                                      data.paymentStatus
                                          .toUpperCase(),
                                      valueWidget:
                                      _buildStatusBadge(
                                        data.paymentStatus,
                                        isPaid,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildInfoSection(
                                  title: 'TRANSACTION',
                                  children: [
                                    _buildInfoLine(
                                      'Receipt No.',
                                      data.receiptNumber,
                                    ),
                                    _buildInfoLine(
                                      'Date',
                                      _dateFormat.format(
                                        createdAt,
                                      ),
                                    ),
                                    _buildInfoLine(
                                      'Time',
                                      _timeFormat.format(
                                        createdAt,
                                      ),
                                    ),
                                    _buildInfoLine(
                                      'Payment',
                                      data.transMode
                                          .toUpperCase(),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                width: 1,
                                height: 125,
                                margin:
                                const EdgeInsets.symmetric(
                                  horizontal: 35,
                                ),
                                color: border,
                              ),

                              Expanded(
                                child: _buildInfoSection(
                                  title: 'CUSTOMER',
                                  children: [
                                    _buildInfoLine(
                                      'Customer',
                                      data.customerName ??
                                          'Walk-in Customer',
                                    ),
                                    if (data.customerPhone !=
                                        null &&
                                        data.customerPhone
                                            .toString()
                                            .isNotEmpty)
                                      _buildInfoLine(
                                        'Phone',
                                        data.customerPhone!
                                            .toString(),
                                      ),
                                    _buildInfoLine(
                                      'Cashier',
                                      provider.staff,
                                    ),
                                    _buildInfoLine(
                                      'Status',
                                      data.paymentStatus
                                          .toUpperCase(),
                                      valueWidget:
                                      _buildStatusBadge(
                                        data.paymentStatus,
                                        isPaid,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // ========================================================
                    // ITEMS
                    // ========================================================

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                      ),
                      child: _buildItemsTable(items),
                    ),

                    const SizedBox(height: 24),

                    // ========================================================
                    // BOTTOM SUMMARY
                    // ========================================================

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        28,
                        0,
                        28,
                        28,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact =
                              constraints.maxWidth < 650;

                          if (compact) {
                            return Column(
                              children: [
                                _buildTransactionStats(
                                  data,
                                  items,
                                ),
                                const SizedBox(height: 20),
                                _buildTotals(
                                  totalAmount,
                                  amountPaid,
                                  change,
                                  discount: data.discount ?? 0.0,
                                  subTotal: totalAmount + (data.discount ?? 0.0),
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child:
                                _buildTransactionStats(
                                  data,
                                  items,
                                ),
                              ),

                              const SizedBox(width: 40),

                              SizedBox(
                                width: 320,
                                child: _buildTotals(
                                  totalAmount,
                                  amountPaid,
                                  change,
                                  discount: data.discount ?? 0.0,
                                  subTotal: totalAmount + (data.discount ?? 0.0),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // ========================================================
                    // FOOTER
                    // ========================================================

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: panelDark,
                        border: Border(
                          top: BorderSide(
                            color: border,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_outlined,
                            size: 15,
                            color: textMuted,
                          ),

                          const SizedBox(width: 8),

                          const Expanded(
                            child: Text(
                              'Thank you for your business.',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          Text(
                            'Generated ${_dateTimeFormat.format(DateTime.now())}',
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUSINESS HEADER
  // ===========================================================================

  Widget _buildBusinessHeader(SalesModel data) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: Colors.white.withOpacity(.08),
            ),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                data.branchName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                data.branchType ?? 'Sales Point',
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: 38,
                height: 3,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius:
                  BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // INVOICE IDENTITY
  // ===========================================================================

  Widget _buildInvoiceIdentity(SalesModel data) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: panelDark,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: [
          const Text(
            'SALES INVOICE',
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            '#${data.receiptNumber}',
            style: const TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // INFO SECTION
  // ===========================================================================

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 13,
              decoration: BoxDecoration(
                color: primary,
                borderRadius:
                BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),

        const SizedBox(height: 13),

        ...children,
      ],
    );
  }

  // ===========================================================================
  // INFO LINE
  // ===========================================================================

  Widget _buildInfoLine(
      String label,
      String value, {
        Widget? valueWidget,
      }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 9,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: valueWidget ??
                Text(
                  value,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STATUS
  // ===========================================================================

  Widget _buildStatusBadge(
      String status,
      bool isPaid,
      ) {
    final Color color =
    isPaid ? success : warning;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius:
          BorderRadius.circular(5),
          border: Border.all(
            color: color.withOpacity(.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              status.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ITEMS TABLE
  // ===========================================================================

  Widget _buildItemsTable(
      List<Map<String, dynamic>> items,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: tableRow,
        border: Border.all(
          color: borderStrong,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // TABLE HEADER
          Container(
            color: tableHeader,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _TableHeader(
                    'ITEM',
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _TableHeader(
                    'QTY',
                    align: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _TableHeader(
                    'MODE',
                    align: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _TableHeader(
                    'UNIT PRICE',
                    align: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _TableHeader(
                    'TOTAL',
                    align: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 40,
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: textMuted,
                      size: 30,
                    ),
                    SizedBox(height: 9),
                    Text(
                      'No items found',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.asMap().entries.map(
                  (entry) {
                final int index = entry.key;
                final item = entry.value;

                final double itemTotal =
                    double.tryParse(
                      item['totalamount']
                          ?.toString() ??
                          '0',
                    ) ??
                        0;

                final double price =
                    double.tryParse(
                      item['price']
                          ?.toString() ??
                          '0',
                    ) ??
                        0;

                return Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? tableRow
                        : tableRowAlt,
                    border: Border(
                      top: BorderSide(
                        color: border,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // ITEM
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['item'] ??
                                  'Unknown Item',
                              maxLines: 2,
                              overflow:
                              TextOverflow.ellipsis,
                              style:
                              const TextStyle(
                                color: textPrimary,
                                fontSize: 11,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),

                            if (item['barcode'] !=
                                null &&
                                item['barcode']
                                    .toString()
                                    .isNotEmpty)
                              Padding(
                                padding:
                                const EdgeInsets.only(
                                  top: 4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons
                                          .qr_code_2_rounded,
                                      size: 11,
                                      color: textMuted,
                                    ),
                                    const SizedBox(
                                      width: 4,
                                    ),
                                    Text(
                                      item['barcode']
                                          .toString(),
                                      style:
                                      const TextStyle(
                                        color: textMuted,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // QTY
                      Expanded(
                        flex: 1,
                        child: Text(
                          item['quantity']
                              ?.toString() ??
                              '0',
                          textAlign:
                          TextAlign.center,
                          style:
                          const TextStyle(
                            color: textPrimary,
                            fontSize: 11,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ),

                      // MODE
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration:
                            BoxDecoration(
                              color: panel,
                              borderRadius:
                              BorderRadius
                                  .circular(5),
                            ),
                            child: Text(
                              item['mode']
                                  ?.toString() ??
                                  'unit',
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style:
                              const TextStyle(
                                color: textSecondary,
                                fontSize: 8,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // UNIT PRICE
                      Expanded(
                        flex: 2,
                        child: Text(
                          'GHS ${price.toStringAsFixed(2)}',
                          textAlign:
                          TextAlign.right,
                          style:
                          const TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),

                      // TOTAL
                      Expanded(
                        flex: 2,
                        child: Text(
                          'GHS ${itemTotal.toStringAsFixed(2)}',
                          textAlign:
                          TextAlign.right,
                          style:
                          const TextStyle(
                            color: success,
                            fontSize: 11,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TRANSACTION STATS
  // ===========================================================================

  Widget _buildTransactionStats(
      SalesModel data,
      List<Map<String, dynamic>> items,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 13,
              decoration: BoxDecoration(
                color: primary,
                borderRadius:
                BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'SALE SUMMARY',
              style: TextStyle(
                color: textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),

        const SizedBox(height: 13),

        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _buildStat(
              Icons.shopping_basket_outlined,
              'Items',
              '${data.itemCount}',
            ),
            _buildStat(
              Icons.inventory_2_outlined,
              'Pieces',
              '${_calculateTotalPieces(items)}',
            ),
            _buildStat(
              Icons.payments_outlined,
              'Payment',
              data.transMode.toUpperCase(),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // STAT
  // ===========================================================================

  Widget _buildStat(
      IconData icon,
      String label,
      String value,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: panelDark,
        borderRadius:
        BorderRadius.circular(7),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: textSecondary,
          ),

          const SizedBox(width: 7),

          Text(
            '$label: ',
            style: const TextStyle(
              color: textSecondary,
              fontSize: 10,
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TOTALS
  // ===========================================================================

  Widget _buildTotals(
      double total,
      double amountPaid,
      double change, {
        double discount = 0.0,
        double subTotal = 0.0,
      }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius:
        BorderRadius.circular(10),
        border: Border.all(
          color: borderStrong,
        ),
      ),
      child: Column(
        children: [
          if (subTotal > 0)
            _buildAmountLine(
              'Subtotal',
              'GHS ${subTotal.toStringAsFixed(2)}',
            ),
          if (discount > 0) ...[
            const SizedBox(height: 10),
            _buildAmountLine(
              'Discount',
              '- GHS ${discount.toStringAsFixed(2)}',
              valueColor: success,
            ),
          ],
          if (subTotal > 0 || discount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10,
              ),
              child: Container(
                height: 1,
                color: borderStrong,
              ),
            ),
          _buildAmountLine(
            'Amount Paid',
            'GHS ${amountPaid.toStringAsFixed(2)}',
          ),

          const SizedBox(height: 10),

          _buildAmountLine(
            'Change',
            'GHS ${change.toStringAsFixed(2)}',
            valueColor:
            change > 0 ? success : textPrimary,
          ),

          Padding(
            padding:
            const EdgeInsets.symmetric(
              vertical: 14,
            ),
            child: Container(
              height: 1,
              color: borderStrong,
            ),
          ),

          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              const Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Amount Due',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),

              Text(
                'GHS ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: success,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // AMOUNT LINE
  // ===========================================================================

  Widget _buildAmountLine(
      String label,
      String value, {
        Color valueColor = textPrimary,
      }) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TABLE HEADER
// =============================================================================

class _TableHeader extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _TableHeader(
      this.text, {
        this.align = TextAlign.left,
      });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .7,
      ),
    );
  }
}