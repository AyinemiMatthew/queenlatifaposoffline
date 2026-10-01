import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/Datafeed.dart';
import '../../widgets/datepicker.dart';

import '../salesviewdetails.dart';

class UnprintedReceipts extends StatefulWidget {
  const UnprintedReceipts({super.key});

  @override
  State<UnprintedReceipts> createState() => _UnprintedReceiptsState();
}

class _UnprintedReceiptsState extends State<UnprintedReceipts> {
  DateTimeRange? _range;
  String? _branchId;
  final _nf = NumberFormat('#,##0.00');

  bool _isSearching = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final d = context.read<Datafeed>();
      d.fetchBranches();
      d.fetchUnprinted();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _query = '';
      _searchController.clear();
    });
  }

  double _total(dynamic sv) {
    final m = Map<String, dynamic>.from(sv.items);
    return m.values.fold<double>(0, (s, i) {
      if (i is Map<String, dynamic>) {
        return s + (double.tryParse(i['totalamount']?.toString() ?? '0') ?? 0);
      }
      return s;
    });
  }

  List _applySearch(List list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((sv) {
      final receipt = (sv.receiptNumber ?? '').toString().toLowerCase();
      final customer = (sv.customerName ?? '').toString().toLowerCase();
      final staff = (sv.createdBy ?? '').toString().toLowerCase();
      final branch = (sv.branchName ?? '').toString().toLowerCase();
      return receipt.contains(q) ||  customer.contains(q) || staff.contains(q) || branch.contains(q);
    }).toList();
  }

  Future<void> _delete(Datafeed d, dynamic sv) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete receipt?'),
        content: Text(
          'Receipt #${sv.receiptNumber} will be permanently deleted. '
              'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await d.deleteUnprintedSale(sv.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? Colors.green : Colors.red,
      content: Text(ok
          ? 'Receipt deleted'
          : 'Could not delete (already printed or an error occurred)'),
    ));
  }

  /// Search field, centered, max width 500.
  Widget _buildSearchField(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  cursorColor: colorScheme.primary,
                  decoration: InputDecoration(
                    hintText: 'Search receipt, customer, staff, branch...',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (_query.isNotEmpty)
                InkWell(
                  onTap: () => setState(() {
                    _query = '';
                    _searchController.clear();
                  }),
                  child: Icon(Icons.close,
                      color: colorScheme.onSurfaceVariant, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(
    BuildContext context,
    int count,
    DateTime s,
    DateTime e,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unprinted Receipts ($count)',
            style: TextStyle(color: colorScheme.onSurface, fontSize: 16)),
        Text(
          '${DateFormat('yyyy MMM dd').format(s)}  –  '
              '${DateFormat('yyyy MMM dd').format(e)}',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(builder: (context, d, _) {
      final canPick = d.isAdminLevel || d.canSelectBranch;
      final showBranch = canPick && d.branches.length > 1;
      final all = d.unprintedSales;
      final list = _applySearch(all);

      final s = _range?.start ?? DateTime.now();
      final e = _range?.end ?? DateTime.now();
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          foregroundColor: theme.appBarTheme.foregroundColor,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
          automaticallyImplyLeading: !_isSearching,
          leading: _isSearching
              ? IconButton(
            tooltip: 'Close search',
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurfaceVariant),
            onPressed: _closeSearch,
          )
              : null,
          centerTitle: _isSearching,
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isSearching
                ? KeyedSubtree(
              key: const ValueKey('search'),
              child: _buildSearchField(context),
            )
                : KeyedSubtree(
              key: const ValueKey('title'),
              child: _buildTitle(context, all.length, s, e),
            ),
          ),
          actions: _isSearching
              ? const []
              : [
            if (showBranch)
              Container(
                constraints: const BoxConstraints(maxWidth: 140),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: d.branches.any((b) => b.id == _branchId)
                        ? _branchId
                        : null,
                    dropdownColor: colorScheme.surfaceContainerHighest,
                    isDense: true,
                    isExpanded: true,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 12,
                    ),
                    icon: Icon(Icons.expand_more,
                        color: colorScheme.onSurfaceVariant, size: 16),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('All Branches')),
                      ...{for (final b in d.branches) b.id: b}
                          .values
                          .map(
                            (b) => DropdownMenuItem<String?>(
                          value: b.id,
                          child: Text(b.branchname,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _branchId = v);
                      d.fetchUnprinted(range: _range, branchId: v);
                    },
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Search',
              icon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              onPressed: _openSearch,
            ),
            ReusableDatePickerWidget(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.calendar_today,
                    size: 20, color: colorScheme.onSurfaceVariant),
              ),
              onDateSelected: (sel) {
                setState(() => _range = sel);
                d.fetchUnprinted(range: sel, branchId: _branchId);
              },
            ),
          ],
        ),
        body: d.isLoadingUnprinted
            ? Center(
            child: CircularProgressIndicator(color: colorScheme.primary))
            : all.isEmpty
            ? Center(
            child: Text('No unprinted receipts',
                style: TextStyle(color: colorScheme.onSurfaceVariant)))
            : list.isEmpty
            ? Center(
            child: Text('No matching receipts',
                style: TextStyle(color: colorScheme.onSurfaceVariant)))

            : Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final sv = list[i];
                final staff = (sv.createdBy ?? '-').toString();
                final branch = (sv.branchName ?? '-').toString();

                return Material(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SalesDetailPage(salesview: sv)),
                    ),
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Receipt #${sv.receiptNumber}',
                                    style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(
                                  showBranch ? '$branch  •  $staff' : staff,
                                  style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Text('GHS ${_nf.format(_total(sv))}',
                              style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13)),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'View',
                            icon: Icon(Icons.visibility,
                                color: colorScheme.onSurface, size: 20),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SalesDetailPage(salesview: sv)),
                            ),
                          ),
                          if (d.isAdminLevel)
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 20),
                              onPressed: () => _delete(d, sv),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    });
  }
}