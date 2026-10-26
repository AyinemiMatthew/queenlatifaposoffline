import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/StockProvider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../constants/constants.dart';
import '../paymentwidgets/changepasswordDialog.dart';
import '../paymentwidgets/showlogout.dart';
import '../providers/routes.dart';

class _WarehousePalette {
  _WarehousePalette(ThemeData theme)
      : isLight = theme.brightness == Brightness.light,
        surface = theme.brightness == Brightness.light
            ? theme.colorScheme.surface
            : Constants.bgCard,
        background = theme.brightness == Brightness.light
            ? theme.colorScheme.surface
            : Constants.bgDark,
        elevatedSurface = theme.brightness == Brightness.light
            ? theme.colorScheme.surfaceContainerHighest
            : Constants.bgInput,
        gradientSurface = theme.brightness == Brightness.light
            ? theme.colorScheme.surfaceContainerHighest
            : const Color(0xFF1E2645),
        primaryText = theme.brightness == Brightness.light
            ? theme.colorScheme.onSurface
            : Constants.textPrimary,
        secondaryText = theme.brightness == Brightness.light
            ? theme.colorScheme.onSurfaceVariant
            : Constants.textSecondary,
        mutedText = theme.brightness == Brightness.light
            ? theme.colorScheme.onSurfaceVariant
            : Constants.textMuted,
        border = theme.brightness == Brightness.light
            ? theme.colorScheme.outlineVariant
            : Constants.borderColor,
        amber = Constants.amber,
        amberFill = Constants.amberFill,
        green = Constants.green,
        accent = Constants.accent,
        amberBackground = theme.brightness == Brightness.light
            ? const Color(0xFFFFF4DF)
            : Constants.amberBg,
        greenBackground = theme.brightness == Brightness.light
            ? const Color(0xFFE8F5EC)
            : Constants.greenBg,
        onAccent = theme.brightness == Brightness.light
            ? theme.colorScheme.onSurface
            : Constants.bgDark;

  final bool isLight;
  final Color surface;
  final Color background;
  final Color elevatedSurface;
  final Color gradientSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final Color border;
  final Color amber;
  final Color amberFill;
  final Color green;
  final Color accent;
  final Color amberBackground;
  final Color greenBackground;
  final Color onAccent;
}

class SaleItem {
  final String name;
  final double qty;
  final double price;
  final String itemMode;
  final String branchid;
  bool isSupplied;

  SaleItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.itemMode,
    required this.branchid,
    this.isSupplied = false,
  });

  double get total => qty * price;
}

class Sale {
  final String id;
  final String receiptNumber;
  final String branchId;
  final String branchName;
  final String branchType;
  final String cashier;
  final String customerName;
  final DateTime date;
  final double totalAmount;
  final int itemCount;
  final List<SaleItem> items;
  final String paymentStatus;
  final String transMode;
  final String time;
  String supplyStatus; // 'pending', 'partial', 'completed'
  Sale copyWith({
    String? id,
    String? receiptNumber,
    String? branchId,
    String? branchName,
    String? branchType,
    String? cashier,
    String? customerName,
    DateTime? date,
    double? totalAmount,
    int? itemCount,
    List<SaleItem>? items,
    String? paymentStatus,
    String? transMode,
    String? time,
    String? supplyStatus,
  }) {
    return Sale(
      id: id ?? this.id,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      branchType: branchType ?? this.branchType,
      cashier: cashier ?? this.cashier,
      customerName: customerName ?? this.customerName,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      itemCount: itemCount ?? this.itemCount,
      items: items ?? this.items,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      transMode: transMode ?? this.transMode,
      time: time ?? this.time,
      supplyStatus: supplyStatus ?? this.supplyStatus,
    );
  }
  Sale({
    required this.id,
    required this.receiptNumber,
    required this.branchId,
    required this.branchName,
    required this.branchType,
    required this.cashier,
    required this.customerName,
    required this.date,
    required this.totalAmount,
    required this.itemCount,
    required this.items,
    required this.paymentStatus,
    required this.transMode,
    required this.time,
    this.supplyStatus = 'pending',
  });

  factory Sale.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final itemMap = Map<String, dynamic>.from(data['items'] ?? {});

    // Get supplied items list from firestore
    final suppliedItems = List<String>.from(data['suppliedItems'] ?? []);

    final items = itemMap.values.map((e) {
      final item = Map<String, dynamic>.from(e);
      final itemName = item['item'] ?? '';

      return SaleItem(
        name: itemName,
        qty: double.tryParse(item['quantity'].toString()) ?? 0,
        price: double.tryParse(item['price'].toString()) ?? 0,
        itemMode: item['mode'] ?? 'single',
        branchid: item['branchid'] ?? 'N/A',
        isSupplied: suppliedItems.contains(itemName),
      );
    }).toList();

    final createdAt = data['createdAt'] as Timestamp?;

    // Determine supply status
    String status = data['supplyStatus'] ?? 'pending';
    if (status == 'completed' || data['isSupplied'] == true) {
      status = 'completed';
    }

    return Sale(
      id: data['id'] ?? doc.id,
      receiptNumber: data['receiptNumber'] ?? '',
      branchId: data['branchId'] ?? '',
      branchName: data['branchName'] ?? '',
      branchType: data['branchType'] ?? '',
      cashier: data['createdBy'] ?? '',
      customerName: data['customerName'] ?? '',
      date: createdAt?.toDate() ?? DateTime.now(),
      totalAmount: (data['totalamount'] as num?)?.toDouble() ?? 0,
      itemCount: data['itemCount'] ?? items.length,
      items: items,
      paymentStatus: data['paymentStatus'] ?? '',
      transMode: data['transMode'] ?? '',
      time: DateFormat('HH:mm').format(createdAt?.toDate() ?? DateTime.now()),
      supplyStatus: status,
    );
  }

  String get dateYmd {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool get isFullySupplied => supplyStatus == 'completed';
  bool get isPartiallySupplied => supplyStatus == 'partial';
  bool get isPending => supplyStatus == 'pending';

  int get suppliedCount => items.where((item) => item.isSupplied).length;
  int get pendingCount => items.where((item) => !item.isSupplied).length;
}

class SupplyQueueHome extends StatefulWidget {
  const SupplyQueueHome({super.key});

  @override
  State<SupplyQueueHome> createState() => _SupplyQueueHomeState();
}

class _SupplyQueueHomeState extends State<SupplyQueueHome> {
  List<Sale> allSales = [];
  String statusFilter = 'pending'; // 'pending', 'partial', 'completed', 'all'
  String searchTerm = '';
  String? expandedId;
  final TextEditingController searchController = TextEditingController();

  // Date range
  DateTimeRange? selectedDateRange;
  bool _isLoading = false;

  // Access control
  bool _isSuperAdmin = false;
  bool _hasSearchedByReceipt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccessLevel();
      _loadDataWithCurrentRange();
    });

    searchController.addListener(_onSearchChanged);
  }

  void _checkAccessLevel() {
    final provider = Provider.of<StockProvider>(context, listen: false);
    _isSuperAdmin = provider.accesslevel == 'super admin';
    setState(() {});
  }

  void _loadDataWithCurrentRange() {
    if (selectedDateRange != null) {
      _loadData(
        startDate: selectedDateRange!.start,
        endDate: selectedDateRange!.end,
      );
    } else {
      _loadData();
    }
  }

  _loadData({DateTime? startDate, DateTime? endDate,}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<StockProvider>(context, listen: false);
      await provider.loadSales(
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) {
        setState(() {
          allSales = provider.salesTosupply;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading sales: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final newSearchTerm = searchController.text;

    // Check if searching by receipt number (assuming receipt numbers are 8+ characters)
    final isSearchingByReceipt = newSearchTerm.length >= 6;

    setState(() {
      searchTerm = newSearchTerm;
      // Only allow viewing items if searching by receipt number or super admin
      if (!_isSuperAdmin) {
        _hasSearchedByReceipt = isSearchingByReceipt && newSearchTerm.isNotEmpty;
      }
    });
  }


  Future<void> _selectDateRange(BuildContext context) async {
    var selectedRange = selectedDateRange;
    final colors = _WarehousePalette(Theme.of(context));

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Select Date Range',
          style: TextStyle(color: colors.primaryText),
        ),
        content: SizedBox(
          height: 400,
          width: 320,
          child: SfDateRangePicker(
            backgroundColor: colors.background,

            headerStyle: DateRangePickerHeaderStyle(
              backgroundColor: colors.surface,
              textAlign: TextAlign.center,
              textStyle: TextStyle(
                color: colors.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),

            monthViewSettings:
            DateRangePickerMonthViewSettings(
              viewHeaderStyle: DateRangePickerViewHeaderStyle(
                textStyle: TextStyle(
                  color: colors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            monthCellStyle:
            DateRangePickerMonthCellStyle(
              textStyle: TextStyle(
                color: colors.primaryText,
              ),
              todayTextStyle: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
              weekendTextStyle: TextStyle(
                color: colors.secondaryText,
              ),
              disabledDatesTextStyle: TextStyle(
                color: colors.mutedText,
              ),
            ),

            selectionColor: Colors.blueAccent,
            startRangeSelectionColor: Colors.blueAccent,
            endRangeSelectionColor: Colors.blueAccent,
            rangeSelectionColor: const Color(0x262196F3),
            todayHighlightColor: Colors.blueAccent,

            selectionTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),

            selectionMode:
            DateRangePickerSelectionMode.range,

            initialSelectedRange: selectedRange == null
                ? null
                : PickerDateRange(
              selectedRange!.start,
              selectedRange!.end,
            ),

            onSelectionChanged: (args) {
              if (args.value is PickerDateRange) {
                final range =
                args.value as PickerDateRange;

                if (range.startDate == null) {
                  return;
                }

                selectedRange = DateTimeRange(
                  start: range.startDate!,
                  end: range.endDate ??
                      range.startDate!,
                );
              }
            },
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: colors.secondaryText,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () {
              if (selectedRange == null) {
                return;
              }

              setState(() {
                selectedDateRange = selectedRange;
              });

              Navigator.pop(dialogContext);

              _loadData(
                startDate: selectedRange!.start,
                endDate: selectedRange!.end,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.amberFill,
              foregroundColor: colors.onAccent,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }


  String get dateRangeLabel {
    if (selectedDateRange == null) return 'Select date range';
    final format = DateFormat('MMM d, yyyy');
    final start = selectedDateRange!.start;
    final end = selectedDateRange!.end;

    if (start.day == end.day &&
        start.month == end.month &&
        start.year == end.year) {
      return format.format(start);
    }
    return '${DateFormat('MMM d').format(start)} - ${format.format(end)}';
  }

  List<Sale> get filteredSales {
    return allSales.where((s) {
      // Date filter
      if (selectedDateRange != null) {
        final saleDate = DateTime(
          s.date.year,
          s.date.month,
          s.date.day,
        );
        final start = DateTime(
          selectedDateRange!.start.year,
          selectedDateRange!.start.month,
          selectedDateRange!.start.day,
        );
        final end = DateTime(
          selectedDateRange!.end.year,
          selectedDateRange!.end.month,
          selectedDateRange!.end.day,
          23,
          59,
          59,
        );
        if (saleDate.isBefore(start) || saleDate.isAfter(end)) return false;
      }

      // Status filter
      if (statusFilter == 'pending' && !s.isPending) return false;
      if (statusFilter == 'partial' && !s.isPartiallySupplied) return false;
      if (statusFilter == 'completed' && !s.isFullySupplied) return false;

      // Search
      if (searchTerm.isNotEmpty) {
        final hay = '${s.receiptNumber} ${s.customerName}'.toLowerCase();
        if (!hay.contains(searchTerm.toLowerCase())) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.time.compareTo(a.time);
      });
  }

  Map<String, List<Sale>> groupByDay(List<Sale> list) {
    final map = <String, List<Sale>>{};
    for (var s in list) {
      map.putIfAbsent(s.dateYmd, () => []).add(s);
    }
    return map;
  }

  void showToast(String message) {
    if (!mounted) return;
    final colors = _WarehousePalette(Theme.of(context));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: colors.green,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.isLight ? colors.primaryText : Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: colors.surface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.border),
        ),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = filteredSales;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    final colors = _WarehousePalette(Theme.of(context));

    // Stats
    final pendingCount = allSales.where((s) => s.isPending).length;
    final partialCount = allSales.where((s) => s.isPartiallySupplied).length;
    final completedCount = allSales.where((s) => s.isFullySupplied).length;
    final totalqueued = allSales.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Supply Queue'),
        centerTitle: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.primaryText,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDataWithCurrentRange,
            tooltip: 'Refresh data',
          ),
          PopupMenuButton<String>(
            onSelected: (selectedValue) {
              if (selectedValue == 'logout') {
                LogoutDialog.show(context, );
              } else if (selectedValue == 'password') {
                ChangePasswordDialog.changePassword(context,);
              } else if (selectedValue == 'profile') {
                Navigator.pushNamed(context, Routes.staffprofile);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20, color: Colors.green),
                    SizedBox(width: 12),
                    Text('My Profile'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'password',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 20, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('Change Password'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 800 : double.infinity,
            minWidth: isDesktop ? 600 : 320,
          ),
          child: _isLoading
              ? Center(
            child: CircularProgressIndicator(
              color: colors.amberFill,
            ),
          )
              : Column(
            children: [
              // Stats Row with Clickable Items
              Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border(
                    bottom: BorderSide(color: colors.border, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    _StatItem(
                      label: 'Pending',
                      value: '$pendingCount',
                      color: colors.amber,
                      isActive: statusFilter == 'pending',
                      onTap: () {
                        setState(() {
                          statusFilter = statusFilter == 'pending' ? 'all' : 'pending';
                        });
                      },
                    ),
                    _StatItem(
                      label: 'Partial',
                      value: '$partialCount',
                      color: colors.accent,
                      isActive: statusFilter == 'partial',
                      onTap: () {
                        setState(() {
                          statusFilter = statusFilter == 'partial' ? 'all' : 'partial';
                        });
                      },
                    ),
                    _StatItem(
                      label: 'Completed',
                      value: '$completedCount',
                      color: colors.green,
                      isActive: statusFilter == 'completed',
                      onTap: () {
                        setState(() {
                          statusFilter = statusFilter == 'completed' ? 'all' : 'completed';
                        });
                      },
                    ),
                    _StatItem(
                      label: 'Total',
                      value: '$totalqueued',
                      color: colors.primaryText,
                      isActive: statusFilter == 'all',
                      onTap: () {
                        setState(() {
                          statusFilter = 'all';
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Filter Bar
              _FilterBar(
                searchController: searchController,
                dateRangeLabel: dateRangeLabel,
                onDateRangeTap: () => _selectDateRange(context),
                isSuperAdmin: _isSuperAdmin,
              ),

              // Access Control Info Banner
              if (!_isSuperAdmin && !_hasSearchedByReceipt && searchTerm.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.amberBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Search by receipt number to view and supply items',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.primaryText,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // List
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 24 : 14,
                    16,
                    isDesktop ? 24 : 14,
                    100,
                  ),
                  child: data.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 40,
                          color: colors.mutedText,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No receipts to supply',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: colors.primaryText,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nothing matches this filter for the selected date range.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: colors.secondaryText,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                      : ListView(
                    children: [
                      for (var day in groupByDay(data).keys.toList()
                        ..sort((a, b) => b.compareTo(a)))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 6),
                              child: Text(
                                _formatDayLabel(day),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: colors.secondaryText,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            for (var sale in groupByDay(data)[day]!)
                              _TicketCard(
                                sale: sale,
                                isExpanded: expandedId == sale.id,
                                canViewItems: _isSuperAdmin || _hasSearchedByReceipt,
                                onToggle: () {
                                  // Only allow toggling if can view items
                                  if (_isSuperAdmin || _hasSearchedByReceipt) {
                                    if (mounted) {
                                      setState(() {
                                        expandedId = expandedId == sale.id
                                            ? null
                                            : sale.id;
                                      });
                                    }
                                  }
                                },
                                onSupplyItem: (itemName) async {
                                  if (!_isSuperAdmin && !_hasSearchedByReceipt) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please search by receipt number first'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  try {
                                    LoadingDialog.show(context, message: 'Updating item supply...');
                                    final provider = Provider.of<StockProvider>(context, listen: false);

                                    // Get current supplied items
                                    final doc = await provider.db.collection('sales').doc(sale.id).get();
                                    final data = doc.data() as Map<String, dynamic>;
                                    String? targetItemKey;
                                    final rawItems = data['items'];

                                    if (rawItems == null || rawItems is! Map) {
                                      throw 'Sale has no items map.';
                                    }
                                    for (final entry in rawItems.entries) {
                                      final itemKey = entry.key.toString();
                                      final itemData = entry.value;

                                      if (itemData is! Map) continue;

                                      final name = itemData['item']?.toString().trim() ?? '';

                                      if (name.toLowerCase() == itemName.toString().trim().toLowerCase()) {
                                        targetItemKey = itemKey;
                                        break;
                                      }
                                    }

                                    if (targetItemKey == null) {
                                      throw 'Item "$itemName" was not found in this sale.';
                                    }
                                    final targetItemData =
                                    Map<String, dynamic>.from(rawItems[targetItemKey] as Map);

                                    final alreadySupplied =
                                        targetItemData['supplystatus'] == true;

                                    if (alreadySupplied) {
                                      showToast('$itemName has already been supplied.');
                                      return;
                                    }

                                    final saleRef = provider.db.collection('sales').doc(sale.id);
                                    await saleRef.update({
                                      'items.$targetItemKey.isSupplied': true,
                                      'items.$targetItemKey.supplyDate': FieldValue.serverTimestamp(),
                                      'items.$targetItemKey.supplyStaff': provider.staff,
                                    });
                                    List<String> suppliedItems = List<String>.from(data['suppliedItems'] ?? []);

                                    // Add item if not already supplied
                                    if (!suppliedItems.contains(itemName)) {
                                      suppliedItems.add(itemName);
                                    }

                                    // Determine supply status
                                    String supplyStatus = 'partial';
                                    final totalItems = sale.items.length;
                                    if (suppliedItems.length == totalItems) {
                                      supplyStatus = 'completed';
                                    }

                                     provider.db.collection('sales').doc(sale.id).set({
                                      'suppliedItems': suppliedItems,
                                      'supplyStatus': supplyStatus,
                                      'supplyat': FieldValue.serverTimestamp(),
                                      'supplyby': provider.staff,
                                      'isSupplied': supplyStatus == 'completed',
                                    }, SetOptions(merge: true));

                                    if (mounted) {
                                      // Update local state
                                      setState(() {
                                        final item = sale.items.firstWhere((i) => i.name == itemName);
                                        item.isSupplied = true;
                                        sale.supplyStatus = supplyStatus;
                                      });

                                      showToast(
                                        '$itemName supplied successfully',
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint("Error updating item supply: $e");
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          margin: const EdgeInsets.all(16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    LoadingDialog.hide();
                                  }
                                },
                                onSupplyAll: () async {
                                  if (sale.isFullySupplied) return;

                                  if (!_isSuperAdmin && !_hasSearchedByReceipt) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please search by receipt number first'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  try {
                                    LoadingDialog.show(
                                      context,
                                      message: 'Supplying all items...',
                                    );

                                    final provider = Provider.of<StockProvider>(
                                      context,
                                      listen: false,
                                    );

                                    final saleRef = provider.db.collection('sales').doc(sale.id);

                                    // Get the latest Firestore version
                                    final doc = await saleRef.get();

                                    if (!doc.exists) {
                                      throw 'Sale document not found.';
                                    }

                                    final data = doc.data() as Map<String, dynamic>;

                                    final rawItems = data['items'];

                                    if (rawItems == null || rawItems is! Map) {
                                      throw 'Sale has no items map.';
                                    }

                                    final Map<String, dynamic> itemUpdates = {};

                                    final List<String> allItemNames = [];

                                    for (final entry in rawItems.entries) {
                                      final itemKey = entry.key.toString();
                                      final itemData = entry.value;

                                      if (itemData is! Map) continue;

                                      final itemName = itemData['item']?.toString().trim() ?? '';

                                      if (itemName.isNotEmpty) {
                                        allItemNames.add(itemName);
                                      }

                                      itemUpdates['items.$itemKey.isSupplied'] = true;
                                      itemUpdates['items.$itemKey.supplyDate'] = FieldValue.serverTimestamp();
                                      itemUpdates['items.$itemKey.supplyStaff'] = provider.staff;

                                    }
                                     saleRef.update({
                                      ...itemUpdates,

                                      'suppliedItems': allItemNames,
                                      'supplyStatus': 'completed',
                                      'supplyat': FieldValue.serverTimestamp(),
                                      'supplyby': provider.staff,
                                      'isSupplied': true,
                                    });

                                    if (mounted) {
                                      setState(() {
                                        for (final item in sale.items) {
                                          item.isSupplied = true;
                                        }

                                        sale.supplyStatus = 'completed';
                                      });

                                      showToast(
                                        'All items supplied for receipt #${sale.receiptNumber.substring(
                                          sale.receiptNumber.length - 8,
                                        )}',
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint("Error updating supply info: $e");

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          margin: const EdgeInsets.all(16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    LoadingDialog.hide();
                                  }
                                },

                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDayLabel(String dateYmd) {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final yesterday =
    DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    if (dateYmd == today) return 'Today · $dateYmd';
    if (dateYmd == yesterday) return 'Yesterday · $dateYmd';

    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateYmd);
      return DateFormat('EEEE, MMM d · yyyy').format(date);
    } catch (_) {
      return dateYmd;
    }
  }
}

// ---------- Stat Item ----------
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _WarehousePalette(Theme.of(context));
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isActive ? color.withOpacity(0.15) : Colors.transparent,
            border: isActive
                ? Border.all(color: color.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [

                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: isActive ? color : colors.primaryText,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.filter_alt,
                      size: 14,
                      color: color,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isActive ? color : colors.primaryText,
                  letterSpacing: 0.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Filter Bar ----------
class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String dateRangeLabel;
  final VoidCallback onDateRangeTap;
  final bool isSuperAdmin;

  const _FilterBar({
    required this.searchController,
    required this.dateRangeLabel,
    required this.onDateRangeTap,
    this.isSuperAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final colors = _WarehousePalette(Theme.of(context));

    return Container(
      color: colors.background,
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 12 : 18,
        12,
        isSmallScreen ? 12 : 18,
        14,
      ),
      child: Column(
        children: [
          // Date Range Picker
          GestureDetector(
            onTap: onDateRangeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surface,
                    colors.gradientSurface,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.border,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.amberFill.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.amberFill.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      size: isSmallScreen ? 16 : 18,
                      color: colors.amberFill,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Date Range',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            color: colors.mutedText,
                            decoration: TextDecoration.none,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateRangeLabel,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: colors.primaryText,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.border.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: colors.mutedText,
                      size: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search bar with hint based on access level
          Container(
            decoration: BoxDecoration(
              color: colors.elevatedSurface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search, size: 15, color: colors.mutedText),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13.5,
                      color: colors.primaryText,
                      decoration: TextDecoration.none,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: isSuperAdmin
                          ? 'Receipt no. or customer'
                          : 'Enter receipt number to search',
                      hintStyle: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13.5,
                        color: colors.mutedText,
                      ),
                    ),
                  ),
                ),
                if (searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      searchController.clear();
                    },
                    child: Icon(
                      Icons.clear,
                      size: 16,
                      color: colors.mutedText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Ticket Card ----------
class _TicketCard extends StatelessWidget {
  final Sale sale;
  final bool isExpanded;
  final bool canViewItems;
  final VoidCallback onToggle;
  final Function(String) onSupplyItem;
  final VoidCallback onSupplyAll;

  const _TicketCard({
    required this.sale,
    required this.isExpanded,
    required this.canViewItems,
    required this.onToggle,
    required this.onSupplyItem,
    required this.onSupplyAll,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _WarehousePalette(Theme.of(context));
    final bool isFullySupplied = sale.isFullySupplied;
    final bool isPartiallySupplied = sale.isPartiallySupplied;

    String statusText = 'Pending';
    Color statusColor = colors.amber;
    Color statusBgColor = colors.amberBackground;
    IconData statusIcon = Icons.pending;

    if (isFullySupplied) {
      statusText = 'Completed';
      statusColor = colors.green;
      statusBgColor = colors.greenBackground;
      statusIcon = Icons.check_circle;
    } else if (isPartiallySupplied) {
      statusText = 'Partial';
      statusColor = colors.accent;
      statusBgColor = colors.accent.withOpacity(0.15);
      statusIcon = Icons.hourglass_top;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // Top section (clickable)
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${sale.receiptNumber.substring(sale.receiptNumber.length - 8)}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.primaryText,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${sale.time} · ${sale.transMode.toUpperCase()} · ${sale.cashier}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: colors.secondaryText,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon,
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: statusColor,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.customerName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.primaryText,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sale.pendingCount}/${sale.itemCount} items pending',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.secondaryText,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'GHS ${sale.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.primaryText,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              height: 1.5,
              color: colors.border,
            ),
          ),

          // Expanded items with supply buttons
          if (isExpanded && canViewItems)
            Container(
              color: colors.background,
              child: Column(
                children: sale.items.map((item) {
                  final isItemSupplied = item.isSupplied;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                isItemSupplied ? Icons.check_circle : Icons.circle_outlined,
                                size: 16,
                                color: isItemSupplied ? colors.green : colors.mutedText,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isItemSupplied ? colors.secondaryText : colors.primaryText,
                                    decoration: isItemSupplied ? TextDecoration.lineThrough : TextDecoration.none,
                                    decorationColor: colors.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '×${item.qty}  · ${item.itemMode}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            color: isItemSupplied ? colors.secondaryText : colors.primaryText,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isFullySupplied && !isItemSupplied)
                          GestureDetector(
                            onTap: () => onSupplyItem(item.name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.amberFill,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Supply',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onAccent,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          )
                        else if (isItemSupplied)
                          Icon(
                            Icons.check,
                            size: 16,
                            color: colors.green,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          else if (isExpanded && !canViewItems)
            Container(
              color: colors.background,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 24,
                      color: colors.mutedText,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search by receipt number to view items',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.secondaryText,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16,
                        color: colors.secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isExpanded ? 'Hide items' : 'View items',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: colors.secondaryText,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!isFullySupplied && canViewItems)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: onSupplyAll,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: colors.amberFill,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.checklist,
                                size: 14,
                                color: colors.onAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Supply All',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onAccent,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else if (!isFullySupplied && !canViewItems)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: colors.secondaryText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Locked',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.secondaryText,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 14, color: colors.green),
                            const SizedBox(width: 6),
                            Text(
                              'All Supplied',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colors.secondaryText,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}