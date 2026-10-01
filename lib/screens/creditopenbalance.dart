import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../models/creditorbalanceModel.dart';
import '../models/suppliermodel.dart';
import 'creditopenbalancelist.dart';

class _C {
  static Color bg(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color card(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color header(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.light
        ? theme.colorScheme.surface
        : theme.colorScheme.primary;
  }

  static Color divider(BuildContext context) =>
      Theme.of(context).colorScheme.outline;
  static const primary = Color(0xFF3A6FF8);
  static Color field(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
  static Color negative(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? const Color(0xFFB91C1C)
      : const Color(0xFFFF5252);
  static Color textPri(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color textSub(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  static Color textMuted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
}

class creditOpenBalScreen extends StatefulWidget {
  final String? docId;
  final CreditorBalance? item;
  const creditOpenBalScreen({Key? key, this.docId, this.item})
    : super(key: key);

  @override
  State<creditOpenBalScreen> createState() => _creditOpenBalScreenState();
}

class _creditOpenBalScreenState extends State<creditOpenBalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _creditorCtrl = TextEditingController();

  final db = FirebaseFirestore.instance;

  DateTime? _selectedDate;
  String? _selectedCreditorId;
  String? _selectedCreditorName;
  bool _saving = false;

  bool get _isEdit => widget.docId != null;

  void showMessage(Color color, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final datafeed = context.read<Datafeed>();
      await datafeed.fetchSuppliers();
      if (!mounted) return;

      final item = widget.item;
      if (item != null) {
        setState(() {
          _selectedCreditorId = item.creditorId;
          _selectedCreditorName = item.creditorName;
          _creditorCtrl.text = item.creditorName;
          _amountCtrl.text = item.amount.toString();
          _selectedDate = item.date;
          _dateCtrl.text = item.date != null
              ? DateFormat('yyyy-MM-dd').format(item.date!)
              : '';
        });
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _creditorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCreditor(Datafeed datafeed) async {
    final picked = await showDialog<Supplier>(
      context: context,
      builder: (_) => _CreditorPickerDialog(
        suppliers: datafeed.suppliers,
        selectedId: _selectedCreditorId,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedCreditorId = picked.id;
        _selectedCreditorName = picked.supplier;
        _creditorCtrl.text = picked.supplier;
      });
      _formKey.currentState?.validate();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: _C.primary, surface: _C.card(ctx)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _reset() {
    setState(() {
      _selectedCreditorId = null;
      _selectedCreditorName = null;
      _selectedDate = null;
    });
    _creditorCtrl.clear();
    _amountCtrl.clear();
    _dateCtrl.clear();
    _formKey.currentState?.reset();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final creditorId = _selectedCreditorId;
    final creditorName = _selectedCreditorName;
    if (creditorId == null || creditorId.isEmpty || creditorName == null) {
      showMessage(Colors.red, 'Please select creditor');
      return;
    }
    if (_selectedDate == null) {
      showMessage(Colors.red, 'Please select date');
      return;
    }

    setState(() => _saving = true);
    final datafeed = context.read<Datafeed>();

    try {
      String sanitize(String input) => input
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');

      final newAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      final docId =
          widget.docId ??
          '${sanitize(creditorId)}_${DateTime.now().millisecondsSinceEpoch}';

      final balanceDoc = db.collection('creditor_balances').doc(docId);
      final supplierDoc = db.collection('suppliers').doc(creditorId);

      final now = DateTime.now();
      final day = DateFormat('EEEE').format(now);
      final year = now.year.toString();
      final month = '${now.year}.${now.month}';
      final weekNumber =
          ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;
      final week = '${now.year}.$weekNumber';
      final dateymd = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final item = CreditorBalance(
        creditorId: creditorId,
        amount: newAmount,
        date: _selectedDate,
        companyid: datafeed.companyid,
        company: datafeed.company,
        companyemail: datafeed.companyemail,
        staff: datafeed.staff,
        branchid: datafeed.branchid,
        branchname: datafeed.branch,
        id: docId,
        datecreated: Timestamp.fromDate(now),
        updatedby: _isEdit ? datafeed.staff : '',
        updatedat: _isEdit ? now : null,
        creditorName: creditorName,
        paymentMode: '',
        transactionRef:
            '${sanitize(creditorName)}_${now.millisecondsSinceEpoch}',
        type: 'creditor opening balance ',
        dateymd: dateymd,
        day: day,
        week: week,
        month: month,
        yearr: year,
      );

      await db.runTransaction((txn) async {
        double creditDelta;
        if (_isEdit) {
          final snap = await txn.get(balanceDoc);
          final liveOld = snap.exists
              ? ((snap.data()?['amount'] ?? 0) as num).toDouble()
              : 0.0;
          creditDelta = newAmount - liveOld;
        } else {
          creditDelta = newAmount;
        }

        txn.set(balanceDoc, item.toMap());
        if (creditDelta != 0) {
          txn.update(supplierDoc, {
            'creditaccount': FieldValue.increment(creditDelta),
          });
        }
      });

      // keep the provider's list in sync so the list page needs no reload
      final list = datafeed.creditoropenbal;
      final idx = list.indexWhere((c) => c.id == docId);
      if (idx != -1) {
        list[idx] = item;
      } else {
        list.insert(0, item);
      }
      datafeed.notifyListeners();

      if (!mounted) return;

      showMessage(
        Colors.green,
        _isEdit ? 'Updated successfully' : 'Saved successfully',
      );

      if (_isEdit) {
        Navigator.pop(context);
      } else {
        _reset();
      }
    } catch (e) {
      showMessage(Colors.red, 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Same field style as the other setup screens (Payment Name / Duration)
  InputDecoration _inputDecoration({
    required String label,
    IconData? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      prefixIcon: prefix != null
          ? Icon(prefix, color: Theme.of(context).colorScheme.onSurfaceVariant)
          : null,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _C.negative(context)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _C.negative(context), width: 1.5),
      ),
      fillColor: _C.field(context),
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, _) {
        return Scaffold(
          backgroundColor: _C.bg(context),
          appBar: AppBar(
            backgroundColor: _C.header(context),
            foregroundColor: _C.textPri(context),
            elevation: 2,
            titleSpacing: 0,
            leading: BackButton(color: _C.textPri(context)),
            title: Text(
              _isEdit ? 'Edit Opening Balance' : 'Creditor Opening Balance',
              style: TextStyle(
                color: _C.textPri(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.home, size: 25),
                tooltip: 'Home',
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false),
              ),
              if (MediaQuery.of(context).size.width >= 800)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _C.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _C.primary.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        datafeed.company,
                        style: const TextStyle(
                          color: _C.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _C.divider(context)),
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _C.card(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Creditor (searchable picker)
                          TextFormField(
                            controller: _creditorCtrl,
                            readOnly: true,
                            onTap: () => _pickCreditor(datafeed),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: _inputDecoration(
                              label: 'Creditor',
                              suffix: Icon(
                                Icons.arrow_drop_down,
                                color: _C.textSub(context),
                              ),
                            ),
                            validator: (_) => _selectedCreditorId == null
                                ? 'Select creditor'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          // Amount
                          TextFormField(
                            controller: _amountCtrl,
                            cursorColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: _inputDecoration(label: 'Amount'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter amount';
                              }
                              final n = double.tryParse(v.trim());
                              if (n == null) return 'Enter a valid number';
                              if (n <= 0)
                                return 'Amount must be greater than 0';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Date
                          TextFormField(
                            controller: _dateCtrl,
                            readOnly: true,
                            onTap: _pickDate,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: _inputDecoration(
                              label: 'Date',
                              suffix: Icon(
                                Icons.calendar_today,
                                color: _C.textSub(context),
                                size: 20,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Select date'
                                : null,
                          ),
                          const SizedBox(height: 26),

                          // Buttons
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              SizedBox(
                                width: 200,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _C.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _saving ? null : _save,
                                  child: _saving
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _isEdit ? 'Update' : 'Add',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(
                                width: 200,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _C.card(context),
                                    foregroundColor: _C.textPri(context),
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: _C.divider(context),
                                      ),
                                    ),
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const creditOpenBalViewPage(),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.view_list,
                                    color: _C.textPri(context),
                                    size: 18,
                                  ),
                                  label: Text(
                                    'View',
                                    style: TextStyle(
                                      color: _C.textPri(context),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Searchable creditor picker
class _CreditorPickerDialog extends StatefulWidget {
  final List<Supplier> suppliers;
  final String? selectedId;
  const _CreditorPickerDialog({required this.suppliers, this.selectedId});

  @override
  State<_CreditorPickerDialog> createState() => _CreditorPickerDialogState();
}

class _CreditorPickerDialogState extends State<_CreditorPickerDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _phone(Supplier s) => (s.contact ?? '').toString().trim();

  List<Supplier> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.suppliers;
    final qDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
    return widget.suppliers.where((s) {
      final name = s.supplier.toLowerCase();
      final phone = _phone(s).toLowerCase();
      final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      return name.contains(q) ||
          phone.contains(q) ||
          (qDigits.isNotEmpty && phoneDigits.contains(qDigits));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final height = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: height * 0.75),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: _C.card(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: _C.header(context),
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'SELECT CREDITOR',
                          style: TextStyle(
                            color: _C.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: _C.textSub(context),
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: _C.divider(context)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search name or phone…',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: _C.field(context),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${list.length} creditor${list.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: _C.textMuted(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Container(height: 1, color: _C.divider(context)),
                Flexible(
                  child: list.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No creditor found',
                            style: TextStyle(
                              color: _C.textSub(context),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final s = list[i];
                            final phone = _phone(s);
                            final selected = s.id == widget.selectedId;
                            return InkWell(
                              onTap: () => Navigator.pop(context, s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? _C.primary.withOpacity(0.15)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _C.divider(context),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.supplier,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: selected
                                                  ? _C.primary
                                                  : _C.textPri(context),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (phone.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              phone,
                                              style: TextStyle(
                                                color: _C.textSub(context),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check,
                                        color: _C.primary,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
