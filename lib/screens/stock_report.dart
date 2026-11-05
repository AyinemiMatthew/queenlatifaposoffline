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
import '../widgets/printStockReportPdf.dart';
import 'stock_movement_page.dart';

class StockReportPage extends StatefulWidget {
  const StockReportPage({super.key});

  @override
  State<StockReportPage> createState() => _StockReportPageState();
}

class _StockReportPageState extends State<StockReportPage> {
  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _backgroundColor =>
      _isLightTheme ? Colors.white : AppColors.background;
  Color get _surfaceColor => _isLightTheme ? Colors.white : AppColors.surface;
  Color get _surfaceLightColor =>
      _isLightTheme ? Colors.white : AppColors.surfaceLight;
  Color get _primaryColor =>
      _isLightTheme ? Theme.of(context).colorScheme.primary : AppColors.primary;
  Color get _textPrimaryColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurface
      : AppColors.textPrimary;
  Color get _textSecondaryColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : AppColors.textSecondary;
  Color get _textMutedColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : AppColors.textMuted;
  Color get _borderColor =>
      _isLightTheme ? Colors.grey.shade300 : AppColors.border;
  Color get _cardBorderColor =>
      _isLightTheme ? Colors.grey.shade300 : AppColors.cardBorder;
  Color get _alternateRowColor =>
      _isLightTheme ? Colors.grey.shade50 : AppColors.surfaceLight;

  Datafeed? _datafeed;
  DateTimeRange? _selectedDateRange;
  String? _selectedType;
  String? _selectedCategory;
  String? _status;
  static const int _rowsPerPage = 10;
  static const double _colGap = 10;
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
      final access = datafeed.accesslevel.toLowerCase().trim();

      final canSelectBranches =
          access == 'super admin' ||
          access == 'systemadmin' ||
          access == 'admin';

      if (!canSelectBranches) {
        selectedBranch = datafeed.branchid;
        selectedBranchName = datafeed.branch;
      }

      await datafeed.fetchstockreport(selectedBranch: selectedBranch);
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

  Widget _reportStatusBanner(Datafeed provider) {
    if (!provider.stockReportOffline && provider.stockReportError == null) {
      return const SizedBox.shrink();
    }

    final hasData = provider.stockReportHasVisibleData;
    final isOffline = provider.stockReportOffline;
    final colorScheme = Theme.of(context).colorScheme;
    final message = isOffline
        ? hasData
              ? 'Offline · Showing saved stock report data.'
              : "Stock report isn't available offline yet. Connect to the internet to load it."
        : hasData
        ? "Couldn't refresh the stock report. Showing saved data."
        : "Couldn't load the stock report. Check your connection and try again.";

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOffline
            ? colorScheme.secondaryContainer
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.cloud_off_outlined : Icons.info_outline,
            color: isOffline
                ? colorScheme.onSecondaryContainer
                : colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isOffline
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: provider.isLoadingStockReport ? null : _applyFilters,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text(
          'Select Date Range',
          style: TextStyle(color: _textPrimaryColor),
        ),
        content: SizedBox(
          height: 400,
          width: 320,
          child: SfDateRangePicker(
            backgroundColor: _surfaceColor,

            headerStyle: DateRangePickerHeaderStyle(
              backgroundColor: _surfaceColor,
              textAlign: TextAlign.center,
              textStyle: TextStyle(
                color: _textPrimaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),

            monthViewSettings: DateRangePickerMonthViewSettings(
              viewHeaderStyle: DateRangePickerViewHeaderStyle(
                textStyle: TextStyle(
                  color: _textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            monthCellStyle: DateRangePickerMonthCellStyle(
              textStyle: TextStyle(color: _textPrimaryColor),

              todayTextStyle: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),

              weekendTextStyle: TextStyle(color: _textSecondaryColor),

              disabledDatesTextStyle: TextStyle(color: _textMutedColor),
            ),

            selectionColor: Colors.blueAccent,
            startRangeSelectionColor: Colors.blueAccent,
            endRangeSelectionColor: Colors.blueAccent,
            rangeSelectionColor: Colors.blueAccent.withOpacity(0.15),

            todayHighlightColor: Colors.blueAccent,

            selectionTextStyle: TextStyle(
              color: _isLightTheme
                  ? Theme.of(context).colorScheme.onPrimary
                  : Colors.white,
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
          ),
        ),

        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _applyFilters();
            },
            child: Text('Clear', style: TextStyle(color: _textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
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

  double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

  List<Map<String, dynamic>> _rows(Datafeed p) => p.filterstockreport(
    productType: _selectedType,
    category: _selectedCategory,
    status: _status,
  );

  void _openSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch(Datafeed p) {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    p.updateStockReportSearch('');
  }

  String _filterSummary() {
    final parts = [
      if (_selectedType != null) _selectedType!,
      if (_selectedCategory != null) _selectedCategory!,
      if (_status != null) _status!,
    ];
    return parts.isEmpty ? '' : ' - ¢ ${parts.join(' -¢ ')}';
  }

  int get _totalPages {
    final totalItems = _rows(context.read<Datafeed>()).length;
    return totalItems == 0 ? 1 : ((totalItems - 1) ~/ _rowsPerPage) + 1;
  }

  List<Map<String, dynamic>> _pageRows(
    List<Map<String, dynamic>> rows, [
    int? pageIndex,
  ]) {
    if (rows.isEmpty) return const [];
    final safePage = (pageIndex ?? _currentPage).clamp(
      0,
      ((rows.length - 1) ~/ _rowsPerPage),
    );
    final start = safePage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  void _resetPage() => setState(() => _currentPage = 0);

  List<Widget> _appBarActions(
    BuildContext context,
    Datafeed provider,
    List<Map<String, dynamic>> stockreport,
    bool compact,
  ) {
    Widget filterIcon(
      GlobalKey k,
      IconData icon,
      String tip,
      bool active,
      VoidCallback onTap,
    ) => IconButton(
      key: k,
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon, size: 21, color: active ? _accent : _textPrimaryColor),
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
      color: _surfaceColor,
      icon: Icon(
        Icons.file_download_outlined,
        size: 21,
        color: _status != null ? _accent : _textPrimaryColor,
      ),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'pdf',
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
                color: _textSecondaryColor,
              ),
              SizedBox(width: 10),
              Text('Download PDF'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'excel',
          child: Row(
            children: [
              Icon(
                Icons.grid_on_outlined,
                size: 18,
                color: _textSecondaryColor,
              ),
              SizedBox(width: 10),
              Text('Download Excel'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'status_all',
          child: Text(
            'All Stock',
            style: TextStyle(
              color: _status == null ? _accent : _textPrimaryColor,
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'status_finished',
          child: Text(
            'Finished',
            style: TextStyle(
              color: _status == 'Finished' ? _accent : _textPrimaryColor,
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'status_reorder',
          child: Text(
            'Reorder',
            style: TextStyle(
              color: _status == 'Reorder' ? _accent : _textPrimaryColor,
            ),
          ),
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

    if (provider.isAdminLevel) {
      commonActions.add(
        IconButton(
          icon: const Icon(Icons.home, size: 25),
          tooltip: 'Home',
          onPressed: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false),
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
        icon: Icon(
          Icons.date_range,
          size: 21,
          color: _selectedDateRange != null ? _accent : _textPrimaryColor,
        ),
        onPressed: _showDateRangePicker,
      ),
      filterIcon(
        _typeKey,
        Icons.inventory_2_outlined,
        'Product type: ${_selectedType ?? 'All'}',
        _selectedType != null,
        () => _showFilterMenu(
          _typeKey,
          'All Product Types',
          provider.stockProductTypes,
          _selectedType,
          (v) {
            setState(() => _selectedType = v);
            _resetPage();
          },
        ),
      ),
      filterIcon(
        _categoryKey,
        Icons.category_outlined,
        'Category: ${_selectedCategory ?? 'All'}',
        _selectedCategory != null,
        () => _showFilterMenu(
          _categoryKey,
          'All Categories',
          provider.stockCategories,
          _selectedCategory,
          (v) {
            setState(() => _selectedCategory = v);
            _resetPage();
          },
        ),
      ),
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
          color: _surfaceColor,
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => [
            if (!provider.isAdminLevel)
              const PopupMenuItem<String>(value: 'home', child: Text('Home')),
            const PopupMenuItem<String>(value: 'search', child: Text('Search')),
            if (provider.canDeleteRecords || provider.isAdminLevel)
              const PopupMenuItem<String>(
                value: 'branch',
                child: Text('Branch'),
              ),
            const PopupMenuItem<String>(
              value: 'date',
              child: Text('Date range'),
            ),
            const PopupMenuItem<String>(value: 'type', child: Text('Type')),
            const PopupMenuItem<String>(
              value: 'category',
              child: Text('Category'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'status_all',
              child: Text('All Stock'),
            ),
            const PopupMenuItem<String>(
              value: 'status_finished',
              child: Text('Finished'),
            ),
            const PopupMenuItem<String>(
              value: 'status_reorder',
              child: Text('Reorder'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'pdf',
              child: Text('Download PDF'),
            ),
            const PopupMenuItem<String>(
              value: 'excel',
              child: Text('Download Excel'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'refresh',
              child: Text('Refresh'),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'home':
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/home', (route) => false);
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
                _showFilterMenu(
                  _typeKey,
                  'All Product Types',
                  provider.stockProductTypes,
                  _selectedType,
                  (v) {
                    setState(() => _selectedType = v);
                    _resetPage();
                  },
                );
                break;
              case 'category':
                _showFilterMenu(
                  _categoryKey,
                  'All Categories',
                  provider.stockCategories,
                  _selectedCategory,
                  (v) {
                    setState(() => _selectedCategory = v);
                    _resetPage();
                  },
                );
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
        ),
      ];
    }

    return commonActions;
  }

  void _showFilterMenu(
    GlobalKey key,
    String allLabel,
    List<String> options,
    String? current,
    ValueChanged<String?> onPicked,
  ) {
    final RenderBox button =
        key.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final p = button.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(p.dx, p.dy + button.size.height, button.size.width, 0),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: _surfaceColor,
      items: [
        PopupMenuItem<String>(
          value: '__ALL__',
          child: Text(
            allLabel,
            style: TextStyle(
              color: current == null ? _accent : _textPrimaryColor,
              fontSize: 13,
            ),
          ),
        ),
        ...options.map(
          (o) => PopupMenuItem<String>(
            value: o,
            child: Text(
              o,
              style: TextStyle(
                color: o == current ? _accent : _textPrimaryColor,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    ).then((picked) {
      if (picked == null) return;
      onPicked(picked == '__ALL__' ? null : picked);
    });
  }

  bool _isSalesPointType(String? t) =>
      (t ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '') ==
      'salespoint';

  void _showBranchMenu(Datafeed value) {
    final visible = value.branches
        .where((b) => !_isSalesPointType(b.branchtype))
        .toList();

    _showFilterMenu(
      _branchKey,
      'All Branches',
      visible.map((b) => b.branchname).toList(),
      selectedBranch == null ? null : selectedBranchName,
      (name) {
        final branch = name == null
            ? null
            : visible.firstWhere((b) => b.branchname == name);
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
    final totalPages = stockreport.isEmpty
        ? 1
        : ((stockreport.length - 1) ~/ _rowsPerPage) + 1;
    final effectivePage = _currentPage.clamp(
      0,
      totalPages == 0 ? 0 : totalPages - 1,
    );

    final paginatedRows = _pageRows(stockreport, effectivePage);
    final stockTotal = stockreport.fold<double>(
      0,
      (s, r) => s + _num(r['stock_value']),
    );

    final sellTotal = stockreport.fold<double>(
      0,
      (s, r) => s + _num(r['selling_value']),
    );

    final compactAppBar = MediaQuery.of(context).size.width < 860;
    final compactFooter = MediaQuery.of(context).size.width < 600;
    final compactTitleWidth = (MediaQuery.of(context).size.width - 100).clamp(
      80.0,
      170.0,
    );

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        foregroundColor: _textPrimaryColor,
        elevation: 0,
        titleSpacing: 12,
        automaticallyImplyLeading: !_isSearching,
        title: _isSearching
            ? Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 21),
                    onPressed: () => _closeSearch(provider),
                  ),
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                          ),
                          cursorColor: Theme.of(context).colorScheme.primary,
                          decoration: InputDecoration(
                            hintText: 'Search stock...',
                            hintStyle: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
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
                ],
              )
            : SizedBox(
                width: compactAppBar ? compactTitleWidth : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Stock Report',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _textPrimaryColor,
                      ),
                    ),
                    Text(
                      '${selectedBranchName ?? provider.company}${_filterSummary()} - ${_formatDateRange()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: _textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
        actions: _isSearching
            ? null
            : _appBarActions(context, provider, stockreport, compactAppBar),
      ),
      body: Column(
        children: [
          if (provider.stockReportOffline || provider.stockReportError != null)
            _reportStatusBanner(provider),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1430),
                  child:
                      provider.isLoadingStockReport &&
                          !provider.stockReportHasVisibleData
                      ? Center(
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                          ),
                        )
                      : stockreport.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: _textMutedColor,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No stock items found',
                                style: TextStyle(color: _textMutedColor),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _surfaceColor,
                                  border: Border.all(color: _borderColor),
                                ),
                                clipBehavior: Clip.none,
                                child: isLargeScreen
                                    ? _buildStockTable(paginatedRows)
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(5),
                                        itemCount: paginatedRows.length,
                                        itemBuilder: (_, i) =>
                                            _buildStockCard(paginatedRows[i]),
                                      ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: _surfaceColor,
                                border: Border(
                                  top: BorderSide(
                                    color: _borderColor,
                                    width: 0.7,
                                  ),
                                ),
                              ),
                              child: isLargeScreen
                                  ? Row(
                                      children: [
                                        if (stockreport.length > _rowsPerPage)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  tooltip: 'Previous page',
                                                  onPressed: effectivePage > 0
                                                      ? () => setState(
                                                          () => _currentPage =
                                                              effectivePage - 1,
                                                        )
                                                      : null,
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(
                                                    Icons.chevron_left,
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _backgroundColor,
                                                  ),
                                                  child: Text(
                                                    '${effectivePage + 1}/$totalPages',
                                                    style: TextStyle(
                                                      color: _textPrimaryColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Next page',
                                                  onPressed:
                                                      effectivePage <
                                                          totalPages - 1
                                                      ? () => setState(
                                                          () => _currentPage =
                                                              effectivePage + 1,
                                                        )
                                                      : null,
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(
                                                    Icons.chevron_right,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        Expanded(
                                          child: _buildDesktopTotalsRow(
                                            _stockColumns(),
                                            stockreport.length,
                                            stockTotal,
                                            sellTotal,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        if (!compactFooter)
                                          Expanded(
                                            child: _footerStat(
                                              'Items',
                                              stockreport.length,
                                            ),
                                          ),

                                        Expanded(
                                          child: _footerStat(
                                            'Total Cost Value(GHS)',
                                            _formatMoney(stockTotal),
                                            dense: compactFooter,
                                          ),
                                        ),
                                        Expanded(
                                          child: _footerStat(
                                            'Total Selling Value(GHS)',
                                            _formatMoney(sellTotal),
                                            dense: compactFooter,
                                          ),
                                        ),
                                        if (stockreport.length > _rowsPerPage)
                                          Padding(
                                            padding: EdgeInsets.only(
                                              right: compactFooter ? 2 : 8,
                                            ),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  tooltip: 'Previous page',
                                                  onPressed: effectivePage > 0
                                                      ? () => setState(
                                                          () => _currentPage =
                                                              effectivePage - 1,
                                                        )
                                                      : null,
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(
                                                    Icons.chevron_left,
                                                  ),
                                                ),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: compactFooter
                                                        ? 5
                                                        : 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _backgroundColor,
                                                  ),
                                                  child: Text(
                                                    '${effectivePage + 1}/$totalPages',
                                                    style: TextStyle(
                                                      color: _textPrimaryColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Next page',
                                                  onPressed:
                                                      effectivePage <
                                                          totalPages - 1
                                                      ? () => setState(
                                                          () => _currentPage =
                                                              effectivePage + 1,
                                                        )
                                                      : null,
                                                  padding: EdgeInsets.zero,
                                                  icon: const Icon(
                                                    Icons.chevron_right,
                                                  ),
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
          ),
        ],
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
      const _StockColumn('Total', 80, numeric: true),
      const _StockColumn('Sales qty', 70, numeric: true),
      const _StockColumn('Purchase. Return.', 70, numeric: true),
      const _StockColumn('Damages', 70, numeric: true),
      if (selectedBranch != null)
        const _StockColumn('Transfer. Out', 70, numeric: true),

      const _StockColumn('Pieces Balance', 95, numeric: true),
      const _StockColumn('Cartons Balance', 105, numeric: true),
      const _StockColumn('Cost Value(GHS)', 110, numeric: true),
      const _StockColumn('Selling Value(GHS)', 115, numeric: true),
    ];
  }

  Widget _buildStockTable(List<Map<String, dynamic>> reportData) {
    final columns = _stockColumns();
    final double colsSum = columns.fold<double>(0, (s, c) => s + c.width);
    final double gapsSum = (columns.length - 1) * _colGap;
    final double totalColsWidth = colsSum + gapsSum + 32;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double contentWidth = constraints.maxWidth > totalColsWidth
            ? constraints.maxWidth
            : totalColsWidth;

        final double scale = constraints.maxWidth > totalColsWidth
            ? (constraints.maxWidth - gapsSum - 32) / colsSum
            : 1.0;

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
                    color: _surfaceLightColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (int i = 0; i < columns.length; i++) ...[
                          SizedBox(
                            width: columns[i].width * scale,
                            child: Text(
                              columns[i].label,
                              textAlign: columns[i].numeric
                                  ? TextAlign.right
                                  : TextAlign.left,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _textPrimaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (i != columns.length - 1)
                            const SizedBox(width: _colGap),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _borderColor),
                  Expanded(
                    child: ListView.builder(
                      itemCount: reportData.length,
                      itemBuilder: (context, i) => Column(
                        children: [
                          _buildStockRow(
                            context,
                            reportData[i],
                            (i + (_currentPage * _rowsPerPage)),
                            columns,
                            selectedBranch,
                            scale,
                          ),
                          Divider(height: 1, color: _borderColor),
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

  Widget _buildStockRow(
    BuildContext context,
    Map<String, dynamic> item,
    int index,
    List<_StockColumn> columns,
    dynamic selectedBranch, [
    double scale = 1.0,
  ]) {
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
    final boxPiece = _num(item['cartonqty_bal']);
    final cartonQtyBal = _num(balanceCd) / (boxPiece == 0 ? 1 : boxPiece);

    final cells = <Widget>[
      Text(
        '${index + 1}',
        style: TextStyle(fontSize: 12, color: _textPrimaryColor),
      ),
      Text(
        itemname,
        softWrap: true,
        overflow: TextOverflow.visible,
        style: TextStyle(fontSize: 12, color: _textPrimaryColor),
      ),
      Text(
        _formatNumber(openingStock),
        textAlign: TextAlign.right,
        style: TextStyle(fontWeight: FontWeight.w500, color: _textPrimaryColor),
      ),
      Text(
        _formatNumber(newStock),
        textAlign: TextAlign.right,
        style: TextStyle(fontWeight: FontWeight.w500, color: _textPrimaryColor),
      ),
      if (selectedBranch != null)
        Text(
          _formatNumber(transferIn),
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: _textPrimaryColor,
          ),
        ),
      Text(
        _formatNumber(saleReturns),
        textAlign: TextAlign.right,
        style: TextStyle(color: _textSecondaryColor),
      ),
      Text(
        _formatNumber(totalStock),
        textAlign: TextAlign.right,
        style: TextStyle(fontWeight: FontWeight.w500, color: _textPrimaryColor),
      ),
      Text(
        _formatNumber(salesQty),
        textAlign: TextAlign.right,
        style: TextStyle(fontWeight: FontWeight.w500, color: _textPrimaryColor),
      ),
      Text(
        _formatNumber(purchaseReturns),
        textAlign: TextAlign.right,
        style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimaryColor),
      ),
      Text(
        _formatNumber(damages),
        textAlign: TextAlign.right,
        style: TextStyle(color: _textSecondaryColor),
      ),
      if (selectedBranch != null)
        Text(
          _formatNumber(transfer),
          textAlign: TextAlign.right,
          style: TextStyle(color: _textSecondaryColor),
        ),

      _stockBalanceCell(balanceCd),
      Text(
        _formatNumber(cartonQtyBal),
        textAlign: TextAlign.right,
        style: TextStyle(color: _textSecondaryColor),
      ),
      Text(
        _formatMoney(item['stock_value']),
        textAlign: TextAlign.right,
        style: TextStyle(color: _textPrimaryColor),
      ),
      Text(
        _formatMoney(item['selling_value']),
        textAlign: TextAlign.right,
        style: TextStyle(color: _textPrimaryColor),
      ),
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
        color: index.isEven ? _surfaceColor : _alternateRowColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (int i = 0; i < columns.length; i++) ...[
              SizedBox(width: columns[i].width * scale, child: cells[i]),
              if (i != columns.length - 1) const SizedBox(width: _colGap),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard(Map<String, dynamic> item) {
    final transfer = item['transfer_qty'] ?? 0;
    final transferIn = item['transfer_recieved_qty'] ?? 0;
    final itemid = item['itemid'] ?? '';
    final itemname = item['item'] ?? '';
    final balanceCd = item['balance_cd'] ?? 0;

    final openingStock = item['opening_stock'] ?? 0;
    final newStock = item['newstock'] ?? 0;
    final totalStock = item['total_stock'] ?? 0;
    final salesQty = item['sales_qty'] ?? 0;
    final cashSales = item['cash_sales'] ?? 0;
    final creditSales = item['credit_sales'] ?? 0;
    final purchaseReturns = item['purchase_returns'] ?? 0;
    final damages = item['damages'] ?? 0;

    final saleReturns = item['sale_returns'] ?? 0;
    final stockOut = item['stock_out'] ?? 0;

    final boxPiece = _num(item['cartonqty_bal']);
    final cartonQtyBal = _num(balanceCd) / (boxPiece == 0 ? 1 : boxPiece);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border.all(color: _cardBorderColor),
      ),
      child: InkWell(
        onTap: () {
          showStockTransactionsDialog(
            context,
            itemId: itemid,
            itemName: itemname,
            boxpiece: boxPiece,
          );
        },

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header  product name + balance
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item['item'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimaryColor,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _stockBalanceCell(balanceCd, label: 'Balance', large: true),
                    const SizedBox(height: 2),
                    Text(
                      'Carton: ${_formatNumber(cartonQtyBal)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            Divider(height: 20, color: _borderColor),

            //Stock movement
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _miniStat2("Opening", openingStock),
                _miniStat2("New Stock", newStock),
                _miniStat2("Total", totalStock),
                _miniStat2("Sales Qty", salesQty),
                _miniStat2("Sale Returns", saleReturns),
                _miniStat2("Purchase Returns", purchaseReturns),
                _miniStat2("Damages", damages),
                _miniStat2("Transfer Out", transfer),
                _miniStat2("Transfer In", transferIn),
                _miniStat2("Carton", cartonQtyBal),

                _miniStat2("Cost Value(GHS)", _formatMoney(item['stock_value'])),
                _miniStat2(
                  "Selling Value(GHS)",
                  _formatMoney(item['selling_value']),
                ),
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
      decoration: BoxDecoration(
        color: _surfaceColor,
        border: Border(
          left: BorderSide(color: _borderColor, width: 0.7),
          right: BorderSide(color: _borderColor, width: 0.7),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 150;
          final label = Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textSecondaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
          final amount = Text(
            value.toString(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textPrimaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [label, amount],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: label),
                    Flexible(child: amount),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildDesktopTotalsRow(
    List<_StockColumn> columns,
    int itemCount,
    double stockTotal,
    double sellTotal,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double colsSum = columns.fold<double>(0, (s, c) => s + c.width);
        final double gapsSum = (columns.length - 1) * _colGap;
        final double totalColsWidth = colsSum + gapsSum + 32;

        final double width = constraints.maxWidth > totalColsWidth
            ? constraints.maxWidth
            : totalColsWidth;
        final double scale = constraints.maxWidth > totalColsWidth
            ? (constraints.maxWidth - gapsSum - 32) / colsSum
            : 1.0;

        return SingleChildScrollView(
          controller: _footerHController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: width,
            child: Container(
              height: 42,
              color: _surfaceLightColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (int i = 0; i < columns.length; i++) ...[
                    SizedBox(
                      width: columns[i].width * scale,
                      child: columns[i].label == 'Product'
                          ? Text(
                              '$itemCount item${itemCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _textPrimaryColor,
                                fontSize: 12,
                              ),
                            )
                          : columns[i].label == 'Cost Value'
                          ? Text(
                              _formatMoney(stockTotal),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _textPrimaryColor,
                                fontSize: 13,
                              ),
                            )
                          : columns[i].label == 'Selling Value'
                          ? Text(
                              _formatMoney(sellTotal),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _textPrimaryColor,
                                fontSize: 13,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (i != columns.length - 1) const SizedBox(width: _colGap),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniStat2(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: _textMutedColor)),
        const SizedBox(height: 2),
        Text(
          _formatNumber(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _stockBalanceCell(dynamic value, {String? label, bool large = false}) {
    final balance = _num(value);
    final textStyle = TextStyle(
      fontSize: large ? 16 : 12,
      fontWeight: FontWeight.bold,
      color: _textSecondaryColor,
    );

    if (balance >= 0) {
      return Text(
        '${label == null ? '' : '$label: '}${_formatNumber(balance)}',
        textAlign: TextAlign.right,
        style: textStyle,
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Tooltip(
        message:
            'Negative stock may indicate sales were recorded before stock was received. Check pending stock-in or stock adjustments.',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (label != null)
              Text(
                '$label: ',
                style: textStyle.copyWith(
                  fontSize: large ? 13 : 11,
                  color: _textSecondaryColor,
                ),
              ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: large ? 8 : 5,
                vertical: large ? 4 : 2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: large ? 16 : 13,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatNumber(balance),
                    textAlign: TextAlign.right,
                    style: textStyle.copyWith(
                      fontSize: large ? 16 : 12,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    return _nf.format(_num(number));
  }

  String _formatMoney(dynamic value) {
    final amount = _num(value);
    return ' ${_nf.format(amount.abs() < 0.005 ? 0 : amount)}';
  }

  void showStockTransactionsDialog(
    BuildContext context, {
    required String itemId,
    required String itemName,
    double? boxpiece,
  }) {
    final company = context.read<Datafeed>().company;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockMovementPage(
          itemId: itemId,
          itemName: itemName,
          boxpiece: boxpiece,
          branchId: selectedBranch,
          branchName: selectedBranchName,
          dateRange: _selectedDateRange,
          onPrint: (transactions) => printStockTransactionsPdf(
            transactions: transactions,
            itemName: itemName,
            companyName: company,
            branchName: selectedBranchName ?? 'All Branches',
            dateRange:
                '${DateFormat('d MMMM y').format(_selectedDateRange?.start ?? DateTime.now())}'
                ' - '
                '${DateFormat('d MMMM y').format(_selectedDateRange?.end ?? DateTime.now())}',
            boxpiece: boxpiece,
          ),
        ),
      ),
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

    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );

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
          mainAxisAlignment: end
              ? pw.MainAxisAlignment.end
              : pw.MainAxisAlignment.start,
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
                    font: regular,
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 9,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          // -- Title block --
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
                      font: regular,
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'STOCK MOVEMENT REPORT',
                    style: pw.TextStyle(font: bold, fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),

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
                    infoRow(
                      'Transactions',
                      '${transactions.length}',
                      end: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

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
                  if (hasCarton)
                    cell(fmt(totBalance / boxpiece!), isBold: true),
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
