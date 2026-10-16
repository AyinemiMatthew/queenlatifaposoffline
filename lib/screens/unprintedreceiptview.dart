import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/salesmodel.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import 'salesviewdetails.dart';

class UnprintedReceiptView extends StatefulWidget {
  const UnprintedReceiptView({super.key});

  @override
  State<UnprintedReceiptView> createState() => _UnprintedReceiptViewState();
}

class _UnprintedReceiptViewState extends State<UnprintedReceiptView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  DateTimeRange? _dateRange;
  String? _selectedBranchId;
  String _searchQuery = '';
  bool _searchExpanded = false;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadReceipts);
  }

  Future<void> _loadReceipts() async {
    final datafeed = context.read<Datafeed>();
    try {
      await datafeed.fetchBranches();
      if (datafeed.isAdminLevel) {
        _selectedBranchId = null;
      } else {
        _selectedBranchId = datafeed.branchid;
      }
      await datafeed.fetchUnprinted(
        range: _dateRange,
        branchId: _selectedBranchId,
      );
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _reload(Datafeed datafeed) async {
    await datafeed.fetchUnprinted(
      range: _dateRange,
      branchId: _selectedBranchId,
    );
  }

  bool _isWarehouseType(String branchType) =>
      branchType.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') ==
      'warehouse';

  void _openSearch() {
    setState(() => _searchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _searchExpanded = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _selectDateRange(Datafeed datafeed, DateTimeRange? range) {
    setState(() => _dateRange = range);
    _reload(datafeed);
  }

  void _selectBranch(Datafeed datafeed, String branchId) {
    setState(() {
      _selectedBranchId = branchId.isEmpty ? null : branchId;
    });
    _reload(datafeed);
  }

  String _dateLabel(SalesModel sale) {
    final date = sale.dateymd;
    if (date != null && date.isNotEmpty) return date;
    return sale.createdAt == null
        ? 'Date unavailable'
        : DateFormat('yyyy-MM-dd').format(sale.createdAt!.toDate());
  }

  String _total(SalesModel sale) =>
      NumberFormat('#,##0.00').format(sale.totalamount);

  bool _matchesSearch(SalesModel sale) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchable = <String>[
      sale.receiptNumber,
      sale.dailyreceiptno ?? '',
      sale.id,
      sale.customerName ?? '',
      sale.customerPhone ?? '',
      sale.createdBy ?? '',
      sale.approvedby ?? '',
      sale.receiptby ?? '',
      sale.staff ?? '',
      sale.transMode,
      sale.paymentStatus,
      sale.branchName,
      sale.branchId,
      sale.pricingtype,
      sale.totalamount.toString(),
      sale.amountPaid.toString(),
      _dateLabel(sale),
      for (final item in sale.items.values.whereType<Map>())
        for (final key in ['item', 'barcode', 'productname', 'mode'])
          item[key]?.toString() ?? '',
    ];
    return searchable.any((value) => value.toLowerCase().contains(query));
  }

  Widget _detailChip(
    ColorScheme colors,
    IconData icon,
    String label,
    String value,
  ) {
    return Chip(
      avatar: Icon(icon, size: 15, color: colors.onSurfaceVariant),
      label: Text('$label: $value', overflow: TextOverflow.ellipsis),
      labelStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
      backgroundColor: colors.surfaceContainerHighest,
      side: BorderSide(color: colors.outlineVariant),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _receiptCard(
    BuildContext context,
    SalesModel sale,
    int index,
    bool showBranch,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final customer = (sale.customerName ?? '').trim().isEmpty
        ? 'Cash Customer'
        : sale.customerName!.trim();
    final staff = (sale.createdBy ?? sale.staff ?? '').trim();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                  child: Text('${index + 1}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receipt #${sale.receiptNumber}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer,
                        style: TextStyle(color: colors.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'GHS ${_total(sale)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                _detailChip(
                  colors,
                  Icons.calendar_today_outlined,
                  'Date',
                  _dateLabel(sale),
                ),
                _detailChip(
                  colors,
                  Icons.person_outline,
                  'Staff',
                  staff.isEmpty ? 'Unknown' : staff,
                ),
                _detailChip(
                  colors,
                  Icons.payment_outlined,
                  'Mode',
                  sale.transMode.isEmpty ? 'Unknown' : sale.transMode,
                ),
                _detailChip(
                  colors,
                  Icons.inventory_2_outlined,
                  'Items',
                  '${sale.itemCount}',
                ),
                if (showBranch)
                  _detailChip(
                    colors,
                    Icons.store_outlined,
                    'Branch',
                    sale.branchName.isEmpty ? 'Unknown' : sale.branchName,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLightTheme
                      ? const Color(0xFF415A77)
                      : colors.secondary,
                  foregroundColor: isLightTheme
                      ? Colors.white
                      : colors.onSecondary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SalesDetailPage(salesview: sale),
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, _) {
        final colors = Theme.of(context).colorScheme;
        final canSeeAllBranches = datafeed.isAdminLevel;
        final selectableBranches = datafeed.branches
            .where(
              (branch) =>
                  !_isWarehouseType(branch.branchtype) && branch.id.isNotEmpty,
            )
            .toList(growable: false);
        final showBranchSelector =
            canSeeAllBranches && selectableBranches.length > 1;
        final receipts = datafeed.unprintedSales
            .where(_matchesSearch)
            .toList(growable: false);
        final rangeStart = _dateRange?.start ?? DateTime.now();
        final rangeEnd = _dateRange?.end ?? DateTime.now();
        var selectedBranchName = 'All branches';
        for (final branch in selectableBranches) {
          if (branch.id == _selectedBranchId) {
            selectedBranchName = branch.branchname;
            break;
          }
        }
        final title = _searchExpanded
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                style: TextStyle(color: colors.onSurface),
                cursorColor: colors.secondary,
                decoration: InputDecoration(
                  hintText: 'Receipt number, customer, staff, mode, item...',
                  hintStyle: TextStyle(color: colors.onSurfaceVariant),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Unprinted Receipts (${receipts.length})'),
                  Text(
                    '${DateFormat('yyyy MMM dd').format(rangeStart)} – '
                    '${DateFormat('yyyy MMM dd').format(rangeEnd)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              );

        return Scaffold(
          appBar: AppBar(
            title: title,
            titleSpacing: _searchExpanded ? 0 : null,
            leading: _searchExpanded
                ? IconButton(
                    tooltip: 'Close search',
                    onPressed: _closeSearch,
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            actions: [
              if (!_searchExpanded && showBranchSelector)
                PopupMenuButton<String>(
                  tooltip: selectedBranchName,
                  icon: const Icon(Icons.store_outlined),
                  onSelected: (branchId) => _selectBranch(datafeed, branchId),
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem<String>(
                      value: '',
                      checked: _selectedBranchId == null,
                      child: const Text('All branches'),
                    ),
                    for (final branch in selectableBranches)
                      CheckedPopupMenuItem<String>(
                        value: branch.id,
                        checked: branch.id == _selectedBranchId,
                        child: Text(branch.branchname),
                      ),
                  ],
                ),
              if (!_searchExpanded)
                Tooltip(
                  message: 'Filter by date',
                  child: ReusableDatePickerWidget(
                    onDateSelected: (range) =>
                        _selectDateRange(datafeed, range),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.calendar_today_outlined,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
              if (!_searchExpanded)
                IconButton(
                  tooltip: 'Refresh receipts',
                  onPressed: () => _reload(datafeed),
                  icon: const Icon(Icons.refresh),
                ),
              IconButton(
                tooltip: _searchExpanded ? 'Clear search' : 'Search receipts',
                onPressed: _searchExpanded
                    ? () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      }
                    : _openSearch,
                icon: Icon(
                  _searchExpanded ? Icons.close : Icons.search,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          body: _initialLoading || datafeed.isLoadingUnprinted
              ? Center(
                  child: CircularProgressIndicator(color: colors.secondary),
                )
              : receipts.isEmpty
              ? Center(
                  child: Text(
                    datafeed.unprintedSales.isEmpty
                        ? 'No unprinted receipts'
                        : 'No receipts match your search',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: receipts.length,
                      itemBuilder: (context, index) => _receiptCard(
                        context,
                        receipts[index],
                        index + 1,
                        showBranchSelector,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
