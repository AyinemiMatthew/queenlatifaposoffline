import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color kSrBg = Color(0xFF101624);
const Color kSrCard = Color(0xFF1B263B);
const Color kSrHeader = Color(0xFF0D1B2A);
const Color kSrTotal = Color(0xFF16213E);
const Color kSrBorder = Colors.white12;
const Color kSrText = Colors.white;
const Color kSrAccent = Color(0xFF6366F1);

const TextStyle kSrHeaderStyle = TextStyle(
  color: kSrText,
  fontWeight: FontWeight.w700,
  fontSize: 13,
  letterSpacing: 0.4,
);

bool srIsLightTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color srBackgroundColor(BuildContext context) =>
    srIsLightTheme(context) ? Colors.white : kSrBg;

Color srCardColor(BuildContext context) =>
    srIsLightTheme(context) ? Colors.white : kSrCard;

Color srHeaderColor(BuildContext context) =>
    srIsLightTheme(context) ? Colors.white : kSrCard;

Color srTotalColor(BuildContext context) =>
    srIsLightTheme(context) ? Colors.white : kSrTotal;

Color srBorderColor(BuildContext context) =>
    srIsLightTheme(context) ? Colors.grey.shade300 : kSrBorder;

Color srTextColor(BuildContext context) =>
    srIsLightTheme(context) ? Theme.of(context).colorScheme.onSurface : kSrText;

Color srMutedTextColor(BuildContext context) => srIsLightTheme(context)
    ? Theme.of(context).colorScheme.onSurfaceVariant
    : Colors.white70;

Color srRowColor(BuildContext context, int index) {
  if (srIsLightTheme(context)) return Colors.white;
  return index.isEven ? const Color(0xFF0D1B2A) : const Color(0xFF111E2F);
}

Color srAccentColor(BuildContext context) =>
    srIsLightTheme(context) ? Theme.of(context).colorScheme.primary : kSrAccent;

final NumberFormat srNf = NumberFormat('#,##0.00');

String srN(double v) => srNf.format(v);

class BranchRow {
  final String branchId;
  final String branchName;
  final double cash;
  final double momo;
  final double card;
  final double bank;
  final double hubtel;
  final double cheque;
  final double credit;
  final double cashReturns;
  final double creditReturns;
  final double discount;
  final double returnDiscount;
  final double profit;
  final double returnProfit;
  final double debt;
  final double qty;
  final String? category;
  final String? producttype;

  const BranchRow({
    required this.branchId,
    required this.branchName,
    required this.cash,
    required this.momo,
    required this.card,
    required this.bank,
    required this.hubtel,
    required this.cheque,
    required this.credit,
    required this.cashReturns,
    required this.creditReturns,
    required this.discount,
    required this.returnDiscount,
    required this.profit,
    required this.returnProfit,
    required this.debt,
    this.qty = 0.0,
    this.category,
    this.producttype,
  });

  factory BranchRow.fromMap(Map<String, dynamic> m) {
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0.0;
    return BranchRow(
      branchId: (m['branchId'] ?? '').toString(),
      branchName: (m['branchName'] ?? '').toString(),
      cash: d('cashSales'),
      momo: d('merchantmomo'),
      card: d('card'),
      bank: d('bank'),
      hubtel: d('hubtel'),
      cheque: d('cheque'),
      credit: d('creditSales'),
      cashReturns: d('cashReturns'),
      creditReturns: d('creditReturns'),
      discount: d('discount'),
      returnDiscount: d('returnDiscount'),
      profit: d('profit'),
      returnProfit: d('returnProfit'),
      debt: d('branchdebt'),
      qty: d('sales_qty'),
      category: '',
      producttype: '',
    );
  }

  factory BranchRow.fromItem(Map<String, dynamic> m) {
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0.0;
    return BranchRow(
      branchId: (m['itemid'] ?? '').toString(),
      branchName: (m['item'] ?? '').toString(),
      cash: d('cashSales'),
      momo: d('momo'),
      card: 0,
      bank: 0,
      hubtel: 0,
      cheque: 0,
      credit: d('creditSales'),
      cashReturns: d('cashReturns'),
      creditReturns: d('creditReturns'),
      discount: d('discount'),
      returnDiscount: d('return_discount'),
      profit: d('profit'),
      returnProfit: d('return_profit'),
      debt: 0,
      qty: d('sales_qty'),
      category: (m['pcategory'] ?? m['category'] ?? '').toString(),
      producttype: (m['producttype'] ?? '').toString(),
    );
  }

  factory BranchRow.sum(List<BranchRow> rows) {
    double cash = 0, momo = 0, card = 0, bank = 0, hubtel = 0, cheque = 0;
    double credit = 0, cashReturns = 0, creditReturns = 0, discount = 0;
    double returnDiscount = 0, profit = 0, returnProfit = 0, debt = 0;
    double qty = 0;

    for (final r in rows) {
      cash += r.cash;
      momo += r.momo;
      card += r.card;
      bank += r.bank;
      hubtel += r.hubtel;
      cheque += r.cheque;
      credit += r.credit;
      cashReturns += r.cashReturns;
      creditReturns += r.creditReturns;
      discount += r.discount;
      returnDiscount += r.returnDiscount;
      profit += r.profit;
      returnProfit += r.returnProfit;
      debt += r.debt;
      qty += r.qty;
    }
    return BranchRow(
      branchId: '',
      branchName: 'Grand Total',
      cash: cash,
      momo: momo,
      card: card,
      bank: bank,
      hubtel: hubtel,
      cheque: cheque,
      credit: credit,
      cashReturns: cashReturns,
      creditReturns: creditReturns,
      discount: discount,
      returnDiscount: returnDiscount,
      profit: profit,
      returnProfit: returnProfit,
      debt: debt,
      qty: qty,
      category: '',
      producttype: '',
    );
  }

  double get cashSales => cash + momo + card + bank + hubtel + cheque;
  double get totalSales => cashSales + credit;
  double get returns => cashReturns + creditReturns;
  double get grossDiscount => discount + returnDiscount;
  double get grossProfit => profit + returnProfit;
  double get cashAtHand => cash - cashReturns;
}

class TxnCol {
  final String label;
  final int flex;
  final double minWidth;
  final bool right;
  const TxnCol(this.label, this.flex, {this.minWidth = 0, this.right = false});
}

typedef ReportExport =
    Future<void> Function({
      required String action,
      required String title,
      required String branchLabel,
      required String countLabel,
      required String firstColumn,
      required DateTime start,
      required DateTime end,
      required String? type,
      required String? category,
      required List<BranchRow> rows,
      required BranchRow t,
    });

typedef ItemTxnExport =
    Future<void> Function({
      required String action,
      required String itemName,
      required String branchLabel,
      required List<Map<String, dynamic>> rows,
      required Map<String, double> summary,
      String? staff,
      String? type,
      String? category,
      String? kind,
    });

String _srLines(
  List<MapEntry<String, double>> parts,
  String totalLabel,
  double total, {
  bool skipZero = false,
}) {
  final lines = <String>[];
  for (final p in parts) {
    if (skipZero && p.value == 0) continue;
    lines.add('${p.key}: ${srN(p.value)}');
  }
  lines.add('$totalLabel: ${srN(total)}');
  return lines.join('\n');
}

List<String> srTips(BranchRow r) {
  final creditTip = r.debt == 0
      ? 'Credit Sales (on account): ${srN(r.credit)}'
      : 'Credit Sales (on account): ${srN(r.credit)}\nDebt payments received: ${srN(r.debt)}';

  return [
    _srLines(
      [
        MapEntry('Cash', r.cash),
        MapEntry('MoMo', r.momo),
        MapEntry('Card', r.card),
        MapEntry('Bank', r.bank),
        MapEntry('Hubtel', r.hubtel),
        MapEntry('Cheque', r.cheque),
      ],
      'Cash Sales',
      r.cashSales,
      skipZero: true,
    ),
    'MoMo: ${srN(r.momo)}',
    'Hubtel: ${srN(r.hubtel)}',
    'Card: ${srN(r.card)}',
    'Bank: ${srN(r.bank)}',
    'Cheque: ${srN(r.cheque)}',
    creditTip,
    _srLines(
      [
        MapEntry('Cash', r.cash),
        MapEntry('MoMo', r.momo),
        MapEntry('Card', r.card),
        MapEntry('Bank', r.bank),
        MapEntry('Hubtel', r.hubtel),
        MapEntry('Cheque', r.cheque),
        MapEntry('Credit', r.credit),
      ],
      'Total Sales',
      r.totalSales,
      skipZero: true,
    ),
    _srLines(
      [
        MapEntry('Cash Returns', r.cashReturns),
        MapEntry('Credit Returns', r.creditReturns),
      ],
      'Total Returns',
      r.returns,
    ),
    'Discount given: ${srN(r.grossDiscount)}\n'
        'Less discount on returns: ${srN(r.returnDiscount)}\n'
        'Net Discount: ${srN(r.discount)}',
    'Gross profit: ${srN(r.grossProfit)}\n'
        'Less profit on returns: ${srN(r.returnProfit)}\n'
        'Net Profit: ${srN(r.profit)}',
    'Cash received: ${srN(r.cash)}\n'
        'Less cash returns: ${srN(r.cashReturns)}\n'
        'Cash @ Hand: ${srN(r.cashAtHand)}',
  ];
}

List<double> srValues(BranchRow r) => [
  r.cash,
  r.momo,
  r.hubtel,
  r.card,
  r.bank,
  r.cheque,
  r.credit,
  r.totalSales,
  r.returns,
  r.discount,
  r.profit,
  r.cashAtHand,
];

void srShowBreakdown(BuildContext context, String title, String message) {
  final textColor = srTextColor(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: srHeaderColor(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget srTip(
  BuildContext context,
  String message,
  Widget child, {
  String title = 'Breakdown',
}) {
  if (MediaQuery.sizeOf(context).width < 600) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => srShowBreakdown(context, title, message),
      child: child,
    );
  }
  final textColor = srTextColor(context);
  return Tooltip(
    message: message,
    waitDuration: const Duration(milliseconds: 250),
    showDuration: const Duration(seconds: 6),
    preferBelow: false,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: srHeaderColor(context),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: srBorderColor(context)),
    ),
    textStyle: TextStyle(color: textColor, fontSize: 12, height: 1.5),
    child: child,
  );
}

Widget srFilterButton({
  required BuildContext context,
  required IconData icon,
  required String tooltip,
  required String allLabel,
  required List<String> options,
  required String? current,
  required ValueChanged<String?> onPicked,
}) {
  return PopupMenuButton<String>(
    tooltip: tooltip,
    color: srCardColor(context),
    icon: Icon(
      icon,
      color: current != null
          ? srAccentColor(context)
          : srMutedTextColor(context),
      size: 21,
    ),
    onSelected: (v) => onPicked(v == '__ALL__' ? null : v),
    itemBuilder: (_) => [
      PopupMenuItem<String>(
        value: '__ALL__',
        child: Text(
          allLabel,
          style: TextStyle(
            color: current == null
                ? srAccentColor(context)
                : srTextColor(context),
            fontSize: 13,
          ),
        ),
      ),
      ...options.map(
        (o) => PopupMenuItem<String>(
          value: o,
          child: Text(
            o,
            style: TextStyle(
              color: o == current
                  ? srAccentColor(context)
                  : srTextColor(context),
              fontSize: 13,
            ),
          ),
        ),
      ),
    ],
  );
}
