import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/creditorbalanceModel.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import 'creditopenbalance.dart';

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

class creditOpenBalViewPage extends StatefulWidget {
  const creditOpenBalViewPage({super.key});

  @override
  State<creditOpenBalViewPage> createState() => _creditOpenBalViewPageState();
}

class _creditOpenBalViewPageState extends State<creditOpenBalViewPage> {
  static const _allKey = '__all__';

  String searchQuery = '';
  DateTimeRange? selectedDate;
  String _selectedBranch = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  bool _searchOpen = false; // mobile only
  final _searchCtrl = TextEditingController();
  final verticalController = ScrollController();

  bool get _isMobile => MediaQuery.of(context).size.width < 800;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final df = context.read<Datafeed>();
      await df.getdata();
      if (df.isAdminLevel) df.fetchBranches();
      _load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    verticalController.dispose();
    super.dispose();
  }

  String _effectiveBranch(Datafeed df) =>
      df.isAdminLevel ? _selectedBranch : df.branchid;

  void _load() {
    if (!mounted) return;
    final df = context.read<Datafeed>();
    // no date picked -> load everything so non-admins are not stuck on "today"
    final range =
        selectedDate ??
        DateTimeRange(start: DateTime(2000), end: DateTime.now());
    df.fetchcreditoropenbal(range, _effectiveBranch(df));
  }

  List<CreditorBalance> _sortRows(List<CreditorBalance> rows) {
    final sorted = List<CreditorBalance>.from(rows);
    if (_sortColumnIndex == null) return sorted;

    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 1:
          cmp = a.creditorName.toLowerCase().compareTo(
            b.creditorName.toLowerCase(),
          );
          break;
        case 2:
          cmp = a.amount.compareTo(b.amount);
          break;
        case 3:
          cmp = (a.date?.millisecondsSinceEpoch ?? 0).compareTo(
            b.date?.millisecondsSinceEpoch ?? 0,
          );
          break;
        default:
          return 0;
      }
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
    });
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchCtrl.clear();
      searchQuery = '';
    });
  }

  Widget _expandableSearch() {
    final w = (MediaQuery.of(context).size.width * 0.22).clamp(180.0, 280.0);
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.centerRight,
      child: _searchOpen
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(width: w, child: _searchField(autofocus: true)),
            )
          : IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search, size: 24),
              onPressed: () => setState(() => _searchOpen = true),
            ),
    );
  }

  String _money(num v) => NumberFormat('#,##0.00').format(v);

  // ─── App bar pieces
  Widget _searchField({bool autofocus = false}) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchCtrl,
        autofocus: autofocus,
        onChanged: (v) => setState(() => searchQuery = v),
        style: TextStyle(color: _C.textPri(context), fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search creditor, phone, amount…',
          hintStyle: TextStyle(color: _C.textMuted(context), fontSize: 13),
          prefixIcon: Icon(Icons.search, color: _C.textSub(context), size: 20),
          // desktop: ✕ always collapses; mobile: ✕ only clears (the AppBar icon closes)
          suffixIcon: (_isMobile && _searchCtrl.text.isEmpty)
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: _C.textSub(context), size: 18),
                  onPressed: () {
                    if (_isMobile) {
                      _searchCtrl.clear();
                      setState(() => searchQuery = '');
                    } else {
                      _closeSearch();
                    }
                  },
                ),
          filled: true,
          fillColor: _C.field(context),
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
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _branchSelector(Datafeed df, {required bool compact}) {
    final branches = df.branches
        .where((b) => b.branchtype != 'Warehouse')
        .toList();

    // Non-admin: fixed label, no menu
    if (!df.isAdminLevel) {
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
                df.branch,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _C.textPri(context), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final match = branches.where((b) => b.id == _selectedBranch);
    final label = match.isEmpty ? 'All Branches' : match.first.branchname;

    return PopupMenuButton<String>(
      tooltip: 'Select branch',
      color: _C.card(context),
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        setState(() => _selectedBranch = v == _allKey ? '' : v);
        _load();
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: _allKey,
          child: Text(
            'All Branches',
            style: TextStyle(
              color: _selectedBranch.isEmpty ? _C.primary : _C.textSub(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...branches.map(
          (b) => PopupMenuItem<String>(
            value: b.id,
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

  PreferredSizeWidget _buildAppBar(Datafeed df, int recordCount) {
    final mobile = _isMobile;

    final Widget title = mobile
        ? (_searchOpen
              ? _searchField(autofocus: true)
              : Text(
                  'Opening Balances',
                  style: TextStyle(
                    color: _C.textPri(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ))
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creditor Opening Balances',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _C.textPri(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'View, edit and delete creditor opening balances',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _C.textSub(context), fontSize: 11),
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
        _branchSelector(df, compact: mobile),
        if (mobile)
          IconButton(
            tooltip: _searchOpen ? 'Close search' : 'Search',
            icon: Icon(_searchOpen ? Icons.close : Icons.search, size: 24),
            onPressed: () => _searchOpen
                ? _closeSearch()
                : setState(() => _searchOpen = true),
          )
        else
          _expandableSearch(),
        // Date range: admin levels only
        if (df.isAdminLevel && !(mobile && _searchOpen))
          ReusableDatePickerWidget(
            child: const Icon(Icons.calendar_today, size: 22),
            onDateSelected: (selection) {
              setState(() => selectedDate = selection);
              _load();
            },
          ),
        if (!(mobile && _searchOpen))
          IconButton(
            icon: const Icon(Icons.home, size: 25),
            tooltip: 'Home',
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (route) => false),
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
                  border: Border.all(color: _C.primary.withOpacity(0.25)),
                ),
                child: Text(
                  '$recordCount record${recordCount == 1 ? '' : 's'}',
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

  // ─── Build
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, df, _) {
        final rows = _sortRows(df.filtercreditorBalance(searchQuery));

        return Scaffold(
          backgroundColor: _C.bg(context),
          appBar: _buildAppBar(df, rows.length),
          floatingActionButton: FloatingActionButton(
            backgroundColor: _C.primary,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const creditOpenBalScreen()),
            ),
          ),
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
                    if (selectedDate != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Period: ${DateFormat.yMMMd().format(selectedDate!.start)} - ${DateFormat.yMMMd().format(selectedDate!.end)}',
                            style: TextStyle(
                              color: _C.textSub(context),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: df.isloadingcreditbal
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: _C.primary,
                              ),
                            )
                          : rows.isEmpty
                          ? _buildEmptyState()
                          : (_isMobile
                                ? _mobileList(rows)
                                : _desktopTable(rows)),
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
            searchQuery.isEmpty
                ? 'No opening balance found'
                : 'No results for "$searchQuery"',
            style: TextStyle(
              color: _C.textSub(context),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mobile cards
  Widget _mobileList(List<CreditorBalance> rows) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = rows[i];
        return Container(
          decoration: BoxDecoration(
            color: _C.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.divider(context)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  color: _C.header(context),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.creditorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      Text(
                        '#${i + 1}',
                        style: TextStyle(
                          color: _C.textMuted(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GHS ${_money(c.amount)}',
                        style: TextStyle(
                          color: _C.textPri(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: _C.textMuted(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c.date != null
                                ? DateFormat.yMMMd().format(c.date!)
                                : '',
                            style: TextStyle(
                              color: _C.textSub(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _C.divider(context)),
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        Icons.edit,
                        'Edit',
                        _C.primary,
                        () => _handleEdit(context, c.id, c),
                      ),
                    ),
                    Expanded(
                      child: _actionButton(
                        Icons.delete_outline,
                        'Delete',
                        _C.negative(context),
                        () => _handleDelete(context, c, c.id),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }

  // ─── Desktop table (header + ListView.builder)
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

  Widget _desktopTable(List<CreditorBalance> rows) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      child: Container(
        decoration: BoxDecoration(
          color: _C.card(context),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
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
                  Expanded(
                    flex: 3,
                    child: _headerCell('Creditor', columnIndex: 1),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _headerCell(
                        'Amount',
                        columnIndex: 2,
                        numeric: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _headerCell('Date', columnIndex: 3)),
                  SizedBox(
                    width: 96,
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
              child: Scrollbar(
                controller: verticalController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: verticalController,
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final c = rows[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? _C.card(context)
                            : _C.field(context).withOpacity(0.55),
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
                              '${i + 1}',
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
                              c.creditorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _C.textPri(context),
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'GHS ${_money(c.amount)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: _C.textPri(context),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text(
                              c.date != null
                                  ? DateFormat.yMMMd().format(c.date!)
                                  : '',
                              style: TextStyle(
                                color: _C.textSub(context),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 96,
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: Icon(
                                    Icons.edit,
                                    color: _C.primary,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _handleEdit(context, c.id, c),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: Icon(
                                    Icons.delete,
                                    color: _C.negative(context),
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _handleDelete(context, c, c.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Actions
  Future<void> _handleDelete(
    BuildContext context,
    CreditorBalance? creditdata,
    String id,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: _C.card(context),
        title: Text(
          'Delete opening balance for ${creditdata?.creditorName}?',
          style: TextStyle(color: _C.textPri(context)),
        ),
        content: Text(
          'This action cannot be undone. Are you sure?',
          style: TextStyle(color: _C.textSub(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: _C.textMuted(context)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.negative(context),
            ),
            onPressed: () => Navigator.pop(innerContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<Datafeed>().deletecreditoropenbal(creditdata, id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${creditdata?.creditorName}'s opening balance deleted successfully",
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete item',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleEdit(
    BuildContext context,
    String id,
    CreditorBalance? creditdata,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => creditOpenBalScreen(docId: id, item: creditdata),
      ),
    );
  }
}
