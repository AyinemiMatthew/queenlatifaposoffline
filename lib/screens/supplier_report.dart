// import 'dart:typed_data';
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:excel/excel.dart' as xl;
// import 'package:file_saver/file_saver.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:provider/provider.dart';
//
// import '../providers/Datafeed.dart';
//
// final NumberFormat _money = NumberFormat('#,##0.00');
// final DateFormat _dbDate = DateFormat('yyyy-MM-dd');
// final DateFormat _shownDate = DateFormat('dd MMM yyyy');
//
// const double _wideBreakpoint = 800;
// const List<int> _pageSizes = [10, 25, 50, 100];
//
// double _num(dynamic v) {
//   if (v is num) return v.toDouble();
//   return double.tryParse(v?.toString() ?? '') ?? 0;
// }
//
// /// Handles a real Firestore Timestamp or a map like {_seconds: .., seconds: ..}
// int _millis(dynamic v) {
//   if (v is Timestamp) return v.millisecondsSinceEpoch;
//   if (v is Map) {
//     final s = v['_seconds'] ?? v['seconds'];
//     if (s is num) return s.toInt() * 1000;
//   }
//   return 0;
// }
//
// Color _balanceColor(double balance) {
//   if (balance > 0.004) return const Color(0xFFE65100); // we owe the supplier
//   if (balance < -0.004) return const Color(0xFF1565C0); // supplier owes us
//   return const Color(0xFF2E7D32); // settled
// }
//
// // ---------------------------------------------------------------------------
// // Statement model + calculation
// // ---------------------------------------------------------------------------
//
// class LedgerLine {
//   final String date;
//   final String description;
//   final double debit; // payments / returns (reduce what we owe)
//   final double credit; // purchases (increase what we owe)
//   final int created;
//   double balance = 0;
//
//   LedgerLine({
//     required this.date,
//     required this.description,
//     required this.debit,
//     required this.credit,
//     required this.created,
//   });
// }
//
// class Statement {
//   final double opening;
//   final List<LedgerLine> lines;
//   final double totalDebit;
//   final double totalCredit;
//   final double closing;
//
//   Statement({
//     required this.opening,
//     required this.lines,
//     required this.totalDebit,
//     required this.totalCredit,
//     required this.closing,
//   });
// }
//
// Future<List<LedgerLine>> _fetchSupplierLines(
//     Datafeed df,
//     String supplierId,
//     ) async {
//   final base = df.db
//       .collection('ledgers')
//       .where('companyId', isEqualTo: df.companyid)
//       .where('account', isEqualTo: 'accounts_payable');
//
//   final results = await Future.wait([
//     base.where('supplierId', isEqualTo: supplierId).get(),
//     base.where('creditorId', isEqualTo: supplierId).get(),
//   ]);
//
//   final seen = <String>{};
//   final lines = <LedgerLine>[];
//   for (final snap in results) {
//     for (final doc in snap.docs) {
//       if (!seen.add(doc.id)) continue;
//       final d = doc.data();
//       final amount = _num(d['amount']);
//       final isCredit = d['type']?.toString().toLowerCase() == 'credit';
//       lines.add(
//         LedgerLine(
//           date: d['date']?.toString() ?? '',
//           description: d['description']?.toString() ?? '',
//           debit: isCredit ? 0 : amount,
//           credit: isCredit ? amount : 0,
//           created: _millis(d['createdAt']),
//         ),
//       );
//     }
//   }
//   return lines;
// }
//
// Statement _buildStatement(
//     List<LedgerLine> all,
//     DateTime? from,
//     DateTime? to,
//     ) {
//   final fromStr = from == null ? null : _dbDate.format(from);
//   final toStr = to == null ? null : _dbDate.format(to);
//
//   // Opening balance = everything before the start date
//   double opening = 0;
//   if (fromStr != null) {
//     for (final l in all) {
//       if (l.date.compareTo(fromStr) < 0) opening += l.credit - l.debit;
//     }
//   }
//
//   final inRange = all.where((l) {
//     if (fromStr != null && l.date.compareTo(fromStr) < 0) return false;
//     if (toStr != null && l.date.compareTo(toStr) > 0) return false;
//     return true;
//   }).toList()
//     ..sort((a, b) {
//       final c = a.date.compareTo(b.date);
//       return c != 0 ? c : a.created.compareTo(b.created);
//     });
//
//   double running = opening, td = 0, tc = 0;
//   for (final l in inRange) {
//     running += l.credit - l.debit;
//     l.balance = running;
//     td += l.debit;
//     tc += l.credit;
//   }
//
//   return Statement(
//     opening: opening,
//     lines: inRange,
//     totalDebit: td,
//     totalCredit: tc,
//     closing: running,
//   );
// }
//
// // ---------------------------------------------------------------------------
// // Shared UI pieces
// // ---------------------------------------------------------------------------
//
// class _StatCard extends StatelessWidget {
//   final String label;
//   final String value;
//   final IconData icon;
//   final Color color;
//
//   const _StatCard({
//     required this.label,
//     required this.value,
//     required this.icon,
//     required this.color,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: cs.surface,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: cs.outlineVariant),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: color.withValues(alpha: 0.12),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Icon(icon, color: color, size: 22),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
//                 ),
//                 const SizedBox(height: 4),
//                 FittedBox(
//                   fit: BoxFit.scaleDown,
//                   alignment: Alignment.centerLeft,
//                   child: Text(
//                     value,
//                     style: TextStyle(
//                       color: cs.onSurface,
//                       fontSize: 18,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// /// 4 cards in a row on wide screens, 2 per row on mobile.
// Widget _statGrid(List<_StatCard> cards) {
//   return LayoutBuilder(
//     builder: (context, c) {
//       final cols = c.maxWidth >= 900 ? 4 : 2;
//       const gap = 12.0;
//       final w = (c.maxWidth - gap * (cols - 1)) / cols;
//       return Wrap(
//         spacing: gap,
//         runSpacing: gap,
//         children: cards.map((e) => SizedBox(width: w, child: e)).toList(),
//       );
//     },
//   );
// }
//
// class _BalanceChip extends StatelessWidget {
//   final double balance;
//   const _BalanceChip(this.balance);
//
//   @override
//   Widget build(BuildContext context) {
//     final c = _balanceColor(balance);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: c.withValues(alpha: 0.12),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Text(
//         'GHS ${_money.format(balance)}',
//         style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13),
//       ),
//     );
//   }
// }
//
// // ---------------------------------------------------------------------------
// // Pagination bar (used under every table)
// // ---------------------------------------------------------------------------
//
// class _PaginationBar extends StatelessWidget {
//   final int total;
//   final int page; // zero based
//   final int pageSize;
//   final ValueChanged<int> onPageChanged;
//   final ValueChanged<int> onPageSizeChanged;
//
//   const _PaginationBar({
//     required this.total,
//     required this.page,
//     required this.pageSize,
//     required this.onPageChanged,
//     required this.onPageSizeChanged,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final pages = total == 0 ? 1 : (total / pageSize).ceil();
//     final start = total == 0 ? 0 : page * pageSize + 1;
//     final end = total == 0 ? 0 : ((page + 1) * pageSize).clamp(0, total);
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       child: Wrap(
//         alignment: WrapAlignment.spaceBetween,
//         crossAxisAlignment: WrapCrossAlignment.center,
//         runSpacing: 4,
//         children: [
//           Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'Rows per page',
//                 style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
//               ),
//               const SizedBox(width: 8),
//               DropdownButton<int>(
//                 value: pageSize,
//                 underline: const SizedBox.shrink(),
//                 borderRadius: BorderRadius.circular(12),
//                 items: _pageSizes
//                     .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
//                     .toList(),
//                 onChanged: (v) {
//                   if (v != null) onPageSizeChanged(v);
//                 },
//               ),
//             ],
//           ),
//           Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 '$start-$end of $total',
//                 style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
//               ),
//               const SizedBox(width: 4),
//               IconButton(
//                 tooltip: 'First page',
//                 onPressed: page > 0 ? () => onPageChanged(0) : null,
//                 icon: const Icon(Icons.first_page_rounded),
//               ),
//               IconButton(
//                 tooltip: 'Previous',
//                 onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
//                 icon: const Icon(Icons.chevron_left_rounded),
//               ),
//               Text(
//                 '${page + 1} / $pages',
//                 style: const TextStyle(fontWeight: FontWeight.w600),
//               ),
//               IconButton(
//                 tooltip: 'Next',
//                 onPressed:
//                 page < pages - 1 ? () => onPageChanged(page + 1) : null,
//                 icon: const Icon(Icons.chevron_right_rounded),
//               ),
//               IconButton(
//                 tooltip: 'Last page',
//                 onPressed:
//                 page < pages - 1 ? () => onPageChanged(pages - 1) : null,
//                 icon: const Icon(Icons.last_page_rounded),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ---------------------------------------------------------------------------
// // Compact date range dialog (replaces the full screen range picker)
// // ---------------------------------------------------------------------------
//
// class _CompactRangeDialog extends StatefulWidget {
//   final DateTimeRange? initial;
//   const _CompactRangeDialog({this.initial});
//
//   @override
//   State<_CompactRangeDialog> createState() => _CompactRangeDialogState();
// }
//
// class _CompactRangeDialogState extends State<_CompactRangeDialog> {
//   late DateTime _from;
//   late DateTime _to;
//   bool _editingFrom = true;
//
//   @override
//   void initState() {
//     super.initState();
//     final now = DateTime.now();
//     _from = widget.initial?.start ?? DateTime(now.year, now.month, 1);
//     _to = widget.initial?.end ?? DateTime(now.year, now.month, now.day);
//     if (_to.isBefore(_from)) _to = _from;
//   }
//
//   Widget _tab(String label, DateTime value, bool isFrom, ColorScheme cs) {
//     final active = _editingFrom == isFrom;
//     return InkWell(
//       borderRadius: BorderRadius.circular(12),
//       onTap: () => setState(() => _editingFrom = isFrom),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         decoration: BoxDecoration(
//           color: active ? cs.primary.withValues(alpha: 0.10) : null,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: active ? cs.primary : cs.outlineVariant,
//             width: active ? 1.5 : 1,
//           ),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               label,
//               style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
//             ),
//             const SizedBox(height: 2),
//             Text(
//               _shownDate.format(value),
//               style: const TextStyle(fontWeight: FontWeight.w700),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 360),
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Select period',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
//               ),
//               const SizedBox(height: 12),
//               Row(
//                 children: [
//                   Expanded(child: _tab('From', _from, true, cs)),
//                   const SizedBox(width: 10),
//                   Expanded(child: _tab('To', _to, false, cs)),
//                 ],
//               ),
//               const SizedBox(height: 8),
//               SizedBox(
//                 height: 340,
//                 child: CalendarDatePicker(
//                   key: ValueKey(_editingFrom),
//                   initialDate: _editingFrom ? _from : _to,
//                   firstDate: _editingFrom ? DateTime(2020) : _from,
//                   lastDate: DateTime(2100),
//                   onDateChanged: (d) {
//                     setState(() {
//                       if (_editingFrom) {
//                         _from = d;
//                         if (_to.isBefore(d)) _to = d;
//                         _editingFrom = false; // jump to the end date
//                       } else {
//                         _to = d;
//                       }
//                     });
//                   },
//                 ),
//               ),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text('Cancel'),
//                   ),
//                   const SizedBox(width: 8),
//                   FilledButton(
//                     onPressed: () => Navigator.pop(
//                       context,
//                       DateTimeRange(start: _from, end: _to),
//                     ),
//                     child: const Text('Apply'),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ===========================================================================
// // PAGE 1: Supplier list (from the `suppliers` collection)
// // ===========================================================================
//
// class _SupplierRow {
//   final String id;
//   final String name;
//   final String contact;
//   final double credit;
//   final double debit;
//   double get balance => credit - debit;
//
//   _SupplierRow(this.id, this.name, this.contact, this.credit, this.debit);
// }
//
// class SupplierReportPage extends StatefulWidget {
//   const SupplierReportPage({super.key});
//
//   @override
//   State<SupplierReportPage> createState() => _SupplierReportPageState();
// }
//
// class _SupplierReportPageState extends State<SupplierReportPage> {
//   String _query = '';
//   int _page = 0;
//   int _pageSize = 10;
//
//   void _open(_SupplierRow r) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) =>
//             SupplierStatementPage(supplierId: r.id, supplierName: r.name),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final df = context.read<Datafeed>();
//
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       appBar: AppBar(
//         title: const Text('Supplier Report'),
//         backgroundColor: cs.surface,
//         foregroundColor: cs.onSurface,
//       ),
//       body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//         stream: df.db
//             .collection('suppliers')
//             .where('companyid', isEqualTo: df.companyid)
//             .snapshots(),
//         builder: (context, snap) {
//           if (snap.hasError) {
//             return Center(child: Text('Error: ${snap.error}'));
//           }
//           if (!snap.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
//
//           final all = snap.data!.docs.map((d) {
//             final m = d.data();
//             return _SupplierRow(
//               m['id']?.toString() ?? d.id,
//               m['supplier']?.toString() ?? 'Unknown',
//               m['contact']?.toString() ?? '',
//               _num(m['creditaccount']),
//               _num(m['debitaccount']),
//             );
//           }).toList()
//             ..sort(
//                   (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
//             );
//
//           final rows = all
//               .where((r) => r.name.toLowerCase().contains(_query.toLowerCase()))
//               .toList();
//
//           final totalCredit = all.fold<double>(0, (s, r) => s + r.credit);
//           final totalDebit = all.fold<double>(0, (s, r) => s + r.debit);
//
//           // ---- pagination ----
//           final pages = (rows.length / _pageSize).ceil();
//           final page =
//           pages == 0 ? 0 : (_page > pages - 1 ? pages - 1 : _page);
//           final pageRows =
//           rows.skip(page * _pageSize).take(_pageSize).toList();
//           final pager = _PaginationBar(
//             total: rows.length,
//             page: page,
//             pageSize: _pageSize,
//             onPageChanged: (p) => setState(() => _page = p),
//             onPageSizeChanged: (s) => setState(() {
//               _pageSize = s;
//               _page = 0;
//             }),
//           );
//
//           return Center(
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 1200),
//               child: ListView(
//                 padding: const EdgeInsets.all(16),
//                 children: [
//                   _statGrid([
//                     _StatCard(
//                       label: 'Suppliers',
//                       value: '${all.length}',
//                       icon: Icons.groups_rounded,
//                       color: const Color(0xFF5E35B1),
//                     ),
//                     _StatCard(
//                       label: 'Total Credit',
//                       value: 'GHS ${_money.format(totalCredit)}',
//                       icon: Icons.shopping_cart_checkout_rounded,
//                       color: const Color(0xFFE65100),
//                     ),
//                     _StatCard(
//                       label: 'Total Debit',
//                       value: 'GHS ${_money.format(totalDebit)}',
//                       icon: Icons.payments_rounded,
//                       color: const Color(0xFF2E7D32),
//                     ),
//                     _StatCard(
//                       label: 'Outstanding',
//                       value: 'GHS ${_money.format(totalCredit - totalDebit)}',
//                       icon: Icons.account_balance_wallet_rounded,
//                       color: const Color(0xFFC62828),
//                     ),
//                   ]),
//                   const SizedBox(height: 16),
//                   TextField(
//                     onChanged: (v) => setState(() {
//                       _query = v;
//                       _page = 0;
//                     }),
//                     decoration: InputDecoration(
//                       hintText: 'Search supplier',
//                       prefixIcon: const Icon(Icons.search),
//                       filled: true,
//                       fillColor: cs.surface,
//                       contentPadding: const EdgeInsets.symmetric(vertical: 16),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(16),
//                         borderSide: BorderSide(color: cs.outlineVariant),
//                       ),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(16),
//                         borderSide: BorderSide(color: cs.outlineVariant),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   LayoutBuilder(
//                     builder: (context, c) => c.maxWidth >= _wideBreakpoint
//                         ? _wideTable(pageRows, cs, pager)
//                         : _mobileList(pageRows, cs, pager),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _wideTable(
//       List<_SupplierRow> rows,
//       ColorScheme cs,
//       Widget pager,
//       ) {
//     Widget head(String t, {int flex = 2, TextAlign a = TextAlign.right}) =>
//         Expanded(
//           flex: flex,
//           child: Text(
//             t,
//             textAlign: a,
//             style: TextStyle(
//               fontWeight: FontWeight.w700,
//               color: cs.onSurfaceVariant,
//               fontSize: 13,
//             ),
//           ),
//         );
//
//     return Container(
//       decoration: BoxDecoration(
//         color: cs.surface,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: cs.outlineVariant),
//       ),
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//             decoration: BoxDecoration(
//               color: cs.surfaceContainerHighest,
//               borderRadius:
//               const BorderRadius.vertical(top: Radius.circular(16)),
//             ),
//             child: Row(
//               children: [
//                 head('Supplier', flex: 4, a: TextAlign.left),
//                 head('Credit Account'),
//                 head('Debit Account'),
//                 head('Balance'),
//                 const SizedBox(width: 32),
//               ],
//             ),
//           ),
//           if (rows.isEmpty)
//             const Padding(
//               padding: EdgeInsets.all(32),
//               child: Text('No suppliers found'),
//             ),
//           for (final r in rows) ...[
//             InkWell(
//               onTap: () => _open(r),
//               child: Padding(
//                 padding:
//                 const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       flex: 4,
//                       child: Row(
//                         children: [
//                           CircleAvatar(
//                             backgroundColor:
//                             cs.primary.withValues(alpha: 0.12),
//                             child: Text(
//                               r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
//                               style: TextStyle(
//                                 color: cs.primary,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Flexible(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   r.name,
//                                   overflow: TextOverflow.ellipsis,
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.w600,
//                                     fontSize: 15,
//                                   ),
//                                 ),
//                                 if (r.contact.isNotEmpty)
//                                   Text(
//                                     r.contact,
//                                     style: TextStyle(
//                                       color: cs.onSurfaceVariant,
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         _money.format(r.credit),
//                         textAlign: TextAlign.right,
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         _money.format(r.debit),
//                         textAlign: TextAlign.right,
//                       ),
//                     ),
//                     Expanded(
//                       flex: 2,
//                       child: Align(
//                         alignment: Alignment.centerRight,
//                         child: _BalanceChip(r.balance),
//                       ),
//                     ),
//                     SizedBox(
//                       width: 32,
//                       child: Icon(
//                         Icons.chevron_right_rounded,
//                         color: cs.onSurfaceVariant,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             Divider(height: 1, color: cs.outlineVariant),
//           ],
//           pager,
//         ],
//       ),
//     );
//   }
//
//   Widget _mobileList(
//       List<_SupplierRow> rows,
//       ColorScheme cs,
//       Widget pager,
//       ) {
//     if (rows.isEmpty) {
//       return const Padding(
//         padding: EdgeInsets.all(32),
//         child: Center(child: Text('No suppliers found')),
//       );
//     }
//     return Column(
//       children: [
//         for (final r in rows)
//           Padding(
//             padding: const EdgeInsets.only(bottom: 12),
//             child: InkWell(
//               borderRadius: BorderRadius.circular(16),
//               onTap: () => _open(r),
//               child: Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: cs.surface,
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(color: cs.outlineVariant),
//                 ),
//                 child: Column(
//                   children: [
//                     Row(
//                       children: [
//                         CircleAvatar(
//                           backgroundColor: cs.primary.withValues(alpha: 0.12),
//                           child: Text(
//                             r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
//                             style: TextStyle(
//                               color: cs.primary,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Text(
//                             r.name,
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(
//                               fontWeight: FontWeight.w600,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                         _BalanceChip(r.balance),
//                       ],
//                     ),
//                     const SizedBox(height: 12),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _miniFigure('Credit', r.credit, cs),
//                         ),
//                         Expanded(
//                           child: _miniFigure('Debit', r.debit, cs),
//                         ),
//                         Icon(
//                           Icons.chevron_right_rounded,
//                           color: cs.onSurfaceVariant,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         Container(
//           decoration: BoxDecoration(
//             color: cs.surface,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: cs.outlineVariant),
//           ),
//           child: pager,
//         ),
//       ],
//     );
//   }
//
//   Widget _miniFigure(String label, double v, ColorScheme cs) => Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Text(
//         label,
//         style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
//       ),
//       Text(
//         'GHS ${_money.format(v)}',
//         style: const TextStyle(fontWeight: FontWeight.w600),
//       ),
//     ],
//   );
// }
//
// // ===========================================================================
// // PAGE 2: Supplier statement (from the `ledgers` collection)
// // ===========================================================================
//
// class SupplierStatementPage extends StatefulWidget {
//   final String supplierId;
//   final String supplierName;
//
//   const SupplierStatementPage({
//     super.key,
//     required this.supplierId,
//     required this.supplierName,
//   });
//
//   @override
//   State<SupplierStatementPage> createState() => _SupplierStatementPageState();
// }
//
// class _SupplierStatementPageState extends State<SupplierStatementPage> {
//   List<LedgerLine> _all = [];
//   bool _loading = true;
//   String? _error;
//   DateTimeRange? _range;
//   int _page = 0;
//   int _pageSize = 10;
//
//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }
//
//   Future<void> _load() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//     try {
//       final df = context.read<Datafeed>();
//       final lines = await _fetchSupplierLines(df, widget.supplierId);
//       if (!mounted) return;
//       setState(() {
//         _all = lines;
//         _page = 0;
//         _loading = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _error = e.toString();
//         _loading = false;
//       });
//     }
//   }
//
//   Future<void> _pickRange() async {
//     final picked = await showDialog<DateTimeRange>(
//       context: context,
//       builder: (_) => _CompactRangeDialog(initial: _range),
//     );
//     if (picked != null) {
//       setState(() {
//         _range = picked;
//         _page = 0;
//       });
//     }
//   }
//
//   Statement get _statement =>
//       _buildStatement(_all, _range?.start, _range?.end);
//
//   String get _periodLabel => _range == null
//       ? 'All dates'
//       : '${_shownDate.format(_range!.start)} - ${_shownDate.format(_range!.end)}';
//
//   void _toast(String msg, {bool error = false}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         backgroundColor: error ? Colors.red : Colors.green,
//       ),
//     );
//   }
//
//   // ---------------------------- PDF ----------------------------------------
//   // PDF and Excel always export every line in the selected period,
//   // not just the page currently shown on screen.
//
//   Future<void> _printPdf(Statement s) async {
//     try {
//       final doc = pw.Document();
//
//       final rows = <List<String>>[
//         ['', 'Opening Balance', '', '', _money.format(s.opening)],
//         for (final l in s.lines)
//           [
//             l.date,
//             l.description,
//             l.debit == 0 ? '' : _money.format(l.debit),
//             l.credit == 0 ? '' : _money.format(l.credit),
//             _money.format(l.balance),
//           ],
//         [
//           '',
//           'Current Balance',
//           _money.format(s.totalDebit),
//           _money.format(s.totalCredit),
//           _money.format(s.closing),
//         ],
//       ];
//
//       doc.addPage(
//         pw.MultiPage(
//           pageFormat: PdfPageFormat.a4,
//           margin: const pw.EdgeInsets.all(28),
//           header: (_) => pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Text(
//                 'Supplier Statement',
//                 style: pw.TextStyle(
//                   fontSize: 20,
//                   fontWeight: pw.FontWeight.bold,
//                 ),
//               ),
//               pw.SizedBox(height: 4),
//               pw.Text(
//                 widget.supplierName,
//                 style: const pw.TextStyle(fontSize: 14),
//               ),
//               pw.Text(
//                 'Period: $_periodLabel',
//                 style: const pw.TextStyle(fontSize: 10),
//               ),
//               pw.SizedBox(height: 12),
//             ],
//           ),
//           footer: (ctx) => pw.Align(
//             alignment: pw.Alignment.centerRight,
//             child: pw.Text(
//               'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
//               style: const pw.TextStyle(fontSize: 9),
//             ),
//           ),
//           build: (_) => [
//             pw.TableHelper.fromTextArray(
//               headers: [
//                 'Date',
//                 'Description',
//                 'Debit',
//                 'Credit',
//                 'Balance',
//               ],
//               data: rows,
//               headerStyle: pw.TextStyle(
//                 fontWeight: pw.FontWeight.bold,
//                 fontSize: 9,
//                 color: PdfColors.white,
//               ),
//               headerDecoration: const pw.BoxDecoration(
//                 color: PdfColors.blueGrey800,
//               ),
//               cellStyle: const pw.TextStyle(fontSize: 8.5),
//               columnWidths: {
//                 0: const pw.FixedColumnWidth(58),
//                 1: const pw.FlexColumnWidth(5),
//                 2: const pw.FixedColumnWidth(58),
//                 3: const pw.FixedColumnWidth(58),
//                 4: const pw.FixedColumnWidth(66),
//               },
//               cellAlignments: {
//                 0: pw.Alignment.centerLeft,
//                 1: pw.Alignment.centerLeft,
//                 2: pw.Alignment.centerRight,
//                 3: pw.Alignment.centerRight,
//                 4: pw.Alignment.centerRight,
//               },
//               oddRowDecoration: const pw.BoxDecoration(
//                 color: PdfColors.grey100,
//               ),
//             ),
//           ],
//         ),
//       );
//
//       final Uint8List bytes = await doc.save();
//       await Printing.layoutPdf(
//         onLayout: (_) async => bytes,
//         name: '${widget.supplierName}_statement.pdf',
//       );
//     } catch (e) {
//       _toast('PDF failed: $e', error: true);
//     }
//   }
//
//   // ---------------------------- Excel --------------------------------------
//
//   Future<void> _exportExcel(Statement s) async {
//     try {
//       final excel = xl.Excel.createExcel();
//       final sheet = excel['Statement'];
//       excel.setDefaultSheet('Statement');
//       excel.delete('Sheet1');
//
//       xl.CellValue t(String v) => xl.TextCellValue(v);
//       xl.CellValue n(double v) => xl.DoubleCellValue(v);
//
//       sheet.appendRow([t('Supplier Statement')]);
//       sheet.appendRow([t('Supplier'), t(widget.supplierName)]);
//       sheet.appendRow([t('Period'), t(_periodLabel)]);
//       sheet.appendRow([]);
//       sheet.appendRow([
//         t('Date'),
//         t('Description'),
//         t('Debit'),
//         t('Credit'),
//         t('Balance'),
//       ]);
//       sheet.appendRow([t(''), t('Opening Balance'), t(''), t(''), n(s.opening)]);
//       for (final l in s.lines) {
//         sheet.appendRow([
//           t(l.date),
//           t(l.description),
//           n(l.debit),
//           n(l.credit),
//           n(l.balance),
//         ]);
//       }
//       sheet.appendRow([
//         t(''),
//         t('Current Balance'),
//         n(s.totalDebit),
//         n(s.totalCredit),
//         n(s.closing),
//       ]);
//
//       final out = excel.encode();
//       if (out == null) throw 'Could not build the Excel file';
//
//       await FileSaver.instance.saveFile(
//         name: '${widget.supplierName}_statement',
//         bytes: Uint8List.fromList(out),
//         fileExtension: 'xlsx', // use `ext:` on file_saver 0.2.x
//         mimeType: MimeType.microsoftExcel,
//       );
//       _toast('Excel file saved');
//     } catch (e) {
//       _toast('Excel export failed: $e', error: true);
//     }
//   }
//
//   // ---------------------------- UI -----------------------------------------
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       appBar: AppBar(
//         title: Text(widget.supplierName),
//         backgroundColor: cs.surface,
//         foregroundColor: cs.onSurface,
//         actions: [
//           IconButton(
//             onPressed: _loading ? null : _load,
//             icon: const Icon(Icons.refresh_rounded),
//             tooltip: 'Refresh',
//           ),
//         ],
//       ),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : _error != null
//           ? Center(child: Text('Error: $_error'))
//           : _content(cs),
//     );
//   }
//
//   Widget _content(ColorScheme cs) {
//     final s = _statement;
//
//     // ---- pagination over the lines in the selected period ----
//     final total = s.lines.length;
//     final pages = (total / _pageSize).ceil();
//     final page = pages == 0 ? 0 : (_page > pages - 1 ? pages - 1 : _page);
//     final pageLines = s.lines.skip(page * _pageSize).take(_pageSize).toList();
//     final isFirst = page == 0;
//     final isLast = pages == 0 || page == pages - 1;
//     final pager = _PaginationBar(
//       total: total,
//       page: page,
//       pageSize: _pageSize,
//       onPageChanged: (p) => setState(() => _page = p),
//       onPageSizeChanged: (v) => setState(() {
//         _pageSize = v;
//         _page = 0;
//       }),
//     );
//
//     return Center(
//       child: ConstrainedBox(
//         constraints: const BoxConstraints(maxWidth: 1200),
//         child: ListView(
//           padding: const EdgeInsets.all(16),
//           children: [
//             // Toolbar: date range + exports
//             Wrap(
//               spacing: 12,
//               runSpacing: 12,
//               crossAxisAlignment: WrapCrossAlignment.center,
//               children: [
//                 OutlinedButton.icon(
//                   onPressed: _pickRange,
//                   icon: const Icon(Icons.date_range_rounded),
//                   label: Text(_periodLabel),
//                   style: _toolbarStyle(cs),
//                 ),
//                 if (_range != null)
//                   TextButton.icon(
//                     onPressed: () => setState(() {
//                       _range = null;
//                       _page = 0;
//                     }),
//                     icon: const Icon(Icons.close_rounded, size: 18),
//                     label: const Text('Clear'),
//                   ),
//                 FilledButton.icon(
//                   onPressed: () => _printPdf(s),
//                   icon: const Icon(Icons.picture_as_pdf_rounded),
//                   label: const Text('PDF / Print'),
//                   style: FilledButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 18,
//                       vertical: 16,
//                     ),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(14),
//                     ),
//                   ),
//                 ),
//                 OutlinedButton.icon(
//                   onPressed: () => _exportExcel(s),
//                   icon: const Icon(Icons.table_chart_rounded),
//                   label: const Text('Excel'),
//                   style: _toolbarStyle(cs),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//
//             _statGrid([
//               _StatCard(
//                 label: 'Opening Balance',
//                 value: 'GHS ${_money.format(s.opening)}',
//                 icon: Icons.flag_rounded,
//                 color: const Color(0xFF5E35B1),
//               ),
//               _StatCard(
//                 label: 'Total Credit',
//                 value: 'GHS ${_money.format(s.totalCredit)}',
//                 icon: Icons.add_shopping_cart_rounded,
//                 color: const Color(0xFFE65100),
//               ),
//               _StatCard(
//                 label: 'Total Debit',
//                 value: 'GHS ${_money.format(s.totalDebit)}',
//                 icon: Icons.payments_rounded,
//                 color: const Color(0xFF2E7D32),
//               ),
//               _StatCard(
//                 label: 'Current Balance',
//                 value: 'GHS ${_money.format(s.closing)}',
//                 icon: Icons.account_balance_wallet_rounded,
//                 color: _balanceColor(s.closing),
//               ),
//             ]),
//             const SizedBox(height: 16),
//
//             LayoutBuilder(
//               builder: (context, c) => c.maxWidth >= _wideBreakpoint
//                   ? _wideStatement(s, cs, pageLines, pager, isFirst, isLast)
//                   : _mobileStatement(s, cs, pageLines, pager, isFirst, isLast),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Balance = Credit - Debit. A positive balance is the amount owed to the supplier. '
//                   'PDF and Excel include every transaction in the selected period.',
//               style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   ButtonStyle _toolbarStyle(ColorScheme cs) => OutlinedButton.styleFrom(
//     padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
//     side: BorderSide(color: cs.outlineVariant),
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(14),
//     ),
//   );
//
//   // ----- Widescreen: table layout -----
//
//   Widget _wideStatement(
//       Statement s,
//       ColorScheme cs,
//       List<LedgerLine> pageLines,
//       Widget pager,
//       bool isFirst,
//       bool isLast,
//       ) {
//     Widget cell(String t,
//         {double? w,
//           int flex = 0,
//           TextAlign a = TextAlign.right,
//           TextStyle? style}) =>
//         flex > 0
//             ? Expanded(
//           flex: flex,
//           child: Text(t, textAlign: a, style: style),
//         )
//             : SizedBox(
//           width: w,
//           child: Text(t, textAlign: a, style: style),
//         );
//
//     final headStyle = TextStyle(
//       fontWeight: FontWeight.w700,
//       color: cs.onSurfaceVariant,
//       fontSize: 13,
//     );
//     const bold = TextStyle(fontWeight: FontWeight.w700);
//
//     Widget row({
//       required String date,
//       required String desc,
//       required String debit,
//       required String credit,
//       required String balance,
//       Color? bg,
//       TextStyle? style,
//       Color? balanceColor,
//     }) =>
//         Container(
//           color: bg,
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               cell(date, w: 100, a: TextAlign.left, style: style),
//               cell(desc, flex: 1, a: TextAlign.left, style: style),
//               const SizedBox(width: 16),
//               cell(debit, w: 110, style: style),
//               cell(credit, w: 110, style: style),
//               cell(
//                 balance,
//                 w: 130,
//                 style: (style ?? const TextStyle()).copyWith(
//                   color: balanceColor,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ],
//           ),
//         );
//
//     return Container(
//       decoration: BoxDecoration(
//         color: cs.surface,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: cs.outlineVariant),
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: Column(
//         children: [
//           row(
//             date: 'Date',
//             desc: 'Description',
//             debit: 'Debit',
//             credit: 'Credit',
//             balance: 'Balance',
//             bg: cs.surfaceContainerHighest,
//             style: headStyle,
//           ),
//           if (isFirst)
//             row(
//               date: '',
//               desc: 'Opening Balance',
//               debit: '',
//               credit: '',
//               balance: _money.format(s.opening),
//               bg: cs.primary.withValues(alpha: 0.06),
//               style: bold,
//               balanceColor: _balanceColor(s.opening),
//             ),
//           if (s.lines.isEmpty)
//             const Padding(
//               padding: EdgeInsets.all(32),
//               child: Text('No transactions in this period'),
//             ),
//           for (final l in pageLines) ...[
//             Divider(height: 1, color: cs.outlineVariant),
//             row(
//               date: l.date,
//               desc: l.description,
//               debit: l.debit == 0 ? '' : _money.format(l.debit),
//               credit: l.credit == 0 ? '' : _money.format(l.credit),
//               balance: _money.format(l.balance),
//               balanceColor: _balanceColor(l.balance),
//             ),
//           ],
//           if (isLast) ...[
//             Divider(height: 1, color: cs.outlineVariant),
//             row(
//               date: '',
//               desc: 'Current Balance',
//               debit: _money.format(s.totalDebit),
//               credit: _money.format(s.totalCredit),
//               balance: _money.format(s.closing),
//               bg: cs.primary.withValues(alpha: 0.06),
//               style: bold,
//               balanceColor: _balanceColor(s.closing),
//             ),
//           ],
//           Divider(height: 1, color: cs.outlineVariant),
//           pager,
//         ],
//       ),
//     );
//   }
//
//   // ----- Mobile: card layout -----
//
//   Widget _mobileStatement(
//       Statement s,
//       ColorScheme cs,
//       List<LedgerLine> pageLines,
//       Widget pager,
//       bool isFirst,
//       bool isLast,
//       ) {
//     Widget card(Widget child, {Color? color}) => Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: color ?? cs.surface,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: cs.outlineVariant),
//       ),
//       child: child,
//     );
//
//     return Column(
//       children: [
//         if (isFirst)
//           card(
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   'Opening Balance',
//                   style: TextStyle(fontWeight: FontWeight.w700),
//                 ),
//                 _BalanceChip(s.opening),
//               ],
//             ),
//             color: cs.primary.withValues(alpha: 0.06),
//           ),
//         if (s.lines.isEmpty)
//           const Padding(
//             padding: EdgeInsets.all(24),
//             child: Text('No transactions in this period'),
//           ),
//         for (final l in pageLines)
//           card(
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       l.date,
//                       style: TextStyle(
//                         color: cs.onSurfaceVariant,
//                         fontSize: 12,
//                       ),
//                     ),
//                     Text(
//                       l.credit > 0
//                           ? '+ GHS ${_money.format(l.credit)}'
//                           : '- GHS ${_money.format(l.debit)}',
//                       style: TextStyle(
//                         fontWeight: FontWeight.w700,
//                         color: l.credit > 0
//                             ? const Color(0xFFE65100)
//                             : const Color(0xFF2E7D32),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Text(l.description, style: const TextStyle(fontSize: 13)),
//                 const SizedBox(height: 10),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Balance',
//                       style: TextStyle(
//                         color: cs.onSurfaceVariant,
//                         fontSize: 12,
//                       ),
//                     ),
//                     Text(
//                       'GHS ${_money.format(l.balance)}',
//                       style: TextStyle(
//                         fontWeight: FontWeight.w700,
//                         color: _balanceColor(l.balance),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         if (isLast)
//           card(
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   'Current Balance',
//                   style: TextStyle(fontWeight: FontWeight.w700),
//                 ),
//                 _BalanceChip(s.closing),
//               ],
//             ),
//             color: cs.primary.withValues(alpha: 0.06),
//           ),
//         card(pager),
//       ],
//     );
//   }
// }