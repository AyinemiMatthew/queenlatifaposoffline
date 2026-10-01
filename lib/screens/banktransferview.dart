import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/appModuls.dart';
import 'package:kologsoft/models/banktransfermodel.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';
import 'banktransfer.dart';

class BanktransferView extends StatefulWidget {
  const BanktransferView({super.key});

  @override
  State<BanktransferView> createState() => _BanktransferViewState();
}

class _BanktransferViewState extends State<BanktransferView> {
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  bool _showSearch = false;
  bool _showBranchSelector = false;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  late final ScrollController verticalController;
  late final ScrollController horizontalController;

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
      _currentPage = 0;
    });
  }

  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void initState() {
    super.initState();
    verticalController = ScrollController();
    horizontalController = ScrollController();

    Future.microtask(() {
      context.read<Datafeed>().fetchBranches();

      context.read<Datafeed>().fetchBankTransfers(
        selectedDate,
        _selectedBranch,
      );
    });
  }

  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildBranchSelector(Datafeed value) {
    final colorScheme = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String?>(
      value: _selectedBranch,
      isExpanded: true,
      dropdownColor: colorScheme.surfaceContainerHighest,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: 'Branch',
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colorScheme.onSurface),
        isDense: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        prefixIcon: Icon(
          Icons.store_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All Branches'),
        ),
        ...value.branches.map(
          (branch) => DropdownMenuItem<String?>(
            value: branch.id,
            child: Text(branch.branchname, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (branchId) {
        setState(() {
          _selectedBranch = branchId;
          _showBranchSelector = false;
        });
        value.fetchBankTransfers(selectedDate, branchId);
      },
    );
  }

  Widget _buildSearchField() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: (text) {
        context.read<Datafeed>().updateSearch(text);
      },
      style: TextStyle(color: colorScheme.onSurface),
      cursorColor: colorScheme.primary,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search transfers...',
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
    );
  }

  // ── Sortable header cell used by the desktop ListView table
  Widget _headerCell(String label, {int? columnIndex, bool numeric = false}) {
    final isSorted = columnIndex != null && _sortColumnIndex == columnIndex;
    return InkWell(
      onTap: columnIndex == null
          ? null
          : () {
              final ascending = isSorted ? !_sortAscending : true;
              switch (columnIndex) {
                case 1:
                  _sort(
                    (d) => d.transferAccount ?? '',
                    columnIndex,
                    ascending,
                    context.read<Datafeed>().filterBankTransfer(),
                  );
                  break;
                case 2:
                  _sort(
                    (d) => d.receivingAccount ?? '',
                    columnIndex,
                    ascending,
                    context.read<Datafeed>().filterBankTransfer(),
                  );
                  break;
                case 3:
                  _sort(
                    (d) => d.narration ?? '',
                    columnIndex,
                    ascending,
                    context.read<Datafeed>().filterBankTransfer(),
                  );
                  break;
                case 4:
                  _sort(
                    (d) => d.amount,
                    columnIndex,
                    ascending,
                    context.read<Datafeed>().filterBankTransfer(),
                  );
                  break;
                case 5:
                  _sort(
                    (d) => d.date ?? DateTime(1970),
                    columnIndex,
                    ascending,
                    context.read<Datafeed>().filterBankTransfer(),
                  );
                  break;
              }
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: numeric
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          if (columnIndex != null) ...[
            const SizedBox(width: 2),
            Icon(
              isSorted
                  ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isSorted
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }

  // ── Desktop table built with ListView.builder + manual pagination
  Widget _desktopTable(List<BankTransferModel> rows) {
    final totalRows = rows.length;
    final totalPages = totalRows == 0 ? 1 : (totalRows / _rowsPerPage).ceil();
    final safePage = _currentPage.clamp(0, totalPages - 1);

    final start = safePage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, totalRows);
    final pageRows = totalRows == 0
        ? <BankTransferModel>[]
        : rows.sublist(start, end);

    return Column(
      children: [
        // Header row
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _headerCell('Transfer Acc', columnIndex: 1),
              ),
              Expanded(
                flex: 3,
                child: _headerCell('Receive Acc', columnIndex: 2),
              ),
              Expanded(
                flex: 3,
                child: _headerCell('Narration', columnIndex: 3),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _headerCell('Amount', columnIndex: 4, numeric: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _headerCell('Date', columnIndex: 5)),
              SizedBox(
                width: 90,
                child: Text(
                  'Action',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white24),

        // Rows
        Expanded(
          child: pageRows.isEmpty
              ? Center(
                  child: Text(
                    'No Bank transfer record found',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: pageRows.length,
                  itemBuilder: (context, i) {
                    final b = pageRows[i];
                    final globalIndex = start + i;
                    final transferbank = b.transferAccount ?? '';
                    final receivebank = b.receivingAccount ?? '';
                    final amount = b.amount;
                    final naration = b.narration ?? '';
                    final date = b.date;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(color: Colors.white12, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${globalIndex + 1}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Text(
                              transferbank,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              receivebank,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              naration,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'GHS $amount',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text(
                              date != null
                                  ? DateFormat.yMMMd().format(date)
                                  : '',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color: Colors.blueAccent,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () =>
                                      _handleEdit(context, b.id, b),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () =>
                                      _handleDelete(context, b, b.id),
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

        const Divider(height: 1, color: Colors.white24),

        // Pagination footer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Rows per page: ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                    ),
                  ),
                  DropdownButton<int>(
                    value: _rowsPerPage,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                    ),
                    underline: const SizedBox(),
                    items: const [5, 10, 20]
                        .map(
                          (v) => DropdownMenuItem(value: v, child: Text('$v')),
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
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: safePage > 0
                        ? () => setState(() => _currentPage = safePage - 1)
                        : null,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredbanktransferlist = value.filterBankTransfer();
        final screenWidth = MediaQuery.of(context).size.width;
        final filterWidth = (screenWidth - 190).clamp(120.0, 360.0);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: _showSearch
                ? SizedBox(width: filterWidth, child: _buildSearchField())
                : _showBranchSelector
                ? SizedBox(
                    width: filterWidth,
                    child: _buildBranchSelector(value),
                  )
                : const Text('Bank transfer list'),
            actions: [
              IconButton(
                tooltip: _showSearch ? 'Close search' : 'Search transfers',
                icon: Icon(_showSearch ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (_showSearch) _showBranchSelector = false;
                    if (!_showSearch) {
                      _searchController.clear();
                      value.updateSearch('');
                    }
                  });
                },
              ),
              IconButton(
                tooltip: _showBranchSelector
                    ? 'Close branch selector'
                    : 'Select branch',
                icon: Icon(
                  _showBranchSelector ? Icons.close : Icons.store_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _showBranchSelector = !_showBranchSelector;
                    if (_showBranchSelector) _showSearch = false;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.home, size: 25),
                tooltip: 'Home',
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/home', (route) => false);
                },
              ),
              ReusableDatePickerWidget(
                child: Icon(Icons.calendar_today, size: 25),
                onDateSelected: (selection) {
                  setState(() {
                    selectedDate = selection;
                  });
                  context.read<Datafeed>().fetchBankTransfers(
                    selectedDate,
                    _selectedBranch,
                  );
                },
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Banktransfer()),
              );
            },
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    if (selectedDate != null) ...[
                      Text(
                        ' List for the period of:',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        "${DateFormat.yMMMd().format(selectedDate!.start)} - ${DateFormat.yMMMd().format(selectedDate!.end)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],

                    Expanded(
                      child: value.isLoadingbtranlist
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : value.bankTransferList.isEmpty
                          ? Center(
                              child: Text(
                                'No Bank transfer record  found',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            )
                          : screenWidth > 700
                          ? _desktopTable(filteredbanktransferlist)
                          : ListView.separated(
                              itemCount: filteredbanktransferlist.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final filterbanklist =
                                    filteredbanktransferlist[index];

                                final id = filterbanklist.id;
                                final transferaccount =
                                    filterbanklist.transferAccount ?? '';
                                final receiveaccount =
                                    filterbanklist.receivingAccount ?? '';
                                final narration =
                                    filterbanklist.narration ?? '';
                                final amount = filterbanklist.amount ?? '0';
                                final date = filterbanklist.date;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.05),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          color: Colors.white.withOpacity(0.03),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amberAccent
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  transferaccount,
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.1,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "#: ${index + 1}",
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              SizedBox(height: 5),
                                              Text(
                                                "Amount: GHS $amount",
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Transfer account: $transferaccount",
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "Receive account: $receiveaccount",
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Divider(
                                                color: Colors.white24,
                                              ),

                                              Text(
                                                "Narration: $narration",
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Date: ${date != null ? DateFormat.yMMMd().format(date) : ''}',
                                                softWrap: true,
                                                maxLines: 2,
                                              ),
                                            ],
                                          ),
                                        ),

                                        Container(
                                          color: Colors.black26,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              if (value.canEdit(
                                                AppModules.accounts,
                                              ))
                                                Expanded(
                                                  child: _buildActionButton(
                                                    Icons.edit,
                                                    "",
                                                    Colors.blueAccent,
                                                    () {
                                                      _handleEdit(
                                                        context,
                                                        id,
                                                        filterbanklist,
                                                      );
                                                    },
                                                  ),
                                                ),

                                              if (value.canDelete(
                                                AppModules.accounts,
                                              ))
                                                Expanded(
                                                  child: _buildActionButton(
                                                    Icons.delete_outline,
                                                    "",
                                                    Colors.redAccent,
                                                    () => _handleDelete(
                                                      context,
                                                      filterbanklist,
                                                      id,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
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
      },
    );
  }

  Widget _buildFooterLabel(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 2),
        Text(
          text,
          softWrap: true,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    if (label.isEmpty) {
      return IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        tooltip: icon == Icons.edit ? 'Edit' : 'Delete',
      );
    }

    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }

  Future<void> _handleDelete(
    BuildContext context,
    BankTransferModel? banktransferdata,
    String id,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          "Delete bank transfer from ${banktransferdata?.transferAccount}?",
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          "This action cannot be undone. Are you sure?",
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(innerContext, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Accessing the provider
        await context.read<Datafeed>().deleteBankTransfer(id, banktransferdata);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${banktransferdata?.amount}'s transfer deleted successfully",
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to delete transfer"),
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
    BankTransferModel? banktransferdata,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Banktransfer(docId: id, data: banktransferdata),
      ),
    );
  }
}
