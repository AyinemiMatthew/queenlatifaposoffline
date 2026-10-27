import 'package:flutter/material.dart';

double nn(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
String f2(double v) => v.toStringAsFixed(2);

String capitalize(String? text) {
  if (text == null || text.isEmpty) return '';
  return text[0].toUpperCase() + text.substring(1);
}

class PayMethod {
  final String id, label, pdfLabel, salesKey, debtKey;
  const PayMethod(
    this.id,
    this.label,
    this.pdfLabel,
    this.salesKey,
    this.debtKey,
  );
}

const kPayMethods = <PayMethod>[
  PayMethod(
    'momo',
    'Merchant MoMo',
    'MoMo',
    'merchantmomo',
    'debtmerchantmomo',
  ),
  PayMethod('hubtel', 'Hubtel', 'Hubtel', 'hubtel', 'debthubtel'),
  PayMethod('card', 'Card', 'Card', 'card', 'debtcard'),
  PayMethod('bank', 'Bank Transfer', 'Bank', 'bank', 'debtbank'),
  PayMethod('cheque', 'Cheque', 'Cheque', 'cheque', 'debtcheque'),
  PayMethod('credit', 'Credit', 'Credit', 'credit', 'debtcredit'),
];

class StaffRow {
  final String staff, email;
  final double cashSales, creditSales, cashReturns, creditReturns;
  final double cashDiscount, creditDiscount, profit, debtCash, cashAtHand;
  final Map<String, double> sales;
  final Map<String, double> debt;

  StaffRow({
    required this.staff,
    required this.email,
    required this.cashSales,
    required this.creditSales,
    required this.cashReturns,
    required this.creditReturns,
    required this.cashDiscount,
    required this.creditDiscount,
    required this.profit,
    required this.debtCash,
    required this.cashAtHand,
    required this.sales,
    required this.debt,
  });

  factory StaffRow.fromMap(Map<String, dynamic> t) => StaffRow(
    staff: (t['staff'] ?? '').toString(),
    email: (t['staffEmail'] ?? '').toString(),
    cashSales: nn(t['cashSales']),
    creditSales: nn(t['creditSales']),
    cashReturns: nn(t['cashReturns']),
    creditReturns: nn(t['creditReturns']),
    cashDiscount: nn(t['cashDiscount']),
    creditDiscount: nn(t['creditDiscount']),
    profit: nn(t['profit']),
    debtCash: nn(t['debtpayment_cash']),
    cashAtHand: nn(t['cashAtHand']),
    sales: {for (final m in kPayMethods) m.id: nn(t[m.salesKey])},
    debt: {for (final m in kPayMethods) m.id: nn(t[m.debtKey])},
  );

  double get returns => cashReturns + creditReturns;
  double get discount => cashDiscount + creditDiscount;
  double get debtTotal => debtCash + debt.values.fold(0.0, (a, b) => a + b);
  double get allSales => cashSales + sales.values.fold(0.0, (a, b) => a + b);
  double get calcCashAtHand => cashSales + debtCash - cashReturns;
  double methodTotal(PayMethod m) => (sales[m.id] ?? 0) + (debt[m.id] ?? 0);

  Map<String, double> get cashSalesLines => {
    'Cash': cashSales,
    for (final m in kPayMethods) m.label: sales[m.id] ?? 0,
  };
  Map<String, double> get returnsLines => {
    'Cash Return': cashReturns,
    'Credit Return': creditReturns,
  };
  Map<String, double> get discountLines => {
    'Cash Discount': cashDiscount,
    'Credit Discount': creditDiscount,
  };
  Map<String, double> get debtLines => {
    'Cash': debtCash,
    for (final m in kPayMethods) m.label: debt[m.id] ?? 0,
  };
  Map<String, double> get cashAtHandLines => {
    'Cash Sales': cashSales,
    'Cash Debt Payment (+)': debtCash,
    'Cash Returns (âˆ’)': cashReturns,
  };
}

String tipText(Map<String, double> lines, String totalLabel, double total) {
  final b = StringBuffer();
  lines.forEach((k, v) => b.writeln('$k: ${f2(v)}'));
  b.writeln();
  b.write('$totalLabel: ${f2(total)}');
  return b.toString();
}

class PaymentFilterOption {
  final String label;
  final String? value;
  final IconData icon;
  const PaymentFilterOption(this.label, this.value, this.icon);
}

class ItemLine {
  final String name;
  final num qty;
  final String barcode;
  final String boxpiece;
  final double cp;
  final double discount;
  final double grossTotalAmount;
  final String mode;
  final String modeQty;
  final String pcategory;
  final double price;
  final String priceMode;
  final String productType;
  final double profit;
  final double totalAmount;
  final num totalPieces;

  ItemLine({
    required this.name,
    required this.qty,
    this.barcode = '',
    this.boxpiece = '',
    this.cp = 0.0,
    this.discount = 0.0,
    this.grossTotalAmount = 0.0,
    this.mode = '',
    this.modeQty = '',
    this.pcategory = '',
    this.price = 0.0,
    this.priceMode = '',
    this.productType = '',
    this.profit = 0.0,
    this.totalAmount = 0.0,
    this.totalPieces = 0,
  });
}

class PaymentLine {
  final String accountName;
  final String accountNumber;
  final double amount;
  final String method;
  final String reference;
  final bool status;

  PaymentLine({
    required this.accountName,
    required this.accountNumber,
    required this.amount,
    required this.method,
    required this.reference,
    required this.status,
  });
}

List<PaymentLine> parsePaymentLines(dynamic paymentsField) {
  final lines = <PaymentLine>[];
  if (paymentsField is! List) return lines;

  for (final value in paymentsField) {
    if (value is! Map) continue;
    lines.add(
      PaymentLine(
        accountName: (value['accountName'] ?? '').toString(),
        accountNumber: (value['accountNumber'] ?? '').toString(),
        amount: double.tryParse(value['amount']?.toString() ?? '0') ?? 0.0,
        method: (value['method'] ?? '').toString(),
        reference: (value['reference'] ?? '').toString(),
        status: value['status'] == true,
      ),
    );
  }
  return lines;
}

List<ItemLine> parseItemLines(dynamic itemsField) {
  final lines = <ItemLine>[];

  double d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0.0;
  num n(dynamic v) => num.tryParse(v?.toString() ?? '0') ?? 0;

  void addEntry(dynamic value, String fallbackName) {
    if (value is! Map) return;
    final name = (value['item'] ?? value['name'] ?? fallbackName).toString();
    final rawQty = value['quantity'] ?? value['qty'] ?? 0;
    final qty = rawQty is num ? rawQty : num.tryParse(rawQty.toString()) ?? 0;

    lines.add(
      ItemLine(
        name: name,
        qty: qty,
        barcode: (value['barcode'] ?? '').toString(),
        boxpiece: (value['boxpiece'] ?? '').toString(),
        cp: d(value['cp']),
        discount: d(value['discount']),
        grossTotalAmount: d(value['grosstotalamount']),
        mode: (value['mode'] ?? '').toString(),
        modeQty: (value['modeqty'] ?? '').toString(),
        pcategory: (value['pcategory'] ?? '').toString(),
        price: d(value['price']),
        priceMode: (value['pricemode'] ?? '').toString(),
        productType: (value['producttype'] ?? '').toString(),
        profit: d(value['profit']),
        totalAmount: d(value['totalamount']),
        totalPieces: n(value['totalpieces']),
      ),
    );
  }

  if (itemsField is Map) {
    for (final entry in itemsField.entries) {
      addEntry(entry.value, entry.key.toString());
    }
  } else if (itemsField is List) {
    for (final value in itemsField) {
      addEntry(value, '');
    }
  }
  return lines;
}


Widget miniStatString(BuildContext context, String title, dynamic value) {
  final isLightTheme = Theme.of(context).brightness == Brightness.light;
  final colorScheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: isLightTheme ? Colors.white : Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      border: isLightTheme
          ? Border.all(color: colorScheme.outlineVariant)
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isLightTheme ? colorScheme.onSurfaceVariant : Colors.white54,
            fontSize: 10,
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            color: isLightTheme ? colorScheme.onSurface : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget miniStatTap(
  BuildContext context,
  String label,
  String value, {
  VoidCallback? onTap,
}) {
  final isLightTheme = Theme.of(context).brightness == Brightness.light;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLightTheme
            ? Colors.white
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: isLightTheme
            ? Border.all(color: Theme.of(context).colorScheme.outlineVariant)
            : null,
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: isLightTheme
              ? Theme.of(context).colorScheme.onSurface
              : Colors.white70,
          decoration: TextDecoration.underline,
        ),
      ),
    ),
  );
}

Widget breakdownRow(String label, num value, {bool bold = false}) {
  final style = TextStyle(
    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        const SizedBox(width: 24),
        Text(value.toStringAsFixed(2), style: style),
      ],
    ),
  );
}

List<Widget> breakdownRows(
  Map<String, double> lines,
  String totalLabel,
  double total,
) => [
  for (final e in lines.entries) breakdownRow(e.key, e.value),
  const Divider(),
  breakdownRow(totalLabel, total, bold: true),
];

void showBreakdownDialog(
  BuildContext context,
  String title,
  Map<String, double> lines,
  String totalLabel,
  double total,
) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: breakdownRows(lines, totalLabel, total),
      ),
    ),
  );
}
