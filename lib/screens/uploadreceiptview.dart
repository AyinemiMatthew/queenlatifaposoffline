import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/screens/uploadreceipt.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../providers/Datafeed.dart';

class uploadReceiptViewPage extends StatefulWidget {
  const uploadReceiptViewPage({super.key});

  @override
  State<uploadReceiptViewPage> createState() => _uploadReceiptViewPageState();
}

class _uploadReceiptViewPageState extends State<uploadReceiptViewPage> {
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _secondaryTextColor =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _tableSurfaceColor =>
      Theme.of(context).brightness == Brightness.light
      ? Colors.white
      : const Color(0xFF1B263B);
  Color get _tableHeaderColor =>
      Theme.of(context).brightness == Brightness.light
      ? Colors.white
      : const Color(0xFF273043);
  Color get _cardSurfaceColor =>
      Theme.of(context).brightness == Brightness.light
      ? Colors.white
      : Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _cardBorderColor => Theme.of(context).brightness == Brightness.light
      ? Theme.of(context).colorScheme.outlineVariant
      : const Color(0xFF415A77);
  Color get _cardHeaderColor => Theme.of(context).brightness == Brightness.light
      ? Colors.white
      : const Color(0xFF273043);

  String searchQuery = '';
  DateTimeRange? selectedDate;
  String _selectedBranch = '';
  final TextEditingController _searchController = TextEditingController();
  bool _searchExpanded = false;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _rowsPerPage = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _receiptDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _selectedBranchLabel(Datafeed datafeed) {
    for (final branch in datafeed.branches) {
      if (branch.id == _selectedBranch) return branch.branchname;
    }
    return 'Select branch';
  }

  List<Map<String, dynamic>> _filterByDate(
    List<Map<String, dynamic>> receipts,
  ) {
    final range = selectedDate;
    if (range == null) return receipts;

    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day + 1);

    return receipts.where((receipt) {
      final date = _receiptDate(receipt['createdat']);
      return date != null && !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: selectedDate,
    );
    if (!mounted || range == null) return;
    setState(() => selectedDate = range);
  }

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

  String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final datafeed = Provider.of<Datafeed>(context, listen: false);
      _selectedBranch = datafeed.canSelectBranch
          ? (datafeed.selectedBranch != null &&
                    datafeed.selectedBranch!.branchtype != 'Warehouse'
                ? datafeed.selectedBranch!.id
                : '')
          : datafeed.activeBranchId;
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchUploadReceipts(
        selectedBranch: _selectedBranch,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final filteredreceipts = _filterByDate(value.filterUploadReceipts());

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0D1B2A)
              : theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: isDark
                ? const Color(0xFF0D1B2A)
                : colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            elevation: 0,
            title: _searchExpanded
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: value.updateSearch,
                    style: TextStyle(color: colorScheme.onSurface),
                    cursorColor: colorScheme.primary,
                    decoration: InputDecoration(
                      hintText: 'Search receipts',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: InputBorder.none,
                      isDense: true,
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                value.updateSearch('');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  )
                : const Text('Receipt View List'),
            actions: [
              if (value.canSelectBranch)
                PopupMenuButton<String>(
                  tooltip: _selectedBranch.isEmpty
                      ? 'All branches'
                      : _selectedBranchLabel(value),
                  icon: const Icon(Icons.store_outlined),
                  onSelected: (branchId) {
                    setState(() => _selectedBranch = branchId);
                    value.fetchUploadReceipts(
                      selectedBranch: branchId.isEmpty ? null : branchId,
                    );
                  },
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem<String>(
                      value: '',
                      checked: _selectedBranch.isEmpty,
                      child: const Text('All branches'),
                    ),
                    ...value.branches
                        .where((branch) => branch.branchtype != 'Warehouse')
                        .map(
                          (branch) => CheckedPopupMenuItem<String>(
                            value: branch.id,
                            checked: _selectedBranch == branch.id,
                            child: Text(branch.branchname),
                          ),
                        ),
                  ],
                ),
              if (value.isAdminLevel)
                IconButton(
                  tooltip: selectedDate == null
                      ? 'Filter by date'
                      : 'Change date filter',
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
              if (selectedDate != null && value.isAdminLevel)
                IconButton(
                  tooltip: 'Clear date filter',
                  onPressed: () => setState(() => selectedDate = null),
                  icon: const Icon(Icons.event_busy_outlined),
                ),
              IconButton(
                tooltip: _searchExpanded ? 'Close search' : 'Search receipts',
                onPressed: () {
                  setState(() {
                    _searchExpanded = !_searchExpanded;
                    if (!_searchExpanded) {
                      _searchController.clear();
                      value.updateSearch('');
                    }
                  });
                },
                icon: Icon(_searchExpanded ? Icons.close : Icons.search),
              ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: isDark
                ? const Color(0xFF415A77)
                : colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptUploadPage()),
              );
            },
          ),
          body: Container(
            decoration: isDark
                ? const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0D1B2A),
                        Color(0xFF1B263B),
                        Color(0xFF415A77),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      if (selectedDate != null) ...[
                        Text(
                          'Upload View List for the period of:',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        Text(
                          "${DateFormat.yMMMd().format(selectedDate!.start)} - ${DateFormat.yMMMd().format(selectedDate!.end)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: _secondaryTextColor,
                          ),
                        ),
                      ],

                      Expanded(
                        child: value.isLoadingReceipt
                            ? const Center(child: CircularProgressIndicator())
                            : filteredreceipts.isEmpty
                            ? Center(
                                child: Text(
                                  'No Upload list found',
                                  style: TextStyle(color: _secondaryTextColor),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final isDesktop = constraints.maxWidth > 600;

                                  if (isDesktop) {
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: 900,
                                          minWidth: 900,
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.vertical,
                                          child: DataTableTheme(
                                            data: DataTableThemeData(
                                              columnSpacing: 8,
                                              headingRowColor:
                                                  MaterialStateProperty.all(
                                                    _tableHeaderColor,
                                                  ),
                                              dataRowColor:
                                                  MaterialStateProperty.all(
                                                    _tableSurfaceColor,
                                                  ),
                                              headingTextStyle: TextStyle(
                                                color: _textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              dataTextStyle: TextStyle(
                                                color: _textColor,
                                              ),
                                              dividerThickness: 0.5,
                                            ),
                                            child: Theme(
                                              data: Theme.of(context).copyWith(
                                                cardColor: _tableSurfaceColor,
                                                dividerColor: Theme.of(
                                                  context,
                                                ).colorScheme.outlineVariant,
                                                iconTheme: IconThemeData(
                                                  color: _secondaryTextColor,
                                                ),
                                                canvasColor: _tableSurfaceColor,
                                                textTheme: TextTheme(
                                                  bodyMedium: TextStyle(
                                                    color: _textColor,
                                                  ),
                                                  bodySmall: TextStyle(
                                                    color: _textColor,
                                                  ),
                                                ),

                                                colorScheme: Theme.of(context)
                                                    .colorScheme
                                                    .copyWith(
                                                      surface:
                                                          _tableSurfaceColor,
                                                      onSurface: _textColor,
                                                    ),
                                              ),

                                              child: PaginatedDataTable(
                                                rowsPerPage: _rowsPerPage,
                                                availableRowsPerPage: const [
                                                  5,
                                                  10,
                                                  20,
                                                  50,
                                                  100,
                                                ],
                                                onRowsPerPageChanged: (value) {
                                                  setState(() {
                                                    _rowsPerPage = value!;
                                                  });
                                                },
                                                sortColumnIndex:
                                                    _sortColumnIndex,
                                                sortAscending: _sortAscending,

                                                headingRowColor:
                                                    MaterialStateProperty.all(
                                                      _tableHeaderColor,
                                                    ),

                                                columns: [
                                                  const DataColumn(
                                                    label: Text("#"),
                                                  ),

                                                  DataColumn(
                                                    label: const Text("Name"),
                                                    onSort: (index, ascending) {
                                                      _sort(
                                                        (d) => d['name'],
                                                        index,
                                                        ascending,
                                                        filteredreceipts,
                                                      );
                                                    },
                                                  ),

                                                  DataColumn(
                                                    label: const Text("Staff"),
                                                    onSort: (index, ascending) {
                                                      _sort(
                                                        (d) =>
                                                            d["createdBy"] ??
                                                            '',
                                                        index,
                                                        ascending,
                                                        filteredreceipts,
                                                      );
                                                    },
                                                  ),

                                                  DataColumn(
                                                    label: const Text("Branch"),
                                                    onSort: (index, ascending) {
                                                      _sort(
                                                        (d) =>
                                                            d['branch'] ?? '',
                                                        index,
                                                        ascending,
                                                        filteredreceipts,
                                                      );
                                                    },
                                                  ),
                                                  DataColumn(
                                                    label: const Text("Image"),
                                                    onSort: (index, ascending) {
                                                      _sort(
                                                        (d) =>
                                                            d['receiptUrl'] ??
                                                            '',
                                                        index,
                                                        ascending,
                                                        filteredreceipts,
                                                      );
                                                    },
                                                  ),
                                                  DataColumn(
                                                    label: const Text("Date"),
                                                    onSort: (index, ascending) {
                                                      _sort(
                                                        (d) =>
                                                            d['createdat'] ??
                                                            '',
                                                        index,
                                                        ascending,
                                                        filteredreceipts,
                                                      );
                                                    },
                                                  ),
                                                  const DataColumn(
                                                    label: Text("Action"),
                                                  ),
                                                ],

                                                source: ReceiptDataSource(
                                                  receipts: filteredreceipts,
                                                  context: context,
                                                  sort: _sort,
                                                  handleDelete: _handleDelete,
                                                  handleEdit: _handleEdit,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  /// MOBILE
                                  return ListView.separated(
                                    itemCount: filteredreceipts.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final receipt = filteredreceipts[index];

                                      final id = receipt['id'] ?? '';
                                      final name = receipt['name'] ?? '';
                                      final branch = receipt['branch'] ?? '';
                                      final staff = receipt['staff'] ?? '';
                                      final List receiptUrls =
                                          receipt['receiptUrl'] ?? [];
                                      final rawDate = receipt['createdat'];

                                      DateTime? parsedDate;

                                      if (rawDate is Timestamp) {
                                        parsedDate = rawDate.toDate();
                                      } else if (rawDate is String &&
                                          rawDate.isNotEmpty) {
                                        parsedDate = DateTime.tryParse(rawDate);
                                      }

                                      final createdDate = parsedDate != null
                                          ? DateFormat(
                                              'MMM dd, yyyy - hh:mm a',
                                            ).format(parsedDate)
                                          : '';
                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _cardSurfaceColor,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: _cardBorderColor,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                color: _cardHeaderColor,
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .amberAccent
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        "Name #$name",
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(
                                                                    context,
                                                                  ).brightness ==
                                                                  Brightness
                                                                      .light
                                                              ? const Color(
                                                                  0xFF8A5A00,
                                                                )
                                                              : Colors
                                                                    .amberAccent,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: 1.1,
                                                        ),
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    Text(
                                                      "#: ${index + 1}",
                                                      style: TextStyle(
                                                        color:
                                                            _secondaryTextColor,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Center(
                                                      child: Container(
                                                        height: 200,
                                                        width: 200,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              _cardSurfaceColor,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                _cardBorderColor,
                                                          ),
                                                        ),
                                                        child:
                                                            receiptUrls.isEmpty
                                                            ? Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .image_not_supported,
                                                                  size: 50,
                                                                  color:
                                                                      _secondaryTextColor,
                                                                ),
                                                              )
                                                            : ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                                child: PageView.builder(
                                                                  itemCount:
                                                                      receiptUrls
                                                                          .length,
                                                                  itemBuilder:
                                                                      (
                                                                        context,
                                                                        index,
                                                                      ) {
                                                                        final url =
                                                                            receiptUrls[index];

                                                                        return GestureDetector(
                                                                          onTap: () {
                                                                            showDialog(
                                                                              context: context,
                                                                              builder:
                                                                                  (
                                                                                    _,
                                                                                  ) => _ImagePreviewDialog(
                                                                                    imageUrl: url,
                                                                                  ),
                                                                            );
                                                                          },
                                                                          child: Image.network(
                                                                            url,
                                                                            fit:
                                                                                BoxFit.cover,
                                                                            errorBuilder:
                                                                                (
                                                                                  context,
                                                                                  error,
                                                                                  stackTrace,
                                                                                ) {
                                                                                  return const Icon(
                                                                                    Icons.error,
                                                                                    color: Colors.red,
                                                                                  );
                                                                                },
                                                                          ),
                                                                        );
                                                                      },
                                                                ),
                                                              ),
                                                      ),
                                                    ),
                                                    Divider(
                                                      color: _cardBorderColor,
                                                    ),

                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            _buildFooterLabel(
                                                              Icons
                                                                  .person_outline,
                                                              "Staff: $staff",
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            _buildFooterLabel(
                                                              Icons
                                                                  .calendar_today_outlined,
                                                              "Date: $createdDate",
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              Container(
                                                color: _cardHeaderColor,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: [
                                                    Text(
                                                      "Branch: $branch",
                                                      style: TextStyle(
                                                        color:
                                                            _secondaryTextColor,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                    Visibility(
                                                      visible: value.canEdit(
                                                        AppModules.accounts,
                                                      ),
                                                      child: _buildActionButton(
                                                        Icons.edit,
                                                        "Edit",
                                                        Colors.blueAccent,
                                                        () {
                                                          _handleEdit(
                                                            context,
                                                            id,
                                                            receipt,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    Visibility(
                                                      visible: value.canDelete(
                                                        AppModules.accounts,
                                                      ),
                                                      child: _buildActionButton(
                                                        Icons.delete_outline,
                                                        "Delete",
                                                        Colors.redAccent,
                                                        () => _handleDelete(
                                                          context,
                                                          name,
                                                          id,
                                                          receiptUrls,
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

  Widget _buildFooterLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _secondaryTextColor, size: 14),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: _textColor, fontSize: 12)),
      ],
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
    String name,
    String id,
    List url,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: _cardSurfaceColor,
        title: Text("Delete $name?", style: TextStyle(color: _textColor)),
        content: Text(
          "This action cannot be undone. Are you sure?",
          style: TextStyle(color: _secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext, false),
            child: Text("Cancel", style: TextStyle(color: _secondaryTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(innerContext, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Accessing the provider
        await context.read<Datafeed>().deleteUploadReceipt(id, url);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$name deleted successfully"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to delete item"),
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
    Map<String, dynamic> item,
  ) async {
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptUploadPage(docId: id, item: item),
      ),
    );
  }
}

class ReceiptDataSource extends DataTableSource {
  final List<Map<String, dynamic>> receipts;
  final BuildContext context;
  final Function sort;
  final Function handleDelete;
  final Function handleEdit;

  ReceiptDataSource({
    required this.receipts,
    required this.context,
    required this.sort,
    required this.handleDelete,
    required this.handleEdit,
  });

  @override
  DataRow getRow(int index) {
    final r = receipts[index];
    final List urls = r['receiptUrl'] ?? [];

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text("${index + 1}")),

        DataCell(Text(r['name'])),

        DataCell(Text(r['staff'])),

        DataCell(Text("${r['branch'] ?? ''}")),

        // DataCell(
        //   Row(
        //     children: (r['receiptUrl'] as List<dynamic>? ?? [])
        //         .take(3)
        //         .map((url) => Padding(
        //       padding: const EdgeInsets.all(4),
        //       child: Image.network(
        //         url,
        //         width: 40,
        //         height: 40,
        //         fit: BoxFit.cover,
        //       ),
        //     ))
        //         .toList(),
        //   ),
        // ),
        DataCell(
          Row(
            children: (r['receiptUrl'] as List<dynamic>? ?? [])
                .take(3)
                .map(
                  (url) => Padding(
                    padding: const EdgeInsets.all(4),
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => _ImagePreviewDialog(imageUrl: url),
                        );
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Image.network(
                          url,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        DataCell(
          Text(
            r['createdat'] != null
                ? (r['createdat'] as Timestamp)
                      .toDate()
                      .toString()
                      .split(' ')
                      .first
                : '',
          ),
        ),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: () {
                  handleEdit(context, r['id'], r);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () =>
                    handleDelete(context, r['name'], r['id'], urls),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => receipts.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

class _ImagePreviewDialog extends StatelessWidget {
  final String imageUrl;

  const _ImagePreviewDialog({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(child: Image.network(imageUrl)),

          //Close button
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
