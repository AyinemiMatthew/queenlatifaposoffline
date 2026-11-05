import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/discountmanager.dart';
import '../providers/Datafeed.dart';

import '../widgets/salespagewidgets/decorateinput.dart';
import '../widgets/salespagewidgets/snackmsg.dart';
import 'discounmangerpage.dart';

class DiscountCodeListPage extends StatefulWidget {
  const DiscountCodeListPage({super.key});

  @override
  State<DiscountCodeListPage> createState() => _DiscountCodeListPageState();
}

class _DiscountCodeListPageState extends State<DiscountCodeListPage> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _textColor => _colors.onSurface;
  Color get _mutedTextColor =>
      _isLightTheme ? _colors.onSurfaceVariant : Colors.white70;
  Color get _borderColor => _isLightTheme ? _colors.outline : Colors.white24;
  Color get _usedTextColor =>
      _isLightTheme ? _colors.onSurfaceVariant : Colors.white38;
  Color get _activeStatusColor =>
      _isLightTheme ? Colors.green.shade700 : Colors.greenAccent;
  Color get _inactiveStatusColor =>
      _isLightTheme ? Colors.deepOrange.shade700 : Colors.orangeAccent;

  String _filter = 'all';
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<Datafeed>().fetchDiscountCodes());
  }

  Future<void> _edit(DiscountCodeModel dc) async {
    final amtCtrl = TextEditingController(text: dc.amount.toStringAsFixed(2));

    DateTime? newExpiry = dc.expiresAt?.toDate();
    bool newActive = dc.isActive;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          title: Text('Edit  ${dc.code}', style: TextStyle(color: _textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Amount
              TextFormField(
                controller: amtCtrl,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: decorationInput(
                  context,
                  'Amount (GHS)',
                  prefix: 'GHS  ',
                ),
              ),
              const SizedBox(height: 14),

              // Expiry
              GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate:
                        newExpiry ??
                        DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (_, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: Colors.blue,
                          surface: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (p != null) setS(() => newExpiry = p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: _mutedTextColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        newExpiry != null
                            ? 'Expires: ${_formatDate(newExpiry!)}'
                            : 'No expiry - tap to set',
                        style: TextStyle(color: _mutedTextColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Active toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active', style: TextStyle(color: _mutedTextColor)),
                  Switch(
                    value: newActive,
                    activeColor: Colors.greenAccent,
                    onChanged: (v) => setS(() => newActive = v),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: _mutedTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text.trim());
                if (amt == null || amt <= 0) return;
                dc.amount = amt;
                dc.isActive = newActive;

                dc.expiresAt = newExpiry != null
                    ? Timestamp.fromDate(newExpiry!)
                    : null;

                await context.read<Datafeed>().editDiscountCode(dc);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(
                'Save',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    amtCtrl.dispose();
  }

  Future<void> _delete(DiscountCodeModel dc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: Text('Delete Code', style: TextStyle(color: _textColor)),
        content: Text(
          'Delete "${dc.code}"? Cannot be undone.',
          style: TextStyle(color: _mutedTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _mutedTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await context.read<Datafeed>().deleteDiscountCode(dc.id);
    if (!ok && mounted) {
      snackMsg(context, 'Cannot delete a used code.', Colors.red);
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    snackMsg(
      context,
      '"$code" copied',
      Colors.green,
      dur: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (_, datafeed, _) {
        final all = datafeed.discountCodes;
        final active = all.where((c) => c.canBeUsed).length;
        final used = all.where((c) => c.isUsed).length;
        final expired = all.where((c) => c.isExpired).length;

        final filtered = all.where((c) {
          if (_filter == 'active') return c.canBeUsed;
          if (_filter == 'used') return c.isUsed;
          if (_filter == 'expired') return c.isExpired;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Discount Codes',
              style: TextStyle(
                color: _textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            centerTitle: true,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            iconTheme: IconThemeData(color: _textColor),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.15),
                    foregroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.blue, width: 0.8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Code', style: TextStyle(fontSize: 13)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DiscountCodeRegisterPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    // Filter chips
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16),
                      child: Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            _chipDiscount('All', 'all', all.length),
                            //  const SizedBox(width: 8),
                            _chipDiscount('Active', 'active', active),
                            //  const SizedBox(width: 8),
                            _chipDiscount('Used', 'used', used),
                            //  const SizedBox(width: 8),
                            _chipDiscount('Expired', 'expired', expired),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.discount_outlined,
                                    color: _mutedTextColor,
                                    size: 56,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No codes here',
                                    style: TextStyle(
                                      color: _mutedTextColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ScrollbarTheme(
                              data: ScrollbarThemeData(
                                thumbColor: MaterialStateProperty.all(
                                  _isLightTheme
                                      ? _colors.outline
                                      : const Color(0xFF22304A),
                                ),
                                trackColor: MaterialStateProperty.all(
                                  Colors.grey.shade300,
                                ),
                                thickness: MaterialStateProperty.all(10),
                                radius: const Radius.circular(10),
                                thumbVisibility: MaterialStateProperty.all(
                                  true,
                                ),
                              ),
                              child: Scrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                interactive: true,
                                thickness: 10,
                                radius: const Radius.circular(10),
                                child: ListView.separated(
                                  controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) =>
                                      _buildTile(filtered[i]),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chipDiscount(String label, String value, int count) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel
              ? Colors.orangeAccent.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? Colors.blue : _borderColor),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: sel ? Colors.blue : _mutedTextColor,
            fontSize: 11,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTile(DiscountCodeModel dc) {
    Color dotColor;
    String statusLabel;
    if (dc.isUsed) {
      dotColor = _mutedTextColor;
      statusLabel = 'Used';
    } else if (dc.isExpired) {
      dotColor = _isLightTheme ? Colors.red.shade700 : Colors.redAccent;
      statusLabel = 'Expired';
    } else if (dc.isActive) {
      dotColor = _activeStatusColor;
      statusLabel = 'Active';
    } else {
      dotColor = _inactiveStatusColor;
      statusLabel = 'Inactive';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dc.isUsed
              ? _isLightTheme
                    ? _borderColor.withOpacity(0.35)
                    : Colors.white12
              : dc.canBeUsed
              ? Colors.green.withOpacity(0.35)
              : _borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Code + amount + status badge
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dc.code,
                      style: TextStyle(
                        color: dc.isUsed ? _usedTextColor : _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.5,
                        decoration: dc.isUsed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: dc.isUsed
                            ? (_isLightTheme
                                  ? _borderColor.withOpacity(0.2)
                                  : Colors.white12)
                            : Colors.orangeAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'GHS ${dc.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: dc.isUsed ? _usedTextColor : Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: dotColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: dotColor, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Meta line
                Text(
                  [
                    if (dc.createdAt != null)
                      'Created ${_formatDate(dc.createdAt!.toDate())}',
                    if (dc.expiresAt != null)
                      'Expires ${_formatDate(dc.expiresAt!.toDate())}',
                    if (dc.isUsed && dc.usedAt != null)
                      'Used ${_formatDate(dc.usedAt!.toDate())}',
                    if (dc.isUsed &&
                        dc.usedBranch != null &&
                        dc.usedBranch!.isNotEmpty)
                      'by ${dc.usedBranch}',
                  ].join('  -  '),
                  style: TextStyle(color: _mutedTextColor, fontSize: 11),
                ),
              ],
            ),
          ),

          // Actions - copy + edit
          if (!dc.isUsed && !dc.isExpired) ...[
            IconButton(
              icon: Icon(Icons.copy, color: _mutedTextColor, size: 20),
              tooltip: 'Copy',
              onPressed: () => _copy(dc.code),
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: Colors.green,
                size: 20,
              ),
              tooltip: 'Edit',
              onPressed: () => _edit(dc),
            ),
          ],

          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: dc.isUsed ? _mutedTextColor : Colors.redAccent,
              size: 20,
            ),
            tooltip: dc.isUsed ? 'Cannot delete used code' : 'Delete',
            onPressed: dc.isUsed ? null : () => _delete(dc),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}
