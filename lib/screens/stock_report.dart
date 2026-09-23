import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../models/stockReport.dart';
import '../widgets/itemhistorypdf.dart';
import '../widgets/printStockReportPdf.dart';
class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {

  Datafeed? _datafeed;
  DateTimeRange? _selectedDateRange;
  String? _selectedType;
  String? _selectedCategory;
  String? _status;
  static const int _rowsPerPage = 10;
  int _currentPage = 0;
  bool _isSearching = false;
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _branchKey = GlobalKey();
  final GlobalKey _typeKey = GlobalKey();
  final GlobalKey _categoryKey = GlobalKey();
  final GlobalKey _statusKey = GlobalKey();
  static const Color _accent = Color(0xFF6366F1);
  final NumberFormat _nf = NumberFormat('#,##0.00');
  String _sortBy = 'lastUpdate';
  bool _sortAscending = false;
  String? selectedBranch;
  String? selectedBranchName;

  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;
  late final ScrollController _vController;
  late final ScrollController _hController;
  late final ScrollController _vvController;
  late final ScrollController _hhController;
  late final TextEditingController _searchController;
  late final ScrollController _footerHController;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Datafeed>().updateSearch('');
      context.read<Datafeed>().updateStockReportSearch('');
      context.read<Datafeed>().updateStockDialogSearch('');
      context.read<Datafeed>().updateItemHistorySearch('');
    });
    _verticalController = ScrollController();
    _horizontalController = ScrollController();


    _vController = ScrollController();
    _hController = ScrollController();
    _vvController = ScrollController();
    _hhController = ScrollController();
    _searchController = TextEditingController();
    _footerHController = ScrollController();
    Future.microtask(() async {
      if (!mounted) return;

      final datafeed = context.read<Datafeed>();
      await datafeed.fetchBranches();
      final access =  datafeed.accesslevel.toLowerCase().trim();

      final canSelectBranches = access == 'super admin' || access == 'systemadmin' ||  access == 'admin';

      if (!canSelectBranches) {
        selectedBranch = datafeed.branchid;
        selectedBranchName = datafeed.branch;
      }

      await datafeed.fetchstockreport(
        selectedBranch: selectedBranch,
      );
    });

    _hController.addListener(() {
      if (_footerHController.hasClients &&
          _footerHController.offset != _hController.offset) {
        _footerHController.jumpTo(_hController.offset);
      }
    });
    _footerHController.addListener(() {
      if (_hController.hasClients &&
          _hController.offset != _footerHController.offset) {
        _hController.jumpTo(_footerHController.offset);
      }
    });

  }


  Future<void> _applyFilters() async {
    await context.read<Datafeed>().fetchstockreport(
      selectedDate: _selectedDateRange,
      selectedBranch: selectedBranch,
    );
  }
  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Select Date Range', style: TextStyle(color: Color(0xFFF9FAFB))),
        content: SizedBox(
          height: 400,
          width: 320,
            child: SfDateRangePicker(
              backgroundColor: const Color(0xFF101624),

              headerStyle: const DateRangePickerHeaderStyle(
                backgroundColor: Color(0xFF1E293B),
                textAlign: TextAlign.center,
                textStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),

              monthViewSettings: const DateRangePickerMonthViewSettings(
                viewHeaderStyle: DateRangePickerViewHeaderStyle(
                  textStyle: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              monthCellStyle: DateRangePickerMonthCellStyle(
                textStyle: const TextStyle(
                  color: Colors.white,
                ),

                todayTextStyle: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),

                weekendTextStyle: const TextStyle(
                  color: Colors.white60,
                ),

                disabledDatesTextStyle: const TextStyle(
                  color: Colors.white24,
                ),
              ),

              selectionColor: Colors.blueAccent,
              startRangeSelectionColor: Colors.blueAccent,
              endRangeSelectionColor: Colors.blueAccent,
              rangeSelectionColor: Colors.blueAccent.withOpacity(0.15),

              todayHighlightColor: Colors.blueAccent,

              selectionTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),

              onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                if (args.value is PickerDateRange) {
                  final range = args.value as PickerDateRange;
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: range.startDate!,
                      end: range.endDate ?? range.startDate!,
                    );
                  });
                }
              },

              selectionMode: DateRangePickerSelectionMode.range,

              initialSelectedRange: _selectedDateRange != null
                  ? PickerDateRange(
                _selectedDateRange!.start,
                _selectedDateRange!.end,
              )
                  : null,
            )
        ),

        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _applyFilters();
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  String _formatDateRange() {
    if (_selectedDateRange == null) return 'All dates';
    return '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _datafeed = context.read<Datafeed>();
  }
  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _vController.dispose();
    _hController.dispose();
    _vvController.dispose();
    _hhController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _footerHController.dispose();
    final datafeed = _datafeed;
    if (datafeed != null) {
      Future.microtask(() {
        datafeed.updateSearch('');
        datafeed.updateStockReportSearch('');
        datafeed.updateStockDialogSearch('');
        datafeed.updateItemHistorySearch('');
      });
    }

    super.dispose();
  }

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

  List<Map<String, dynamic>> _rows(Datafeed p) => p.filterstockreport(
      productType: _selectedType, category: _selectedCategory, status: _status);

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch(Datafeed p) {
    setState(() { _isSearching = false; _searchController.clear(); });
    p.updateStockReportSearch('');
  }

  String _filterSummary() {
    final parts = [
      if (_selectedType != null) _selectedType!,
      if (_selectedCategory != null) _selectedCategory!,
      if (_status != null) _status!,
    ];
    return parts.isEmpty ? '' : ' • ${parts.join(' • ')}';
  }

  int get _totalPages {
    final totalItems = _rows(context.read<Datafeed>()).length;
    return totalItems == 0 ? 1 : ((totalItems - 1) ~/ _rowsPerPage) + 1;
  }

  List<Map<String, dynamic>> _pageRows(List<Map<String, dynamic>> rows, [int? pageIndex]) {
    if (rows.isEmpty) return const [];
    final safePage = (pageIndex ?? _currentPage).clamp(0, ((rows.length - 1) ~/ _rowsPerPage));
    final start = safePage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  void _resetPage() => setState(() => _currentPage = 0);

  List<Widget> _appBarActions(BuildContext context, Datafeed provider, List<Map<String, dynamic>> stockreport, bool compact) {
    Widget filterIcon(GlobalKey k, IconData icon, String tip, bool active, VoidCallback onTap) =>
        IconButton(
          key: k,
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, size: 21, color: active ? _accent : AppColors.textPrimary),
        );

    String _dateRangeStr() =>
        '${DateFormat('d MMMM y').format(_selectedDateRange?.start ?? DateTime.now())} - '
            '${DateFormat('d MMMM y').format(_selectedDateRange?.end ?? DateTime.now())}';

    void _downloadPdf() => printStockReportPdf(
      reportData: stockreport,
      companyName: provider.company,
      branchName: selectedBranchName ?? 'All Branches',
      dateRange: _dateRangeStr(),
    );

    void _downloadExcel() => exportStockReportExcel(
      reportData: stockreport,
      companyName: provider.company,
      branchName: selectedBranchName ?? 'All Branches',
      dateRange: _dateRangeStr(),
      productType: _selectedType,
      category: _selectedCategory,
    );

    // Combined "Download / Stock status" dropdown
    Widget downloadStatusMenu() => PopupMenuButton<String>(
      key: _statusKey,
      tooltip: 'Download / Stock status',
      color: AppColors.surface,
      icon: Icon(
        Icons.file_download_outlined,
        size: 21,
        color: _status != null ? _accent : AppColors.textPrimary,
      ),
      itemBuilder: (_) => [
        const PopupMenuItem<String>(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.white70),
              SizedBox(width: 10),
              Text('Download PDF'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'excel',
          child: Row(
            children: [
              Icon(Icons.grid_on_outlined, size: 18, color: Colors.white70),
              SizedBox(width: 10),
              Text('Download Excel'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'status_all',
          child: Text('All Stock',
              style: TextStyle(color: _status == null ? _accent : Colors.white)),
        ),
        PopupMenuItem<String>(
          value: 'status_finished',
          child: Text('Finished',
              style: TextStyle(color: _status == 'Finished' ? _accent : Colors.white)),
        ),
        PopupMenuItem<String>(
          value: 'status_reorder',
          child: Text('Reorder',
              style: TextStyle(color: _status == 'Reorder' ? _accent : Colors.white)),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'pdf':
            _downloadPdf();
            break;
          case 'excel':
            _downloadExcel();
            break;
          case 'status_all':
            setState(() => _status = null);
            _resetPage();
            break;
          case 'status_finished':
            setState(() => _status = 'Finished');
            _resetPage();
            break;
          case 'status_reorder':
            setState(() => _status = 'Reorder');
            _resetPage();
            break;
        }
      },
    );

    final commonActions = <Widget>[];

    if (!provider.isAdminLevel) {
      commonActions.add(
        IconButton(
          icon: const Icon(Icons.home, size: 25),
          tooltip: 'Home',
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
        ),
      );
    }

    commonActions.add(
      IconButton(
        tooltip: 'Search',
        icon: const Icon(Icons.search, size: 21),
        onPressed: _openSearch,
      ),
    );

    if (provider.canDeleteRecords || provider.isAdminLevel) {
      commonActions.add(
        IconButton(
          key: _branchKey,
          tooltip: 'Branch: ${selectedBranchName ?? 'All Branches'}',
          icon: const Icon(Icons.store_outlined, size: 21),
          onPressed: () => _showBranchMenu(provider),
        ),
      );
    }

    commonActions.addAll([
      IconButton(
        tooltip: _formatDateRange(),
        icon: Icon(Icons.date_range, size: 21,
            color: _selectedDateRange != null ? _accent : AppColors.textPrimary),
        onPressed: _showDateRangePicker,
      ),
      filterIcon(_typeKey, Icons.inventory_2_outlined,
          'Product type: ${_selectedType ?? 'All'}', _selectedType != null,
              () => _showFilterMenu(_typeKey, 'All Product Types',
              provider.stockProductTypes, _selectedType,
                  (v) {
                setState(() => _selectedType = v);
                _resetPage();
              })),
      filterIcon(_categoryKey, Icons.category_outlined,
          'Category: ${_selectedCategory ?? 'All'}', _selectedCategory != null,
              () => _showFilterMenu(_categoryKey, 'All Categories',
              provider.stockCategories, _selectedCategory,
                  (v) {
                setState(() => _selectedCategory = v);
                _resetPage();
              })),
      downloadStatusMenu(),
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () {
          _resetPage();
          _applyFilters();
        },
        tooltip: 'Refresh',
      ),
    ]);

    if (compact) {
      return [
        PopupMenuButton<String>(
          tooltip: 'More actions',
          color: AppColors.surface,
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => [
            if (!provider.isAdminLevel)
              const PopupMenuItem<String>(value: 'home', child: Text('Home')),
            const PopupMenuItem<String>(value: 'search', child: Text('Search')),
            if (provider.canDeleteRecords || provider.isAdminLevel)
              const PopupMenuItem<String>(value: 'branch', child: Text('Branch')),
            const PopupMenuItem<String>(value: 'date', child: Text('Date range')),
            const PopupMenuItem<String>(value: 'type', child: Text('Type')),
            const PopupMenuItem<String>(value: 'category', child: Text('Category')),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(value: 'status_all', child: Text('All Stock')),
            const PopupMenuItem<String>(value: 'status_finished', child: Text('Finished')),
            const PopupMenuItem<String>(value: 'status_reorder', child: Text('Reorder')),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(value: 'pdf', child: Text('Download PDF')),
            const PopupMenuItem<String>(value: 'excel', child: Text('Download Excel')),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(value: 'refresh', child: Text('Refresh')),
          ],
          onSelected: (value) {
            switch (value) {
              case 'home':
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                break;
              case 'search':
                _openSearch();
                break;
              case 'branch':
                _showBranchMenu(provider);
                break;
              case 'date':
                _showDateRangePicker();
                break;
              case 'type':
                _showFilterMenu(_typeKey, 'All Product Types', provider.stockProductTypes, _selectedType,
                        (v) {
                      setState(() => _selectedType = v);
                      _resetPage();
                    });
                break;
              case 'category':
                _showFilterMenu(_categoryKey, 'All Categories', provider.stockCategories, _selectedCategory,
                        (v) {
                      setState(() => _selectedCategory = v);
                      _resetPage();
                    });
                break;
              case 'status_all':
                setState(() => _status = null);
                _resetPage();
                break;
              case 'status_finished':
                setState(() => _status = 'Finished');
                _resetPage();
                break;
              case 'status_reorder':
                setState(() => _status = 'Reorder');
                _resetPage();
                break;
              case 'pdf':
                _downloadPdf();
                break;
              case 'excel':
                _downloadExcel();
                break;
              case 'refresh':
                _resetPage();
                _applyFilters();
                break;
            }
          },
        )
      ];
    }

    return commonActions;
  }


  void _showFilterMenu(GlobalKey key, String allLabel, List<String> options,
      String? current, ValueChanged<String?> onPicked) {
    final RenderBox button = key.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final p = button.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(p.dx, p.dy + button.size.height, button.size.width, 0),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: AppColors.surface,
      items: [
        PopupMenuItem<String>(
          value: '__ALL__',
          child: Text(allLabel, style: TextStyle(
              color: current == null ? _accent : Colors.white, fontSize: 13)),
        ),
        ...options.map((o) => PopupMenuItem<String>(
          value: o,
          child: Text(o, style: TextStyle(
              color: o == current ? _accent : Colors.white, fontSize: 13)),
        )),
      ],
    ).then((picked) {
      if (picked == null) return;
      onPicked(picked == '__ALL__' ? null : picked);
    });
  }

  void _showBranchMenu(Datafeed value) {
    _showFilterMenu(
      _branchKey,
      'All Branches',
      value.branches.where((b) => b.branchname != 'Sales Point').map((b) => b.branchname).toList(),
      selectedBranch == null ? null : selectedBranchName,
          (name) {
        final branch = name == null
            ? null
            : value.branches.firstWhere((b) => b.branchname == name);
        setState(() {
          selectedBranch = branch?.id;
          selectedBranchName = branch?.branchname ?? 'All Branches';
        });
        _applyFilters();
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;
    final provider = context.watch<Datafeed>();
    final stockreport = _rows(provider);
    final totalPages = stockreport.isEmpty ? 1 : ((stockreport.length - 1) ~/ _rowsPerPage) + 1;
    final effectivePage = _currentPage.clamp(0, totalPages == 0 ? 0 : totalPages - 1);
    final paginatedRows = _pageRows(stockreport, effectivePage);
    final stockTotal = stockreport.fold<double>(0, (s, r) => s + _num(r['stock_value']));
    final sellTotal  = stockreport.fold<double>(0, (s, r) => s + _num(r['selling_value']));
    final compactAppBar = MediaQuery.of(context).size.width < 860;
    final compactFooter = MediaQuery.of(context).size.width < 600;
    final compactTitleWidth =
      (MediaQuery.of(context).size.width - 100).clamp(80.0, 170.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleSpacing: 12,
        automaticallyImplyLeading: !_isSearching,
        title: _isSearching
            ? Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 21),
                  onPressed: () => _closeSearch(provider),
                ),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        cursorColor: AppColors.textPrimary,
                        decoration: const InputDecoration(
                          hintText: 'Search stock...',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        onChanged: (t) {
                          setState(() {
                            _currentPage = 0;
                          });
                          provider.updateStockReportSearch(t);
                        },
                      ),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() => _searchController.clear());
                      provider.updateStockReportSearch('');
                      _searchFocusNode.requestFocus();
                    },
                  ),
              ])
            : SizedBox(
              width: compactAppBar ? compactTitleWidth : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Stock Report',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${selectedBranchName ?? provider.company}${_filterSummary()} • ${_formatDateRange()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
        actions: _isSearching ? null : _appBarActions(context, provider, stockreport, compactAppBar),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1430),
            child: provider.isloadingsalesreport
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : stockreport.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textMuted),
                            SizedBox(height: 16),
                            Text('No stock items found',
                                style: TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.border),
                              ),
                              clipBehavior: Clip.none,
                              child: isLargeScreen
                                  ? _buildStockTable(paginatedRows)
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(8),
                                      itemCount: paginatedRows.length,
                                      itemBuilder: (_, i) => _buildStockCard(paginatedRows[i]),
                                    ),
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              border: Border(top: BorderSide(color: Color(0xFF475569), width: 0.7)),
                            ),
                            child: isLargeScreen
                                ? Row(
                              children: [
                                Expanded(
                                  child: _buildDesktopTotalsRow(
                                      _stockColumns(), stockreport.length, stockTotal, sellTotal),
                                ),
                                if (stockreport.length > _rowsPerPage)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Previous page',
                                          onPressed: effectivePage > 0
                                              ? () => setState(() => _currentPage = effectivePage - 1)
                                              : null,
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.chevron_left),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: const BoxDecoration(color: AppColors.background),
                                          child: Text('${effectivePage + 1}/$totalPages',
                                              style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12)),
                                        ),
                                        IconButton(
                                          tooltip: 'Next page',
                                          onPressed: effectivePage < totalPages - 1
                                              ? () => setState(() => _currentPage = effectivePage + 1)
                                              : null,
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.chevron_right),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            )
                                : Row(
                              children: [
                                if (!compactFooter)
                                  Expanded(child: _footerStat('Items', stockreport.length)),
                                Expanded(child: _footerStat('Value@CP', _nf.format(stockTotal), dense: compactFooter)),
                                Expanded(child: _footerStat('Value@SP', _nf.format(sellTotal), dense: compactFooter)),
                                if (stockreport.length > _rowsPerPage)
                                  Padding(
                                    padding: EdgeInsets.only(right: compactFooter ? 2 : 8),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Previous page',
                                          onPressed: effectivePage > 0
                                              ? () => setState(() => _currentPage = effectivePage - 1)
                                              : null,
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.chevron_left),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: compactFooter ? 5 : 10, vertical: 6),
                                          decoration: const BoxDecoration(color: AppColors.background),
                                          child: Text('${effectivePage + 1}/$totalPages',
                                              style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12)),
                                        ),
                                        IconButton(
                                          tooltip: 'Next page',
                                          onPressed: effectivePage < totalPages - 1
                                              ? () => setState(() => _currentPage = effectivePage + 1)
                                              : null,
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.chevron_right),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
  List<_StockColumn> _stockColumns() {
    return [
      const _StockColumn('#', 20),
      const _StockColumn('Product', 100),
      const _StockColumn('Opening Stock', 70, numeric: true),
      const _StockColumn('New Stock', 70, numeric: true),
      if (selectedBranch != null)
        const _StockColumn('Transfer In', 70, numeric: true),
      const _StockColumn('Sales Return', 70, numeric: true),
      const _StockColumn('Total',80, numeric: true),
      const _StockColumn('Sales qty', 70, numeric: true),
      const _StockColumn('Purchase. Return.', 70, numeric: true),
      const _StockColumn('Damages', 70, numeric: true),
      if (selectedBranch != null)
        const _StockColumn('Transfer. Out', 70, numeric: true),

      const _StockColumn('Pcs Bal', 70, numeric: true),
      const _StockColumn('Ctns Bal', 70, numeric: true),
      const _StockColumn('Value@CP', 90, numeric: true),
      const _StockColumn('Value@SP', 90, numeric: true),
    ];
  }

  Widget _buildStockTable(List<Map<String, dynamic>> reportData) {
    final columns = _stockColumns();
    final double totalColsWidth =
        columns.fold<double>(0, (s, c) => s + c.width) +
            (columns.length - 1) * 24 +
            32;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentWidth = constraints.maxWidth > totalColsWidth
            ? constraints.maxWidth
            : totalColsWidth;

        return Scrollbar(
          controller: _hController,
          thumbVisibility: true,
          notificationPredicate: (notif) => notif.depth == 0,
          child: SingleChildScrollView(
            controller: _hController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 42,
                    color: AppColors.surfaceLight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (int i = 0; i < columns.length; i++) ...[
                          SizedBox(
                            width: columns[i].width,
                            child: Text(
                              columns[i].label,
                              textAlign: columns[i].numeric
                                  ? TextAlign.right
                                  : TextAlign.left,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontSize: 12),
                            ),
                          ),
                          if (i != columns.length - 1)
                            const SizedBox(width: 24),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFF475569)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: reportData.length,
                      itemBuilder: (context, i) => Column(
                        children: [
                          _buildStockRow(context, reportData[i], (i + (_currentPage * _rowsPerPage)), columns, selectedBranch),
                          const Divider(height: 1, color: Color(0xFF475569)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStockRow(BuildContext context, Map<String, dynamic> item,
      int index, List<_StockColumn> columns, dynamic selectedBranch) {
    final itemid = item['itemid'] ?? '';
    final itemname = item['item'] ?? '';

    final balanceCd = item['balance_cd'] ?? 0;
    final openingStock = item['opening_stock'] ?? 0;
    final transfer = item['transfer_qty'] ?? 0;
    final transferIn = item['transfer_recieved_qty'] ?? 0;
    final newStock = item['newstock'] ?? 0;
    final totalStock = item['total_stock'] ?? 0;
    final salesQty = item['sales_qty'] ?? 0;
    final purchaseReturns = item['purchase_returns'] ?? 0;
    final damages = item['damages'] ?? 0;
    final saleReturns = item['sale_returns'] ?? 0;
    final boxPiece = double.tryParse(item['cartonqty_bal'].toString()) ?? 1;
    final cartonQtyBal = balanceCd / (boxPiece == 0 ? 1 : boxPiece);

    final cells = <Widget>[
      Text('${index + 1}',
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      Text(itemname,
          softWrap: true,
          overflow: TextOverflow.visible,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      Text(_formatNumber(openingStock),
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      Text(_formatNumber(newStock),
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      if (selectedBranch != null)
        Text(_formatNumber(transferIn),
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      Text(_formatNumber(saleReturns),
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary)),
      Text(_formatNumber(totalStock),
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      Text(_formatNumber(salesQty),
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      Text(_formatNumber(purchaseReturns),
          textAlign: TextAlign.right,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      Text(_formatNumber(damages),
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary)),
      if (selectedBranch != null)
        Text(_formatNumber(transfer),
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textSecondary)),

      Text(_formatNumber(balanceCd),
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary)),
      Text(
        cartonQtyBal > 0 ? '${_formatNumber(cartonQtyBal)} ' : '_',
        textAlign: TextAlign.right,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      Text(_nf.format(_num(item['stock_value'])),
          textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textPrimary)),
      Text(_nf.format(_num(item['selling_value'])),
          textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textPrimary)),
    ];

    return InkWell(
      onTap: () {
        showStockTransactionsDialog(
          context,
          itemId: itemid,
          itemName: itemname,
          boxpiece: boxPiece,
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, maxHeight: 60),
        alignment: Alignment.center,
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (int i = 0; i < columns.length; i++) ...[
              SizedBox(width: columns[i].width, child: cells[i]),
              if (i != columns.length - 1) const SizedBox(width: 24),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildStockCard(Map<String, dynamic> item) {

    final transfer = item['transfer_qty'] ?? 0;
    final transferIn = item['transfer_recieved_qty'] ?? 0;
    final itemid = item['itemid']?? '';
    final itemname = item['item']?? '';
    final balanceCd = item['balance_cd']?? 0;

    final openingStock = item['opening_stock']?? 0;
    final newStock = item['newstock']?? 0;
    final totalStock = item['total_stock']?? 0;
    final salesQty = item['sales_qty']?? 0;
    final cashSales = item['cash_sales']?? 0;
    final creditSales = item['credit_sales']?? 0;
    final purchaseReturns = item['purchase_returns']?? 0;
    final damages = item['damages']?? 0;

    final saleReturns = item['sale_returns']?? 0;
    final stockOut = item['stock_out']?? 0;

    final boxPiece =  double.tryParse(item['cartonqty_bal'].toString()) ?? 1;
    final cartonQtyBal = balanceCd / (boxPiece == 0 ? 1 : boxPiece);


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: (){
          showStockTransactionsDialog(
            context,
            itemId:    itemid,
            itemName:  itemname,
            boxpiece: boxPiece,
          );
        },

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Header — product name + balance
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item['item'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Balance: ${_formatNumber(balanceCd)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Carton: ${_formatNumber(cartonQtyBal)}',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: 20, color: AppColors.border),

            //Stock movement
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _miniStat2("Opening", openingStock),
                _miniStat2("New Stock",newStock),
                _miniStat2("Total",totalStock),
                _miniStat2("Sales Qty",salesQty),
                _miniStat2("Sale Returns",saleReturns),
                _miniStat2("Purchase Returns",purchaseReturns),
                _miniStat2("Damages", damages),
                _miniStat2("Transfer Out",transfer),
                 _miniStat2("Transfer In",transferIn),
                 _miniStat2("Carton",cartonQtyBal),

                _miniStat2("Value@CP", _nf.format(_num(item['stock_value']))),
                _miniStat2("Value@SP", _nf.format(_num(item['selling_value']))),

              ],
            ),

          ],
        ),
      ),
    );
  }


  Widget _footerStat(String title, dynamic value, {bool dense = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 14, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: Color(0xFF475569), width: 0.7),
          right: BorderSide(color: Color(0xFF475569), width: 0.7),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 150;
          final label = Text(title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600));
          final amount = Text(value.toString(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13));
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [label, amount],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Flexible(child: label), Flexible(child: amount)],
                );
        },
      ),
    );
  }
  Widget _buildDesktopTotalsRow(
      List<_StockColumn> columns, int itemCount, double stockTotal, double sellTotal) {
    final double contentWidth =
        columns.fold<double>(0, (s, c) => s + c.width) + (columns.length - 1) * 24 + 32;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width =
        constraints.maxWidth > contentWidth ? constraints.maxWidth : contentWidth;

        return SingleChildScrollView(
          controller: _footerHController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: width,
            child: Container(
              height: 42,
              color: AppColors.surfaceLight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (int i = 0; i < columns.length; i++) ...[
                    SizedBox(
                      width: columns[i].width,
                      child: columns[i].label == 'Product'
                          ? Text('$itemCount item${itemCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 12))
                          : columns[i].label == 'Value@CP'
                          ? Text(_nf.format(stockTotal),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 13))
                          : columns[i].label == 'Value@SP'
                          ? Text(_nf.format(sellTotal),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 13))
                          : const SizedBox.shrink(),
                    ),
                    if (i != columns.length - 1) const SizedBox(width: 24),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _dialogPagerFooter({
    required String label,
    required int count,
    required int page,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFF475569), width: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(child: _dialogFooterCell(label, count)),
          Expanded(child: _dialogFooterCell('Page', '${page + 1}/$totalPages')),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: page < totalPages - 1
                ? () => onPageChanged(page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _dialogFooterCell(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 150;
          final label = Text(title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600));
          final amount = Text(value.toString(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13));
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [label, amount],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Flexible(child: label), Flexible(child: amount)],
                );
        },
      ),
    );
  }

  Widget _miniStatstring(String title, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 10)),
          Text(
            textAlign: TextAlign.right,
            value.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _miniStat2(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          _formatNumber(value),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }


  String _getSortDisplayName() {
    switch (_sortBy) {
      case 'name':
        return 'Name';
      case 'stockValue':
        return 'Value';
      case 'quantity':
        return 'Qty';
      default:
        return 'Date';
    }
  }

  String _formatNumber(dynamic number) {
    if (number is double) {
      return number.truncateToDouble() == number ? number.toInt().toString() : number.toStringAsFixed(1);
    }
    return number.toString();
  }


  Future<void> showStockTransactionsDialog( BuildContext context, { required String itemId, required String itemName,double? boxpiece}) async {
    final dialogSearchController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final provider = Provider.of<Datafeed>(context, listen: false);

    try {
      final now = DateTime.now();
      final startDate = _selectedDateRange?.start ?? DateTime(now.year, now.month, now.day);
      final endDate   = _selectedDateRange?.end   ?? DateTime(now.year, now.month, now.day);

      await provider.loadStockTransactions(
        startDate: startDate,
        endDate: endDate,
        itemId: itemId,
        itemName: itemName,
        selectedBranch: selectedBranch,

      );
    } catch (e) {
      print(e);
    }

    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).pop();

    var movementPage = 0;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<Datafeed>(
          builder: (context, provider, _) {
            final transactions =   provider.filterstockTransactions();

            final isSmallScreen =   MediaQuery.of(dialogContext).size.width < 600;

            return StatefulBuilder(
              builder: (context, setDialogState) {
                const rowsPerPage = 10;
                final totalPages = transactions.isEmpty
                    ? 1
                    : ((transactions.length - 1) ~/ rowsPerPage) + 1;
                return AlertDialog(
              backgroundColor: const Color(0xFF101624),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              insetPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8 : 40,
                vertical: 12,
              ),

              title: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$itemName Stock Movement for ${selectedBranchName ?? 'All Branches'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,color: Colors.white),
                        onPressed: () {
                          provider.updateStockDialogSearch('');
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  isSmallScreen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                          controller: dialogSearchController,
                          onChanged: (val){
                            setDialogState(() => movementPage = 0);
                            provider.updateStockDialogSearch(val);
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Search ...",
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            filled: true,
                            fillColor: const Color(0xFF1A2235),
                            border: const OutlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('Print', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF415A77),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () async {
                          final datafeed = Provider.of<Datafeed>(dialogContext, listen: false);
                          await printStockTransactionsPdf(
                            transactions: provider.filterstockTransactions(),
                            itemName: itemName,
                            companyName: datafeed.company,
                            branchName: selectedBranchName ?? 'All Branches',
                            dateRange:
                            '${DateFormat('d MMMM y').format(_selectedDateRange?.start ?? DateTime.now())}'
                                ' - '
                                '${DateFormat('d MMMM y').format(_selectedDateRange?.end ?? DateTime.now())}',
                            boxpiece: boxpiece,
                          );
                        },
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: dialogSearchController,
                                onChanged: (val) {
                                  setDialogState(() => movementPage = 0);
                                  provider.updateStockDialogSearch(val);
                                },
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Search ...',
                                  hintStyle: TextStyle(color: Colors.white54),
                                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                                  filled: true,
                                  fillColor: Color(0xFF1A2235),
                                  border: OutlineInputBorder(borderSide: BorderSide.none),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _movementPrintButton(dialogContext, provider, itemName, boxpiece),
                          ],
                        ),

                ],
              ),

              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height *
                  (isSmallScreen ? 0.68 : 0.78),
                child: transactions.isEmpty
                    ? const Text("No transactions found",
                        style: TextStyle(color: Colors.white70))
                    : Column(
                        children: [
                          Expanded(
                            child: isSmallScreen
                                ? _buildMobileStockCards(
                                    transactions
                                        .skip(movementPage * rowsPerPage)
                                        .take(rowsPerPage)
                                        .toList(),
                                    boxpiece,
                                    startIndex: movementPage * rowsPerPage,
                                  )
                                : _buildDesktopStockTable(
                                    transactions
                                        .skip(movementPage * rowsPerPage)
                                        .take(rowsPerPage)
                                        .toList(),
                                    boxpiece,
                                    startIndex: movementPage * rowsPerPage,
                                  ),
                          ),
                          _dialogPagerFooter(
                            label: 'Transactions',
                            count: transactions.length,
                            page: movementPage,
                            totalPages: totalPages,
                            onPageChanged: (next) =>
                                setDialogState(() => movementPage = next),
                          ),
                        ],
                      ),
              ),
              );
            },
          );
          },
        );
      },
    );
  }

  Widget _buildMobileStockCards(
      List<Map<String, dynamic>> transactions, double? boxpiece,
      {int startIndex = 0}) {
    final verticalController = ScrollController();

    return Scrollbar(
      controller: verticalController,
      child: ListView.builder(
        controller: verticalController,
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final t = transactions[index];

          final no = startIndex + index + 1;
          final item = t['item'] ?? '';
          final itemid = t['itemId'] ?? '';
          final branch = t['branch'] ?? '';


          final transferIn = t['transfer_recieved_qty']?? 0;
          final openingStock = t['opening_stock'] ?? 0;
          final newStock = t['newstock'] ?? 0;

          final salesQty = t['sales_qty'] ?? 0;
          final saleReturns = t['sale_returns'] ?? 0;
          final purchaseReturns = t['purchase_returns'] ?? 0;
          final damages = t['damages'] ?? 0;
          final transfer = t['transfer_qty'] ?? 0;
        //  final transfer = t['transfer'] ?? 0;
          final balance = t['balance_cd'] ?? 0;


          final boxPiece =  double.tryParse(boxpiece.toString()) ?? 1;

          final cartonQtyBal = balance / (boxPiece == 0 ? 1 : boxPiece);
          final datte = t['date'] ?? '';

          String formattedDate = '-';

          if (datte is DateTime) {
            formattedDate = DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format(datte);
          } else if (datte is Timestamp) {
            formattedDate = DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format(datte.toDate());
          }

          return InkWell(
             onTap: (){
               showItemHistoryDialog(context,
                   itemId: itemid,
                   itemName: item,
                   branchId: selectedBranch,
                   boxpieces:boxPiece
               );
             },
            child: Card(
              color: AppColors.surface,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$no',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.toString(),
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        // _miniStatstring(
                        //   "Branch",
                        //   branch.toString(),
                        // ),
                        _miniStatstring(
                          "Opening Stock",
                          openingStock.toString(),
                        ),


                        _miniStatstring(
                          "New Stock",
                          newStock.toString(),
                        ),
                        _miniStatstring(
                          "Sales Qty",
                          salesQty.toString(),
                        ),

                        _miniStatstring(
                          "Sale Return",
                          saleReturns.toString(),
                        ),
                        _miniStatstring("Transfer In",  transferIn?.toString() ?? '0'),
                        _miniStatstring("Transfer Out", t['transfer']?.toString() ?? '0'),
                        _miniStatstring(
                          "Purchase Return",
                          purchaseReturns.toString(),
                        ),
                        _miniStatstring(
                          "Damages",
                          damages.toString(),
                        ),
                        _miniStatstring(
                          "Transfer",
                          transfer.toString(),
                        ),

                        _miniStatstring(
                          "Pcs Bal",
                          balance.toString(),
                        ),
                        _miniStatstring(
                          "Ctn Bal",
                          cartonQtyBal.toStringAsFixed(1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _movementPrintButton(BuildContext dialogContext, Datafeed provider,
      String itemName, double? boxpiece) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: const Text('Print', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF415A77),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      onPressed: () async {
        final datafeed = Provider.of<Datafeed>(dialogContext, listen: false);
        await printStockTransactionsPdf(
          transactions: provider.filterstockTransactions(),
          itemName: itemName,
          companyName: datafeed.company,
          branchName: selectedBranchName ?? 'All Branches',
          dateRange:
              '${DateFormat('d MMMM y').format(_selectedDateRange?.start ?? DateTime.now())}'
              ' - '
              '${DateFormat('d MMMM y').format(_selectedDateRange?.end ?? DateTime.now())}',
          boxpiece: boxpiece,
        );
      },
    );
  }


  final List<_HistoryColumn> _historyColumns = const [
    _HistoryColumn('#', 40),
    _HistoryColumn('Date', 100),
    _HistoryColumn('Opening', 90),
    _HistoryColumn('New Stock', 90),
    _HistoryColumn('Transfer In', 90),
    _HistoryColumn('Transfer Out', 90),
    _HistoryColumn('Sales Qty', 90),
    _HistoryColumn('Sale Return', 90),
    _HistoryColumn('Purchase Return', 80),
    _HistoryColumn('Damages', 70),

    _HistoryColumn('Pcs Bal', 90),
    _HistoryColumn('Ctn Bal', 80),
   // _HistoryColumn('Branch', 110),
  ];

    Widget _buildDesktopStockTable(
      List<Map<String, dynamic>> transactions, double? boxpiece,
      {int startIndex = 0}) {
    final verticalController = ScrollController();
    final horizontalController = ScrollController();
    final double totalColsWidth =
        _historyColumns.fold<double>(0, (s, c) => s + c.width) +
            (_historyColumns.length - 1) * 24 +
            32;

    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(const Color(0xFF415A77)),
        trackColor: MaterialStateProperty.all(const Color(0xFF22304A)),
        trackBorderColor: MaterialStateProperty.all(const Color(0xFF1B263B)),
        thickness: MaterialStateProperty.all(10),
        radius: const Radius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double contentWidth = constraints.maxWidth > totalColsWidth
              ? constraints.maxWidth
              : totalColsWidth;

          return Scrollbar(
            controller: horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header
                    Container(
                      height: 40,
                      color: AppColors.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          for (int i = 0; i < _historyColumns.length; i++) ...[
                            SizedBox(
                              width: _historyColumns[i].width,
                              child: Text(
                                _historyColumns[i].label,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            if (i != _historyColumns.length - 1)
                              const SizedBox(width: 24),
                          ],
                        ],
                      ),
                    ),
                    // ── Body (virtualized rows)
                    Expanded(
                      child: Scrollbar(
                        controller: verticalController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        child: ListView.builder(
                          controller: verticalController,
                          itemCount: transactions.length,
                          itemBuilder: (context, index) => Column(
                            children: [
                              _buildDesktopStockRow(context, transactions[index],
                                  startIndex + index, boxpiece),
                              const Divider(height: 1, color: Color(0xFF475569)),
                            ],
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
    );
  }

  Widget _buildDesktopStockRow(BuildContext context, Map<String, dynamic> t,
      int index, double? boxpiece) {
    final summarydate = t['date'] ?? '';
    final opening_stock = t['opening_stock'] ?? 0;
    final newstock = t['newstock'] ?? 0;
    final salesQty = t['sales_qty'] ?? 0;
    final sale_returns = t['sale_returns'] ?? 0;
    final purchase_returns = t['purchase_returns'] ?? 0;
    final damages = t['damages'] ?? 0;
    final balance_cd = t['balance_cd'] ?? 0;
    final branch = t['branch'] ?? '';
    final transferIn = t['transfer_recieved_qty'] ?? 0;
    final transferOut = t['transfer_qty'] ?? 0;
    final item = t['item'] ?? '';
    final itemid = t['itemId'] ?? '';
   // final transferOut = t['transfer'] ?? 0;
    final boxPiece = double.tryParse(boxpiece.toString()) ?? 1;
    final cartonQtyBal = balance_cd / (boxPiece == 0 ? 1 : boxPiece);

    final cells = <Widget>[
      Text('${index + 1}', style: const TextStyle(color: Colors.white70)),
      Text(summarydate.toString(), style: const TextStyle(color: Colors.white70)),
      Text(opening_stock.toString(), style: const TextStyle(color: Colors.white70)),
      Text(newstock.toString(), style: const TextStyle(color: Colors.white70)),
      Text(transferIn.toString(), style: const TextStyle(color: Colors.white70)),
      Text(transferOut.toString(), style: const TextStyle(color: Colors.white70)),
      Text(salesQty.toString(), style: const TextStyle(color: Colors.white70)),
      Text(sale_returns.toString(), style: const TextStyle(color: Colors.white70)),
      Text(purchase_returns.toString(), style: const TextStyle(color: Colors.white70)),
      Text(damages.toString(), style: const TextStyle(color: Colors.white70)),

      Text(balance_cd.toString(), style: const TextStyle(color: Colors.white70)),
      Text(cartonQtyBal.toStringAsFixed(1), style: const TextStyle(color: Colors.white70)),
     // Text(branch.toString(), style: const TextStyle(color: Colors.white70)),
    ];

    return InkWell(
      onTap: () {
        showItemHistoryDialog(context,
            itemId: itemid,
            itemName: item,
            branchId: selectedBranch,
            boxpieces: boxPiece);
      },
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            for (int i = 0; i < _historyColumns.length; i++) ...[
              SizedBox(width: _historyColumns[i].width, child: cells[i]),
              if (i != _historyColumns.length - 1) const SizedBox(width: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyFooterBar({
    required bool isSmall,
    required VoidCallback onPrint,
    required VoidCallback onDownloadPdf,
    required VoidCallback onDownloadExcel,
    required VoidCallback onClose,
    required Widget pager,
  }) {
    final controls = Wrap(
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'Print',
          icon: const Icon(Icons.print_outlined, color: Colors.white70, size: 20),
          onPressed: onPrint,
        ),
        IconButton(
          tooltip: 'Download PDF',
          icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white70, size: 20),
          onPressed: onDownloadPdf,
        ),
        IconButton(
          tooltip: 'Download Excel',
          icon: const Icon(Icons.grid_on_outlined, color: Colors.white70, size: 20),
          onPressed: onDownloadExcel,
        ),
        IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
          onPressed: onClose,
        ),
      ],
    );

    if (isSmall) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          pager,
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [controls],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: pager),
        controls,
      ],
    );
  }

  Future<void> showItemHistoryDialog(BuildContext context, {required String itemId,required String itemName,required String? branchId,double? boxpieces}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final now = DateTime.now();

    final startDate = _selectedDateRange?.start ?? DateTime(now.year, now.month, now.day);
    final endDate = _selectedDateRange?.end ?? now;
    await context.read<Datafeed>().loadItemHistory(
      itemId:    itemId,
      itemName:  itemName,
      branchId:  branchId,
      startDate: startDate,
      endDate:  endDate,
    );

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final dateLabel = _selectedDateRange == null
        ? DateFormat('dd MMM yyyy').format(DateTime.now())
        : '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} – '
        '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}';

    var historyPage = 0;
    final historySearchController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isSmall   = MediaQuery.of(dialogContext).size.width < 600;

        Color signColor(String s) => s == '+' ? Colors.greenAccent : Colors.redAccent;
        Color typeColor(String t) {
          if (t.startsWith('Transfer In'))  return Colors.greenAccent;
          if (t.startsWith('Transfer Out')) return Colors.orangeAccent;
          switch (t) {
            case 'Sale':          return Colors.redAccent;
            case 'Sales Return':  return Colors.greenAccent;
            case 'Purchase':      return Colors.blueAccent;
            case 'Transfer Out':  return Colors.orangeAccent;
            default:              return Colors.white54;
          }
        }


        return Consumer<Datafeed>(
          builder: (context, datafeed, _) {
            final entries = datafeed.filterItemHistoryEntries();

            return StatefulBuilder(
              builder: (context, setDialogState) {
                const rowsPerPage = 10;
                final totalPages = entries.isEmpty
                    ? 1
                    : ((entries.length - 1) ~/ rowsPerPage) + 1;
                final pagedEntries = entries
                    .skip(historyPage * rowsPerPage)
                    .take(rowsPerPage)
                    .toList();

                return AlertDialog(
                  backgroundColor: const Color(0xFF101624),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  insetPadding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 8 : 40,
                    vertical: 12,
                  ),
                  titlePadding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(itemName.toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text('${selectedBranchName ?? 'All Branches'} Stock History  ·  $dateLabel',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54),
                            onPressed: () {
                              datafeed.updateItemHistorySearch('');
                              Navigator.of(dialogContext).pop();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: historySearchController,
                        onChanged: (val) {
                          setDialogState(() => historyPage = 0);
                          datafeed.updateItemHistorySearch(val);
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search ...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF1A2235),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: MediaQuery.sizeOf(dialogContext).height *
                        (isSmall ? 0.70 : 0.80),
                    child: entries.isEmpty
                        ? const Center(
                        child: Text('No transactions found.',
                            style: TextStyle(color: Colors.white54)))
                        : Column(
                      children: [
                        Expanded(
                          child: isSmall
                              ? ListView.builder(
                            itemCount: pagedEntries.length,
                            itemBuilder: (_, i) {
                              final t = pagedEntries[i];
                              final double qty = (t.qty ?? 0).toDouble();
                              final box = boxpieces ?? 1;
                              final double cartonqty = boxpieces == 0 ? 0 : qty / box;
                              final dateStr = t.date != null
                                  ? DateFormat('dd MMM yyyy  hh:mm a')
                                  .format(t.date!)
                                  : '-';
                              return Card(
                                color: AppColors.surface,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: typeColor(t.type).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color:
                                                typeColor(t.type).withOpacity(0.5)),
                                          ),
                                          child: Text(t.type,
                                              style: TextStyle(
                                                  color: typeColor(t.type),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                        const Spacer(),
                                        Text(dateStr,
                                            style: const TextStyle(
                                                color: Colors.white54, fontSize: 11)),
                                      ]),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${t.sign}${t.qty.toStringAsFixed(0)} pcs',
                                              style: TextStyle(
                                                  color: signColor(t.sign),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          Text('GHS ${t.total.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text('${t.sign}${cartonqty.toStringAsFixed(0)} Carton',
                                          style: TextStyle(
                                              color: signColor(t.sign),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      const SizedBox(height: 6),
                                      Text('${t.branch}  ·  ${t.staff}',
                                          style: const TextStyle(
                                              color: Colors.white54, fontSize: 11)),
                                      if (t.transactionid.isNotEmpty)
                                        Text('Ref: ${t.transactionid}',
                                            style: const TextStyle(
                                                color: Colors.white38, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                              : ScrollbarTheme(
                            data: ScrollbarThemeData(
                              thumbColor:
                              MaterialStateProperty.all(const Color(0xFF415A77)),
                              trackColor:
                              MaterialStateProperty.all(const Color(0xFF22304A)),
                              thickness: MaterialStateProperty.all(8),
                              radius: const Radius.circular(6),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double gap =
                                MediaQuery.sizeOf(context).width < 1100 ? 14 : 40;
                                final isKS008 = datafeed.companyid == 'KS008';

                                final detailColumns = <_HistoryColumn>[
                                  const _HistoryColumn('#', 30),
                                  const _HistoryColumn('Entry Date', 130),
                                  const _HistoryColumn('Txn Date', 90),
                                  const _HistoryColumn('Type', 100),
                                  if (isKS008) ...[
                                    const _HistoryColumn('Carton', 70),
                                  ],
                                  const _HistoryColumn('±Qty (pcs)', 60),
                                  const _HistoryColumn('Unit Price', 70),
                                  const _HistoryColumn('Total', 80),
                                  const _HistoryColumn('Mode', 80),
                                  // const _HistoryColumn('Branch', 80),
                                  const _HistoryColumn('Staff', 60),
                                  const _HistoryColumn('Record ID', 90),
                                ];

                                final double contentWidth = detailColumns
                                    .fold<double>(0, (s, c) => s + c.width) +
                                    (detailColumns.length - 1) * gap +
                                    32;
                                final double tableWidth =
                                constraints.maxWidth > contentWidth
                                    ? constraints.maxWidth
                                    : contentWidth;

                                return Scrollbar(
                                  controller: _horizontalController,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _horizontalController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: tableWidth,
                                      height: constraints.maxHeight.isFinite
                                          ? constraints.maxHeight
                                          : null,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            color: const Color(0xFF1E2A3D),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 10),
                                            child: Row(
                                              children: [
                                                for (int i = 0;
                                                i < detailColumns.length;
                                                i++) ...[
                                                  SizedBox(
                                                    width: detailColumns[i].width,
                                                    child: Text(
                                                        detailColumns[i].label,
                                                        style: const TextStyle(
                                                            color: Colors.white70)),
                                                  ),
                                                  if (i != detailColumns.length - 1)
                                                    SizedBox(width: gap),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const Divider(
                                              height: 1, color: Color(0xFF475569)),
                                          Expanded(
                                            child: Scrollbar(
                                              controller: _verticalController,
                                              thumbVisibility: true,
                                              child: ListView.builder(
                                                controller: _verticalController,
                                                itemCount: pagedEntries.length,
                                                itemBuilder: (context, i) {
                                                  final t = pagedEntries[i];
                                                  final dateStr = t.date != null
                                                      ? DateFormat(
                                                      'dd MMM yyyy  hh:mm a')
                                                      .format(t.date!)
                                                      : '-';
                                                  final invoiceDateStr =
                                                      t.invoiceDate ?? '';

                                                  final double qty =
                                                  (t.qty).toDouble();
                                                  final box = boxpieces ?? 1;
                                                  final double cartonqty =
                                                  boxpieces == 0 ? 0 : qty / box;

                                                  final detailCells = <Widget>[
                                                    Text('${historyPage * rowsPerPage + i + 1}',
                                                        style: const TextStyle(
                                                            color: Colors.white54,
                                                            fontSize: 12)),
                                                    Text(dateStr,
                                                        style: const TextStyle(
                                                            color: Colors.white70,
                                                            fontSize: 12)),
                                                    Text(invoiceDateStr,
                                                        style: const TextStyle(
                                                            color: Colors.white70,
                                                            fontSize: 12)),
                                                    Container(
                                                      padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: typeColor(t.type)
                                                            .withOpacity(0.12),
                                                      ),
                                                      child: Text(t.type,
                                                          style: TextStyle(
                                                              color:
                                                              typeColor(t.type),
                                                              fontSize: 11,
                                                              fontWeight:
                                                              FontWeight.bold)),
                                                    ),
                                                    if (isKS008) ...[
                                                      Text(
                                                          '${t.sign}${cartonqty.toStringAsFixed(0)}',
                                                          style: TextStyle(
                                                              color:
                                                              signColor(t.sign),
                                                              fontWeight:
                                                              FontWeight.bold,
                                                              fontSize: 13)),
                                                    ],
                                                    Text(
                                                        '${t.sign}${t.qty.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                            color: signColor(t.sign),
                                                            fontWeight:
                                                            FontWeight.bold,
                                                            fontSize: 13)),
                                                    Text(t.price.toStringAsFixed(2),
                                                        style: const TextStyle(
                                                            color: Colors.white70,
                                                            fontSize: 12)),
                                                    Text(t.total.toStringAsFixed(2),
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                            fontWeight:
                                                            FontWeight.w600)),
                                                    Text(t.mode,
                                                        style: const TextStyle(
                                                            color: Colors.white54,
                                                            fontSize: 12)),

                                                    Text(t.staff,
                                                        style: const TextStyle(
                                                            color: Colors.white70,
                                                            fontSize: 12)),
                                                    Text(
                                                        t.transactionid.isNotEmpty
                                                            ? t.transactionid
                                                            : '-',
                                                        style: const TextStyle(
                                                            color: Colors.white38,
                                                            fontSize: 11)),
                                                  ];

                                                  return Padding(
                                                    padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          children: [
                                                            for (int i = 0;
                                                            i < detailColumns.length;
                                                            i++) ...[
                                                              SizedBox(
                                                                  width: detailColumns[i]
                                                                      .width,
                                                                  child: detailCells[i]),
                                                              if (i !=
                                                                  detailColumns.length - 1)
                                                                SizedBox(width: gap),
                                                            ],
                                                          ],
                                                        ),
                                                        const Divider(
                                                            height: 1,
                                                            color: Color(0xFF475569)),
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
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFF334155)),
                        _historyFooterBar(
                          isSmall: isSmall,
                          onPrint: () async {
                            try {
                              await printItemHistory(
                                context,
                                entries: datafeed.itemHistoryEntries,
                                itemName: itemName,
                                dateLabel: dateLabel,
                                companyName: datafeed.company,
                              );
                            } catch (e) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text('Print failed: $e')),
                                );
                              }
                            }
                          },
                          onDownloadPdf: () async {
                            try {
                              await downloadItemHistoryPdf(
                                entries: datafeed.itemHistoryEntries,
                                itemName: itemName,
                                dateLabel: dateLabel,
                                companyName: datafeed.company,
                              );
                            } catch (e) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text('PDF download failed: $e')),
                                );
                              }
                            }
                          },
                          onDownloadExcel: () async {
                            try {
                              await exportItemHistoryExcel(
                                entries: datafeed.itemHistoryEntries,
                                itemName: itemName,
                                dateLabel: dateLabel,
                                companyName: datafeed.company,
                              );
                            } catch (e) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text('Excel export failed: $e')),
                                );
                              }
                            }
                          },
                          onClose: () {
                            datafeed.updateItemHistorySearch('');
                            Navigator.pop(dialogContext);
                          },
                          pager: _dialogPagerFooter(
                            label: 'Records',
                            count: entries.length,
                            page: historyPage,
                            totalPages: totalPages,
                            onPageChanged: (next) =>
                                setDialogState(() => historyPage = next),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  Future<void> printStockTransactionsPdf({
    required List<Map<String, dynamic>> transactions,
    required String itemName,
    required String companyName,
    String branchName = 'All Branches',
    String dateRange = '',
    double? boxpiece,
  }) async {
    final pdf = pw.Document();

    final regular =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold =
    pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final now = DateTime.now();
    final hasCarton = boxpiece != null && boxpiece > 0;

    const headerBg = PdfColors.white;
    const totalBg = PdfColors.white;

    String fmt(dynamic v) {
      if (v == null) return '0';
      final d = double.tryParse(v.toString()) ?? 0.0;
      return d == d.truncateToDouble()
          ? d.toInt().toString()
          : d.toStringAsFixed(2);
    }

    double num0(dynamic v) => double.tryParse('${v ?? 0}') ?? 0.0;

    pw.Widget cell(
        String text, {
          bool head = false,
          bool isBold = false,
          bool right = true,
        }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 3),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: (head || isBold) ? bold : regular,
            fontSize: head ? 6.5 : 7.5,
            color: PdfColors.black,
          ),
        ),
      );
    }

    pw.Widget infoRow(String label, String val, {bool end = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          mainAxisAlignment:
          end ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
          children: [
            pw.Text('$label:  ', style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text(val, style: pw.TextStyle(font: regular, fontSize: 10)),
          ],
        ),
      );
    }

    pw.Widget sectionLabel(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: bold,
          fontSize: 10,
          color: PdfColors.grey600,
          letterSpacing: 1.4,
        ),
      ),
    );

    final headers = <String>[
      '#',
      'DATE',
      'OPENING',
      'NEW\nSTOCK',
      'TRANSFER\nIN',
      'TRANSFER\nOUT',
      'SALES\nQTY',
      'CASH\nSALES',
      'CREDIT\nSALES',
      'SALE\nRETURNS',
      'PURCHASE\nRETURNS',
      'DAMAGES',
      'BALANCE',
      if (hasCarton) 'CARTON',
    ];

    double totSalesQty = 0, totCash = 0, totCredit = 0;
    double totTransferIn = 0, totTransferOut = 0;
    double totSaleReturns = 0, totPurchaseReturns = 0, totDamages = 0;
    double totNewStock = 0, totBalance = 0;

    for (final t in transactions) {
      totNewStock += num0(t['newstock']);
      totTransferIn += num0(t['transfer_recieved_qty']);
      totTransferOut += num0(t['transfer_qty'] ?? t['transfer']);
      totSalesQty += num0(t['sales_qty']);
      totCash += num0(t['cash_sales']);
      totCredit += num0(t['credit_sales']);
      totSaleReturns += num0(t['sale_returns']);
      totPurchaseReturns += num0(t['purchase_returns']);
      totDamages += num0(t['damages']);
      totBalance += num0(t['balance_cd']);
    }

    final summary = <List<String>>[
      ['Total Transactions', '${transactions.length}'],
      ['Transfer In', fmt(totTransferIn)],
      ['Transfer Out', fmt(totTransferOut)],
      ['Sales Qty', fmt(totSalesQty)],
      ['Cash Sales', fmt(totCash)],
      ['Credit Sales', fmt(totCredit)],
      ['Sale Returns', fmt(totSaleReturns)],
      ['Damages', fmt(totDamages)],
      ['Balance', fmt(totBalance)],
      if (hasCarton) ['Carton', fmt(totBalance / boxpiece!)],
    ];

    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(20),
      1: const pw.FixedColumnWidth(52),
      for (int i = 2; i < headers.length; i++) i: const pw.FlexColumnWidth(1),
    };

    final border = pw.TableBorder.all(color: PdfColors.grey300, width: 0.8);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.all(24),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(thickness: 0.1, color: PdfColors.grey),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(now)}',
                  style: pw.TextStyle(
                      font: regular, fontSize: 9, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: regular, fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          // ── Title block ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    companyName.toUpperCase(),
                    style: pw.TextStyle(font: bold, fontSize: 22),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    branchName,
                    style: pw.TextStyle(
                        font: regular, fontSize: 11, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('STOCK MOVEMENT REPORT',
                      style: pw.TextStyle(font: bold, fontSize: 18)),


                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // ── Info block ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    infoRow('Item', itemName),
                    infoRow('Period', dateRange.isEmpty ? 'All' : dateRange),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    infoRow('Branch', branchName, end: true),
                    infoRow('Transactions', '${transactions.length}', end: true),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // ── Stock movement ──
          sectionLabel('STOCK MOVEMENT'),
          pw.Table(
            border: border,
            columnWidths: colWidths,
            children: [
              pw.TableRow(
                repeat: true,
                decoration: const pw.BoxDecoration(color: headerBg),
                children: [
                  for (int i = 0; i < headers.length; i++)
                    cell(headers[i], head: true, right: i != 1),
                ],
              ),
              ...transactions.asMap().entries.map((entry) {
                final item = entry.value;
                final balance = num0(item['balance_cd']);
                final bp = hasCarton ? boxpiece! : 1.0;
                final carton = balance / bp;

                final values = [
                  '${entry.key + 1}',
                  item['date']?.toString() ?? '',
                  fmt(item['opening_stock']),
                  fmt(item['newstock']),
                  fmt(item['transfer_recieved_qty']),
                  fmt(item['transfer_qty'] ?? item['transfer']),
                  fmt(item['sales_qty']),
                  fmt(item['cash_sales']),
                  fmt(item['credit_sales']),
                  fmt(item['sale_returns']),
                  fmt(item['purchase_returns']),
                  fmt(item['damages']),
                  fmt(balance),
                  if (hasCarton) (carton > 0 ? fmt(carton) : '-'),
                ];

                return pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.white),
                  children: [
                    for (int i = 0; i < values.length; i++)
                      cell(
                        values[i],
                        right: i != 1 && i != 0 ? true : false,
                        isBold: i == 12, // balance column
                      ),
                  ],
                );
              }),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.white),
                children: [
                  cell(''),
                  cell('GRAND TOTAL', isBold: true, right: false),
                  cell(''),
                  cell(fmt(totNewStock), isBold: true),
                  cell(fmt(totTransferIn), isBold: true),
                  cell(fmt(totTransferOut), isBold: true),
                  cell(fmt(totSalesQty), isBold: true),
                  cell(fmt(totCash), isBold: true),
                  cell(fmt(totCredit), isBold: true),
                  cell(fmt(totSaleReturns), isBold: true),
                  cell(fmt(totPurchaseReturns), isBold: true),
                  cell(fmt(totDamages), isBold: true),
                  cell(fmt(totBalance), isBold: true),
                  if (hasCarton) cell(fmt(totBalance / boxpiece!), isBold: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'stock_movement_${itemName}_${now.millisecondsSinceEpoch}.pdf',
    );
  }



    }



class _StockColumn {
  final String label;
  final double width;
  final bool numeric;
  const _StockColumn(this.label, this.width, {this.numeric = false});
}
class _HistoryColumn {
  final String label;
  final double width;
  const _HistoryColumn(this.label, this.width);
}