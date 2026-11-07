
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/Datafeed.dart';

final NumberFormat _money = NumberFormat('#,##0.00');
final DateFormat _dbDate = DateFormat('yyyy-MM-dd');
final DateFormat _shownDate = DateFormat('dd MMM yyyy');

const double _wideBreakpoint = 800;
const List<int> _pageSizes = [10, 25, 50, 100];

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

/// Handles a real Firestore Timestamp or a map like {_seconds: .., seconds: ..}
int _millis(dynamic v) {
  if (v is Timestamp) return v.millisecondsSinceEpoch;
  if (v is Map) {
    final s = v['_seconds'] ?? v['seconds'];
    if (s is num) return s.toInt() * 1000;
  }
  return 0;
}

/// Positive = customer owes us (shown in orange), zero = settled (green),
/// negative = customer has overpaid / holds credit with us (blue).
Color _balanceColor(double balance) {
  if (balance > 0.004) return const Color(0xFFE65100);
  if (balance < -0.004) return const Color(0xFF1565C0);
  return const Color(0xFF2E7D32);
}

Color _stripe(ColorScheme cs) => cs.primary.withValues(alpha: 0.05);
Color _footerTint(ColorScheme cs) => cs.primary.withValues(alpha: 0.09);

/// Standard financial format: negatives are shown as the absolute value
/// in brackets, e.g. -1,250.50 becomes (1,250.50).
String _acct(double v) =>
    v < -0.004 ? '(${_money.format(v.abs())})' : _money.format(v);

/// Same idea inside Excel: the cell keeps its real (signed) number so it can
/// still be summed, but is displayed with brackets for negatives.
final xl.CellStyle _acctExcelStyle = xl.CellStyle(
  numberFormat: xl.NumFormat.custom(formatCode: '#,##0.00;(#,##0.00)'),
);

void _styleLastRow(xl.Sheet sheet, List<int> cols) {
  final row = sheet.maxRows - 1;
  for (final c in cols) {
    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
        .cellStyle = _acctExcelStyle;
  }
}

// ---------------------------------------------------------------------------
// SMS reminders
// ---------------------------------------------------------------------------

/// Ghana-style numbers: 0302282883 -> +233302282883
String _normalizePhone(String raw) {
  final p = raw.replaceAll(RegExp(r'[^\d+]'), '');
  if (p.startsWith('+')) return p;
  if (p.startsWith('00')) return '+${p.substring(2)}';
  if (p.startsWith('0')) return '+233${p.substring(1)}';
  if (p.startsWith('233')) return '+$p';
  return p;
}

String _defaultSmsMessage({
  required String name,
  required double amount,
  required String company,
}) =>
    'Dear $name, this is a friendly reminder that you have an outstanding '
        'balance of GHS ${_money.format(amount)} with $company. '
        'Kindly settle at your earliest convenience. Thank you.';

/// ONE place that actually sends the SMS.
/// Right now it opens the phone's SMS app with the number and message
/// filled in (works on Android / iOS). To send straight from the app through
/// an SMS gateway (Arkesel, mNotify, Twilio ...) replace this body with your
/// gateway request and return true when it succeeds.
Future<bool> _sendSms(String phone, String message) async {
  try {
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');
    return await launchUrl(uri);
  } catch (_) {
    return false;
  }
}

Future<void> _showSmsDialog(
    BuildContext context, {
      required String name,
      required String phone,
      required double amount,
      required String company,
    }) {
  return showDialog(
    context: context,
    builder: (_) => _SmsDialog(
      name: name,
      phone: phone,
      amount: amount,
      company: company,
    ),
  );
}

class _SmsDialog extends StatefulWidget {
  final String name;
  final String phone;
  final String company;
  final double amount;

  const _SmsDialog({
    required this.name,
    required this.phone,
    required this.amount,
    required this.company,
  });

  @override
  State<_SmsDialog> createState() => _SmsDialogState();
}

class _SmsDialogState extends State<_SmsDialog> {
  late final TextEditingController _phone =
  TextEditingController(text: widget.phone);
  late final TextEditingController _message = TextEditingController(
    text: _defaultSmsMessage(
      name: widget.name,
      amount: widget.amount,
      company: widget.company,
    ),
  );
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  int get _segments {
    final n = _message.text.length;
    if (n == 0) return 0;
    return n <= 160 ? 1 : (n / 153).ceil();
  }

  Future<void> _send() async {
    final number = _normalizePhone(_phone.text);
    final text = _message.text.trim();

    if (number.replaceAll('+', '').length < 9) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    if (text.isEmpty) {
      setState(() => _error = 'Message cannot be empty');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final ok = await _sendSms(number, text);
    if (ok) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('SMS ready for $number'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the SMS app. The message was copied to the clipboard.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('SMS reminder'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Outstanding: GHS ${_money.format(widget.amount)}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _message,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Message (you can edit this)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_message.text.length} characters - $_segments SMS',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending
              ? null
              : () => setState(() {
            _message.text = _defaultSmsMessage(
              name: widget.name,
              amount: widget.amount,
              company: widget.company,
            );
          }),
          child: const Text('Reset message'),
        ),
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Send'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Statement model + calculation
// ---------------------------------------------------------------------------

class DebtorLine {
  final String date;
  final String description;
  final double debit; // credit sales (customer owes more)
  final double credit; // payments / returns (customer owes less)
  final int created;
  double balance = 0;

  DebtorLine({
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.created,
  });
}

class DebtorStatement {
  final double opening;
  final List<DebtorLine> lines;
  final double totalDebit;
  final double totalCredit;
  final double closing;

  DebtorStatement({
    required this.opening,
    required this.lines,
    required this.totalDebit,
    required this.totalCredit,
    required this.closing,
  });
}

/// Loads every accounts_receivable ledger line for one customer.
/// Filtering on account == accounts_receivable avoids counting the sales /
/// cash legs of the same transaction. `debtorId` is queried as well in case
/// your payment entries use it instead of `customerId`.
Future<List<DebtorLine>> _fetchDebtorLines(
    Datafeed df,
    String customerId,
    ) async {
  final base = df.db
      .collection('ledgers')
      .where('companyId', isEqualTo: df.companyid)
      .where('account', isEqualTo: 'accounts_receivable');

  final results = await Future.wait([
    base.where('customerId', isEqualTo: customerId).get(),
    base.where('debtorId', isEqualTo: customerId).get(),
  ]);

  final seen = <String>{};
  final lines = <DebtorLine>[];
  for (final snap in results) {
    for (final doc in snap.docs) {
      if (!seen.add(doc.id)) continue;
      final d = doc.data();
      final amount = _num(d['amount']);
      final isDebit = d['type']?.toString().toLowerCase() == 'debit';
      lines.add(
        DebtorLine(
          date: d['date']?.toString() ?? '',
          description: d['description']?.toString() ?? '',
          debit: isDebit ? amount : 0,
          credit: isDebit ? 0 : amount,
          created: _millis(d['createdAt']),
        ),
      );
    }
  }
  return lines;
}

DebtorStatement _buildStatement(
    List<DebtorLine> all,
    DateTime? from,
    DateTime? to,
    ) {
  final fromStr = from == null ? null : _dbDate.format(from);
  final toStr = to == null ? null : _dbDate.format(to);

  // Opening balance = everything before the start date
  double opening = 0;
  if (fromStr != null) {
    for (final l in all) {
      if (l.date.compareTo(fromStr) < 0) opening += l.debit - l.credit;
    }
  }

  final inRange = all.where((l) {
    if (fromStr != null && l.date.compareTo(fromStr) < 0) return false;
    if (toStr != null && l.date.compareTo(toStr) > 0) return false;
    return true;
  }).toList()
    ..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.created.compareTo(b.created);
    });

  double running = opening, td = 0, tc = 0;
  for (final l in inRange) {
    running += l.debit - l.credit;
    l.balance = running;
    td += l.debit;
    tc += l.credit;
  }

  return DebtorStatement(
    opening: opening,
    lines: inRange,
    totalDebit: td,
    totalCredit: tc,
    closing: running,
  );
}

// ---------------------------------------------------------------------------
// Shared UI pieces
// ---------------------------------------------------------------------------

class _BalanceChip extends StatelessWidget {
  final double balance;
  const _BalanceChip(this.balance);

  @override
  Widget build(BuildContext context) {
    final c = _balanceColor(balance);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'GHS ${_acct(balance)}',
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int total;
  final int page; // zero based
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  const _PaginationBar({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pages = total == 0 ? 1 : (total / pageSize).ceil();
    final start = total == 0 ? 0 : page * pageSize + 1;
    final end = total == 0 ? 0 : ((page + 1) * pageSize).clamp(0, total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rows per page',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: pageSize,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(12),
                items: _pageSizes
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onPageSizeChanged(v);
                },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$start-$end of $total',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'First page',
                onPressed: page > 0 ? () => onPageChanged(0) : null,
                icon: const Icon(Icons.first_page_rounded),
              ),
              IconButton(
                tooltip: 'Previous',
                onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${page + 1} / $pages',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed:
                page < pages - 1 ? () => onPageChanged(page + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              IconButton(
                tooltip: 'Last page',
                onPressed:
                page < pages - 1 ? () => onPageChanged(pages - 1) : null,
                icon: const Icon(Icons.last_page_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactRangeDialog extends StatefulWidget {
  final DateTimeRange? initial;
  const _CompactRangeDialog({this.initial});

  @override
  State<_CompactRangeDialog> createState() => _CompactRangeDialogState();
}

class _CompactRangeDialogState extends State<_CompactRangeDialog> {
  late DateTime _from;
  late DateTime _to;
  bool _editingFrom = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = widget.initial?.start ?? DateTime(now.year, now.month, 1);
    _to = widget.initial?.end ?? DateTime(now.year, now.month, now.day);
    if (_to.isBefore(_from)) _to = _from;
  }

  Widget _tab(String label, DateTime value, bool isFrom, ColorScheme cs) {
    final active = _editingFrom == isFrom;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _editingFrom = isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? cs.primary.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? cs.primary : cs.outlineVariant,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              _shownDate.format(value),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select period',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _tab('From', _from, true, cs)),
                  const SizedBox(width: 10),
                  Expanded(child: _tab('To', _to, false, cs)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 340,
                child: CalendarDatePicker(
                  key: ValueKey(_editingFrom),
                  initialDate: _editingFrom ? _from : _to,
                  firstDate: _editingFrom ? DateTime(2020) : _from,
                  lastDate: DateTime(2100),
                  onDateChanged: (d) {
                    setState(() {
                      if (_editingFrom) {
                        _from = d;
                        if (_to.isBefore(d)) _to = d;
                        _editingFrom = false; // jump to the end date
                      } else {
                        _to = d;
                      }
                    });
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      DateTimeRange(start: _from, end: _to),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// PAGE 1: Debtor list (from the `customers` collection)
// ===========================================================================

class _DebtorRow {
  final String id;
  final String name;
  final String contact;
  final String branch;
  final String type;
  final double balance; // customers.creditBalance = amount the customer owes

  _DebtorRow(
      this.id,
      this.name,
      this.contact,
      this.branch,
      this.type,
      this.balance,
      );
}

class DebtorReportPage extends StatefulWidget {
  const DebtorReportPage({super.key});

  @override
  State<DebtorReportPage> createState() => _DebtorReportPageState();
}

class _DebtorReportPageState extends State<DebtorReportPage> {
  String _query = '';
  bool _onlyOutstanding = true; // hide customers who owe nothing
  int _page = 0;
  int _pageSize = 10;

  /// Rows currently matching the filters (all pages). Used by PDF / Excel.
  List<_DebtorRow> _exportRows = [];

  void _remind(_DebtorRow r) {
    _showSmsDialog(
      context,
      name: r.name,
      phone: r.contact,
      amount: r.balance,
      company: context.read<Datafeed>().company,
    );
  }

  void _open(_DebtorRow r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DebtorStatementPage(
          customerId: r.id,
          customerName: r.name,
          contact: r.contact,
        ),
      ),
    );
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // ---------------------------- PDF ----------------------------------------

  Future<void> _printDebtorsPdf() async {
    final rows = _exportRows;
    if (rows.isEmpty) {
      _toast('Nothing to export', error: true);
      return;
    }
    try {
      final total = rows.fold<double>(0, (s, r) => s + r.balance);

      final data = <List<String>>[
        for (final r in rows)
          [r.name, r.contact, r.branch, r.type, _acct(r.balance)],
        ['TOTAL (${rows.length} debtors)', '', '', '', _acct(total)],
      ];

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Debtor Report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 12),
            ],
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (_) => [
            pw.TableHelper.fromTextArray(
              headers: ['Customer', 'Contact', 'Branch', 'Type', 'Outstanding'],
              data: data,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2.5),
              },
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
              },
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),
          ],
        ),
      );

      final Uint8List bytes = await doc.save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'debtor_report.pdf',
      );
    } catch (e) {
      _toast('PDF failed: $e', error: true);
    }
  }

  // ---------------------------- Excel --------------------------------------

  Future<void> _exportDebtorsExcel() async {
    final rows = _exportRows;
    if (rows.isEmpty) {
      _toast('Nothing to export', error: true);
      return;
    }
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Debtors'];
      excel.setDefaultSheet('Debtors');
      excel.delete('Sheet1');

      xl.CellValue t(String v) => xl.TextCellValue(v);
      xl.CellValue n(double v) => xl.DoubleCellValue(v);

      sheet.appendRow([
        t('Customer'),
        t('Contact'),
        t('Branch'),
        t('Type'),
        t('Outstanding'),
      ]);

      double total = 0;
      for (final r in rows) {
        total += r.balance;
        sheet.appendRow([
          t(r.name),
          t(r.contact),
          t(r.branch),
          t(r.type),
          n(r.balance),
        ]);
        _styleLastRow(sheet, [4]);
      }
      sheet.appendRow([
        t('TOTAL (${rows.length} debtors)'),
        t(''),
        t(''),
        t(''),
        n(total),
      ]);
      _styleLastRow(sheet, [4]);

      final out = excel.encode();
      if (out == null) throw 'Could not build the Excel file';

      await FileSaver.instance.saveFile(
        name:
        'debtor_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
        bytes: Uint8List.fromList(out),
        fileExtension: 'xlsx', // use `ext:` on file_saver 0.2.x
        mimeType: MimeType.microsoftExcel,
      );
      _toast('Excel file saved');
    } catch (e) {
      _toast('Excel export failed: $e', error: true);
    }
  }

  // ---------------------------- UI -----------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final df = context.read<Datafeed>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Debtor Report'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        actions: [
          IconButton(
            tooltip: 'PDF / Print',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _printDebtorsPdf,
          ),
          IconButton(
            tooltip: 'Download Excel',
            icon: const Icon(Icons.table_chart_rounded),
            onPressed: _exportDebtorsExcel,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: df.db
            .collection('customers')
            .where('companyid', isEqualTo: df.companyid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snap.data!.docs
              .where((d) => (d.data()['deletedby']?.toString() ?? '').isEmpty)
              .map((d) {
            final m = d.data();
            return _DebtorRow(
              m['id']?.toString() ?? d.id,
              m['name']?.toString() ?? 'Unknown',
              m['contact']?.toString() ?? '',
              m['branchname']?.toString() ?? '',
              m['customertype']?.toString() ?? '',
              _num(m['creditBalance']),
            );
          }).toList()
            ..sort(
                  (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

          final q = _query.toLowerCase();
          final rows = all.where((r) {
            if (_onlyOutstanding && r.balance.abs() < 0.005) return false;
            return r.name.toLowerCase().contains(q) ||
                r.contact.toLowerCase().contains(q);
          }).toList();
          _exportRows = rows; // used by the app bar PDF / Excel buttons

          // Total covers every debtor matching the filters, not only this page
          final totalBalance = rows.fold<double>(0, (s, r) => s + r.balance);

          // ---- pagination ----
          final pages = (rows.length / _pageSize).ceil();
          final page =
          pages == 0 ? 0 : (_page > pages - 1 ? pages - 1 : _page);
          final pageRows =
          rows.skip(page * _pageSize).take(_pageSize).toList();
          final pager = _PaginationBar(
            total: rows.length,
            page: page,
            pageSize: _pageSize,
            onPageChanged: (p) => setState(() => _page = p),
            onPageSizeChanged: (s) => setState(() {
              _pageSize = s;
              _page = 0;
            }),
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() {
                            _query = v;
                            _page = 0;
                          }),
                          decoration: InputDecoration(
                            hintText: 'Search customer or contact',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: cs.surface,
                            contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: cs.outlineVariant),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('Owing only'),
                        selected: _onlyOutstanding,
                        onSelected: (v) => setState(() {
                          _onlyOutstanding = v;
                          _page = 0;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) => c.maxWidth >= _wideBreakpoint
                        ? _wideTable(
                      pageRows,
                      cs,
                      pager,
                      rows.length,
                      totalBalance,
                    )
                        : _mobileList(
                      pageRows,
                      cs,
                      pager,
                      rows.length,
                      totalBalance,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _avatar(_DebtorRow r, ColorScheme cs) => CircleAvatar(
    backgroundColor: cs.primary.withValues(alpha: 0.12),
    child: Text(
      r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
      style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
    ),
  );

  Widget _wideRowTile(_DebtorRow r, int index, ColorScheme cs) {
    return Material(
      color: index.isOdd ? _stripe(cs) : Colors.transparent,
      child: InkWell(
        onTap: () => _open(r),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    _avatar(r, cs),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (r.contact.isNotEmpty)
                            Text(
                              r.contact,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(r.branch, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 2,
                child: Text(r.type, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _BalanceChip(r.balance),
                ),
              ),
              SizedBox(
                width: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Send SMS reminder',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.sms_outlined, size: 20),
                      color: cs.primary,
                      onPressed:
                      r.balance > 0.004 ? () => _remind(r) : null,
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
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

  Widget _wideTable(
      List<_DebtorRow> rows,
      ColorScheme cs,
      Widget pager,
      int totalCount,
      double totalBalance,
      ) {
    Widget head(String t, {int flex = 2, TextAlign a = TextAlign.left}) =>
        Expanded(
          flex: flex,
          child: Text(
            t,
            textAlign: a,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        );

    const bold = TextStyle(fontWeight: FontWeight.w700);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            color: cs.surfaceContainerHighest,
            child: Row(
              children: [
                head('Customer', flex: 4),
                head('Branch'),
                head('Type'),
                head('Outstanding', a: TextAlign.right),
                const SizedBox(width: 72),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No debtors found'),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            _wideRowTile(rows[i], i, cs),
            Divider(height: 1, color: cs.outlineVariant),
          ],

          // ---------------- Totals footer ----------------
          Container(
            color: _footerTint(cs),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  flex: 8,
                  child: Text('Total ($totalCount debtors)', style: bold),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _BalanceChip(totalBalance),
                  ),
                ),
                const SizedBox(width: 72),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          pager,
        ],
      ),
    );
  }

  Widget _mobileList(
      List<_DebtorRow> rows,
      ColorScheme cs,
      Widget pager,
      int totalCount,
      double totalBalance,
      ) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No debtors found')),
      );
    }

    Widget miniText(String label, String v) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          Text(
            v.isEmpty ? '-' : v,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _open(rows[i]),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: i.isOdd ? _stripe(cs) : cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _avatar(rows[i], cs),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            rows[i].name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _BalanceChip(rows[i].balance),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        miniText('Contact', rows[i].contact),
                        miniText('Branch', rows[i].branch),
                        IconButton(
                          tooltip: 'Send SMS reminder',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.sms_outlined),
                          color: cs.primary,
                          onPressed: rows[i].balance > 0.004
                              ? () => _remind(rows[i])
                              : null,
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ---------------- Totals footer ----------------
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _footerTint(cs),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total ($totalCount debtors)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              _BalanceChip(totalBalance),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: pager,
        ),
      ],
    );
  }
}

// ===========================================================================
// PAGE 2: Debtor statement (from the `ledgers` collection)
// ===========================================================================

class DebtorStatementPage extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String contact;

  const DebtorStatementPage({
    super.key,
    required this.customerId,
    required this.customerName,
    this.contact = '',
  });

  @override
  State<DebtorStatementPage> createState() => _DebtorStatementPageState();
}

class _DebtorStatementPageState extends State<DebtorStatementPage> {
  List<DebtorLine> _all = [];
  bool _loading = true;
  String? _error;
  DateTimeRange? _range;
  int _page = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final df = context.read<Datafeed>();
      final lines = await _fetchDebtorLines(df, widget.customerId);
      if (!mounted) return;
      setState(() {
        _all = lines;
        _page = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => _CompactRangeDialog(initial: _range),
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _page = 0;
      });
    }
  }

  /// Overall amount owed (all time), regardless of the selected period.
  void _remind() {
    final owed = _all.fold<double>(0, (s, l) => s + l.debit - l.credit);
    if (owed <= 0.004) {
      _toast('This customer has no outstanding balance', error: true);
      return;
    }
    _showSmsDialog(
      context,
      name: widget.customerName,
      phone: widget.contact,
      amount: owed,
      company: context.read<Datafeed>().company,
    );
  }

  DebtorStatement get _statement =>
      _buildStatement(_all, _range?.start, _range?.end);

  String get _periodLabel => _range == null
      ? 'All dates'
      : '${_shownDate.format(_range!.start)} - ${_shownDate.format(_range!.end)}';

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // ---------------------------- PDF ----------------------------------------
  // PDF and Excel always export every line in the selected period,
  // not just the page currently shown on screen.

  Future<void> _printPdf(DebtorStatement s) async {
    try {
      final doc = pw.Document();

      final rows = <List<String>>[
        ['', 'Opening Balance', '', '', _acct(s.opening)],
        for (final l in s.lines)
          [
            l.date,
            l.description,
            l.debit == 0 ? '' : _money.format(l.debit),
            l.credit == 0 ? '' : _money.format(l.credit),
            _acct(l.balance),
          ],
        [
          '',
          'Total / Current Balance',
          _money.format(s.totalDebit),
          _money.format(s.totalCredit),
          _acct(s.closing),
        ],
      ];

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Debtor Statement',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                widget.customerName,
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.Text(
                'Period: $_periodLabel',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 12),
            ],
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          build: (_) => [
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Description', 'Debit', 'Credit', 'Balance'],
              data: rows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(58),
                1: const pw.FlexColumnWidth(5),
                2: const pw.FixedColumnWidth(58),
                3: const pw.FixedColumnWidth(58),
                4: const pw.FixedColumnWidth(66),
              },
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),
          ],
        ),
      );

      final Uint8List bytes = await doc.save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${widget.customerName}_statement.pdf',
      );
    } catch (e) {
      _toast('PDF failed: $e', error: true);
    }
  }

  // ---------------------------- Excel --------------------------------------

  Future<void> _exportExcel(DebtorStatement s) async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Statement'];
      excel.setDefaultSheet('Statement');
      excel.delete('Sheet1');

      xl.CellValue t(String v) => xl.TextCellValue(v);
      xl.CellValue n(double v) => xl.DoubleCellValue(v);

      sheet.appendRow([t('Debtor Statement')]);
      sheet.appendRow([t('Customer'), t(widget.customerName)]);
      sheet.appendRow([t('Period'), t(_periodLabel)]);
      sheet.appendRow([]);
      sheet.appendRow([
        t('Date'),
        t('Description'),
        t('Debit'),
        t('Credit'),
        t('Balance'),
      ]);
      sheet.appendRow([t(''), t('Opening Balance'), t(''), t(''), n(s.opening)]);
      _styleLastRow(sheet, [4]);
      for (final l in s.lines) {
        sheet.appendRow([
          t(l.date),
          t(l.description),
          n(l.debit),
          n(l.credit),
          n(l.balance),
        ]);
        _styleLastRow(sheet, [4]);
      }
      sheet.appendRow([
        t(''),
        t('Total / Current Balance'),
        n(s.totalDebit),
        n(s.totalCredit),
        n(s.closing),
      ]);
      _styleLastRow(sheet, [4]);

      final out = excel.encode();
      if (out == null) throw 'Could not build the Excel file';

      await FileSaver.instance.saveFile(
        name: '${widget.customerName}_statement',
        bytes: Uint8List.fromList(out),
        fileExtension: 'xlsx', // use `ext:` on file_saver 0.2.x
        mimeType: MimeType.microsoftExcel,
      );
      _toast('Excel file saved');
    } catch (e) {
      _toast('Excel export failed: $e', error: true);
    }
  }

  // ---------------------------- UI -----------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ready = !_loading && _error == null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.customerName),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        actions: [
          IconButton(
            tooltip: 'Send SMS reminder',
            icon: const Icon(Icons.sms_outlined),
            onPressed: ready ? _remind : null,
          ),
          IconButton(
            tooltip: 'Select period',
            icon: Icon(
              Icons.date_range_rounded,
              color: _range != null ? cs.primary : null,
            ),
            onPressed: ready ? _pickRange : null,
          ),
          IconButton(
            tooltip: 'PDF / Print',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: ready ? () => _printPdf(_statement) : null,
          ),
          IconButton(
            tooltip: 'Download Excel',
            icon: const Icon(Icons.table_chart_rounded),
            onPressed: ready ? () => _exportExcel(_statement) : null,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _content(cs),
    );
  }

  Widget _content(ColorScheme cs) {
    final s = _statement;

    // ---- pagination over the lines in the selected period ----
    final total = s.lines.length;
    final pages = (total / _pageSize).ceil();
    final page = pages == 0 ? 0 : (_page > pages - 1 ? pages - 1 : _page);
    final pageLines = s.lines.skip(page * _pageSize).take(_pageSize).toList();
    final pager = _PaginationBar(
      total: total,
      page: page,
      pageSize: _pageSize,
      onPageChanged: (p) => setState(() => _page = p),
      onPageSizeChanged: (v) => setState(() {
        _pageSize = v;
        _page = 0;
      }),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period label (the picker itself is in the app bar)
            Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Period: $_periodLabel',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
                if (_range != null)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _range = null;
                      _page = 0;
                    }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, c) => c.maxWidth >= _wideBreakpoint
                  ? _wideStatement(s, cs, pageLines, pager)
                  : _mobileStatement(s, cs, pageLines, pager),
            ),
            const SizedBox(height: 8),
            Text(
              'Balance = Debit - Credit. Debit is a credit sale, Credit is a payment received. '
                  'A positive balance is the amount the customer owes. '
                  'PDF and Excel include every transaction in the selected period.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ----- Widescreen: table layout -----

  Widget _wideStatement(
      DebtorStatement s,
      ColorScheme cs,
      List<DebtorLine> pageLines,
      Widget pager,
      ) {
    Widget cell(String t,
        {double? w,
          int flex = 0,
          TextAlign a = TextAlign.right,
          TextStyle? style}) =>
        flex > 0
            ? Expanded(
          flex: flex,
          child: Text(t, textAlign: a, style: style),
        )
            : SizedBox(
          width: w,
          child: Text(t, textAlign: a, style: style),
        );

    final headStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: cs.onSurfaceVariant,
      fontSize: 13,
    );
    const bold = TextStyle(fontWeight: FontWeight.w700);

    Widget row({
      required String date,
      required String desc,
      required String debit,
      required String credit,
      required String balance,
      Color? bg,
      TextStyle? style,
      Color? balanceColor,
    }) =>
        Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell(date, w: 100, a: TextAlign.left, style: style),
              cell(desc, flex: 1, a: TextAlign.left, style: style),
              const SizedBox(width: 16),
              cell(debit, w: 110, style: style),
              cell(credit, w: 110, style: style),
              cell(
                balance,
                w: 130,
                style: (style ?? const TextStyle()).copyWith(
                  color: balanceColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

    Widget lineRow(DebtorLine l, int i) => row(
      date: l.date,
      desc: l.description,
      debit: l.debit == 0 ? '' : _money.format(l.debit),
      credit: l.credit == 0 ? '' : _money.format(l.credit),
      balance: _acct(l.balance),
      balanceColor: _balanceColor(l.balance),
      bg: i.isOdd ? _stripe(cs) : null,
    );

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          row(
            date: 'Date',
            desc: 'Description',
            debit: 'Debit',
            credit: 'Credit',
            balance: 'Balance',
            bg: cs.surfaceContainerHighest,
            style: headStyle,
          ),
          // Opening balance stays at the top on every page
          row(
            date: '',
            desc: 'Opening Balance',
            debit: '',
            credit: '',
            balance: _acct(s.opening),
            bg: _footerTint(cs),
            style: bold,
            balanceColor: _balanceColor(s.opening),
          ),
          if (s.lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No transactions in this period'),
            ),
          for (var i = 0; i < pageLines.length; i++) ...[
            Divider(height: 1, color: cs.outlineVariant),
            lineRow(pageLines[i], i),
          ],

          // ---------------- Totals footer (always visible) ----------------
          Divider(height: 1, color: cs.outlineVariant),
          row(
            date: '',
            desc: 'Total / Current Balance',
            debit: _money.format(s.totalDebit),
            credit: _money.format(s.totalCredit),
            balance: _acct(s.closing),
            bg: _footerTint(cs),
            style: bold,
            balanceColor: _balanceColor(s.closing),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          pager,
        ],
      ),
    );
  }

  // ----- Mobile: card layout -----

  Widget _mobileStatement(
      DebtorStatement s,
      ColorScheme cs,
      List<DebtorLine> pageLines,
      Widget pager,
      ) {
    Widget card(Widget child, {Color? color}) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );

    Widget figure(String label, double v) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          Text(
            'GHS ${_acct(v)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    return Column(
      children: [
        // Opening balance stays at the top on every page
        card(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Opening Balance',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _BalanceChip(s.opening),
            ],
          ),
          color: _footerTint(cs),
        ),
        if (s.lines.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No transactions in this period'),
          ),
        for (var i = 0; i < pageLines.length; i++)
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pageLines[i].date,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      pageLines[i].debit > 0
                          ? '+ GHS ${_money.format(pageLines[i].debit)}'
                          : '- GHS ${_money.format(pageLines[i].credit)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: pageLines[i].debit > 0
                            ? const Color(0xFFE65100)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pageLines[i].description,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Balance',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'GHS ${_acct(pageLines[i].balance)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _balanceColor(pageLines[i].balance),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            color: i.isOdd ? _stripe(cs) : null,
          ),

        // ---------------- Totals footer ----------------
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  figure('Total Debit', s.totalDebit),
                  figure('Total Credit', s.totalCredit),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Current Balance',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  _BalanceChip(s.closing),
                ],
              ),
            ],
          ),
          color: _footerTint(cs),
        ),
        card(pager),
      ],
    );
  }
}