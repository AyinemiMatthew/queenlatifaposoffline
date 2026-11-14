import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:kologsoft/screens/uploadreceipt.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../providers/Datafeed.dart';
import '../providers/item_provider.dart';

Future<void> _saveReceiptToDevice(
  BuildContext context,
  String url,
  String receiptName,
) async {
  try {
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('The receipt could not be downloaded.');
    }

    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/heic' => 'heic',
      'image/heif' => 'heif',
      'image/jpeg' => 'jpg',
      _ =>
        uri.pathSegments.isNotEmpty && uri.pathSegments.last.contains('.')
            ? uri.pathSegments.last.split('.').last.split('?').first
            : 'jpg',
    };
    final safeName = receiptName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final fileName =
        '${safeName}_receipt_${DateTime.now().millisecondsSinceEpoch}';

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: response.bodyBytes,
      fileExtension: extension,
      mimeType: MimeType.other,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt saved to your device.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not save receipt: $error')));
  }
}

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

  String _selectedBranchLabel(Datafeed datafeed) {
    for (final branch in datafeed.branches) {
      if (branch.id == _selectedBranch) return branch.branchname;
    }
    return 'Select branch';
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
        final itemProvider = context.watch<ItemProvider>();
        final filteredreceipts = itemProvider.filterReceipts(
          receipts: value.receiptList,
          query: value.searchQuery,
          dateRange: selectedDate,
        );

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
                  constraints: const BoxConstraints(maxWidth: 1300),
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
                                        constraints: const BoxConstraints(
                                          maxWidth: 1300,
                                          minWidth: 1300,
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
                                                    label: const Text(
                                                      "Description",
                                                    ),
                                                    onSort: (index, ascending) {
                                                      _sort(
                                                        (d) =>
                                                            d['description'] ??
                                                            '',
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
                                                    label: const Text(
                                                      "Receipt",
                                                    ),
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
                                      final description =
                                          (receipt['description'] ?? '')
                                              .toString();
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

                                      return StatefulBuilder(
                                        builder: (context, setState) {
                                          bool hovered = false;
                                          return MouseRegion(
                                            cursor: SystemMouseCursors.click,
                                            onEnter: (_) =>
                                                setState(() => hovered = true),
                                            onExit: (_) =>
                                                setState(() => hovered = false),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 150,
                                              ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _cardSurfaceColor,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: hovered
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : _cardBorderColor,
                                                  width: hovered ? 1.5 : 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        (hovered
                                                                ? Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary
                                                                : Colors.black)
                                                            .withOpacity(
                                                              hovered
                                                                  ? 0.08
                                                                  : 0.12,
                                                            ),
                                                    blurRadius: hovered
                                                        ? 16
                                                        : 10,
                                                    offset: const Offset(0, 5),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 14,
                                                          ),
                                                      color: _cardHeaderColor,
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  name,
                                                                  style: TextStyle(
                                                                    color:
                                                                        _textColor,
                                                                    fontSize:
                                                                        15,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Text(
                                                                  'Branch: $branch',
                                                                  style: TextStyle(
                                                                    color:
                                                                        _secondaryTextColor,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          IconButton(
                                                            tooltip: 'Download',
                                                            onPressed:
                                                                receiptUrls
                                                                    .isEmpty
                                                                ? null
                                                                : () async {
                                                                    await _saveReceiptToDevice(
                                                                      context,
                                                                      receiptUrls
                                                                          .first
                                                                          .toString(),
                                                                      name,
                                                                    );
                                                                  },
                                                            icon: const Icon(
                                                              Icons
                                                                  .download_rounded,
                                                            ),
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                          ),
                                                          if (value.canEdit(
                                                            AppModules.accounts,
                                                          ))
                                                            IconButton(
                                                              tooltip:
                                                                  'Edit receipt',
                                                              visualDensity:
                                                                  VisualDensity
                                                                      .compact,
                                                              onPressed: () =>
                                                                  _handleEdit(
                                                                    context,
                                                                    id,
                                                                    receipt,
                                                                  ),
                                                              icon: const Icon(
                                                                Icons
                                                                    .edit_outlined,
                                                              ),
                                                            ),
                                                          if (value.canDelete(
                                                            AppModules.accounts,
                                                          ))
                                                            IconButton(
                                                              tooltip:
                                                                  'Delete receipt',
                                                              visualDensity:
                                                                  VisualDensity
                                                                      .compact,
                                                              color: Theme.of(
                                                                context,
                                                              ).colorScheme.error,
                                                              onPressed: () =>
                                                                  _handleDelete(
                                                                    context,
                                                                    name,
                                                                    id,
                                                                    receiptUrls,
                                                                  ),
                                                              icon: const Icon(
                                                                Icons
                                                                    .delete_outline,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),

                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          if (receiptUrls
                                                              .isEmpty)
                                                            Container(
                                                              height: 160,
                                                              width: double
                                                                  .infinity,
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
                                                              child: Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .image_not_supported,
                                                                  size: 48,
                                                                  color:
                                                                      _secondaryTextColor,
                                                                ),
                                                              ),
                                                            )
                                                          else
                                                            SizedBox(
                                                              height: 160,
                                                              child: ListView.separated(
                                                                scrollDirection:
                                                                    Axis.horizontal,
                                                                itemCount:
                                                                    receiptUrls
                                                                        .length,
                                                                separatorBuilder:
                                                                    (_, __) =>
                                                                        const SizedBox(
                                                                          width:
                                                                              10,
                                                                        ),
                                                                itemBuilder:
                                                                    (
                                                                      context,
                                                                      imageIndex,
                                                                    ) {
                                                                      final url =
                                                                          receiptUrls[imageIndex]
                                                                              .toString();
                                                                      return GestureDetector(
                                                                        onTap: () => showDialog(
                                                                          context:
                                                                              context,
                                                                          builder: (_) => _ImagePreviewDialog(
                                                                            imageUrl:
                                                                                url,
                                                                          ),
                                                                        ),
                                                                        child: ClipRRect(
                                                                          borderRadius: BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                          child: Stack(
                                                                            children: [
                                                                              Image.network(
                                                                                url,
                                                                                width: 140,
                                                                                height: 160,
                                                                                fit: BoxFit.cover,
                                                                                errorBuilder:
                                                                                    (
                                                                                      context,
                                                                                      error,
                                                                                      stackTrace,
                                                                                    ) => Container(
                                                                                      width: 140,
                                                                                      height: 160,
                                                                                      color: Colors.grey.shade200,
                                                                                      child: const Icon(
                                                                                        Icons.broken_image_outlined,
                                                                                        color: Colors.red,
                                                                                      ),
                                                                                    ),
                                                                              ),
                                                                              Positioned(
                                                                                top: 8,
                                                                                right: 8,
                                                                                child: InkWell(
                                                                                  onTap: () async {
                                                                                    await _saveReceiptToDevice(
                                                                                      context,
                                                                                      url,
                                                                                      name,
                                                                                    );
                                                                                  },
                                                                                  child: Container(
                                                                                    padding: const EdgeInsets.all(
                                                                                      6,
                                                                                    ),
                                                                                    decoration: BoxDecoration(
                                                                                      color: Colors.black54,
                                                                                      borderRadius: BorderRadius.circular(
                                                                                        20,
                                                                                      ),
                                                                                    ),
                                                                                    child: const Icon(
                                                                                      Icons.download_rounded,
                                                                                      color: Colors.white,
                                                                                      size: 16,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                              ),
                                                            ),
                                                          const SizedBox(
                                                            height: 12,
                                                          ),
                                                          if (description
                                                              .isNotEmpty)
                                                            Container(
                                                              width: double
                                                                  .infinity,
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    10,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .surfaceContainerLowest,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      10,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                description,
                                                                style: TextStyle(
                                                                  color:
                                                                      _textColor,
                                                                  fontSize: 13,
                                                                  height: 1.4,
                                                                ),
                                                              ),
                                                            ),
                                                          const SizedBox(
                                                            height: 12,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Column(
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
                                                              ),
                                                              Text(
                                                                'No. ${index + 1}',
                                                                style: TextStyle(
                                                                  color:
                                                                      _secondaryTextColor,
                                                                  fontSize: 11,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
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

  Widget _buildActionMenu(
    BuildContext context, {
    required String name,
    required String id,
    required List<dynamic> urls,
    required Map<String, dynamic> receipt,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'download':
            if (urls.isNotEmpty) {
              await _saveReceiptToDevice(context, urls.first.toString(), name);
            }
            break;
          case 'edit':
            _handleEdit(context, id, receipt);
            break;
          case 'delete':
            _handleDelete(context, name, id, urls);
            break;
        }
      },
      itemBuilder: (context) => [
        if (urls.isNotEmpty)
          const PopupMenuItem(
            value: 'download',
            child: Row(
              children: [
                Icon(Icons.download_rounded, size: 18),
                SizedBox(width: 8),
                Text('Download'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
      ],
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
        final datafeed = context.read<Datafeed>();
        await context.read<ItemProvider>().deleteReceipt(
          datafeed: datafeed,
          id: id,
          imageUrls: List<String>.from(url),
        );

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
      color: MaterialStateProperty.resolveWith((states) {
        if (index.isEven) {
          return Theme.of(context).brightness == Brightness.light
              ? const Color(0xFFF3F7FA)
              : const Color(0xFF243247);
        }
        return null;
      }),
      cells: [
        DataCell(Text("${index + 1}")),

        DataCell(Text(r['name'])),

        DataCell(Text((r['description'] ?? '').toString())),

        DataCell(Text(r['staff'])),

        DataCell(Text("${r['branch'] ?? ''}")),

        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: (r['receiptUrl'] as List<dynamic>? ?? [])
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
                    child: SizedBox(
                      width: 96,
                      height: 72,
                      child: Material(
                        clipBehavior: Clip.antiAlias,
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            InkWell(
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) =>
                                    _ImagePreviewDialog(imageUrl: entry.value),
                              ),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Image.network(
                                  entry.value,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Download receipt',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _saveReceiptToDevice(
                                    context,
                                    entry.value.toString(),
                                    (r['name'] ?? 'receipt').toString(),
                                  ),
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
              PopupMenuButton<String>(
                tooltip: 'More actions',
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  switch (value) {
                    case 'download':
                      if (urls.isNotEmpty) {
                        await _saveReceiptToDevice(
                          context,
                          urls.first.toString(),
                          (r['name'] ?? 'receipt').toString(),
                        );
                      }
                      break;
                    case 'edit':
                      handleEdit(context, r['id'], r);
                      break;
                    case 'delete':
                      handleDelete(context, r['name'], r['id'], urls);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (urls.isNotEmpty)
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Download'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
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
