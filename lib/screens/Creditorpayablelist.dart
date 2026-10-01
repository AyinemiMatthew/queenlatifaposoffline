import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/creditorbalanceModel.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import 'Creditorpayable.dart';

class CreditorPayablelistScreen extends StatefulWidget {
  const CreditorPayablelistScreen({super.key});

  @override
  State<CreditorPayablelistScreen> createState() =>
      _CreditorPayablelistScreenState();
}

class _CreditorPayablelistScreenState extends State<CreditorPayablelistScreen> {
  static const _allKey = '__all__';

  String searchQuery = '';
  DateTimeRange? selectedDate;
  String _selectedBranch = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  bool _searchOpen = false; // mobile only
  final _searchCtrl = TextEditingController();
  final verticalController = ScrollController();
  final horizontalController = ScrollController();

  bool get _isMobile => MediaQuery.of(context).size.width < 800;

  void _sort<T>(
    Comparable<T> Function(dynamic d) getField,
    int columnIndex,
    bool ascending,
    List list,
  ) {
    list.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final df = context.read<Datafeed>();
      await df.getdata();
      df.fetchBranches();
      _load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  String _effectiveBranch(Datafeed df) =>
      df.isAdminLevel ? _selectedBranch : df.branchid;

  void _load() {
    if (!mounted) return;
    final df = context.read<Datafeed>();
    df.fetchCreditorPaylist(selectedDate, _effectiveBranch(df));
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

  Widget _searchField({bool autofocus = false}) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchCtrl,
        autofocus: autofocus,
        onChanged: (v) => setState(() => searchQuery = v),
        style: TextStyle(color: _C.textPri(context), fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search creditor, account, reference…',
          hintStyle: TextStyle(color: _C.textMuted(context), fontSize: 13),
          prefixIcon: Icon(Icons.search, color: _C.textSub(context), size: 20),
          // desktop: ✕ collapses; mobile: ✕ only clears (the AppBar icon closes)
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

  void _openPaymentDialog(CreditorBalance? creditor) {
    showDialog(
      context: context,
      builder: (_) => _CreditorPaymentDialog(creditinfo: creditor),
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
                color: _C.bg(context),
                borderRadius: BorderRadius.circular(10),
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
                  'Creditor Payments',
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
                'Creditor Payments',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _C.textPri(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'View, edit and delete payments made to creditors',
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

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredCreditorpayment = value.filterCreditorPaylist(
          searchQuery,
        );
        final screenWidth = MediaQuery.of(context).size.width;

        return Scaffold(
          backgroundColor: _C.bg(context),
          appBar: _buildAppBar(value, filteredCreditorpayment.length),
          floatingActionButton: FloatingActionButton(
            backgroundColor: _C.primary,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreditorPayableScreen()),
            ),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _isMobile ? 950 : 1400),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if (_isMobile)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${filteredCreditorpayment.length} record${filteredCreditorpayment.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: _C.textMuted(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: value.isLoadingcreditpaylist
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: _C.primary,
                                ),
                              )
                            : filteredCreditorpayment.isEmpty
                            ? Center(
                                child: Text(
                                  'No Creditor record found',
                                  style: TextStyle(color: _C.textSub(context)),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final isDesktop = screenWidth > 900;

                                  if (isDesktop) {
                                    return ScrollbarTheme(
                                      data: ScrollbarThemeData(
                                        thumbColor: MaterialStateProperty.all(
                                          _C.primary,
                                        ),
                                        trackColor: MaterialStateProperty.all(
                                          _C.surface(context),
                                        ),
                                        trackBorderColor:
                                            MaterialStateProperty.all(
                                              _C.divider(context),
                                            ),
                                        thickness: MaterialStateProperty.all(
                                          10,
                                        ),
                                        radius: const Radius.circular(8),
                                      ),
                                      child: Scrollbar(
                                        controller: verticalController,
                                        thumbVisibility: true,
                                        trackVisibility: true,
                                        child: Scrollbar(
                                          controller: horizontalController,
                                          thumbVisibility: true,
                                          trackVisibility: true,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            controller: horizontalController,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 1000,
                                                minWidth: 1000,
                                              ),
                                              child: _CreditorListTable(
                                                creditlist:
                                                    filteredCreditorpayment,
                                                context: context,
                                                sort: _sort,
                                                handleDelete: _handleDelete,
                                                handleEdit: _handleEdit,
                                                sortColumnIndex:
                                                    _sortColumnIndex,
                                                sortAscending: _sortAscending,
                                                verticalController:
                                                    verticalController,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  /// MOBILE
                                  return ListView.separated(
                                    itemCount: filteredCreditorpayment.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final creditorinfo =
                                          filteredCreditorpayment[index];
                                      return _buildMobileCard(creditorinfo);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileCard(CreditorBalance creditorinfo) {
    final id = creditorinfo.id;
    final creditorname = creditorinfo.creditorName;
    final amount = creditorinfo.amount;
    final paymentMode = creditorinfo.paymentMode;
    final paymentaccount = creditorinfo.paymentaccount;
    final transactionRef = creditorinfo.transactionRef;
    final createdAt = creditorinfo.date;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: _C.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _C.header(context),
              child: Text(
                'Creditor: $creditorname',
                softWrap: true,
                style: const TextStyle(
                  color: _C.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount: GHS $amount',
                    style: TextStyle(
                      color: _C.textPri(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Payment Method: $paymentMode',
                    style: TextStyle(color: _C.textSub(context), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Payment Account: ${paymentaccount ?? ''}',
                    style: TextStyle(color: _C.textSub(context), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transaction Ref: $transactionRef',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _C.textSub(context), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Divider(color: _C.divider(context)),
                  _buildFooterLabel(
                    Icons.calendar_today_outlined,
                    'Date: ${createdAt != null ? DateFormat.yMMMd().format(createdAt) : ''}',
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _C.divider(context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildActionButton(
                    Icons.edit,
                    'Edit',
                    _C.primary,
                    () => _handleEdit(context, id, creditorinfo),
                  ),
                ),
                Expanded(
                  child: _buildActionButton(
                    Icons.delete_outline,
                    'Delete',
                    _C.negative(context),
                    () => _handleDelete(context, creditorinfo, id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLabel(IconData icon, String label) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Icon(icon, size: 13, color: _C.textMuted(context)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _C.textMuted(context), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
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
          'Delete payment to ${creditdata?.creditorName}?',
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
        await context.read<Datafeed>().deleteCreditorpay(creditdata, id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${creditdata?.creditorName}'s creditor payment deleted successfully",
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
              content: Text('Failed to delete item'),
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
    _openPaymentDialog(creditdata);
  }
}

class _CreditorListTable extends StatelessWidget {
  final List<CreditorBalance> creditlist;
  final BuildContext context;
  final Function sort;
  final Function handleDelete;
  final Function handleEdit;
  final int? sortColumnIndex;
  final bool sortAscending;
  final ScrollController verticalController;

  const _CreditorListTable({
    required this.creditlist,
    required this.context,
    required this.sort,
    required this.handleDelete,
    required this.handleEdit,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.verticalController,
  });

  static const double _colHash = 40;
  static const double _colCreditor = 150;
  static const double _colAmount = 110;
  static const double _colPaymentMethod = 140;
  static const double _colPaymentAccount = 140;
  static const double _colReference = 120;
  static const double _colDate = 100;
  static const double _colAction = 110;

  Widget _headerCell(
    String label,
    double width, {
    int? columnIndex,
    Comparable Function(dynamic d)? getField,
  }) {
    final isSorted = columnIndex != null && sortColumnIndex == columnIndex;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: (columnIndex == null || getField == null)
            ? null
            : () {
                final ascending = isSorted ? !sortAscending : true;
                sort(getField, columnIndex, ascending, creditlist);
              },
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: _C.textSub(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSorted)
              Icon(
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: _C.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _dataCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(color: _C.textPri(context), fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Container(
          color: _C.card(context),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _headerCell('#', _colHash),
              _headerCell(
                'Creditor',
                _colCreditor,
                columnIndex: 1,
                getField: (d) => d.creditorName ?? '',
              ),
              _headerCell(
                'Amount',
                _colAmount,
                columnIndex: 2,
                getField: (d) => d.amount,
              ),
              _headerCell(
                'Payment Method',
                _colPaymentMethod,
                columnIndex: 3,
                getField: (d) => d.paymentMode ?? '',
              ),
              _headerCell(
                'Payment Account',
                _colPaymentAccount,
                columnIndex: 4,
                getField: (d) => d.paymentaccount ?? '',
              ),
              _headerCell(
                'Reference',
                _colReference,
                columnIndex: 5,
                getField: (d) => d.transactionRef ?? '',
              ),
              _headerCell(
                'Date',
                _colDate,
                columnIndex: 6,
                getField: (d) =>
                    d.date ?? DateTime.fromMillisecondsSinceEpoch(0),
              ),
              _headerCell('Action', _colAction),
            ],
          ),
        ),
        Container(height: 1, color: _C.divider(context)),

        // Body
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 700),
          child: ListView.builder(
            controller: verticalController,
            shrinkWrap: true,
            itemCount: creditlist.length,
            itemBuilder: (context, index) {
              final creditview = creditlist[index];

              final id = creditview.id;
              final creditor = creditview.creditorName;
              final amount = creditview.amount;
              final paymentMode = creditview.paymentMode;
              final transactionRef = creditview.transactionRef;
              final paymentAccount = creditview.paymentaccount;
              final createdAt = creditview.date;

              return Container(
                decoration: BoxDecoration(
                  color: index.isEven ? _C.bg(context) : _C.surface(context),
                  border: Border(
                    bottom: BorderSide(color: _C.divider(context), width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _dataCell('${index + 1}', _colHash),
                    _dataCell(creditor, _colCreditor),
                    _dataCell('GHS $amount', _colAmount),
                    _dataCell(paymentMode, _colPaymentMethod),
                    _dataCell(paymentAccount ?? '', _colPaymentAccount),
                    _dataCell(transactionRef, _colReference),
                    _dataCell(
                      createdAt != null
                          ? DateFormat.yMMMd().format(createdAt)
                          : '',
                      _colDate,
                    ),
                    SizedBox(
                      width: _colAction,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: _C.primary),
                            onPressed: () =>
                                handleEdit(context, id, creditview),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: _C.negative(context),
                            ),
                            onPressed: () =>
                                handleDelete(context, creditview, id),
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
      ],
    );
  }
}

// ─── Edit payment dialog
class _CreditorPaymentDialog extends StatefulWidget {
  final CreditorBalance? creditinfo;
  const _CreditorPaymentDialog({this.creditinfo});

  @override
  State<_CreditorPaymentDialog> createState() => _CreditorPaymentDialogState();
}

class _CreditorPaymentDialogState extends State<_CreditorPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _narationCtrl = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateCtrl = TextEditingController();

  DateTime? _selectedDate;
  String? _paymentMode;
  String? _paymentAccount;
  bool _saving = false;
  bool _ready = false;
  String? selectedMomoNetwork = 'MTN';
  List<String> _allowed = [];

  String _key(String m) => m
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<String> _payModes() {
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

  void _prefill(List<String> allowed) {
    final data = widget.creditinfo;
    if (data == null) return;

    _amountCtrl.text = data.amount.toString();
    _referenceCtrl.text = data.transactionRef;
    _narationCtrl.text = data.naration ?? '';
    _phoneController.text = data.phone ?? '';
    selectedMomoNetwork =
        ['MTN', 'Vodafone', 'AirtelTigo'].contains(data.networktype)
        ? data.networktype
        : 'MTN';

    if (data.date != null) {
      _selectedDate = data.date;
      _dateCtrl.text = DateFormat('dd/MM/yyyy').format(data.date!);
    }

    final saved = _key(data.paymentMode);
    final match = allowed.where(
      (m) => _key(m) == saved || (saved == 'momo' && _key(m).contains('momo')),
    );
    _paymentMode = match.isEmpty ? null : match.first;
    _paymentAccount = data.paymentaccount;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final df = context.read<Datafeed>();
      try {
        await df.getdata();
        final allowedSnapshot = List<String>.from(df.allowedPaymentMethods);
        await df.fetchpaiymentMethods();
        if (!mounted) return;
        final companyModes = df.linkedAccounts.keys.toList();
        final modes = df.isAdminLevel && allowedSnapshot.isEmpty
            ? companyModes
            : allowedSnapshot;
        setState(() {
          _allowed = modes;
          _prefill(modes);
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
    _referenceCtrl.dispose();
    _narationCtrl.dispose();
    _phoneController.dispose();
    _dateCtrl.dispose();
    super.dispose();
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
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final modeKey = _key(_paymentMode ?? '');
    final isMomo = modeKey.contains('momo') || modeKey.contains('mobile money');

    if (isMomo &&
        (selectedMomoNetwork == null || selectedMomoNetwork!.isEmpty)) {
      showMessage(context, Colors.red, 'Please select MoMo network');
      return;
    }

    // Guard: prevent concurrent saves
    if (_saving) return;
    setState(() => _saving = true);

    final datafeed = Provider.of<Datafeed>(context, listen: false);
    final docId = widget.creditinfo?.id;
    final supplierid = widget.creditinfo?.creditorId;
    final oldAmount = widget.creditinfo?.amount;
    final amountText = _amountCtrl.text.trim();
    final transRef = _referenceCtrl.text.trim();
    final naration = _narationCtrl.text.trim();
    final phone = _phoneController.text.trim();
    final paymentMode = isMomo ? 'momo' : modeKey; // normalized
    final payAccount = _paymentAccount ?? '';
    final selectedDate = _selectedDate;

    if (docId == null ||
        docId.isEmpty ||
        supplierid == null ||
        supplierid.isEmpty) {
      showMessage(context, Colors.red, 'Invalid record: missing ID');
      setState(() => _saving = false);
      return;
    }

    final double newAmount;
    try {
      newAmount = double.parse(amountText);
    } catch (_) {
      showMessage(context, Colors.red, 'Invalid amount entered');
      setState(() => _saving = false);
      return;
    }

    // Delta: edit -> difference; new record -> full amount
    final double debitIncrement = (oldAmount != null)
        ? newAmount - oldAmount
        : newAmount;

    final now = DateTime.now();
    final day = DateFormat('EEEE').format(now);
    final year = now.year.toString();
    final month = '${now.year}.${now.month}';
    final weekNumber =
        ((now.difference(DateTime(now.year, 1, 1)).inDays) / 7).floor() + 1;
    final week = '${now.year}.$weekNumber';

    // dateymd follows the payment date the user picked
    final dateymd = DateFormat('yyyy-MM-dd').format(selectedDate ?? now);

    final creditpay = CreditorBalance(
      id: docId,
      creditorId: supplierid,
      creditorName: widget.creditinfo!.creditorName,
      amount: newAmount,
      type: 'credit payment',
      paymentMode: paymentMode,
      transactionRef: transRef,
      naration: naration,
      phone: phone,
      date: selectedDate,
      branchid: widget.creditinfo?.branchid ?? datafeed.branchid,
      companyid: datafeed.companyid,
      companyemail: datafeed.companyemail,
      paymentaccount: payAccount,
      staff: datafeed.staff,
      updatedby: datafeed.staff,
      updatedat: DateTime.now(),
      networktype: isMomo ? selectedMomoNetwork : null,
      day: day,
      week: week,
      month: month,
      yearr: year,
    );

    try {
      final batch = datafeed.db.batch();

      // 1. Upsert the payment document
      batch.set(datafeed.db.collection('creditor_payments').doc(docId), {
        ...creditpay.toMap(),
        'dateymd': dateymd,
      });

      // 2. Apply delta only
      if (debitIncrement != 0) {
        batch.update(datafeed.db.collection('suppliers').doc(supplierid), {
          'debitaccount': FieldValue.increment(debitIncrement),
        });
      }

      await batch.commit();

      final indexed = datafeed.creditorpayList.indexWhere((t) => t.id == docId);
      if (indexed == -1) {
        datafeed.creditorpayList.add(creditpay);
      } else {
        datafeed.creditorpayList[indexed] = creditpay;
      }
      datafeed.notifyListeners();

      if (!mounted) return;

      showMessage(context, Colors.green, 'Payment updated successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showMessage(context, _C.negative(context), 'Error: $e');
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
        final payModes = _payModes();
        final accountList = _accountsFor(datafeed);
        final safeAccount = accountList.contains(_paymentAccount)
            ? _paymentAccount
            : null;
        final modeKey = _key(_paymentMode ?? '');
        final isMomo =
            modeKey.contains('momo') || modeKey.contains('mobile money');
        final isBank = modeKey.contains('bank');
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
                            cursorColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            controller: _amountCtrl,
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
                              if (n <= 0)
                                return 'Amount must be greater than 0';
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
                              value:
                                  [
                                    'MTN',
                                    'Vodafone',
                                    'AirtelTigo',
                                  ].contains(selectedMomoNetwork)
                                  ? selectedMomoNetwork
                                  : 'MTN',
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
                              controller: _phoneController,
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
                                  return 'Phone number is required for MoMo payment';
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
                            keyboardType: TextInputType.text,
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
                                          'Update',
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
                                  onPressed: () =>
                                      setState(() => _prefill(_allowed)),
                                  icon: Icon(
                                    Icons.refresh,
                                    color: _C.textPri(context),
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Reset',
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

class _C {
  static Color bg(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
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

class _FormLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FormLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
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
          Text(
            ' *',
            style: TextStyle(color: _C.negative(context), fontSize: 12),
          ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    return ElevatedButton(
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
}
