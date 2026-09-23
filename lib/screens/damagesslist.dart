import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../models/damageitem.dart';
import '../providers/Datafeed.dart';
import '../utils/damagepdf.dart';
import '../widgets/datepicker.dart';
import 'damages.dart';

class DamagesListPage extends StatefulWidget {
  const DamagesListPage({super.key});

  @override
  State<DamagesListPage> createState() => _DamagesListPageState();
}

class _DamagesListPageState extends State<DamagesListPage> {
  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();


  final GlobalKey _branchButtonKey = GlobalKey();

  String searchQuery = '';
  DateTimeRange? selectedDate;
  String? _selectedBranchId;

  bool _isSearching = false;

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

  bool _canManagePage(Datafeed value) => value.isAdminLevel;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final value = context.read<Datafeed>();

      await value.fetchBranches();

      if (!mounted) return;

      final branchId = _canManagePage(value)
          ? null
          : value.branchid;

      await value.fetchdamages(
        selectedDate: selectedDate,
        selectedBranch: branchId,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }


  List<damageitemmodel> filterdamages(Datafeed value) {
    if (searchQuery.trim().isEmpty) {
      return List.of(value.damages);
    }

    final q = searchQuery.trim().toLowerCase();

    return value.damages.where((s) {
      final itemMap = Map<String, dynamic>.from(s.item ?? {});

      final headerValues = <dynamic>[
        s.id,
        s.company,
        s.branchname,
        s.createdby,
        s.createdat,
        s.dateymd,
      ];

      final headerMatch = headerValues.any(
            (v) => v?.toString().toLowerCase().contains(q) ?? false,
      );

      if (headerMatch) return true;

      return itemMap.values.any((item) {
        if (item is! Map) return false;

        return <dynamic>[
          item['item'],
          item['itemid'],
          item['mode'],
          item['reason'],
          item['cp'],
          item['barcode'],
          item['modeqty'],
          item['quantity'],
          item['totalpieces'],
        ].any(
              (v) => v?.toString().toLowerCase().contains(q) ?? false,
        );
      });
    }).toList();
  }

  void _openSearch() {
    setState(() {
      _isSearching = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();

    setState(() {
      searchQuery = '';
      _isSearching = false;
    });
  }


  double _calcTotal(Map<String, dynamic> itemMap) {
    return itemMap.values.fold<double>(
      0,
          (sum, item) {
        if (item is Map) {
          final cp =
              double.tryParse(
                item['cp']?.toString() ?? '0',
              ) ??
                  0;

          final qty =
              double.tryParse(
                item['totalpieces']?.toString() ?? '0',
              ) ??
                  0;

          return sum + (cp * qty);
        }

        return sum;
      },
    );
  }



  Future<void> _reloadDamages(Datafeed value) async {
    final branchId = _canManagePage(value)
        ? _selectedBranchId
        : value.branchid;

    await value.fetchdamages(
      selectedDate: selectedDate,
      selectedBranch: branchId,
    );
  }



  Future<void> _showBranchDropdown(
      BuildContext context,
      Datafeed value,
      ) async {
    if (!_canManagePage(value)) return;

    if (value.branches.isEmpty) {
      await value.fetchBranches();
    }

    if (!mounted) return;

    final renderObject =
    _branchButtonKey.currentContext?.findRenderObject();

    if (renderObject is! RenderBox) return;

    final renderBox = renderObject;

    final position = renderBox.localToGlobal(
      Offset.zero,
    );

    final size = renderBox.size;

    final screenWidth = MediaQuery.sizeOf(context).width;

    final selected = await showMenu<String>(
      context: context,
      color: const Color(0xFF1B263B),
      elevation: 8,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + size.height + 4,
        screenWidth - position.dx - size.width,
        0,
      ),
      items: [
        // ALL BRANCHES
        PopupMenuItem<String>(
          value: '',
          height: 44,
          child: Row(
            children: [
              const Icon(
                Icons.apartment,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'All Branches',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_selectedBranchId == null)
                const Icon(
                  Icons.check,
                  color: Colors.greenAccent,
                  size: 18,
                ),
            ],
          ),
        ),

        // BRANCHES
        ...value.branches.map(
              (branch) {
            final id = branch.id;

            final name = branch.branchname.isNotEmpty
                ? branch.branchname
                : id;

            return PopupMenuItem<String>(
              value: id,
              height: 44,
              child: Row(
                children: [
                  const Icon(
                    Icons.store_outlined,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (_selectedBranchId == id)
                    const Icon(
                      Icons.check,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );

    if (!mounted || selected == null) return;

    setState(() {
      _selectedBranchId =
      selected.isEmpty ? null : selected;
    });

    await _reloadDamages(value);
  }

  String _selectedBranchLabel(Datafeed value) {
    if (_selectedBranchId == null) {
      return 'All Branches';
    }

    for (final branch in value.branches) {
      if (branch.id == _selectedBranchId) {
        return branch.branchname.isNotEmpty
            ? branch.branchname
            : 'Branch';
      }
    }

    return 'Branch';
  }

  void _showItemsDialog(
      BuildContext context,
      damageitemmodel damage,
      ) {
    final itemMap = Map<String, dynamic>.from(
      damage.item ?? {},
    );

    final entries = itemMap.entries.where((entry) {
      return entry.value is Map;
    }).toList();

    if (entries.isEmpty) {
      return;
    }

    double grandTotal = 0;

    for (final entry in entries) {
      final item = Map<String, dynamic>.from(
        entry.value as Map,
      );

      final cp =
          double.tryParse(
            item['cp']?.toString() ?? '0',
          ) ??
              0;

      final totalPieces =
          double.tryParse(
            item['totalpieces']?.toString() ?? '0',
          ) ??
              0;

      grandTotal += cp * totalPieces;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF101624),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 30,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 900,
              maxHeight: 650,
            ),
            child: Column(
              children: [
                // HEADER
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF22304A),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.amberAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Damage Items',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${entries.length} item${entries.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                // ITEMS
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item =
                      Map<String, dynamic>.from(
                        entries[index].value as Map,
                      );

                      final cp =
                          double.tryParse(
                            item['cp']?.toString() ?? '0',
                          ) ??
                              0;

                      final totalPieces =
                          double.tryParse(
                            item['totalpieces']?.toString() ?? '0',
                          ) ??
                              0;

                      final itemTotal =
                          cp * totalPieces;

                      final itemName =
                          item['item']?.toString() ?? 'Unknown Item';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B263B),
                          borderRadius:
                          BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            // ITEM NAME + TOTAL
                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${index + 1}. ${itemName.toUpperCase()}',
                                    maxLines: 2,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight:
                                      FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'GHC ${itemTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 14,
                                    fontWeight:
                                    FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // DETAILS
                            Wrap(
                              spacing: 20,
                              runSpacing: 8,
                              children: [
                                _dialogDetail(
                                  'Qty',
                                  '${item['quantity'] ?? '-'}',
                                ),

                                _dialogDetail(
                                  'Mode',
                                  '${item['mode'] ?? '-'}',
                                ),

                                _dialogDetail(
                                  'Mode Qty',
                                  '${item['modeqty'] ?? '-'}',
                                ),

                                _dialogDetail(
                                  'Total Pieces',
                                  '${item['totalpieces'] ?? '-'}',
                                ),

                                _dialogDetail(
                                  'CP',
                                  'GHC ${cp.toStringAsFixed(2)}',
                                ),

                                if (item['barcode'] != null)
                                  _dialogDetail(
                                    'Barcode',
                                    '${item['barcode']}',
                                  ),
                              ],
                            ),

                            if (item['reason'] != null &&
                                item['reason']
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding:
                                const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent
                                      .withOpacity(0.08),
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Description: ${item['reason']}',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // TOTAL
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF22304A),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'GRAND TOTAL',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'GHC ${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
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
  }

  Widget _dialogDetail(
      String label,
      String value,
      ) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBarIcon({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Color? color,
    double size = 19,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 34,
        minHeight: 40,
      ),
      visualDensity: const VisualDensity(
        horizontal: -3,
        vertical: -3,
      ),
      icon: Icon(
        icon,
        size: size,
        color: color ?? Colors.white,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final isDesktop = width >= 1050;
    final isSmall = width < 700;

    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredDamages = filterdamages(value);

        final canManage = _canManagePage(value);

        return Scaffold(
          backgroundColor: const Color(0xFF101624),

          appBar: AppBar(
            backgroundColor: const Color(0xFF101624),
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: isSmall ? 2 : 8,
            leading: _appBarIcon(
              icon: Icons.arrow_back,
              size: 21,
              tooltip: 'Back',
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),

            title: _isSearching
                ? Container(
              height: 44,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF22304A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,

                textAlignVertical:
                TextAlignVertical.center,

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),

                cursorColor: Colors.white,
                cursorWidth: 2,

                decoration: const InputDecoration(
                  hintText: 'Search damages...',
                  hintStyle: TextStyle(
                    color: Colors.white54,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                  ),

                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white54,
                    size: 22,
                  ),

                  prefixIconConstraints:
                  BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),

                  border: InputBorder.none,

                  isDense: true,

                  contentPadding:
                  EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                ),

                onChanged: (text) {
                  setState(() {
                    searchQuery = text;
                  });
                },
              ),
            )
                : const Text(
              'Damages List',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),



            actions: _isSearching
                ? [
              _appBarIcon(
                icon: Icons.clear,
                size: 18,
                tooltip: 'Close search',
                onPressed: _closeSearch,
              ),
            ]
                : [
              // SEARCH
              _appBarIcon(
                icon: Icons.search,
                size: 19,
                tooltip: 'Search damages',
                onPressed: _openSearch,
              ),

              // BRANCH DROPDOWN
              if (canManage)
                KeyedSubtree(
                  key: _branchButtonKey,
                  child: _appBarIcon(
                    icon: Icons.store_outlined,
                    size: 19,
                    tooltip: _selectedBranchId == null
                        ? 'All Branches'
                        : _selectedBranchLabel(value),
                    color:
                    _selectedBranchId != null
                        ? Colors.amberAccent
                        : Colors.white,
                    onPressed: () {
                      _showBranchDropdown(
                        context,
                        value,
                      );
                    },
                  ),
                ),

              // DATE
              if (!isSmall)
                ReusableDatePickerWidget(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      size: 19,
                    ),
                  ),
                  onDateSelected:
                      (selection) async {
                    setState(() {
                      selectedDate = selection;
                    });

                    await _reloadDamages(value);
                  },
                )
              else
                _appBarIcon(
                  icon: Icons.calendar_today,
                  size: 18,
                  tooltip: 'Date filter',
                  onPressed: () async {
                    final selection =
                    await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: selectedDate,
                      builder:
                          (context, child) {
                        return Theme(
                          data: Theme.of(context)
                              .copyWith(
                            colorScheme:
                            const ColorScheme.dark(
                              primary: Colors.blue,
                              onPrimary:
                              Colors.white,
                              surface:
                              Color(0xFF22304A),
                              onSurface:
                              Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (selection == null) {
                      return;
                    }

                    setState(() {
                      selectedDate = selection;
                    });

                    await _reloadDamages(value);
                  },
                ),
            ],
          ),


          floatingActionButton:
          FloatingActionButton(
            backgroundColor:
            const Color(0xFF415A77),
            tooltip: 'Register Damage',
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const Damages(),
                ),
              );
            },
          ),


          body: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 8 : 20,
              vertical: isSmall ? 8 : 20,
            ),
            child: Column(
              children: [
                if (canManage &&
                    _selectedBranchId != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 8,
                      ),
                      child: Text(
                        'Branch: ${_selectedBranchLabel(value)}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                Expanded(
                  child: value.isloadingdamages
                      ? const Center(
                    child:
                    CircularProgressIndicator(
                      color: Colors.white70,
                    ),
                  )
                      : filteredDamages.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons
                              .warning_amber_outlined,
                          color:
                          Colors.white30,
                          size: 42,
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Text(
                          searchQuery
                              .isEmpty
                              ? 'No damages found'
                              : 'No matching damages found',
                          style:
                          const TextStyle(
                            color:
                            Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  )
                      : Align(
                    alignment:
                    Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints:
                      const BoxConstraints(
                        maxWidth: 1200,
                      ),
                      child: isDesktop
                          ? _desktopTable(
                        filteredDamages,
                        value,

                      )
                          : _mobileList(
                        filteredDamages,
                        value,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _desktopTable(
      List<damageitemmodel> items,
      Datafeed value,
      ) {
    final source = _DamageDataSource(
      items: items,
      context: context,
      calcTotal: _calcTotal,

      onEdit: (d) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Damages(
              damageitem: d,
            ),
          ),
        );
      },

      onDelete: (d) {
        final itemMap =
        Map<String, dynamic>.from(
          d.item ?? {},
        );

        final firstItem =
        itemMap.values.isNotEmpty &&
            itemMap.values.first is Map
            ? itemMap.values.first
        as Map<String, dynamic>
            : <String, dynamic>{};

        _handleDelete(
          context,
          firstItem['item']?.toString() ?? '',
          d.id,
        );
      },

      onPrint: (d) async {
        final itemsMap =
        Map<String, dynamic>.from(
          d.item ?? {},
        );

        await DamageReportPdf.generate(
          header: {
            'company': d.company,
            'branchname': d.branchname,
            'createdby': d.createdby,
            'createdat': d.createdat,
          },
          itemsMap: itemsMap,
        );
      },

      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      value: value,
    );

    const columnWidths = <double>[
      30,
      250,
      140,
      90,
      90,
      250,
    ];

    const columnLabels = <String>[
      '#',
      'Item',
      'Total (GHS)',
      'Date',
      'Trx Date',
      'Actions',
    ];

    Widget buildHeaderLabel(int index) {
      final sortable = index == 1 || index == 2;

      final isActive =
          _sortColumnIndex == index;

      final label = Text(
        columnLabels[index],
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      );

      Widget content = label;

      if (sortable) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: index == 2
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (index == 2 && isActive) ...[
              Icon(
                _sortAscending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 4),
            ],
            label,
            if (index != 2 && isActive) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: Colors.white70,
                size: 14,
              ),
            ],
          ],
        );
      }

      final aligned = Align(
        alignment: index == 2
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: content,
      );

      return SizedBox(
        width: columnWidths[index],
        child: sortable
            ? InkWell(
          onTap: () {
            setState(() {
              if (_sortColumnIndex ==
                  index) {
                _sortAscending =
                !_sortAscending;
              } else {
                _sortColumnIndex = index;
                _sortAscending = true;
              }
            });
          },
          child: aligned,
        )
            : aligned,
      );
    }

    List<Widget> withSpacing(
        List<Widget> cells,
        ) {
      final spaced = <Widget>[];

      for (var i = 0;
      i < cells.length;
      i++) {
        spaced.add(cells[i]);

        if (i != cells.length - 1) {
          spaced.add(
            const SizedBox(width: 10),
          );
        }
      }

      return spaced;
    }

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor:
        MaterialStateProperty.all(
          const Color(0xFF415A77),
        ),
        trackColor:
        MaterialStateProperty.all(
          const Color(0xFF22304A),
        ),
        trackBorderColor:
        MaterialStateProperty.all(
          const Color(0xFF1B263B),
        ),
        thickness:
        MaterialStateProperty.all(10),
        radius: const Radius.circular(8),
      ),
      child: Scrollbar(
        controller: horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        notificationPredicate:
            (notif) => notif.depth == 1,
        child: SingleChildScrollView(
          controller: horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1050,
            child: Column(
              children: [
                Container(
                  height: 44,
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 15,
                  ),
                  color:
                  const Color(0xFF22304A),
                  child: Row(
                    children:
                    withSpacing(
                      List.generate(
                        columnLabels.length,
                        buildHeaderLabel,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: Scrollbar(
                    controller:
                    verticalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: ListView.builder(
                      controller:
                      verticalController,
                      itemCount:
                      source.rowCount,
                      itemBuilder:
                          (context, index) {
                        final cells =
                        source.getRow(
                          index,
                        );

                        if (cells == null) {
                          return const SizedBox();
                        }

                        return Container(
                          height: 52,
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 15,
                          ),
                          color:
                          const Color(
                              0xFF1B263B),
                          child: Row(
                            children:
                            withSpacing(
                              List.generate(
                                columnWidths
                                    .length,
                                    (i) {
                                  return SizedBox(
                                    width:
                                    columnWidths[
                                    i],
                                    child: Align(
                                      alignment:
                                      i == 2
                                          ? Alignment
                                          .centerRight
                                          : Alignment
                                          .centerLeft,
                                      child:
                                      cells[i],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _mobileList(
      List<damageitemmodel> filteredDamages,
      Datafeed value,
      ) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints:
        const BoxConstraints(maxWidth: 700),
        child: ListView.separated(
          itemCount: filteredDamages.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final damages =
            filteredDamages[index];

            final id = damages.id;

            final Map<String, dynamic>
            itemMap =
            Map<String, dynamic>.from(
              damages.item ?? {},
            );

            final firstItem =
            itemMap.values.isNotEmpty &&
                itemMap.values.first is Map
                ? itemMap.values.first
            as Map<String, dynamic>
                : <String, dynamic>{};

            final itemName =
                firstItem['item']
                    ?.toString() ??
                    '';

            final totalamountt =
            _calcTotal(itemMap);

            return Container(
              margin:
              const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 4,
              ),
              decoration: BoxDecoration(
                color:
                const Color(0xFF1B263B),
                borderRadius:
                BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white
                      .withOpacity(0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.2),
                    blurRadius: 12,
                    offset:
                    const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Container(
                      padding:
                      const EdgeInsets.all(
                        16,
                      ),
                      color: Colors.white
                          .withOpacity(0.03),
                      child: Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration:
                              BoxDecoration(
                                color: Colors
                                    .amberAccent
                                    .withOpacity(
                                    0.1),
                                borderRadius:
                                BorderRadius
                                    .circular(8),
                              ),
                              child: Text(
                                "ITEM #$itemName",
                                maxLines: 1,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                                style:
                                const TextStyle(
                                  color: Colors
                                      .amberAccent,
                                  fontSize: 14,
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                  letterSpacing:
                                  1.1,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Text(
                            "#: ${index + 1}",
                            style: TextStyle(
                              color: Colors.white70
                                  .withOpacity(
                                  0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ITEMS
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
                          ...itemMap.values
                              .map((item) {
                            if (item
                            is! Map<
                                String,
                                dynamic>) {
                              return const SizedBox();
                            }

                            final cp =
                                double.tryParse(
                                  item['cp']
                                      ?.toString() ??
                                      '0',
                                ) ??
                                    0;

                            final qty =
                                double.tryParse(
                                  item['totalpieces']
                                      ?.toString() ??
                                      '0',
                                ) ??
                                    0;

                            final itemCost =
                                cp * qty;

                            return Container(
                              margin:
                              const EdgeInsets
                                  .only(
                                bottom: 16,
                              ),
                              padding:
                              const EdgeInsets
                                  .all(12),
                              decoration:
                              BoxDecoration(
                                color:
                                Colors.black12,
                                borderRadius:
                                BorderRadius
                                    .circular(
                                    12),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child:
                                        Text(
                                          item['item']
                                              ?.toString()
                                              .toUpperCase() ??
                                              '',
                                          style:
                                          const TextStyle(
                                            color:
                                            Colors.white,
                                            fontWeight:
                                            FontWeight
                                                .w800,
                                            fontSize:
                                            16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                          width: 8),
                                      Text(
                                        "GHC ${itemCost.toStringAsFixed(2)}",
                                        style:
                                        const TextStyle(
                                          color:
                                          Colors.white,
                                          fontWeight:
                                          FontWeight
                                              .bold,
                                          fontSize:
                                          16,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Divider(
                                    color:
                                    Colors.white10,
                                    height: 20,
                                  ),

                                  Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(
                                          1),
                                      1: FlexColumnWidth(
                                          1),
                                    },
                                    children: [
                                      _buildTableRow(
                                        "Qty",
                                        "${item['quantity']} (${item['mode']})",
                                      ),

                                      if (item['cp'] !=
                                          null) ...[
                                        _buildTableRow(
                                          "CP",
                                          "GHC ${cp.toStringAsFixed(2)}",
                                        ),
                                        _buildTableRow(
                                          "Mode qty",
                                          "${item['modeqty']}",
                                        ),
                                      ],

                                      if (item[
                                      'barcode'] !=
                                          null)
                                        _buildTableRow(
                                          "Barcode",
                                          "${item['barcode']}",
                                        ),
                                    ],
                                  ),

                                  if (item[
                                  'reason'] !=
                                      null) ...[
                                    const SizedBox(
                                        height: 8),
                                    Container(
                                      width: double
                                          .infinity,
                                      padding:
                                      const EdgeInsets
                                          .all(8),
                                      decoration:
                                      BoxDecoration(
                                        color: Colors
                                            .redAccent
                                            .withOpacity(
                                            0.1),
                                        borderRadius:
                                        BorderRadius
                                            .circular(
                                            6),
                                      ),
                                      child: Text(
                                        "Description: ${item['reason']}",
                                        style:
                                        const TextStyle(
                                          color: Colors
                                              .redAccent,
                                          fontSize:
                                          12,
                                          fontWeight:
                                          FontWeight
                                              .w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),

                          const Divider(
                            color: Colors.white24,
                          ),

                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
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
                                      "Staff: ${damages.createdby}",
                                    ),

                                    const SizedBox(
                                        height: 4),

                                    _buildFooterLabel(
                                      Icons
                                          .calendar_today_outlined,
                                      "Date: ${damages.createdat.toString().substring(0, 10)}",
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(
                                  width: 10),

                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .end,
                                children: [
                                  const Text(
                                    "TOTAL AMOUNT",
                                    style:
                                    TextStyle(
                                      color: Colors
                                          .white54,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    "GHC ${totalamountt.toStringAsFixed(2)}",
                                    style:
                                    const TextStyle(
                                      color:
                                      Colors.white,
                                      fontSize: 20,
                                      fontWeight:
                                      FontWeight
                                          .w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ACTIONS
                    Container(
                      color: Colors.black26,
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      child: Wrap(
                        children: [
                          _buildActionButton(
                            Icons.print,
                            "Print",
                            Colors.tealAccent,
                                () async {
                              final itemsMap =
                              Map<String,
                                  dynamic>.from(
                                damages.item ?? {},
                              );

                              await DamageReportPdf
                                  .generate(
                                header: {
                                  'company':
                                  damages.company,
                                  'branchname':
                                  damages
                                      .branchname,
                                  'createdby':
                                  damages
                                      .createdby,
                                  'createdat':
                                  damages
                                      .createdat,
                                },
                                itemsMap: itemsMap,
                              );
                            },
                          ),

                          Visibility(
                            visible: value.canEdit(
                              AppModules.stock,
                            ),
                            child:
                            _buildActionButton(
                              Icons
                                  .edit_outlined,
                              "",
                              Colors.amber,
                                  () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        Damages(
                                          damageitem:
                                          damages,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),

                          Visibility(
                            visible: value.canDelete(
                              AppModules.stock,
                            ),
                            child:
                            _buildActionButton(
                              Icons
                                  .delete_outline,
                              "",
                              Colors.redAccent,
                                  () => _handleDelete(
                                context,
                                itemName,
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
    );
  }


  TableRow _buildTableRow(
      String label,
      String value,
      ) {
    return TableRow(
      children: [
        Padding(
          padding:
          const EdgeInsets.symmetric(
            vertical: 2,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ),
        Padding(
          padding:
          const EdgeInsets.symmetric(
            vertical: 2,
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLabel(
      IconData icon,
      String text,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white54,
          size: 14,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
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
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: color,
        size: 20,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
        ),
      ),
    );
  }



  Future<void> _handleDelete(
      BuildContext context,
      String itemName,
      String id,
      ) async {
    final confirm =
    await showDialog<bool>(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          backgroundColor:
          const Color(0xFF1B263B),
          title: Text(
            "Delete $itemName?",
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
          content: Text(
            "This action cannot be undone. Are you sure?",
            style: TextStyle(
              color:
              Colors.white.withOpacity(0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  innerContext,
                  false,
                );
              },
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                Colors.redAccent,
              ),
              onPressed: () {
                Navigator.pop(
                  innerContext,
                  true,
                );
              },
              child: const Text(
                "Delete",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await context
          .read<Datafeed>()
          .deletedamage(id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "$itemName deleted successfully",
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.green,
          behavior:
          SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Failed to delete item",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          backgroundColor:
          Colors.redAccent,
          behavior:
          SnackBarBehavior.floating,
        ),
      );
    }
  }
}


class _DamageDataSource {
  List<damageitemmodel> items;

  final BuildContext context;

  final double Function(
      Map<String, dynamic>,
      ) calcTotal;

  final void Function(
      damageitemmodel,
      ) onEdit;

  final void Function(
      damageitemmodel,
      ) onDelete;

  final Future<void> Function(
      damageitemmodel,
      ) onPrint;

  final Datafeed value;

  _DamageDataSource({
    required this.items,
    required this.context,
    required this.calcTotal,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    required this.value,
    int sortColumnIndex = 0,
    bool sortAscending = true,
  }) {
    _sort(
      sortColumnIndex,
      sortAscending,
    );
  }

  void _sort(
      int columnIndex,
      bool ascending,
      ) {
    items.sort(
          (a, b) {
        int result = 0;

        final aMap =
        Map<String, dynamic>.from(
          a.item ?? {},
        );

        final bMap =
        Map<String, dynamic>.from(
          b.item ?? {},
        );

        final aFirst =
        aMap.values.isNotEmpty &&
            aMap.values.first is Map
            ? aMap.values.first
        as Map<String, dynamic>
            : <String, dynamic>{};

        final bFirst =
        bMap.values.isNotEmpty &&
            bMap.values.first is Map
            ? bMap.values.first
        as Map<String, dynamic>
            : <String, dynamic>{};

        switch (columnIndex) {
          case 1:
            result = (aFirst['item']
                ?.toString() ??
                '')
                .compareTo(
              bFirst['item']
                  ?.toString() ??
                  '',
            );
            break;

          case 2:
            result = calcTotal(aMap)
                .compareTo(
              calcTotal(bMap),
            );
            break;
        }

        return ascending
            ? result
            : -result;
      },
    );
  }

  List<Widget>? getRow(int index) {
    if (index >= items.length) {
      return null;
    }

    final d = items[index];

    final itemMap =
    Map<String, dynamic>.from(
      d.item ?? {},
    );

    final firstItem =
    itemMap.values.isNotEmpty &&
        itemMap.values.first is Map
        ? itemMap.values.first
    as Map<String, dynamic>
        : <String, dynamic>{};

    final itemName =
        firstItem['item']?.toString() ?? '';

    final total = calcTotal(itemMap);

    final itemCount = itemMap.length;

    return [
      Text(
        '${index + 1}',
        style: const TextStyle(
          color: Colors.white70,
        ),
      ),

      Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        crossAxisAlignment:
        CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            itemName.toUpperCase(),
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '$itemCount item(s)',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ),

      Text(
        'GHC ${NumberFormat('#,##0.00').format(total)}',
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
        ),
      ),

      Text(
        d.createdat
            .toString()
            .substring(0, 10),
        style: const TextStyle(
          color: Colors.white70,
        ),
      ),

      Text(
        d.dateymd
            .toString()
            .substring(0, 10),
        style: const TextStyle(
          color: Colors.white70,
        ),
      ),

      Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.print,
              color: Colors.tealAccent,
              size: 18,
            ),
            onPressed: () => onPrint(d),
            tooltip: 'Print',
          ),

          Visibility(
            visible: value.canEdit(
              AppModules.stock,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: Colors.amber,
                size: 18,
              ),
              onPressed: () => onEdit(d),
              tooltip: 'Edit',
            ),
          ),

          Visibility(
            visible: value.canDelete(
              AppModules.stock,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 18,
              ),
              onPressed: () => onDelete(d),
              tooltip: 'Delete',
            ),
          ),
        ],
      ),
    ];
  }

  int get rowCount => items.length;
}



/*
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../models/damageitem.dart';
import '../providers/Datafeed.dart';
import '../utils/damagepdf.dart';
import '../widgets/datepicker.dart';
import 'damages.dart';

class DamagesListPage extends StatefulWidget {
  const DamagesListPage({super.key});

  @override
  State<DamagesListPage> createState() => _DamagesListPageState();
}

class _DamagesListPageState extends State<DamagesListPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _branchKey = GlobalKey();

  String searchQuery = '';
  DateTimeRange? selectedDate;
  String? _selectedBranchId;
  bool _isSearching = false;

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  final verticalController = ScrollController();
  final horizontalController = ScrollController();

  static const Color _cardColor = Color(0xFF1B263B);
  static const Color _textColor = Colors.white;

  bool _canManagePage(Datafeed value) => value.isAdminLevel;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final value = context.read<Datafeed>();
      await value.fetchBranches();

      if (!mounted) return;
      final branchId = _canManagePage(value) ? null : value.branchid;

      await value.fetchdamages(
        selectedDate: selectedDate,
        selectedBranch: branchId,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  String _branchLabel(Datafeed value) {
    if (!_canManagePage(value)) return value.branch;
    if (_selectedBranchId == null) return 'All Branches';

    final matches = value.branches.where((b) => b.id == _selectedBranchId);
    if (matches.isEmpty) return 'All Branches';
    return matches.first.branchname;
  }

  void _showBranchMenu(BuildContext context, Datafeed value) {
    final buttonObject = _branchKey.currentContext?.findRenderObject();
    final overlayObject = Overlay.of(context).context.findRenderObject();
    if (buttonObject is! RenderBox || overlayObject is! RenderBox) return;
    final RenderBox button = buttonObject;
    final RenderBox overlay = overlayObject;

    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        buttonPosition.dx,
        buttonPosition.dy + button.size.height,
        button.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String?>(
      context: context,
      position: position,
      color: _cardColor,
      items: [
        const PopupMenuItem<String?>(
          value: '__ALL__',
          child: Text(
            'All Branches',
            style: TextStyle(color: _textColor, fontSize: 13),
          ),
        ),
        ...{
          for (final b in value.branches) b.id: b,
        }.values.where((b) => b.id != null && b.id!.isNotEmpty).map(
              (b) => PopupMenuItem<String?>(
            value: b.id,
            child: Text(
              b.branchname,
              style: const TextStyle(color: _textColor, fontSize: 13),
            ),
          ),
        ),
      ],
    ).then((picked) {
      if (picked == null) return;
      final branch = picked == '__ALL__' ? null : picked;
      setState(() => _selectedBranchId = branch);
      _reloadDamages(value);
    });
  }
  List<damageitemmodel> filterdamages(Datafeed value) {
    if (searchQuery.trim().isEmpty) return List.of(value.damages);

    final q = searchQuery.trim().toLowerCase();

    return value.damages.where((s) {
      final itemMap = Map<String, dynamic>.from(s.item ?? {});


      final headerValues = <dynamic>[
        s.id,
        s.company,
        s.branchname,
        s.createdby,
        s.createdat,
        s.dateymd,
      ];

      final headerMatch = headerValues.any(
            (v) => v?.toString().toLowerCase().contains(q) ?? false,
      );

      if (headerMatch) return true;

      return itemMap.values.any((item) {
        if (item is! Map) return false;

        return <dynamic>[
          item['item'],
          item['itemid'],
          item['mode'],
          item['reason'],
          item['cp'],
          item['barcode'],
          item['modeqty'],
          item['quantity'],
          item['totalpieces'],
        ].any(
              (v) => v?.toString().toLowerCase().contains(q) ?? false,
        );
      });
    }).toList();
  }

  double _calcTotal(Map<String, dynamic> itemMap) {
    return itemMap.values.fold<double>(0, (sum, item) {
      if (item is Map) {
        final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
        final qty =
            double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
        return sum + (cp * qty);
      }
      return sum;
    });
  }

  Future<void> _reloadDamages(Datafeed value) async {
    final branchId = _canManagePage(value)
        ? _selectedBranchId
        : value.branchid;

    await value.fetchdamages(
      selectedDate: selectedDate,
      selectedBranch: branchId,
    );
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      searchQuery = '';
      _isSearching = false;
    });
  }

  String _selectedBranchLabel(Datafeed value) {
    if (_selectedBranchId == null) return 'All Branches';

    for (final branch in value.branches) {
      if (branch.id == _selectedBranchId) {
        return branch.branchname.isNotEmpty ? branch.branchname : 'Branch';
      }
    }
    return 'Branch';
  }

  void _showItemsDialog(BuildContext context, damageitemmodel damage) {
    final itemMap = Map<String, dynamic>.from(damage.item ?? {});
    final entries = itemMap.entries.where((e) => e.value is Map).toList();

    if (entries.isEmpty) return;

    double grandTotal = 0;
    for (final entry in entries) {
      final item = Map<String, dynamic>.from(entry.value as Map);
      final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
      final pieces = double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
      grandTotal += cp * pieces;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF101624),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 650),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF22304A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: Colors.amberAccent, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Damage Items',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${entries.length} item${entries.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final item = Map<String, dynamic>.from(entries[index].value as Map);
                    final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
                    final pieces = double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
                    final itemTotal = cp * pieces;
                    final itemName = item['item']?.toString() ?? 'Unknown Item';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B263B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${index + 1}. ${itemName.toUpperCase()}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'GHC ${itemTotal.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 20,
                            runSpacing: 8,
                            children: [
                              _dialogDetail('Qty', '${item['quantity'] ?? '-'}'),
                              _dialogDetail('Mode', '${item['mode'] ?? '-'}'),
                              _dialogDetail('Mode Qty', '${item['modeqty'] ?? '-'}'),
                              _dialogDetail('Total Pieces', '${item['totalpieces'] ?? '-'}'),
                              _dialogDetail('CP', 'GHC ${cp.toStringAsFixed(2)}'),
                              if (item['barcode'] != null) _dialogDetail('Barcode', '${item['barcode']}'),
                            ],
                          ),
                          if (item['reason'] != null && item['reason'].toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Description: ${item['reason']}',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF22304A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GRAND TOTAL', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(
                      'GHC ${grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogDetail(String label, String value) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _appBarIcon({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Color? color,
    double size = 19,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 34,
        minHeight: 40,
      ),
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      icon: Icon(
        icon,
        size: size,
        color: color ?? Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1050;
    final isSmall = width < 700;

    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredDamages = filterdamages(value);
        final canManage = _canManagePage(value);

        return Scaffold(
          backgroundColor: const Color(0xFF101624),
          appBar: AppBar(
            backgroundColor: const Color(0xFF101624),
            foregroundColor: Colors.white,
            elevation: 0,
            titleSpacing: isSmall ? 2 : 8,
            automaticallyImplyLeading: false,


            leading: canManage
                ? _appBarIcon(
              icon: Icons.close,
              size: 20,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            )
                : null,

            title: _isSearching
                ? Container(
              height: 38,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF22304A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Search damages...',
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white54,
                    size: 19,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                onChanged: (text) {
                  setState(() => searchQuery = text);
                },
              ),
            )
                : const Text(
              'Damages List',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            actions: _isSearching
                ? [
              _appBarIcon(
                icon: Icons.clear,
                size: 18,
                tooltip: 'Clear search',
                onPressed: _searchController.text.isEmpty
                    ? _closeSearch
                    : () {
                  _searchController.clear();
                  setState(() => searchQuery = '');
                  _searchFocusNode.requestFocus();
                },
              ),
            ]
                : [
// Search is available to everyone.
              _appBarIcon(
                icon: Icons.search,
                size: 19,
                tooltip: 'Search damages',
                onPressed: _openSearch,
              ),

// Branch filter is only available to the three admin roles.
              if (canManage)
                IconButton(
                  key: _branchKey,
                  tooltip: 'Branch: ${_branchLabel(value)}',
                  icon: const Icon(
                    Icons.store_outlined,
                    color: _textColor,
                    size: 21,
                  ),
                  onPressed: () => _showBranchMenu(context, value),
                ),

              if (!isSmall)
                ReusableDatePickerWidget(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.calendar_today, size: 19),
                  ),
                  onDateSelected: (selection) async {
                    setState(() => selectedDate = selection);
                    await _reloadDamages(value);
                  },
                )
              else
                _appBarIcon(
                  icon: Icons.calendar_today,
                  size: 18,
                  tooltip: 'Date filter',
                  onPressed: () async {
                    final selection = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: selectedDate,
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.blue,
                            onPrimary: Colors.white,
                            surface: Color(0xFF22304A),
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );

                    if (selection == null) return;
                    setState(() => selectedDate = selection);
                    await _reloadDamages(value);
                  },
                ),
            ],
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            tooltip: 'Register Damage',
            child: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Damages()),
            ),
          ),

          body: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 8 : 20,
              vertical: isSmall ? 8 : 20,
            ),
            child: Column(
              children: [
                if (canManage && _selectedBranchId != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Branch: ${_selectedBranchLabel(value)}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                Expanded(
                  child: value.isloadingdamages
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                    ),
                  )
                      : filteredDamages.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_outlined,
                          color: Colors.white30,
                          size: 42,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          searchQuery.isEmpty
                              ? 'No damages found'
                              : 'No matching damages found',
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  )
                      : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 1200,
                      ),
                      child: isDesktop
                          ? _desktopTable(
                        filteredDamages,
                        value,
                        onViewItems: (d) => _showItemsDialog(context, d),
                      )
                          : _mobileList(filteredDamages, value),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// DESKTOP TABLE

  Widget _desktopTable(
      List<damageitemmodel> items,
      Datafeed value,
      {required void Function(damageitemmodel) onViewItems}
      ) {
    final source = _DamageDataSource(
      items: items,
      context: context,
      calcTotal: _calcTotal,
      onEdit: (d) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Damages(damageitem: d)),
      ),
      onDelete: (d) {
        final itemMap = Map<String, dynamic>.from(d.item ?? {});
        final firstItem = itemMap.values.isNotEmpty && itemMap.values.first is Map
            ? Map<String, dynamic>.from(itemMap.values.first as Map)
            : {};

        final name = firstItem['item']?.toString() ?? '';
        _handleDelete(context, name.isEmpty ? 'this damage' : name, d.id);
      },
      onViewItems: onViewItems,
      onPrint: (d) async {
        final itemsMap = Map<String, dynamic>.from(d.item ?? {});
        await DamageReportPdf.generate(
          header: {
            'company': d.company,
            'branchname': d.branchname,
            'createdby': d.createdby,
            'createdat': d.createdat,
          },
          itemsMap: itemsMap,
        );
      },
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      value: value,
    );

    const columnWidths = <double>[30, 250, 140, 90, 90, 250];
    const columnLabels = <String>['#', 'Item', 'Total (GHS)', 'Date', 'Trx Date', 'Actions'];

    Widget buildHeaderLabel(int index) {
      final sortable = index == 1 || index == 2;
      final isActive = _sortColumnIndex == index;
      final label = Text(
        columnLabels[index],
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      );

      Widget content = label;
      if (sortable) {
        content = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
          index == 2 ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (index == 2 && isActive) ...[
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 4),
            ],
            label,
            if (index != 2 && isActive) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: Colors.white70,
                size: 14,
              ),
            ],
          ],
        );
      }

      final aligned = Align(
        alignment: index == 2 ? Alignment.centerRight : Alignment.centerLeft,
        child: content,
      );

      return SizedBox(
        width: columnWidths[index],
        child: sortable
            ? InkWell(
          onTap: () => setState(() {
            if (_sortColumnIndex == index) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumnIndex = index;
              _sortAscending = true;
            }
          }),
          child: aligned,
        )
            : aligned,
      );
    }

    List<Widget> withSpacing(List<Widget> cells) {
      final spaced = <Widget>[];
      for (var i = 0; i < cells.length; i++) {
        spaced.add(cells[i]);
        if (i != cells.length - 1) spaced.add(const SizedBox(width: 10));
      }
      return spaced;
    }

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(
          const Color(0xFF415A77),
        ),
        trackColor: MaterialStateProperty.all(
          const Color(0xFF22304A),
        ),
        trackBorderColor: MaterialStateProperty.all(
          const Color(0xFF1B263B),
        ),
        thickness: MaterialStateProperty.all(10),
        radius: const Radius.circular(8),
      ),
      child: Scrollbar(
        controller: horizontalController,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1050,
            child: Column(
              children: [
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  color: const Color(0xFF22304A),
                  child: Row(
                    children: withSpacing(
                      List.generate(columnLabels.length, buildHeaderLabel),
                    ),
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: verticalController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: ListView.builder(
                      controller: verticalController,
                      itemCount: source.rowCount,
                      itemBuilder: (context, index) {
                        final cells = source.getRow(index);
                        if (cells == null) return const SizedBox();
                        return Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          color: const Color(0xFF1B263B),
                          child: Row(
                            children: withSpacing(
                              List.generate(columnWidths.length, (i) {
                                return SizedBox(
                                  width: columnWidths[i],
                                  child: Align(
                                    alignment: i == 2
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: cells[i],
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

//  MOBILE LIST

  Widget _mobileList(List<damageitemmodel> filteredDamages,Datafeed value) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView.separated(
          itemCount: filteredDamages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final damages = filteredDamages[index];
            final id = damages.id;

            final Map<String, dynamic> itemMap =
            Map<String, dynamic>.from(damages.item ?? {});
            final firstItem = itemMap.values.isNotEmpty &&
                itemMap.values.first is Map
                ? Map<String, dynamic>.from(itemMap.values.first as Map)
                : {};
            final itemName = firstItem['item']?.toString() ?? '';
            final totalamountt = _calcTotal(itemMap);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B263B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
// ── header ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white.withOpacity(0.03),
                      child: Wrap(
                        spacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amberAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "ITEM #$itemName",
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          Text(
                            "#: ${index + 1}",
                            softWrap: true,
                            maxLines: 2,
                            style: TextStyle(
                                color: Colors.white70.withOpacity(0.5),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),

// ── items ──
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...itemMap.values.map((item) {
                            if (item is! Map) return const SizedBox();
                            final itemData = Map<String, dynamic>.from(item);
                            final cp = double.tryParse(item['cp']?.toString() ?? '0') ?? 0;
                            final qty = double.tryParse(item['totalpieces']?.toString() ?? '0') ?? 0;
                            final itemCost = cp * qty;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          itemData['item']?.toString().toUpperCase() ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "GHC ${itemCost.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white10, height: 20),
                                  Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(1),
                                      1: FlexColumnWidth(1),
                                    },
                                    children: [
                                      _buildTableRow("Qty", "${item['quantity']} (${item['mode']})"),
                                      if (item['cp'] != null) ...[
                                        _buildTableRow("CP", "GHC ${cp.toStringAsFixed(2)}"),
                                        _buildTableRow("Mode qty", "${item['modeqty']}"),
                                      ],
                                      if (item['barcode'] != null)
                                        _buildTableRow("Barcode", "${item['barcode']}"),
                                    ],
                                  ),
                                  if (itemData['reason'] != null &&
                                      itemData['reason'].toString().trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Description: ${item['reason']}",
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                          const Divider(color: Colors.white24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFooterLabel(Icons.person_outline,
                                      "Staff: ${damages.createdby}"),
                                  const SizedBox(height: 4),
                                  _buildFooterLabel(
                                      Icons.calendar_today_outlined,
                                      "Date: ${(damages.createdat.toString().length >= 10 ? damages.createdat.toString().substring(0, 10) : damages.createdat.toString())}"),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("TOTAL AMOUNT",
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 10)),
                                  Text(
                                    "GHC ${totalamountt.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

// ── actions ──
                    Container(
                      color: Colors.black26,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Wrap(
//  mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildActionButton(Icons.print, "Print",
                              Colors.tealAccent, () async {
                                final itemsMap =
                                Map<String, dynamic>.from(damages.item ?? {});
                                await DamageReportPdf.generate(
                                  header: {
                                    'company': damages.company,
                                    'branchname': damages.branchname,
                                    'createdby': damages.createdby,
                                    'createdat': damages.createdat,
                                  },
                                  itemsMap: itemsMap,
                                );
                              }),
                          Visibility(
                            visible: value.canEdit(AppModules.stock),
                            child: _buildActionButton(Icons.edit_outlined, "",   Colors.amber, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => Damages(damageitem: damages)),
                              );
                            }),
                          ),
                          Visibility(
                              visible: value.canDelete(AppModules.stock),
                              child: _buildActionButton(Icons.delete_outline, "",   Colors.redAccent,
                                      () => _handleDelete(
                                      context,
                                      itemName.isEmpty ? 'this damage' : itemName,
                                      id))),

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
    );
  }

// HELPERS

  TableRow _buildTableRow(String label, String value) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    ]);
  }

  Widget _buildFooterLabel(IconData icon, String text) {
    return Row(children: [
      Icon(icon, color: Colors.white54, size: 14),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    ]);
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }

  Future<void> _handleDelete(
      BuildContext context, String itemName, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (innerContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: Text("Delete $itemName?",
            style: const TextStyle(color: Colors.white)),
        content: Text("This action cannot be undone. Are you sure?",
            style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext, false),
            child:
            const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(innerContext, true),
            child:
            const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<Datafeed>().deletedamage(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("$itemName deleted successfully",style: TextStyle(color: Colors.white),),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Failed to delete item",style: TextStyle(color: Colors.white),),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }
}

// DATA SOURCE

class _DamageDataSource {
List<damageitemmodel> items;
final BuildContext context;
final double Function(Map<String, dynamic>) calcTotal;

final void Function(damageitemmodel) onEdit;
final void Function(damageitemmodel) onDelete;
final Future<void> Function(damageitemmodel) onPrint;


final void Function(damageitemmodel) onViewItems;

Datafeed value;

_DamageDataSource({
required this.items,
required this.context,
required this.calcTotal,
required this.onEdit,
required this.onDelete,
required this.onPrint,

// THIS NOW MATCHES THE FIELD ABOVE
required this.onViewItems,

required this.value,
int sortColumnIndex = 0,
bool sortAscending = true,
}) {
_sort(sortColumnIndex, sortAscending);
}
*/