

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/Receiptdatamodel.dart';

const bool kUseCode39 = false;

final PdfPageFormat kReceipt72 = PdfPageFormat(
  72 * PdfPageFormat.mm,
  double.infinity,
);

Barcode receiptBarcode() => kUseCode39 ? Barcode.code39() : Barcode.code128();

/// 2 -> "2", 1.5 -> "1.50"
String formatQty(double q) =>
    q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);


class InvoiceItem {
  final String description;
  final double qty;
  final double price;

  /// Optional small line under the name (e.g. the warehouse / branch).
  final String note;

  const InvoiceItem({
    required this.description,
    required this.qty,
    required this.price,
    this.note = '',
  });

  double get total => qty * price;

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      description: (map['name'] ?? map['description'] ?? '').toString(),
      qty: ((map['quantity'] ?? map['qty'] ?? 0) as num).toDouble(),
      price: ((map['price'] ?? map['unitPrice'] ?? 0) as num).toDouble(),
      note: (map['note'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'description': description,
    'qty': qty,
    'price': price,
    'note': note,
    'total': total,
  };
}


const List<InvoiceItem> sampleInvoiceItems = [
  InvoiceItem(description: 'Milo Tin 400g', qty: 2, price: 32.50),
  InvoiceItem(description: 'Gino Tomato Paste', qty: 3, price: 4.50),
  InvoiceItem(description: 'Fresh Milk 1L', qty: 1, price: 18.00),
  InvoiceItem(description: 'Perfumed Rice 5kg', qty: 1, price: 95.00),
  InvoiceItem(description: 'Bottled Water 500ml', qty: 6, price: 2.50),
];

class ProformaInvoicePdf {
  final String title;
  final String businessName;
  final String tagline;
  final String address;
  final String telephone;
  final String supplierTin;
  final String customerName;
  final String customerTin;
  final String receiptNo;
  final String cashier;
  final String till;
  final DateTime? dateTime;
  final String barcodeData;
  final List<InvoiceItem> items;
  final String vatLabel;
  final double vatRate;
  final String poweredBy;
  final String thankYou;
  final String policy;
  final double discount;
  final double? amountPaid;
  final String? documentTitle;


  final pw.Font? regularFont;
  final pw.Font? boldFont;

  const ProformaInvoicePdf({
    required this.items,
    this.title = 'PROFORMA INVOICE',
    this.businessName = 'ABIBA',
    this.tagline = '',
    this.address = '',
    this.telephone = '0553354349',
    this.supplierTin = '',
    this.customerName = '',
    this.customerTin = '',
    this.receiptNo = '',
    this.cashier = 'Atams',
    this.till = '',
    this.dateTime,
    this.barcodeData = '01790709813513',
    this.vatLabel = 'VAT (15%)',
    this.vatRate = 0.15,
    this.poweredBy = 'POWERED BY KOLOGSOFT',
    this.thankYou = 'Thank you for shopping with us!',
    this.policy = 'Goods sold are not returnable',
    this.discount = 0,
    this.amountPaid,
    this.documentTitle,
    this.regularFont,
    this.boldFont,
  });

  String _money(double v) => v.toStringAsFixed(2);
  String _gh(double v) => 'GH\u00A2 ${_money(v)}';
  String _two(int n) => n.toString().padLeft(2, '0');

  static const _black = PdfColors.black;
  static final _beige = PdfColor.fromHex('#E6E6CF');
  static final _orange = PdfColor.fromHex('#CC6600');
  static final _lightGrey = PdfColor.fromHex('#BBBBBB');
  static final _valueGrey = PdfColor.fromHex('#777777');

  // inside class ProformaInvoicePdf
  static Future<ProformaInvoicePdf> fromReceiptData(ReceiptData data) async {
    final regular =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final isSalesPoint =
        (data.branchType ?? '').trim().toLowerCase() == 'sales point';

    final items = data.items.map((i) {
      final name = (i.isService || i.mode.trim().isEmpty)
          ? i.name
          : '${i.name} (${i.mode})';
      return InvoiceItem(
        description: name,
        qty: i.qty.toDouble(),
        price: i.price.toDouble(),
        // the warehouse shows under the item name, only for sales points
        note: isSalesPoint ? (i.branch ?? '').trim() : '',
      );
    }).toList();

    final barcode = data.barcode.trim().isNotEmpty
        ? data.barcode.trim()
        : data.receiptNumber;

    return ProformaInvoicePdf(
      items: items,
      title: data.receiptName.trim().isEmpty
          ? 'SALES RECEIPT'
          : data.receiptName.toUpperCase(),
      businessName: data.companyName.trim().toUpperCase(),
      tagline: (data.branch ?? '').trim(),
      address: (data.address ?? '').trim(),
      telephone: data.contact,
      receiptNo: data.receiptNumber,
      cashier: data.cashier.trim().split(' ').first,
      customerName: data.customername.trim().isEmpty
          ? 'Cash Customer'
          : data.customername.trim(),
      dateTime: data.datetime,
      barcodeData: barcode,
      discount: data.discount.toDouble(),
      amountPaid: data.amountPaid.toDouble(),
      vatRate: 0, // your data already has the payable amount, so don't add VAT again
      thankYou: 'Thank you for choosing ${data.companyName.trim()}!',
      policy: 'Exchanges accepted within 7 days. No cash refund.',
      documentTitle: data.transactionId,
      regularFont: regular,
      boldFont: bold,
    );
  }

  Future<Uint8List> build({PdfPageFormat? format}) async {
    final doc = await buildDocument(format: format);
    return doc.save();
  }

  Future<pw.Document> buildDocument({PdfPageFormat? format}) async {
    format ??= kReceipt72;
    final doc = pw.Document(title: documentTitle);

    final reg = regularFont ?? pw.Font.courier();
    final bold = boldFont ?? pw.Font.courierBold();
    final mute = PdfColor.fromHex('#555555');

    // Receipt roll (infinite height) fits its content; any other paper
    // (A4, Letter...) is stretched to the full width and paginated.
    final isRoll = format.height == double.infinity;
    const pageMargin = 24.0;
    final usable =
    isRoll ? format.availableWidth : format.width - pageMargin * 2;
    // 1.0 on an 80mm roll, grows gently on wider paper.
    final s = (usable / 198).clamp(1.0, 1.6).toDouble();

    pw.TextStyle st(double size, {bool b = false, PdfColor? color}) =>
        pw.TextStyle(
            font: b ? bold : reg,
            fontSize: size * s,
            color: color ?? PdfColors.black);

    final when = dateTime ?? DateTime.now();
    final units = items.fold<double>(0, (a, i) => a + i.qty);
    final subtotal = items.fold<double>(0, (a, i) => a + i.total);
    final net = subtotal - discount;
    final vat = net * vatRate;
    final grand = net + vat;
    final change = amountPaid == null ? '' : _gh(amountPaid! - grand);

    pw.Widget dashed() => pw.Divider(
        height: 10, thickness: 0.6, borderStyle: pw.BorderStyle.dashed);
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

    final content = <pw.Widget>[
      centered(businessName, size: 15, b: true),
      if (tagline.isNotEmpty) centered(tagline, size: 8, c: mute),
      for (final line in address.split('\n'))
        if (line.trim().isNotEmpty) centered(line),
      if (telephone.isNotEmpty) centered('Tel: $telephone'),
      if (supplierTin.isNotEmpty) centered('TIN: $supplierTin', size: 8, c: mute),
      dashed(),
      centered(title, size: 10, b: true),
      dashed(),
      kv('Receipt No:', receiptNo.isEmpty ? '#$barcodeData' : receiptNo),
      kv('Date:', '${_two(when.day)}/${_two(when.month)}/${when.year}'),
      kv('Time:',
          '${_two(when.hour)}:${_two(when.minute)}:${_two(when.second)}'),
      kv('Cashier:', cashier),
      if (till.isNotEmpty) kv('Till:', till),
      if (customerName.isNotEmpty) kv('Customer:', customerName),
      if (customerTin.isNotEmpty) kv('Cust. TIN:', customerTin),
      dashed(),
      cols('ITEM', 'QTY', 'PRICE', 'TOTAL', b: true, size: 8),
      pw.Divider(height: 6, thickness: 0.6),
      for (final i in items)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(i.description, style: st(8.5, b: true)),
              cols(i.note, formatQty(i.qty), _money(i.price), _money(i.total)),
            ],
          ),
        ),
      dashed(),
      kv('Items (${formatQty(units)} units)', ''),
      kv('Subtotal', _gh(subtotal)),
      kv('Discount', '-${_gh(discount)}'),
      kv('Net Amount', _gh(net)),
      if (vatRate > 0) kv(vatLabel, _gh(vat)),
      solid(),
      kv('GRAND TOTAL', _gh(grand), size: 11, b: true),
      solid(),
      kv('Paid', amountPaid == null ? '' : _gh(amountPaid!)),
      kv('Change', change),
      dashed(),
      centered(thankYou),
      centered(policy, size: 8, c: mute),
      pw.SizedBox(height: 2),
      centered(poweredBy, size: 7, c: mute),
      dashed(),
     pw.SizedBox(height: 2),
      pw.Center(
        child: pw.Container(
          color: PdfColors.white,
          padding: const pw.EdgeInsets.all(4),
          child: pw.BarcodeWidget(
            barcode: Barcode.qrCode(),
            data: barcodeData,
            width: 50,
            height: 40,
            drawText: false,
            color: _black,
          ),
        ),
      ),
    ];

    if (isRoll) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(4),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: content,
          ),
        ),
      );
    } else {
      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(pageMargin),
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          build: (context) => content,
        ),
      );
    }

    return doc;
  }
}
class ProformaInvoiceScreen extends StatefulWidget {
  final String title;
  final String businessName;
  final String tagline;
  final String address;
  final String telephone;
  final String supplierTin;
  final String customerName;
  final String customerTin;
  final String receiptNo;
  final String cashier;
  final String till;
  final DateTime? dateTime;
  final String barcodeData;
  final List<InvoiceItem> items;
  final String vatLabel;
  final double vatRate;
  final String poweredBy;
  final String thankYou;
  final String policy;

  /// true  = Discount / Paid are text fields the cashier can type in.
  /// false = they are shown as plain values (use for a finished sale).
  final bool editable;
  final double initialDiscount;
  final double? initialPaid;

  const ProformaInvoiceScreen({
    super.key,
    this.title = 'PROFORMA INVOICE',
    this.businessName = 'FRESHMART',
    this.tagline = 'Supermarket & Groceries',
    this.address = '14 Adum High Street\nKumasi, Ashanti, Ghana',
    this.telephone = '+233 24 000 0000',
    this.supplierTin = 'C0001234567',
    this.customerName = '',
    this.customerTin = '',
    this.receiptNo = '',
    this.cashier = 'Ama Serwaa',
    this.till = '03',
    this.dateTime,
    this.barcodeData = '01790709813513',
    this.vatLabel = 'VAT (15%)',
    this.vatRate = 0.15,
    this.poweredBy = 'POWERED BY KOLOGSOFT',
    this.thankYou = 'Thank you for shopping with us!',
    this.policy = 'Goods sold are not returnable',
    this.editable = true,
    this.initialDiscount = 0,
    this.initialPaid,
    this.items = sampleInvoiceItems,
  });

  @override
  State<ProformaInvoiceScreen> createState() => _ProformaInvoiceScreenState();
}

class _ProformaInvoiceScreenState extends State<ProformaInvoiceScreen> {
  static const Color _bg = Color(0xFFE9E7E2);
  static const Color _ink = Color(0xFF111111);
  static const Color _mute = Color(0xFF555555);
  static const Color _navy = Color(0xFF000080);

  static const TextStyle _base = TextStyle(
    fontFamily: 'Courier New',
    fontFamilyFallback: ['Courier', 'monospace'],
    fontSize: 12.5,
    height: 1.45,
    color: _ink,
  );

  static const double _qtyW = 30;
  static const double _priceW = 60;
  static const double _totalW = 68;

  late final TextEditingController _discountCtrl = TextEditingController(
      text: widget.initialDiscount.toStringAsFixed(2));
  late final TextEditingController _paidCtrl = TextEditingController(
      text: widget.initialPaid == null
          ? ''
          : widget.initialPaid!.toStringAsFixed(2));
  late final DateTime _when = widget.dateTime ?? DateTime.now();

  @override
  void dispose() {
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _money(double v) => v.toStringAsFixed(2);
  String _gh(double v) => 'GH₵ ${_money(v)}';

  // small building blocks
  Widget _center(String t, {TextStyle? style}) =>
      Text(t, textAlign: TextAlign.center, style: style);

  Widget _dashed() => LayoutBuilder(builder: (context, c) {
    final n = (c.maxWidth / 6).floor();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          n,
              (_) => const SizedBox(
            width: 3,
            height: 1,
            child: ColoredBox(color: _ink),
          ),
        ),
      ),
    );
  });

  Widget _solid() => Container(
    height: 2,
    margin: const EdgeInsets.symmetric(vertical: 10),
    color: _ink,
  );

  Widget _kv(String a, String b) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [Text(a), Flexible(child: Text(b, textAlign: TextAlign.right))],
  );

  Widget _tot(String a, String b, {TextStyle? style}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [Text(a, style: style), Text(b, style: style)],
  );

  Widget _cols(String a, String q, String p, String t, {TextStyle? style}) {
    return Row(
      children: [
        Expanded(child: Text(a, style: style)),
        SizedBox(
            width: _qtyW,
            child: Text(q, textAlign: TextAlign.right, style: style)),
        const SizedBox(width: 6),
        SizedBox(
            width: _priceW,
            child: Text(p, textAlign: TextAlign.right, style: style)),
        const SizedBox(width: 6),
        SizedBox(
            width: _totalW,
            child: Text(t, textAlign: TextAlign.right, style: style)),
      ],
    );
  }

  Widget _inlineInput(TextEditingController c, {String? hint}) {
    const line = UnderlineInputBorder(
        borderSide: BorderSide(color: _ink, width: 1));
    return SizedBox(
      width: 120,
      child: TextField(
        controller: c,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        style: _base,
        decoration: InputDecoration(
          isDense: true,
          fillColor: Theme.of(context).colorScheme.onSurfaceVariant,
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          prefixText: 'GH₵ ',
          prefixStyle: _base,
          hintText: hint,
          hintStyle: _base.copyWith(color: _mute),
          border: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,

          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _ink, width: 2)),
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap, {bool filled = true}) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? _navy : Colors.white,
          foregroundColor: filled ? Colors.white : _navy,
          elevation: 0,
          shape: const RoundedRectangleBorder(),
          side: const BorderSide(color: _navy, width: 1.5),
        ),
        child: Text(label, style: _base.copyWith(fontSize: 13)),
      ),
    );
  }

  // ---- build ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final units = items.fold<double>(0, (a, i) => a + i.qty);
    final subtotal = items.fold<double>(0, (a, i) => a + i.total);
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final net = subtotal - discount;
    final vat = net * widget.vatRate;
    final grand = net + vat;
    final paid = double.tryParse(_paidCtrl.text.trim());
    final change = paid == null ? '' : _gh(paid - grand);

    final receiptNo =
    widget.receiptNo.isEmpty ? '#${widget.barcodeData}' : widget.receiptNo;
    final dateStr = '${_two(_when.day)}/${_two(_when.month)}/${_when.year}';
    final timeStr =
        '${_two(_when.hour)}:${_two(_when.minute)}:${_two(_when.second)}';

    final small = _base.copyWith(fontSize: 11);
    final mute = _base.copyWith(color: _mute, fontSize: 11.5);
    final bold = _base.copyWith(fontWeight: FontWeight.w700);

    final receipt = PhysicalShape(
      clipper: _ZigzagClipper(),
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
        child: DefaultTextStyle(
          style: _base,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- header ----
              _center(
                widget.businessName,
                style: _base.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2),
              ),
              if (widget.tagline.isNotEmpty) _center(widget.tagline, style: mute),
              for (final line in widget.address.split('\n'))
                if (line.trim().isNotEmpty) _center(line),
              if (widget.telephone.isNotEmpty)
                _center('Tel: ${widget.telephone}'),
              if (widget.supplierTin.isNotEmpty)
                _center('TIN: ${widget.supplierTin}', style: mute),
              _dashed(),
              _center(
                widget.title,
                style: _base.copyWith(
                    fontWeight: FontWeight.w700, letterSpacing: 3),
              ),
              _dashed(),

              // ---- details ----
              _kv('Receipt No:', receiptNo),
              _kv('Date:', dateStr),
              _kv('Time:', timeStr),
              _kv('Cashier:', widget.cashier),
              if (widget.till.isNotEmpty) _kv('Till:', widget.till),
              if (widget.customerName.isNotEmpty)
                _kv('Customer:', widget.customerName),
              if (widget.customerTin.isNotEmpty)
                _kv('Cust. TIN:', widget.customerTin),
              _dashed(),

              // ---- items ----
              Container(
                padding: const EdgeInsets.only(bottom: 3),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _ink, width: 1)),
                ),
                child: _cols('ITEM', 'QTY', 'PRICE', 'TOTAL',
                    style: small.copyWith(fontWeight: FontWeight.w700)),
              ),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.description, style: bold),
                      _cols(i.note, formatQty(i.qty), _money(i.price),
                          _money(i.total),
                          style: i.note.isEmpty ? null : small),
                    ],
                  ),
                ),
              _dashed(),

              // ---- totals ----
              _tot('Items (${formatQty(units)} units)', ''),
              _tot('Subtotal', _gh(subtotal)),
              if (widget.editable)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Discount'),
                    _inlineInput(_discountCtrl),
                  ],
                )
              else
                _tot('Discount', '-${(discount)}'),
              _tot('Net Amount', _gh(net)),
              if (widget.vatRate > 0) _tot(widget.vatLabel, _gh(vat)),
              _solid(),
              _tot('GRAND TOTAL', _gh(grand),
                  style: _base.copyWith(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              _solid(),
              if (widget.editable)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Paid'),
                    _inlineInput(_paidCtrl, hint: '0.00'),
                  ],
                )
              else
                _tot('Paid', paid == null ? '' : _gh(paid)),
              _tot('Change', change),
              _dashed(),

              // ---- barcode ----
              const SizedBox(height: 4),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(4),
                  child: BarcodeWidget(
                    barcode: Barcode.qrCode(),
                    data: widget.barcodeData,
                    width: 40,
                    height: 40,
                    drawText: false,
                    color: Colors.black,
                  ),
                ),
              ),
              _dashed(),

              // ---- footer ----
              _center(widget.thankYou),
              _center(widget.policy, style: mute),
              const SizedBox(height: 4),
              _center(widget.poweredBy,
                  style: _base.copyWith(fontSize: 10, color: _mute)),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  receipt,
                  const SizedBox(height: 18),
                  _button('Print', () async {
                    await Printing.layoutPdf(
                      onLayout: (format) => ProformaInvoicePdf(
                        items: widget.items,
                        title: widget.title,
                        businessName: widget.businessName,
                        tagline: widget.tagline,
                        address: widget.address,
                        telephone: widget.telephone,
                        supplierTin: widget.supplierTin,
                        customerName: widget.customerName,
                        customerTin: widget.customerTin,
                        receiptNo: receiptNo,
                        cashier: widget.cashier,
                        till: widget.till,
                        dateTime: _when,
                        barcodeData: widget.barcodeData,
                        vatLabel: widget.vatLabel,
                        vatRate: widget.vatRate,
                        poweredBy: widget.poweredBy,
                        thankYou: widget.thankYou,
                        policy: widget.policy,
                        discount: discount,
                        amountPaid: paid,
                      ).build(format: kReceipt72),
                    );
                  }),
                  const SizedBox(height: 8),
                  _button('Close', () => Navigator.of(context).maybePop(),
                      filled: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _ZigzagClipper extends CustomClipper<Path> {
  static const double tooth = 12;

  @override
  Path getClip(Size size) {
    final n = (size.width / tooth).floor().clamp(1, 1000);
    final step = size.width / n;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - tooth / 2);
    for (var i = 0; i < n; i++) {
      final xRight = size.width - i * step;
      path.lineTo(xRight - step / 2, size.height);
      path.lineTo(xRight - step, size.height - tooth / 2);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

