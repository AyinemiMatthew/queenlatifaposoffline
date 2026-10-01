import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalesDetailPage extends StatelessWidget {
  final dynamic salesview;

  const SalesDetailPage({super.key, required this.salesview});

  Color _backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  Color _cardColor(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
  Color _headerColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  Color _borderColor(BuildContext context) =>
      Theme.of(context).colorScheme.outline;
  Color _textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final receipt = salesview.receiptNumber ?? '';
    final createdBy = salesview.createdBy ?? '-';
    final branchName = salesview.branchName ?? salesview.branchname ?? '-';
    final isReturned = salesview.isreturned == true;

    // Prefer createdAt (Timestamp); fall back to dateymd (String) if needed.
    final dateStr = salesview.createdAt != null
        ? DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(salesview.createdAt!.toDate())
        : (salesview.dateymd != null && salesview.dateymd!.isNotEmpty)
        ? DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(DateTime.parse(salesview.dateymd!))
        : '-';

    final Map<String, dynamic> itemMap = Map<String, dynamic>.from(
      salesview.items ?? {},
    );
    final items = itemMap.values.whereType<Map<String, dynamic>>().toList();

    final numberFormat = NumberFormat('#,##0.00');

    final totalAmount = itemMap.values.fold<double>(0, (sum, item) {
      if (item is Map<String, dynamic>) {
        return sum +
            (double.tryParse(item['totalamount']?.toString() ?? '0') ?? 0);
      }
      return sum;
    });

    return Scaffold(
      backgroundColor: _backgroundColor(context),
      appBar: AppBar(
        backgroundColor: _cardColor(context),
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor(context)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Receipt #$receipt',
          style: TextStyle(
            color: _textColor(context),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
          if (isReturned)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: const Text(
                'Returned',
                style: TextStyle(color: Colors.redAccent, fontSize: 10),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(child: _appBarInfo(context, 'Date', dateStr)),
                      const SizedBox(width: 18),
                      Flexible(child: _appBarInfo(context, 'Staff', createdBy)),
                      const SizedBox(width: 18),
                      Flexible(
                        child: _appBarInfo(context, 'Branch', branchName),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Grand total',
                      style: TextStyle(
                        color: _textColor(context),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'GHS ${numberFormat.format(totalAmount)}',
                      style: TextStyle(
                        color: _textColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 700;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: 24,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionLabel(context, 'ITEMS'),
                    const SizedBox(height: 10),
                    _itemsCard(
                      context,
                      items,
                      isDesktop,
                      numberFormat,
                      totalAmount,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _appBarInfo(BuildContext context, String label, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          value,
          style: TextStyle(
            color: _textColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _sectionLabel(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: _textColor(context),
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
    ),
  );

  Widget _itemsCard(
    BuildContext context,
    List<Map<String, dynamic>> items,
    bool isDesktop,
    NumberFormat nf,
    double totalAmount,
  ) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor(context)),
        ),
        alignment: Alignment.center,
        child: Text(
          'No items on this receipt.',
          style: TextStyle(color: _textColor(context), fontSize: 12),
        ),
      );
    }

    final columnWidths = <int, TableColumnWidth>{
      0: const FlexColumnWidth(0.5),
      1: const FlexColumnWidth(2.6),
      2: const FlexColumnWidth(1),
      if (isDesktop) 3: const FlexColumnWidth(1.2),
      if (isDesktop) 4: const FlexColumnWidth(1),
      (isDesktop ? 5 : 3): const FlexColumnWidth(1.3),
    };

    return Container(
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Table(
            columnWidths: columnWidths,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: _headerColor(context),
                  border: Border(
                    bottom: BorderSide(color: _borderColor(context)),
                  ),
                ),
                children: [
                  _itemHeaderCell(context, '#'),
                  _itemHeaderCell(context, 'Description'),
                  _itemHeaderCell(context, 'Qty', align: TextAlign.right),
                  if (isDesktop)
                    _itemHeaderCell(
                      context,
                      'Unit Price',
                      align: TextAlign.right,
                    ),
                  if (isDesktop)
                    _itemHeaderCell(
                      context,
                      'Discount',
                      align: TextAlign.right,
                    ),
                  _itemHeaderCell(context, 'Total', align: TextAlign.right),
                ],
              ),
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final status = item['status']?.toString() ?? '';
                final isItemReturned = status == 'returned';
                final name = (item['item'] ?? '-').toString().toUpperCase();
                final label = isItemReturned ? '$name  ·  Returned' : name;
                final itemTotal =
                    double.tryParse(item['totalamount']?.toString() ?? '0') ??
                    0;

                return TableRow(
                  decoration: BoxDecoration(
                    color: isItemReturned
                        ? Colors.redAccent.withOpacity(0.08)
                        : _cardColor(context),
                    border: Border(
                      top: BorderSide(color: _borderColor(context)),
                    ),
                  ),
                  children: [
                    _itemCell(context, '${i + 1}', color: _textColor(context)),
                    _itemCell(
                      context,
                      label,
                      bold: true,
                      color: isItemReturned
                          ? Colors.redAccent
                          : _textColor(context),
                    ),
                    _itemCell(
                      context,
                      isDesktop
                          ? '${item['quantity'] ?? item['totalpieces'] ?? '-'} (${item['mode'] ?? '-'})'
                          : '${item['quantity'] ?? item['totalpieces'] ?? '-'}',
                      align: TextAlign.right,
                    ),
                    if (isDesktop)
                      _itemCell(
                        context,
                        'GHS ${item['price'] ?? '-'}',
                        align: TextAlign.right,
                        color: _textColor(context),
                      ),
                    if (isDesktop)
                      _itemCell(
                        context,
                        item['discount']?.toString() ?? '0',
                        align: TextAlign.right,
                        color: _textColor(context),
                      ),
                    _itemCell(
                      context,
                      'GHS ${nf.format(itemTotal)}',
                      align: TextAlign.right,
                      bold: true,
                    ),
                  ],
                );
              }),
            ],
          ),
          // Footer summary row — gives the card a defined bottom edge
          // instead of ending abruptly on the last item.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _borderColor(context))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Total  ',
                  style: TextStyle(color: _textColor(context), fontSize: 12),
                ),
                Text(
                  'GHS ${nf.format(totalAmount)}',
                  style: TextStyle(
                    color: _textColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemHeaderCell(
    BuildContext context,
    String text, {
    TextAlign align = TextAlign.left,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          color: _textColor(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _itemCell(
    BuildContext context,
    String text, {
    TextAlign align = TextAlign.left,
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          color: color ?? _textColor(context),
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
    );
  }
}
