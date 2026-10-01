import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../models/creditorbalanceModel.dart';
import 'Creditorpayablelist.dart';

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
  static Color positive(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? const Color(0xFF15803D)
      : const Color(0xFF69F0AE);
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
  static Color field(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
}

class CreditorPayableScreen extends StatefulWidget {
  final String? selectedBranch;
  final String? docId;
  final CreditorBalance? creditinfo;
  const CreditorPayableScreen({
    Key? key,
    this.docId,
    this.creditinfo,
    this.selectedBranch,
  }) : super(key: key);

  @override
  State<CreditorPayableScreen> createState() => _CreditorPayableScreenState();
}

class _CreditorPayableScreenState extends State<CreditorPayableScreen> {
  static const _allKey = '__all__';

  final _searchCtrl = TextEditingController();
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String? _selectedBranch;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  bool _searchOpen = false; // mobile only

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final datafeed = Provider.of<Datafeed>(context, listen: false);

      setState(() => _selectedBranch = datafeed.selectedBranch?.id);
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchCreditorlist();
    });

    _searchCtrl.addListener(() {
      if (!mounted) return;
      final datafeed = Provider.of<Datafeed>(context, listen: false);
      datafeed.searchQuery = _searchCtrl.text;
      datafeed.notifyListeners();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 800;

  void _openPaymentDialog(Map<String, dynamic> creditor) {
    showDialog(
      context: context,
      builder: (_) => _CreditorPaymentDialog(
        creditorId: creditor['creditorId'] ?? '',
        creditorName: creditor['name'] ?? '',
        balance: (creditor['balance'] ?? 0).toString(),
        selectedBranch: _selectedBranch ?? '',
        creditinfo: widget.creditinfo,
      ),
    );
  }

  List<dynamic> _branchList(Datafeed datafeed) {
    final out = <dynamic>[];
    for (final b in datafeed.branches.where(
      (b) => b.branchtype != 'Warehouse',
    )) {
      if (!out.any((x) => x.id == b.id)) out.add(b);
    }
    return out;
  }

  Widget _searchField(Datafeed datafeed, {bool autofocus = false}) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchCtrl,
        autofocus: autofocus,
        style: TextStyle(color: _C.textPri(context), fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search creditor name…',
          hintStyle: TextStyle(color: _C.textMuted(context), fontSize: 13),
          prefixIcon: Icon(Icons.search, color: _C.textSub(context), size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: _C.textSub(context), size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    datafeed.searchQuery = '';
                    datafeed.notifyListeners();
                  },
                )
              : null,
          filled: true,
          fillColor: _C.bg(context),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _branchSelector(Datafeed datafeed, {required bool compact}) {
    if (!datafeed.isAdminLevel) {
      if (compact) return const SizedBox.shrink();
      return Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _C.field(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.divider(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store_mall_directory_outlined,
              color: _C.textSub(context),
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                datafeed.branch,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _C.textPri(context), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final branches = _branchList(datafeed);
    final match = branches.where((b) => b.id == _selectedBranch);
    final label = match.isEmpty
        ? 'All Branches'
        : match.first.branchname as String;

    return PopupMenuButton<String>(
      tooltip: 'Select branch',
      color: _C.field(context),
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        final id = v == _allKey ? null : v;
        setState(() {
          _selectedBranch = id;
          _currentPage = 0;
        });
        datafeed.fetchCreditorlist(branchID: id);
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: _allKey,
          child: Text(
            'All Branches',
            style: TextStyle(
              color: _selectedBranch == null ? _C.primary : _C.textSub(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...branches.map(
          (b) => PopupMenuItem<String>(
            value: b.id as String,
            child: Text(
              b.branchname,
              style: TextStyle(
                color: _selectedBranch == b.id
                    ? _C.primary
                    : _C.textPri(context),
              ),
            ),
          ),
        ),
      ],
      child: compact
          ? Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.store_mall_directory_outlined,
                color: _C.textPri(context),
                size: 24,
              ),
            )
          : Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _C.field(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.divider(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.store_mall_directory_outlined,
                    color: _C.textSub(context),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.textPri(context),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: _C.textSub(context),
                    size: 20,
                  ),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(Datafeed datafeed, int recordCount) {
    final mobile = _isMobile;

    final Widget title = mobile
        ? (_searchOpen
              ? _searchField(datafeed, autofocus: true)
              : Text(
                  'Creditors',
                  style: TextStyle(
                    color: _C.textPri(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ))
        : Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'List of Creditors',
                    style: TextStyle(
                      color: _C.textPri(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Manage your creditors and track payables',
                    style: TextStyle(color: _C.textSub(context), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: _searchField(datafeed),
                ),
              ),
            ],
          );

    return AppBar(
      backgroundColor: _C.header(context),
      foregroundColor: _C.textPri(context),
      elevation: 2,
      titleSpacing: 0,
      toolbarHeight: mobile ? kToolbarHeight : 64,
      leading: BackButton(color: _C.textPri(context)),
      title: title,
      actions: [
        _branchSelector(datafeed, compact: mobile),
        if (mobile)
          IconButton(
            tooltip: _searchOpen ? 'Close search' : 'Search',
            icon: Icon(_searchOpen ? Icons.close : Icons.search, size: 24),
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchCtrl.clear();
                  datafeed.searchQuery = '';
                  datafeed.notifyListeners();
                }
              });
            },
          ),
        if (!mobile)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _C.bg(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$recordCount record${recordCount == 1 ? '' : 's'}',
                  style: TextStyle(color: _C.textSub(context), fontSize: 13),
                ),
              ),
            ),
          ),
        // Home icon hidden while mobile search is open
        if (!(mobile && _searchOpen))
          IconButton(
            icon: const Icon(Icons.home, size: 25),
            tooltip: 'Home',
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (route) => false);
            },
          ),
        if (!mobile)
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
        if (mobile) const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.divider(context)),
      ),
    );
  }

  Widget _mobileList(List<Map<String, dynamic>> rows) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = rows[i];
        final name = c['name'] ?? '';
        final debit = (c['debit'] as num?)?.toDouble() ?? 0.0;
        final credit = (c['credit'] as num?)?.toDouble() ?? 0.0;
        final balance = (c['balance'] as num?)?.toDouble() ?? 0.0;
        final isOwed = balance > 0;

        return Material(
          color: _C.card(context),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openPaymentDialog(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _C.primary.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: _C.textPri(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: _C.textPri(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: _C.textMuted(context),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _AmountChip(
                              'Debit: GHS ${NumberFormat('#,##0.00').format(debit)}',
                              _C.textSub(context),
                            ),
                            const SizedBox(height: 4),
                            _AmountChip(
                              'Credit: GHS ${NumberFormat('#,##0.00').format(credit)}',
                              _C.textSub(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: _BalanceChip(balance, isOwed)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _sortRows(List<Map<String, dynamic>> rows) {
    final sorted = List<Map<String, dynamic>>.from(rows);
    if (_sortColumnIndex == null) return sorted;

    sorted.sort((a, b) {
      dynamic av, bv;
      switch (_sortColumnIndex) {
        case 1:
          av = (a['name'] ?? '').toString();
          bv = (b['name'] ?? '').toString();
          break;
        case 2:
          av = (a['debit'] as num?)?.toDouble() ?? 0.0;
          bv = (b['debit'] as num?)?.toDouble() ?? 0.0;
          break;
        case 3:
          av = (a['credit'] as num?)?.toDouble() ?? 0.0;
          bv = (b['credit'] as num?)?.toDouble() ?? 0.0;
          break;
        case 4:
          av = (a['balance'] as num?)?.toDouble() ?? 0.0;
          bv = (b['balance'] as num?)?.toDouble() ?? 0.0;
          break;
        default:
          return 0;
      }
      final cmp = Comparable.compare(av as Comparable, bv as Comparable);
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _currentPage = 0;
    });
  }

  Widget _headerCell(String label, {int? columnIndex, bool numeric = false}) {
    final isSorted = columnIndex != null && _sortColumnIndex == columnIndex;
    return InkWell(
      onTap: columnIndex == null ? null : () => _onSort(columnIndex),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: numeric
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _C.textSub(context),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          if (columnIndex != null) ...[
            const SizedBox(width: 2),
            Icon(
              isSorted
                  ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isSorted ? _C.primary : _C.textMuted(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _desktopTable(
    double width,
    List<Map<String, dynamic>> rows,
    Datafeed datafeed,
  ) {
    final sortedRows = _sortRows(rows);

    final totalRows = sortedRows.length;
    final totalPages = totalRows == 0 ? 1 : (totalRows / _rowsPerPage).ceil();
    final safePage = _currentPage.clamp(0, totalPages - 1);

    final start = safePage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, totalRows);
    final pageRows = totalRows == 0
        ? <Map<String, dynamic>>[]
        : sortedRows.sublist(start, end);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: _C.card(context),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header row
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: _C.card(context),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '#',
                      style: TextStyle(
                        color: _C.textSub(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _headerCell('Name', columnIndex: 1)),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _headerCell(
                        'Debit',
                        columnIndex: 2,
                        numeric: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _headerCell(
                        'Credit',
                        columnIndex: 3,
                        numeric: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _headerCell(
                        'Balance',
                        columnIndex: 4,
                        numeric: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 90,
                    child: Text(
                      'Action',
                      style: TextStyle(
                        color: _C.textSub(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: _C.divider(context)),

            // Rows
            Expanded(
              child: pageRows.isEmpty
                  ? const SizedBox()
                  : ListView.builder(
                      itemCount: pageRows.length,
                      itemBuilder: (context, i) {
                        final c = pageRows[i];
                        final globalIndex = start + i;
                        final name = c['name'] ?? '';
                        final debit = (c['debit'] as num?)?.toDouble() ?? 0.0;
                        final credit = (c['credit'] as num?)?.toDouble() ?? 0.0;
                        final balance =
                            (c['balance'] as num?)?.toDouble() ?? 0.0;
                        final isOwed = balance > 0;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openPaymentDialog(c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _C.divider(context),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      '${globalIndex + 1}',
                                      style: TextStyle(
                                        color: _C.textSub(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: _C.textPri(context),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      debit > 0
                                          ? NumberFormat(
                                              '#,##0.00',
                                            ).format(debit)
                                          : '0.00',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: _C.textSub(context),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      credit > 0
                                          ? NumberFormat(
                                              '#,##0.00',
                                            ).format(credit)
                                          : '0.00',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: _C.textSub(context),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: _BalanceChip(balance, isOwed),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 90,
                                    child: TextButton(
                                      onPressed: () => _openPaymentDialog(c),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: _C.primary,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Pay',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            Container(height: 1, color: _C.divider(context)),

            // Pagination footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Rows per page: ',
                        style: TextStyle(
                          color: _C.textSub(context),
                          fontSize: 12,
                        ),
                      ),
                      DropdownButton<int>(
                        value: _rowsPerPage,
                        dropdownColor: _C.card(context),
                        style: TextStyle(
                          color: _C.textPri(context),
                          fontSize: 12,
                        ),
                        underline: const SizedBox(),
                        items: const [10, 25, 50, 100]
                            .map(
                              (v) =>
                                  DropdownMenuItem(value: v, child: Text('$v')),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _rowsPerPage = v;
                            _currentPage = 0;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        totalRows == 0
                            ? '0–0 of 0'
                            : '${start + 1}–$end of $totalRows',
                        style: TextStyle(
                          color: _C.textSub(context),
                          fontSize: 12,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left,
                          color: _C.textSub(context),
                          size: 20,
                        ),
                        onPressed: safePage > 0
                            ? () => setState(() => _currentPage = safePage - 1)
                            : null,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: _C.textSub(context),
                          size: 20,
                        ),
                        onPressed: (safePage + 1) < totalPages
                            ? () => setState(() => _currentPage = safePage + 1)
                            : null,
                      ),
                    ],
                  ),
                ],
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
        final rows = datafeed.filterCreditorlist();
        final isLoading = datafeed.isLoadingcreditlist;

        return Scaffold(
          backgroundColor: _C.bg(context),
          appBar: _buildAppBar(datafeed, rows.length),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  children: [
                    if (_isMobile)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${rows.length} record${rows.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: _C.textMuted(context),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    Flexible(
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: _C.primary,
                              ),
                            )
                          : rows.isEmpty
                          ? _buildEmptyState()
                          : LayoutBuilder(
                              builder: (ctx, constraints) {
                                if (_isMobile) return _mobileList(rows);
                                final w = constraints.maxWidth < 900
                                    ? 900.0
                                    : constraints.maxWidth;
                                return _desktopTable(w, rows, datafeed);
                              },
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

  Widget _buildEmptyState() {
    final q = _searchCtrl.text;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.card(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: _C.textMuted(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            q.isEmpty ? 'No creditors found' : 'No results for "$q"',
            style: TextStyle(
              color: _C.textSub(context),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            q.isEmpty
                ? 'Creditors will appear here once data is loaded and Branch selected.'
                : 'Try adjusting your search term.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.textMuted(context), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Payment dialog
class _CreditorPaymentDialog extends StatefulWidget {
  final String creditorId;
  final String creditorName;
  final String balance;
  final String selectedBranch;
  final CreditorBalance? creditinfo;

  const _CreditorPaymentDialog({
    required this.creditorId,
    required this.creditorName,
    required this.balance,
    required this.selectedBranch,
    this.creditinfo,
  });

  @override
  State<_CreditorPaymentDialog> createState() => _CreditorPaymentDialogState();
}

class _CreditorPaymentDialogState extends State<_CreditorPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _narationCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final phoneController = TextEditingController();
  bool _ready = false;
  DateTime? _selectedDate;
  String? _paymentMode;
  String? _paymentAccount;
  bool _saving = false;
  String? selectedMomoNetwork = 'MTN';
  List<String> _allowed = [];

  String _key(String m) => m
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<String> _payModes(Datafeed datafeed) {
    final seen = <String>{};
    final out = <String>[];
    for (final m in _allowed) {
      final name = m.toString().trim();
      if (name.isEmpty) continue;
      final k = _key(name);
      if (k.contains('credit')) continue;
      if (seen.add(k)) out.add(name);
    }
    return out;
  }

  List<String> _accountsFor(Datafeed datafeed) {
    final mode = _paymentMode;
    if (mode == null || mode.isEmpty) return <String>[];
    final k = _key(mode);
    final result = <String>{};
    for (final e in datafeed.linkedAccounts.entries) {
      if (_key(e.key) == k) {
        for (final a in e.value) {
          final name = a.toString().trim();
          if (name.isNotEmpty) result.add(name);
        }
      }
    }
    return result.toList();
  }

  void _syncAccountToMode(Datafeed datafeed) {
    final accounts = _accountsFor(datafeed);
    _paymentAccount = accounts.length == 1 ? accounts.first : null;
  }

  void showMessage(BuildContext context, Color color, String message) {
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

    final bal = double.tryParse(widget.balance) ?? 0.0;
    _amountCtrl.text = bal > 0 ? bal.toStringAsFixed(2) : '';

    Future.microtask(() async {
      if (!mounted) return;
      final df = context.read<Datafeed>();
      try {
        await df.getdata();
        final allowedSnapshot = List<String>.from(df.allowedPaymentMethods);
        await df.fetchpaiymentMethods();
        if (!mounted) return;
        final companyModes = df.linkedAccounts.keys.toList();
        setState(() {
          _allowed = df.isAdminLevel && allowedSnapshot.isEmpty
              ? companyModes
              : allowedSnapshot;
          if (widget.creditinfo != null) {
            final c = widget.creditinfo!;
            _referenceCtrl.text = c.transactionRef;
            _amountCtrl.text = c.amount.toString();
            _narationCtrl.text = c.naration ?? '';
            _dateCtrl.text = c.date != null
                ? DateFormat('yyyy-MM-dd').format(c.date!)
                : '';

            final saved = _key(c.paymentMode ?? '');
            bool isMatch(String m) =>
                _key(m) == saved ||
                (saved == 'momo' && _key(m).contains('momo'));
            final match = _allowed.where(isMatch);
            _paymentMode = match.isEmpty ? null : match.first;

            _paymentAccount = c.paymentaccount ?? '';
            _selectedDate = c.date;
            phoneController.text = c.phone ?? '';
          }
          _ready = true;
        });
      } catch (_) {
        if (mounted) setState(() => _ready = true);
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _referenceCtrl.dispose();
    _narationCtrl.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
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
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  //Save
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_paymentAccount == null || _paymentAccount!.trim().isEmpty) {
      showMessage(context, Colors.red, 'Please select a payment account');
      return;
    }

    final modeKey = _key(_paymentMode ?? '');
    final isMomo = modeKey.contains('momo') || modeKey.contains('mobile money');

    if (isMomo &&
        (selectedMomoNetwork == null || selectedMomoNetwork!.isEmpty)) {
      showMessage(context, Colors.red, 'Please select MoMo network');
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    final datafeed = Provider.of<Datafeed>(context, listen: false);
    final amountText = _amountCtrl.text.trim();
    final transRef = _referenceCtrl.text.trim();
    final naration = _narationCtrl.text.trim();
    final paymentMode = isMomo ? 'momo' : modeKey;
    final payAccount = _paymentAccount ?? '';
    final selectedDate = _selectedDate;
    final phone = phoneController.text.trim();
    final momoNetwork = selectedMomoNetwork;
    final supplierid = widget.creditorId;

    final double amount;
    try {
      amount = double.parse(amountText);
    } catch (_) {
      showMessage(context, Colors.red, 'Invalid amount entered');
      setState(() => _saving = false);
      return;
    }

    String sanitize(String input) => input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    final ts = DateTime.now().millisecondsSinceEpoch;
    final docId =
        '${sanitize(datafeed.companyid)}_${sanitize(datafeed.staffPosition.toString())}_${sanitize(widget.creditorName)}_$ts';
    final now = DateTime.now();
    final day = DateFormat('EEEE').format(now);
    final year = now.year.toString();
    final month = '${now.year}.${now.month}';
    final weekNumber =
        ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;

    final week = '${now.year}.$weekNumber';
    final payDate = selectedDate ?? now;
    final dateymd = DateFormat('yyyy-MM-dd').format(payDate);
    try {
      final creditpay = CreditorBalance(
        id: docId,
        creditorId: widget.creditorId,
        creditorName: widget.creditorName,
        amount: amount,
        type: 'credit payment',
        paymentMode: paymentMode,
        transactionRef: transRef,
        naration: naration,
        date: selectedDate,
        branchid: widget.selectedBranch.isNotEmpty
            ? widget.selectedBranch
            : datafeed.branchid,
        companyid: datafeed.companyid,
        companyemail: datafeed.companyemail,
        paymentaccount: payAccount,
        phone: phone,
        staff: datafeed.staff,
        updatedby: '',
        updatedat: null,
        networktype: momoNetwork,
        day: day,
        week: week,
        month: month,
        yearr: year,
        dateymd: dateymd,
      );

      final batch = datafeed.db.batch();
      batch.set(
        datafeed.db.collection('creditor_payments').doc(docId),
        creditpay.toMap(),
      );
      batch.update(datafeed.db.collection('suppliers').doc(supplierid), {
        'debitaccount': FieldValue.increment(amount),
      });
      await batch.commit();

      final index = datafeed.creditorList.indexWhere(
        (item) => item['creditorId'] == supplierid,
      );
      final indexed = datafeed.creditorpayList.indexWhere((t) => t.id == docId);
      if (indexed == -1) {
        datafeed.creditorpayList.add(creditpay);
      } else {
        datafeed.creditorpayList[indexed] = creditpay;
      }

      if (index != -1) {
        final creditor = datafeed.creditorList[index];
        final newDebit = ((creditor['debit'] ?? 0) as num) + amount;
        final credit = ((creditor['credit'] ?? 0) as num);
        final newBalance = credit - newDebit;

        datafeed.creditorList[index] = {
          ...creditor,
          'debit': newDebit,
          'balance': newBalance,
        };
        datafeed.notifyListeners();
      }

      if (!mounted) return;

      _amountCtrl.clear();
      _dateCtrl.clear();
      _referenceCtrl.clear();
      _narationCtrl.clear();
      setState(() {
        _paymentMode = null;
        _paymentAccount = null;
      });

      showMessage(context, Colors.green, 'Payment saved successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showMessage(context, Colors.red, 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, _) {
        if (!_ready) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: _C.primary),
              ),
            ),
          );
        }
        final payModes = _payModes(datafeed);
        final accountList = _accountsFor(datafeed);
        final safeAccount = accountList.contains(_paymentAccount)
            ? _paymentAccount
            : null;
        final modeKey = _key(_paymentMode ?? '');
        final isMomo =
            modeKey.contains('momo') || modeKey.contains('mobile money');
        final isBank = modeKey.contains('bank_transfer');
        final isCheque = modeKey.contains('cheque');
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: _C.card(context),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
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
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            style: TextStyle(color: _C.textPri(context)),
                            decoration: _fieldDecoration('Amount'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Amount is required';
                              final n = double.tryParse(v.trim());
                              if (n == null) return 'Enter a valid number';
                              if (n <= 0) return 'Amount must be > 0';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            value: payModes.contains(_paymentMode)
                                ? _paymentMode
                                : null,
                            isExpanded: true,
                            dropdownColor: _C.card(context),
                            style: TextStyle(color: _C.textPri(context)),
                            decoration: _fieldDecoration('Payment Mode'),
                            items: payModes
                                .map(
                                  (m) => DropdownMenuItem<String>(
                                    value: m,
                                    child: Text(m),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              _paymentMode = v;
                              _paymentAccount = null;
                              _syncAccountToMode(datafeed);
                            }),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Select payment mode'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            key: ValueKey('acct_${_paymentMode ?? 'none'}'),
                            value: safeAccount,
                            isExpanded: true,
                            dropdownColor: _C.card(context),
                            style: TextStyle(color: _C.textPri(context)),
                            decoration: _fieldDecoration(
                              _paymentMode == null
                                  ? 'Payment Account (select mode first)'
                                  : accountList.isEmpty
                                  ? 'No account for this mode'
                                  : 'Payment Account',
                            ),
                            items: accountList
                                .map(
                                  (a) => DropdownMenuItem<String>(
                                    value: a,
                                    child: Text(a),
                                  ),
                                )
                                .toList(),
                            onChanged: accountList.isEmpty
                                ? null
                                : (v) => setState(() => _paymentAccount = v),
                            validator: (v) {
                              if (_paymentMode == null ||
                                  _paymentMode!.isEmpty) {
                                return 'Select payment mode first';
                              }
                              if (accountList.isNotEmpty &&
                                  (v == null || v.isEmpty)) {
                                return 'Select a payment account';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          if (isMomo) ...[
                            DropdownButtonFormField<String>(
                              value: selectedMomoNetwork,
                              isExpanded: true,
                              dropdownColor: _C.card(context),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: _fieldDecoration('Network'),
                              items: ['MTN', 'Vodafone', 'AirtelTigo']
                                  .map(
                                    (n) => DropdownMenuItem<String>(
                                      value: n,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.sim_card,
                                            color: n == 'MTN'
                                                ? Colors.yellow
                                                : n == 'Vodafone'
                                                ? Colors.red
                                                : Colors.blue,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(n),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null)
                                  setState(() => selectedMomoNetwork = v);
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(color: _C.textPri(context)),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\+?\d*'),
                                ),
                              ],
                              decoration: _fieldDecoration('Phone number'),
                              validator: (value) {
                                if (!isMomo) return null;
                                if (value == null || value.trim().isEmpty) {
                                  return 'Phone number is required for MoMo';
                                }
                                if (!RegExp(
                                  r'^(?:\+233|0)\d{9}$',
                                ).hasMatch(value.trim())) {
                                  return 'Enter a valid number (e.g. 0240**** or +23324****)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                          ],

                          TextFormField(
                            controller: _dateCtrl,
                            readOnly: true,
                            onTap: _pickDate,
                            style: TextStyle(color: _C.textPri(context)),
                            decoration: _fieldDecoration(
                              'Date',
                              suffix: Icon(
                                Icons.calendar_today,
                                color: _C.textSub(context),
                                size: 20,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Date is required'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            cursorColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            controller: _referenceCtrl,
                            style: TextStyle(color: _C.textPri(context)),
                            decoration: _fieldDecoration(
                              isCheque
                                  ? 'Cheque number *'
                                  : isBank
                                  ? 'Bank transfer reference'
                                  : 'Reference',
                            ),
                            validator: (v) =>
                                (isCheque && (v == null || v.trim().isEmpty))
                                ? 'Please enter cheque number'
                                : null,
                          ),
                          const SizedBox(height: 22),

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
                                      : const Text(
                                          'Save',
                                          style: TextStyle(color: Colors.white),
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
                                          CreditorPayablelistScreen(),
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

  InputDecoration _fieldDecoration(String label, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: _C.field(context),
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
      );
}

//Shared small widgets
class _FormLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FormLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        text,
        style: TextStyle(
          color: _C.textSub(context),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      if (required)
        Text(' *', style: TextStyle(color: _C.negative(context), fontSize: 12)),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: loading ? null : onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: loading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

class _BalanceChip extends StatelessWidget {
  final num balance;
  final bool isOwed;
  const _BalanceChip(this.balance, this.isOwed);

  @override
  Widget build(BuildContext context) {
    final isCredit = balance < 0; // negative = overpaid, supplier owes you
    final displayAmount = balance.abs();
    final color = isCredit ? _C.positive(context) : _C.textPri(context);
    final label = isCredit ? 'Owed to you' : null;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GHS ${NumberFormat('#,##0.00').format(displayAmount)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (label != null)
            Text(
              'Owed to you',
              style: TextStyle(color: _C.positive(context), fontSize: 9),
            ),
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String text;
  final Color color;
  const _AmountChip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
  );
}
