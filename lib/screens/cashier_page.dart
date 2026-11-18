import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/models/salesmodel.dart';
import 'package:kologsoft/screens/salesPointInvoicePriview.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';
import '../models/paymentMethod.dart';
import '../paymentwidgets/changepasswordDialog.dart';
import '../paymentwidgets/showlogout.dart';
import '../providers/Datafeed.dart';
import '../providers/cashier_provider.dart';
import '../providers/routes.dart';
import '../widgets/momopaymentwidget.dart';


class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> with SingleTickerProviderStateMixin {
  String? momoType;
  String _searchQuery = '';
  String _selectedFilter = 'Pending';
  final List<String> _filters = ['All', 'Pending', 'Paid','Credit'];
  late TabController _tabController;
  bool _isMobileView = false;
  bool _showInvoiceList = true;
  double _fontScale = 1.0;
  final GlobalKey<FormState> _cashierFormKey = GlobalKey<FormState>();
  final List<String> momoNetworks = ['MTN', 'Vodafone', 'AirtelTigo', 'Telecel'];
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeActive = false;
  List<String> _paymentMethods = [];
  String paymentMethod='';
  @override
  void initState() {
    super.initState();
    _loadFontScale();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() async{
      final provider = Provider.of<CashierProvider>(context, listen: false);
      await provider.getdata();
      await provider.fetchDiscountCodes();
      provider.listenToInvoices(context);
      _paymentMethods=provider.allowedPaymentMethods;
    });
  }

  Future<void> _loadFontScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedScale = prefs.getDouble('cashier_font_scale');
      if (savedScale != null) {
        setState(() {
          _fontScale = savedScale.clamp(0.7, 1.8);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveFontScale(double scale) async {
    setState(() {
      _fontScale = scale.clamp(0.7, 1.8);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('cashier_font_scale', _fontScale);
    } catch (_) {}
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D2A3C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.format_size, color: Colors.white70),
              const SizedBox(width: 10),
              const Text('Adjust Font Size', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current: ${(_fontScale * 100).round()}%',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _fontScale > 0.7 
                        ? () {
                            final newScale = (_fontScale - 0.1).clamp(0.7, 1.8);
                            _saveFontScale(newScale);
                            setDialogState(() {});
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                    label: const Text('Smaller'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5A), foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      _saveFontScale(1.0);
                      setDialogState(() {});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _fontScale < 1.8 
                        ? () {
                            final newScale = (_fontScale + 0.1).clamp(0.7, 1.8);
                            _saveFontScale(newScale);
                            setDialogState(() {});
                          }
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Larger'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A5A), foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Slider(
                value: _fontScale,
                min: 0.7,
                max: 1.8,
                divisions: 11,
                activeColor: Colors.green,
                inactiveColor: Colors.white24,
                label: '${(_fontScale * 100).round()}%',
                onChanged: (value) {
                  _saveFontScale(value);
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _fontPresetButton('Small (85%)', 0.85, setDialogState),
                  _fontPresetButton('Normal (100%)', 1.0, setDialogState),
                  _fontPresetButton('Large (115%)', 1.15, setDialogState),
                  _fontPresetButton('X-Large (130%)', 1.3, setDialogState),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fontPresetButton(String label, double scale, StateSetter setDialogState) {
    final isSelected = (_fontScale - scale).abs() < 0.01;
    return OutlinedButton(
      onPressed: () {
        _saveFontScale(scale);
        setDialogState(() {});
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.green.shade800 : Colors.transparent,
        side: BorderSide(color: isSelected ? Colors.green : Colors.white24),
      ),
      child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11)),
    );
  }
  // MOMO Transaction Variables
  List<TextEditingController> momoTransactionControllers = [TextEditingController()];
  List<TextEditingController> momoTransactionAmountControllers = [TextEditingController()];
  TextEditingController? _contactController = TextEditingController();

  List<bool> momoTransactionAmountLoaded = [false];
  List<Timer?> momoTransactionTimers = [null];
  TextEditingController? accountNumberController = TextEditingController();
  TextEditingController referenceController = TextEditingController();
  TextEditingController amountPaidController = TextEditingController();
  final _amountController = TextEditingController();
  final Map<String, TextEditingController> _cashierDiscountControllers = {};
  final Map<String, String?> _cashierAppliedDiscountCodes = {};
  final Set<String> _returningInvoiceIds = {};

  @override
  void dispose() {
    _tabController.dispose();
    accountNumberController?.dispose();
    referenceController.dispose();
    amountPaidController.dispose();
    _amountController.dispose();
    _cashierDiscountControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
  void updateMomoPaidTotal() {
    final total = momoTransactionAmountControllers
        .map((controller) => double.tryParse(controller.text.trim()) ?? 0)
        .fold(0.0, (sum, value) => sum + value);
    setState(() {
      _amountController.text = total.toStringAsFixed(2);
      amountPaidController.text = total.toStringAsFixed(2);
    });
  }

  Future<void> fetchMomoAmountForTransaction(int index) async {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    final transactionId = momoTransactionControllers[index].text.trim();

    if (transactionId.isEmpty) {
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('momo')
          .where('transactionId', isEqualTo: transactionId)
          .where('companyid', isEqualTo: provider.companyid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MOMO transaction $transactionId not found'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          momoTransactionAmountControllers[index].text = '';
          momoTransactionAmountLoaded[index] = false;
          updateMomoPaidTotal();
        });
        return;
      }

      final doc = query.docs.first;
      final momoData = doc.data();
      final statusValue = momoData['status']?.toString().toLowerCase() ?? '';

      if (statusValue == 'saved') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction ID $transactionId has already been used'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          momoTransactionAmountControllers[index].text = '';
          momoTransactionAmountLoaded[index] = false;
          updateMomoPaidTotal();
        });
        return;
      }

      final amountText = momoData['amount']?.toString() ?? '';
      final amount = double.tryParse(amountText);

      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to parse amount for transaction $transactionId'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          momoTransactionAmountControllers[index].text = '';
          momoTransactionAmountLoaded[index] = false;
          updateMomoPaidTotal();
        });
        return;
      }

      setState(() {
        momoTransactionAmountControllers[index].text = amount.toStringAsFixed(2);
        momoTransactionAmountLoaded[index] = true;
        updateMomoPaidTotal();
      });
    } catch (e) {
      print('Error fetching MOMO transaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDateRangePicker() async {
    final DateTime? start = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF22304A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (start != null) {
      final DateTime? end = await showDatePicker(
        context: context,
        initialDate: _endDate ?? start,
        firstDate: start,
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.blue,
                onPrimary: Colors.white,
                surface: Color(0xFF22304A),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (end != null) {
        setState(() {
          _startDate = DateTime(start.year, start.month, start.day);
          _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
          _isDateRangeActive = true;
        });
        if (_startDate == null || _endDate == null) return;
        final cashDate = Provider.of<CashierProvider>(context, listen: false);
        cashDate.listenToInvoices(context,todayOnly:false,startDate:_startDate ,endDate:_endDate);

        _showDateRangeBadge();
      }
    }
  }
  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isDateRangeActive = false;
    });
    final cash = Provider.of<CashierProvider>(context, listen: false);
    cash.listenToInvoices(context);
    _showSuccessSnackBar('Date filters cleared');
  }
  void _showDateRangeBadge() {
    if (_startDate == null || _endDate == null) return;

    final message = 'Showing: ${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.date_range, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
  void _selectInvoice(SalesModel invoice) {
    context.read<CashierProvider>().selectInvoice(invoice.id, invoice);

    if (_isMobileView) {
      setState(() {
        _showInvoiceList = false;
      });
    }
  }

  String _getCustomerName(SalesModel invoice) {
    return invoice.customerName ?? 'Walk-in Customer';
  }

  List<Map<String, dynamic>> _parseItems(dynamic itemsData) {
    List<Map<String, dynamic>> items = [];
    if (itemsData == null) return items;
    if (itemsData is Map) {
      itemsData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          items.add(value);
        }
      });
    } else if (itemsData is List) {
      items = List<Map<String, dynamic>>.from(itemsData);
    }
    items.sort((a, b) {
      final aKey = a['itemkey'] ?? '';
      final bKey = b['itemkey'] ?? '';
      return aKey.compareTo(bKey);
    });
    return items;
  }

  Widget _buildInvoiceItemsCard(SalesModel invoice) {
    final items = _parseItems(invoice.items);
    if (items.isEmpty) {
      return _buildInlineEmpty('No items recorded for this invoice', Icons.inventory_2_outlined);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Items',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${items.length} lines  •  ${invoice.itemCount} units',
              style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(.07)),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                color: const Color(0xFF101D2D),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: _tableHeaderCell('ITEM')),
                    Expanded(flex: 1, child: _tableHeaderCell('QTY', align: TextAlign.center)),
                    Expanded(flex: 2, child: _tableHeaderCell('UNIT PRICE', align: TextAlign.right)),
                    Expanded(flex: 2, child: _tableHeaderCell('AMOUNT', align: TextAlign.right)),
                  ],
                ),
              ),
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final itemName = item['item']?.toString() ?? 'Unknown Item';
                final qty = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                final mode = item['mode']?.toString() ?? '';
                final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                final total = double.tryParse(item['totalamount']?.toString() ?? '') ?? (qty * price);
                final displayItem = mode.isNotEmpty && mode.toLowerCase() != 'unit' ? '$itemName • $mode' : itemName;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: index.isEven ? const Color(0xFF132238) : const Color(0xFF111F31),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(.045))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(displayItem, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                      Expanded(flex: 1, child: Text(qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2), textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 12))),
                      Expanded(flex: 2, child: Text('GHS ${price.toStringAsFixed(2)}', textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12))),
                      Expanded(flex: 2, child: Text('GHS ${total.toStringAsFixed(2)}', textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableHeaderCell(String text, {TextAlign align = TextAlign.left}) {
    return Text(text,
        textAlign: align,
        style: TextStyle(color: Colors.white.withOpacity(.38), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .8));
  }

  Widget _buildInlineEmpty(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Row(children: [
        Icon(icon, color: Colors.white24, size: 22),
        const SizedBox(width: 10),
        Text(message, style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 12)),
      ]),
    );
  }


  List<SalesModel> get _filteredInvoices {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    final invoices = provider.invoices;
    return invoices.where((invoice) {
      if (_selectedFilter != 'All') {
        final status = invoice.paymentStatus;
        final transmode = invoice.transMode;
        bool printed = invoice.printed;
        if (_selectedFilter == 'Pending' && status == 'paid') return false;
        if (_selectedFilter == 'Paid' && status != 'paid') return false;
        if (_selectedFilter == 'Credit' && transmode != 'credit') return false;
      }

      // Apply search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final receiptNumber = invoice.receiptNumber.toString().toLowerCase();
        final customerName = _getCustomerName(invoice).toLowerCase();
        final transmode = invoice.transMode.toString().toLowerCase();
        final dailyNoStr = invoice.dailyNumber?.toString().toLowerCase() ?? '';
        final qClean = query.replaceAll('#', '').replaceAll('daily', '').trim();

        return receiptNumber.contains(query) ||
            customerName.contains(query) ||
            transmode.contains(query) ||
            dailyNoStr.contains(query) ||
            (qClean.isNotEmpty && dailyNoStr == qClean) ||
            'daily #$dailyNoStr'.contains(query) ||
            '#$dailyNoStr'.contains(query);
      }

      return true;
    }).toList();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D2A3C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Invoices',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return ListTile(
                leading: Icon(
                  _getFilterIcon(filter),
                  color: isSelected ? Colors.green : Colors.white70,
                ),
                title: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.green : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _selectedFilter = filter);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'All': return Icons.list;
      case 'Pending': return Icons.pending;
      case 'Paid': return Icons.check_circle;
      case 'Today': return Icons.today;
      case 'Credit': return Icons.credit_card;
      default: return Icons.filter_list;
    }
  }

  Widget _buildDesktopLayout() {
    final provider=Provider.of<CashierProvider>(context,listen: false);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInvoicePanel(),

        if (provider.selectedInvoice != null)
          _buildInvoiceDetailsPanel()
        else
          _buildEmptyState(),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final provider=Provider.of<CashierProvider>(context,listen: false);
    if (provider.selectedInvoice != null && !_showInvoiceList) {
      return _buildMobileInvoiceDetails();
    }
    return _buildMobileInvoiceList();
  }

  Widget _buildInvoicePanel() {
    final provider = Provider.of<CashierProvider>(context, listen: true);
    final filteredInvoices = _filteredInvoices;

    return Container(
      width: 390,
      color: const Color(0xFF0D1B2A),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(children: [
              Row(children: [
                const Expanded(child: Text('Invoices', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
                Text('${filteredInvoices.length} shown', style: TextStyle(color: Colors.white.withOpacity(.4), fontSize: 11)),
              ]),
              const SizedBox(height: 12),
              _buildSearchField(),
              const SizedBox(height: 10),
              _buildFilterBar(),
            ]),
          ),
          if (_startDate != null && _endDate != null) _buildDateRangeBar(),
          Container(height: 1, color: Colors.white.withOpacity(.06)),
          Expanded(
            child: filteredInvoices.isEmpty
                ? _buildInvoiceListEmpty()
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
              itemCount: filteredInvoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (_, index) {
                final invoice = filteredInvoices[index];
                return _buildInvoiceCard(invoice, provider.selectedInvoiceId == invoice.id);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        hintText: 'Search receipt, customer, daily no...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(.32), fontSize: 12),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 19),
        suffixIcon: _searchQuery.isEmpty ? null : IconButton(
          icon: const Icon(Icons.close, color: Colors.white54, size: 17),
          onPressed: () => setState(() => _searchQuery = ''),
        ),
        filled: true,
        fillColor: const Color(0xFF111F31),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.white.withOpacity(.07))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: Colors.white.withOpacity(.07))),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7)), borderSide: BorderSide(color: Colors.blueGrey)),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: _filters.map((filter) {
        final selected = _selectedFilter == filter;
        return Expanded(
          child: InkWell(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: selected ? Colors.green.shade800 : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: selected ? Colors.green.shade700 : Colors.white.withOpacity(.06)),
              ),
              child: Text(filter, textAlign: TextAlign.center,
                  style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 10, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateRangeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(children: [
        const Icon(Icons.date_range_rounded, color: Colors.blueGrey, size: 15),
        const SizedBox(width: 7),
        Expanded(child: Text('${DateFormat('dd/MM/yy').format(_startDate!)} – ${DateFormat('dd/MM/yy').format(_endDate!)}',
            style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 11))),
        InkWell(onTap: _clearDateRange, child: const Icon(Icons.close, color: Colors.white38, size: 16)),
      ]),
    );
  }

  Widget _buildInvoiceListEmpty() {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(_searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.receipt_long_outlined, size: 38, color: Colors.white24),
      const SizedBox(height: 12),
      Text(_searchQuery.isNotEmpty ? 'No matching invoices' : 'No invoices found', style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 13)),
      if (_searchQuery.isNotEmpty) TextButton(onPressed: () => setState(() => _searchQuery = ''), child: const Text('Clear search')),
    ])));
  }

  Widget _buildStatCard(String title, String amount, String subtitle, Color color, IconData icon) {
    return Row(children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 10)),
        const SizedBox(height: 2),
        Text(amount, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(.28), fontSize: 9)),
      ])),
    ]);
  }

  Widget _buildInvoiceCard(SalesModel invoice, bool isSelected) {
    final totalAmount = invoice.totalamount.toDouble();
    final amountPaid = invoice.amountPaid.toDouble();
    var status = invoice.paymentStatus;
    if (invoice.transMode == 'credit') status = 'credit';
    final color = _statusColor(status);
    final createdAt = invoice.createdAt?.toDate();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectInvoice(invoice),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF172B40) : Colors.transparent,
            border: Border(left: BorderSide(color: isSelected ? Colors.green : Colors.transparent, width: 3)),
          ),
          child: Row(children: [
            Icon(_statusIcon(status), size: 17, color: color),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(invoice.receiptNumber, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                Text('GHS ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(child: Text(_getCustomerName(invoice), overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 11))),
                Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 4),
              if (createdAt != null) Text(_dateTimeFormat.format(createdAt), style: TextStyle(color: Colors.white.withOpacity(.28), fontSize: 9)),
              if (invoice.dailyNumber != null) ...[
                const SizedBox(height: 2),
                Text('Daily #${invoice.dailyNumber}', style: TextStyle(color: Colors.cyan.shade300, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
              if (status == 'partial' && amountPaid > 0) ...[
                const SizedBox(height: 2),
                Text('Paid ${amountPaid.toStringAsFixed(2)}', style: TextStyle(color: Colors.green.shade300, fontSize: 9)),
              ],
            ])),
          ]),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid': return Colors.green;
      case 'credit': return Colors.orange;
      case 'partial': return Colors.amber;
      case 'returned_for_edit': return Colors.deepOrange;
      default: return Colors.blueGrey.shade300;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid': return Icons.check_circle_rounded;
      case 'credit': return Icons.account_balance_wallet_rounded;
      case 'partial': return Icons.timelapse_rounded;
      case 'returned_for_edit': return Icons.edit_note_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  Widget _buildMobileInvoiceList() {
    final provider = Provider.of<CashierProvider>(context, listen: true);
    final filteredInvoices = _filteredInvoices;
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Column(children: [
        Row(children: [
          Expanded(child: Text('${filteredInvoices.length} invoices', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
          Text(_selectedFilter, style: TextStyle(color: Colors.green.shade300, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        _buildSearchField(),
        const SizedBox(height: 10),
        _buildFilterBar(),
      ])),
      if (_startDate != null && _endDate != null) _buildDateRangeBar(),
      Container(height: 1, color: Colors.white.withOpacity(.06)),
      Expanded(child: filteredInvoices.isEmpty ? _buildInvoiceListEmpty() : ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: filteredInvoices.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withOpacity(.035)),
        itemBuilder: (_, index) {
          final invoice = filteredInvoices[index];
          return _buildMobileInvoiceCard(invoice, provider.selectedInvoiceId == invoice.id);
        },
      )),
    ]);
  }

  Widget _buildMobileInvoiceCard(SalesModel invoice, bool isSelected) {
    final total = (invoice.totalamount as num?)?.toDouble() ?? 0;
    final paid = (invoice.amountPaid as num?)?.toDouble() ?? 0;
    var status = invoice.paymentStatus;
    if (invoice.transMode == 'credit') status = 'credit';
    final color = _statusColor(status);
    final created = (invoice.createdAt as Timestamp?)?.toDate();
    return Material(color: Colors.transparent, child: InkWell(
      onTap: () => _selectInvoice(invoice),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
        color: isSelected ? const Color(0xFF172B40) : Colors.transparent,
        child: Column(children: [
          Row(children: [
            Icon(_statusIcon(status), color: color, size: 19), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(invoice.receiptNumber, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(_getCustomerName(invoice), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 11)),
            ])),
            Text('GHS ${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            if (created != null) Text(_dateTimeFormat.format(created), style: TextStyle(color: Colors.white.withOpacity(.3), fontSize: 9)),
            const Spacer(),
            Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
            if (paid > 0 && status != 'paid') ...[const SizedBox(width: 10), Text('Paid ${paid.toStringAsFixed(2)}', style: TextStyle(color: Colors.green.shade300, fontSize: 9))],
          ]),
          if (invoice.dailyNumber != null) ...[
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Daily #${invoice.dailyNumber}', style: TextStyle(color: Colors.cyan.shade300, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      ),
    ));
  }

  Widget _buildInvoiceDetailsPanel() {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    final invoice = provider.selectedInvoice!;
    var status = invoice.paymentStatus;
    if (invoice.transMode == 'credit') status = 'credit';
    final total = (invoice.totalamount as num?)?.toDouble() ?? 0;
    final paid = (invoice.amountPaid as num?)?.toDouble() ?? 0;
    final balance = total - paid;
    final created = (invoice.createdAt as Timestamp?)?.toDate();

    return Expanded(child: Container(color: const Color(0xFF0A1828), child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 15),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.07)))),
        child: Row(children: [
          const Icon(Icons.receipt_long_rounded, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Receipt #${invoice.receiptNumber}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              if (invoice.dailyNumber != null) ...[const SizedBox(width: 10), Text('Daily #${invoice.dailyNumber}', style: TextStyle(color: Colors.cyan.shade300, fontSize: 10, fontWeight: FontWeight.w600))],
            ]),
            const SizedBox(height: 3),
            Text(_getCustomerName(invoice), style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 11)),
          ])),
          _buildStatusBadge(status),
        ]),
      ),
      Expanded(child: Padding(padding: const EdgeInsets.all(20), child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(flex: 6, child: SingleChildScrollView(padding: const EdgeInsets.only(right: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildInvoiceMetaStrip(invoice, created),
          const SizedBox(height: 18),
          _buildInvoiceItemsCard(invoice),
          const SizedBox(height: 18),
          _buildTotalsSummary(invoice, total, paid, balance),
        ]))),
        Container(width: 1, color: Colors.white.withOpacity(.07)),
        Expanded(flex: 4, child: SingleChildScrollView(padding: const EdgeInsets.only(left: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('PAYMENT', Icons.payments_outlined),
          const SizedBox(height: 10),
          _buildPaymentSection(),
          const SizedBox(height: 18),
          _buildActionButtons(),
        ]))),
      ]))),
    ])));
  }

  Widget _buildInvoiceMetaStrip(SalesModel invoice, DateTime? created) {
    return Row(children: [
      _metaValue('DATE', created == null ? '—' : _dateFormat.format(created)),
      const SizedBox(width: 24),
      _metaValue('TIME', created == null ? '—' : _timeFormat.format(created)),
      const SizedBox(width: 24),
      _metaValue('PAYMENT', invoice.transMode.toUpperCase()),
      const SizedBox(width: 24),
      Expanded(child: _metaValue('CASHIER', invoice.createdBy ?? '—')),
    ]);
  }

  Widget _metaValue(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(.3), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: .7)),
      const SizedBox(height: 4),
      Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildTotalsSummary(SalesModel invoice, double total, double paid, double balance) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('ACCOUNT SUMMARY', Icons.receipt_outlined),
      const SizedBox(height: 10),
      _summaryLine('Invoice total', total),
      if (paid > 0) _summaryLine('Amount paid', paid, color: Colors.green.shade300),
      if (balance > 0) _summaryLine('Balance due', balance, color: Colors.orange.shade300),
      const SizedBox(height: 8),
      Divider(color: Colors.white.withOpacity(.08), height: 1),
      const SizedBox(height: 9),
      Row(children: [
        Text('${invoice.itemCount} units', style: TextStyle(color: Colors.white.withOpacity(.4), fontSize: 10)),
        const Spacer(),
        Text(invoice.transMode.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    ]);
  }

  Widget _summaryLine(String label, double amount, {Color? color}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: Colors.white.withOpacity(.48), fontSize: 12))),
      Text('GHS ${amount.toStringAsFixed(2)}', style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    ]));
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 15, color: Colors.white38), const SizedBox(width: 7),
      Text(title, style: TextStyle(color: Colors.white.withOpacity(.48), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .9)),
    ]);
  }

  Widget _buildMobileInvoiceDetails() {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    final invoice = provider.selectedInvoice!;
    final total = (invoice.totalamount as num?)?.toDouble() ?? 0;
    final paid = (invoice.amountPaid as num?)?.toDouble() ?? 0;
    final balance = total - paid;
    var status = invoice.paymentStatus;
    if (invoice.transMode == 'credit') status = 'credit';
    return Column(children: [
      Container(padding: const EdgeInsets.fromLTRB(16, 13, 16, 13), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.07)))),
          child: Row(children: [
            const Icon(Icons.receipt_long, color: Colors.white54, size: 20), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Receipt #${invoice.receiptNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)), const SizedBox(height: 2), Text(_getCustomerName(invoice), style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 11))])),
            _buildStatusBadge(status),
          ])),
      Container(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: Row(children: [
        Expanded(child: _mobileAmount('TOTAL', total, Colors.white)),
        Expanded(child: _mobileAmount('PAID', paid, Colors.green.shade300)),
        Expanded(child: _mobileAmount('BALANCE', balance > 0 ? balance : 0, Colors.orange.shade300)),
      ])),
      Expanded(child: TabBarView(controller: _tabController, children: [_buildMobileDetailsTab(), _buildMobilePaymentTab()])),
      Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), child: _buildActionButtons()),
    ]);
  }

  Widget _mobileAmount(String label, double value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.white.withOpacity(.3), fontSize: 8, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text('GHS ${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700))]);
  }

  Widget _buildPaymentSection() {
    final provider = Provider.of<CashierProvider>(context, listen: false);

    final invoice = provider.selectedInvoice!;
    final invoiceId = invoice.id;
    final paymentStatus = invoice.paymentStatus;
    final transmode = invoice.transMode;
    final totalAmount = (invoice.totalamount as num?)?.toDouble() ?? 0.0;
    final amountPaid = (invoice.amountPaid as num?)?.toDouble() ?? 0.0;
    final change = (invoice.change as num?)?.toDouble() ?? 0.0;
    
    final discCtrl = _cashierDiscountControllers.putIfAbsent(invoiceId, () => TextEditingController());
    final discVal = double.tryParse(discCtrl.text.trim()) ?? 0.0;
    final effectiveTotal = (totalAmount - discVal).clamp(0.0, double.infinity);
    final appliedCode = _cashierAppliedDiscountCodes[invoiceId];
    final balance = effectiveTotal - amountPaid;

    paymentMethod = provider.selectedPaymentMethods[invoiceId] ?? 'cash';
    String? selectedNetwork = provider.selectedNetworks[invoiceId];

    double currentChange=0.00;
    if (paymentStatus == 'paid') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withAlpha((0.3 * 255).round())),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (invoice.discount != null && invoice.discount! > 0)
              Text(
                'Discount: GHS ${invoice.discount!.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
              ),
            if (change > 0)
              Text(
                'Change: GHS ${change.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      );
    }
    if (transmode == 'credit') {
      return  Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2A3C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: balance > 0 ? Colors.orange : Colors.green, width: 1),
          ),
          child:const Text("Credit customer",style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),)
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2A3C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: balance > 0 ? Colors.orange : Colors.green, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(balance > 0 ? Icons.payment : Icons.check_circle, color: balance > 0 ? Colors.orange : Colors.green),
              const SizedBox(width: 8),
              Text(
                balance > 0 ? 'Process Payment' : 'Payment Successful',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
              value: _paymentMethods.map((e) => e.toLowerCase())
                  .contains(paymentMethod)
                  ? paymentMethod
                  : null,
              dropdownColor: const Color(0xFF1E3A5A),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Payment Method',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.payment, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1E3A5A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _paymentMethods.map((method) {
                return DropdownMenuItem(
                  value: method,
                  child: Row(
                    children: [
                      Icon(
                        _getPaymentMethodIcon(method),
                        color: _getPaymentMethodColor(method),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(method, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null && value.isNotEmpty) {
                  final methodKey = value.toLowerCase();

                  setState(() {
                    paymentMethod = methodKey;
                    provider.selectedPaymentMethods[invoiceId] = methodKey;
                    if (value.toLowerCase() == 'momo') {
                      provider.selectedNetworks[invoiceId] = 'mtn';
                    } else {
                      provider.selectedNetworks[invoiceId] = null;
                    }
                    if (methodKey != 'momo') {
                      provider.selectedNetworks[invoiceId] = null;
                    }

                    if (methodKey != 'card') {
                      provider.selectedCardTypes[invoiceId] = null;
                    }
                  });
                }
              }
          ),

          const SizedBox(height: 16),
          if (paymentMethod.toLowerCase() == 'momo')
            MomoPaymentFields(
              selectedNetwork: selectedNetwork,
              momoType: momoType,
              networks: momoNetworks,

              onNetworkChanged: (value) {
                if (value != null) {
                  setState(() {
                    provider.selectedNetworks[invoiceId] = value;
                  });
                }
              },

              onMomoTypeChanged: (value) {
                setState(() {
                  momoType = value;
                });
              },

              merchantFields: _buildMomoTransactionFields(),

              phoneController: _contactController,
            ),
          // if (paymentMethod.toLowerCase() == 'momo') ...[
          //   DropdownButtonFormField<String>(
          //     value: selectedNetwork,
          //     dropdownColor: const Color(0xFF1E3A5A),
          //     style: const TextStyle(color: Colors.white),
          //     decoration: InputDecoration(
          //       labelText: 'Select Network',
          //       labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          //       prefixIcon: const Icon(Icons.sim_card, color: Colors.white70),
          //       filled: true,
          //       fillColor: const Color(0xFF1E3A5A),
          //       border: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(12),
          //         borderSide: BorderSide.none,
          //       ),
          //     ),
          //     items: momoNetworks.map((network) {
          //       return DropdownMenuItem(
          //         value: network.toLowerCase(),
          //         child: Row(
          //           children: [
          //             Icon(
          //               _getNetworkIcon(network),
          //               color: _getNetworkColor(network),
          //               size: 20,
          //             ),
          //             const SizedBox(width: 8),
          //             Text(network, style: const TextStyle(color: Colors.white)),
          //           ],
          //         ),
          //       );
          //     }).toList(),
          //     onChanged: (value) {
          //       if (value != null) {
          //         setState(() {
          //           provider.selectedNetworks[invoiceId] = value;
          //         });
          //       }
          //     },
          //     validator: (value) {
          //       if (paymentMethod.toLowerCase() == 'momo' && value == null) {
          //         return 'Please select a network';
          //       }
          //       return null;
          //     },
          //   ),
          //   const SizedBox(height: 12),
          //   TextFormField(
          //     controller: accountNumberController,
          //     style: const TextStyle(color: Colors.white),
          //     keyboardType: TextInputType.phone,
          //     inputFormatters: [
          //     FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          //     ],
          //     decoration: InputDecoration(
          //       labelText: 'Mobile Money Number',
          //       labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          //       hintText: 'e.g. 055XXXXXXX',
          //       hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          //       prefixIcon: const Icon(Icons.phone_android, color: Colors.white70),
          //       filled: true,
          //       fillColor: const Color(0xFF1E3A5A),
          //       border: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(12),
          //         borderSide: BorderSide.none,
          //       ),
          //     ),
          //     validator: (value) {
          //       if (paymentMethod.toLowerCase() == 'momo' && (value == null || value.isEmpty)) {
          //         return 'Please enter mobile money number';
          //       }
          //       if (value != null && value.isNotEmpty && !RegExp(r'^0\d{9}$').hasMatch(value)) {
          //         return 'Enter a valid 10-digit number starting with 0';
          //       }
          //       return null;
          //     },
          //   ),
          // ],

          if (paymentMethod.toLowerCase() == 'bank_transfer' || paymentMethod.toLowerCase() == 'cheque') ...[
            TextFormField(
              controller: referenceController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Reference Number',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintText: 'Enter Reference Number',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.receipt, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1E3A5A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (paymentMethod.toLowerCase() == 'cheque' && (value == null || value.isEmpty)) {
                  return 'Please enter reference number';
                }
                return null;
              },
            ),

          ],

          const SizedBox(height: 16),

          if (paymentStatus != 'paid' && transmode != 'credit') ...[
            Builder(
              builder: (context) {
                final sEmail = provider.staffemail.trim().toLowerCase();
                final sId = (provider.currentStaff?.id ?? '').trim().toLowerCase();
                final assignedCodes = provider.discountCodes.where((c) {
                  if (!c.canBeUsed) return false;
                  final email = (c.assignedStaffEmail ?? '').trim().toLowerCase();
                  final id = (c.assignedStaffId ?? '').trim().toLowerCase();
                  if (email.isEmpty && id.isEmpty) return true;
                  return (email.isNotEmpty && email == sEmail) || (id.isNotEmpty && id == sId);
                }).toList();

                if (assignedCodes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5A),
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent, width: 0.8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.send_outlined, size: 16),
                      label: const Text('Request Discount Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        final success = await provider.requestDiscountCode(
                          companyId: provider.companyid,
                          staffName: provider.staff,
                          staffEmail: provider.staffemail,
                          branchId: provider.branchid,
                        );
                        if (success) {
                          _showSuccessSnackBar('Discount code request sent to admin successfully!');
                        } else {
                          _showErrorSnackBar('Failed to send request. Try again.');
                        }
                      },
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: discCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      onChanged: (v) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Discount (GHS or Code)',
                        labelStyle: TextStyle(color: Colors.white.withAlpha((0.7 * 255).round()), fontSize: 12),
                        prefixIcon: const Icon(Icons.discount_outlined, color: Colors.white70, size: 18),
                        filled: true,
                        fillColor: const Color(0xFF1E3A5A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixIcon: appliedCode != null
                            ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18)
                            : IconButton(
                                icon: const Icon(Icons.search, color: Colors.white70, size: 18),
                                tooltip: 'Validate Discount Code',
                                onPressed: () async {
                                  final code = discCtrl.text.trim();
                                  if (code.isEmpty) return;
                                  final match = await provider.validateDiscountCode(code);
                                  if (match == null || match.containsKey('error')) {
                                    _showErrorSnackBar(match?['error'] ?? 'Invalid or used discount code');
                                    return;
                                  }
                                  final amt = (match['amount'] as num).toDouble();
                                  setState(() {
                                    discCtrl.text = amt.toStringAsFixed(2);
                                    _cashierAppliedDiscountCodes[invoiceId] = match['code'].toString();
                                  });
                                  _showSuccessSnackBar('Discount code "${match['code']}" applied - GHS ${amt.toStringAsFixed(2)} off');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Discount Codes:',
                            style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).round()), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: assignedCodes.map((c) {
                              final isMine = (c.assignedStaffEmail ?? '').trim().isNotEmpty || (c.assignedStaffId ?? '').trim().isNotEmpty;
                              return ActionChip(
                                backgroundColor: const Color(0xFF1E3A5A),
                                side: const BorderSide(color: Colors.blueAccent, width: 0.8),
                                avatar: Icon(
                                  isMine ? Icons.person : Icons.local_offer_outlined,
                                  size: 14,
                                  color: Colors.blueAccent,
                                ),
                                label: Text(
                                  '${c.code} (GHS ${c.amount.toStringAsFixed(2)})',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                onPressed: () async {
                                  final match = await provider.validateDiscountCode(c.code);
                                  if (match == null || match.containsKey('error')) {
                                    _showErrorSnackBar(match?['error'] ?? 'Invalid or used discount code');
                                    return;
                                  }
                                  final amt = (match['amount'] as num).toDouble();
                                  setState(() {
                                    discCtrl.text = amt.toStringAsFixed(2);
                                    _cashierAppliedDiscountCodes[invoiceId] = match['code'].toString();
                                  });
                                  _showSuccessSnackBar('Discount code "${match['code']}" applied - GHS ${amt.toStringAsFixed(2)} off');
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Amount', style: TextStyle(color: Colors.white.withAlpha((0.6 * 255).round()), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('GHS ${effectiveTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (amountPaid > 0)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Already Paid', style: TextStyle(color: Colors.green.withAlpha((0.6 * 255).round()), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('GHS ${amountPaid.toStringAsFixed(2)}', style: TextStyle(color: Colors.green.shade300, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          if (balance > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha((0.3 * 255).round())),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance Due:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  Text('GHS ${balance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          const SizedBox(height: 16),

          if (paymentStatus != 'paid')
            TextFormField(
              enabled: transmode != 'credit',
              controller: amountPaidController,
              style: const TextStyle(color: Colors.white),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: (value) {
                final entered = double.tryParse(value) ?? 0.0;
                setState(() {
                  currentChange = entered - effectiveTotal;
                  provider.changeAmounts[invoiceId] = currentChange;
                });
              },
              validator: (value) {
                final number = double.tryParse(value!);

                if (value == null || value.isEmpty) {
                  return 'Enter amount paid';
                }

                if (number == null) {
                  return 'Enter a valid number';
                }

                if (number < 0.5) {
                  return 'Value must be greater than or equal to 0.5';
                }

                if (number < effectiveTotal && paymentMethod=='cash') {
                  return 'Amount paid cannot be less than $effectiveTotal';
                }

                return null;
              },
              decoration: InputDecoration(
                labelText: 'Amount Paid',
                labelStyle: TextStyle(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                ),
                prefixIcon: const Icon(Icons.attach_money, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1E3A5A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

          //const SizedBox(height: 12),
          if (currentChange > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha((0.3 * 255).round())),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Balance Due:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  Text('GHS ${currentChange.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          const SizedBox(height: 12),

          if (paymentMethod == 'cash' && (provider.changeAmounts[invoiceId] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withAlpha((0.3 * 255).round())),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Change:', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Text('GHS ${(provider.changeAmounts[invoiceId] ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          if (paymentStatus != 'paid')
            Center(
              child: SizedBox(
                width: 420,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: (paymentStatus == 'returned_for_edit' || _returningInvoiceIds.contains(invoiceId)) ? Colors.grey : Colors.orangeAccent,
                          side: BorderSide(color: (paymentStatus == 'returned_for_edit' || _returningInvoiceIds.contains(invoiceId)) ? Colors.grey : Colors.orangeAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: Icon((paymentStatus == 'returned_for_edit') ? Icons.check : Icons.undo_rounded, size: 16),
                        label: Text(
                          _returningInvoiceIds.contains(invoiceId)
                              ? 'Returning...'
                              : (paymentStatus == 'returned_for_edit' ? 'Returned for Edit' : 'Return for Edit'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: (paymentStatus == 'returned_for_edit' || _returningInvoiceIds.contains(invoiceId) || provider.isLoadingpayment)
                            ? null
                            : () => _showReturnForEditDialog(invoice, provider),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: provider.isLoadingpayment
                            ? null
                            : () async {
                          if (_cashierFormKey.currentState!.validate()) {
                      if (paymentMethod.toLowerCase() == 'momo' &&
                          selectedNetwork == null) {
                        _showErrorSnackBar(
                          'Please select a mobile money network',
                        );
                        return;
                      }

                      final newamountPaid = double.tryParse(amountPaidController.text) ?? effectiveTotal;

                      final totalamountPaid = newamountPaid + amountPaid;

                      final balance = effectiveTotal - totalamountPaid;

                      final change = totalamountPaid - effectiveTotal;

                      final accountNumber = accountNumberController?.text.trim();

                      final reference = referenceController.text.trim();

                      final Map<String, Map<String, dynamic>>
                      paymentMethodConfig = {
                        'cash': {
                          'accountNumber': 'cash',
                          'amountPaid': effectiveTotal,
                        },
                        'momo': {
                          'accountName': selectedNetwork,
                          'status': false,
                        },
                        'bank_transfer': {
                          'accountNumber': reference,
                        },
                        'cheque': {
                          'accountNumber': reference,
                        },
                        'card': {
                          'accountNumber': paymentMethod,
                        },
                      };

                      final config = paymentMethodConfig[paymentMethod] ?? {};
                      if (paymentMethod == 'cash') {
                        config['amountPaid'] = effectiveTotal;
                      }

                      final paymentData = PaymentMethodModel(
                        id: invoiceId,
                        amount: config['amountPaid'] ?? newamountPaid,
                        totalamount: effectiveTotal,
                        discount: discVal,
                        discountCode: appliedCode,
                        paymentmethod: paymentMethod,
                        accountName: config['accountName'] ?? paymentMethod,
                        accountNumber: config['accountNumber'] ?? accountNumber,
                        status: config['status'] ?? true,
                        change: change,
                        balance: balance,
                        reference: reference,
                      );

                      try {
                        LoadingDialog.show(
                          context,
                          message: 'please wait...',
                        );

                        final res =await provider.processPayment(paymentData);

                        final paymentChange = res['change'] as double? ?? 0.0;

                        if (paymentChange > 0) {
                          _showSuccessSnackBar(
                            'Payment processed successfully. '
                                'Change: GHS ${paymentChange.toStringAsFixed(2)}',
                          );
                        } else {
                          _showSuccessSnackBar(
                            'Payment processed successfully',
                          );
                        }

                        referenceController.clear();
                        amountPaidController!.clear();
                        accountNumberController?.clear();

                        await provider.printReceipt(
                          invoiceId,
                          provider.selectedInvoice!,
                        );

                        if (context.mounted) {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PrintPreviewWidget(
                                invoiceData: provider.selectedInvoice!,
                                showPrintButton: false,
                                autoPrint: true,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        _showErrorSnackBar(
                          'Failed to process payment: $e',
                        );
                      } finally {
                        LoadingDialog.hide();
                      }
                    }
                  },
                  icon: const Icon(Icons.payment),
                  label: Text(
                    provider.isLoadingpayment
                        ? 'Processing...'
                        : 'Process Payment',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.green.shade700,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
}

  Future<void> _showReturnForEditDialog(SalesModel invoice, CashierProvider provider) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Text('Send Receipt #${invoice.receiptNumber} for Edit', style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Specify why this order is being returned to Sales Attendance to edit items or quantities:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Customer wants to add items, change quantity, or remove an item...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF22304A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                //validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a reason' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            icon: const Icon(Icons.send_rounded, color: Colors.black, size: 16),
            label: const Text('Send Back for Edit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim();
      setState(() {
        _returningInvoiceIds.add(invoice.id);
      });
      try {
        final datafeed = context.read<Datafeed>();
        final firestore = FirebaseFirestore.instance;

        // 1. Update sales doc
        await firestore.collection('sales').doc(invoice.id).update({
          'paymentStatus': 'returned_for_edit',
          'returnReason': reason,
          'returnedBy': datafeed.staff,
          'returnedAt': FieldValue.serverTimestamp(),
        });

        invoice.paymentStatus = 'returned_for_edit';

        // 2. Audit log
        final auditRef = firestore.collection('sale_edit_logs').doc();
        await auditRef.set({
          'id': auditRef.id,
          'saleId': invoice.id,
          'receiptNumber': invoice.receiptNumber,
          'action': 'returned_for_edit',
          'reason': reason,
          'cashier': datafeed.staff,
          'salesAttendance': invoice.createdBy,
          'companyId': datafeed.companyid,
          'branchId': datafeed.branchid,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _showSuccessSnackBar('Order #${invoice.receiptNumber} returned to Sales Attendance for edit');
        setState(() {});
      } catch (e) {
        _showErrorSnackBar('Failed to return order: $e');
      } finally {
        if (mounted) {
          setState(() {
            _returningInvoiceIds.remove(invoice.id);
          });
        }
      }
    }
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'momo':
        return Icons.phone_android;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'cheque':
        return Icons.receipt;
      case 'credit':
        return Icons.credit_score;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'momo':
        return Colors.orange;
      case 'bank_transfer':
        return Colors.purple;
      case 'cheque':
        return Colors.teal;
      case 'credit':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  bool _isDuplicateMomoTransactionId(int currentIndex) {
    final currentId = momoTransactionControllers[currentIndex]
        .text
        .trim()
        .toLowerCase();

    if (currentId.isEmpty) {
      return false;
    }

    for (int i = 0; i < momoTransactionControllers.length; i++) {
      if (i == currentIndex) {
        continue;
      }

      final otherId = momoTransactionControllers[i]
          .text
          .trim()
          .toLowerCase();

      if (otherId.isNotEmpty && otherId == currentId) {
        return true;
      }
    }

    return false;
  }


  Widget _buildMomoTransactionFields() {
    if (paymentMethod.toLowerCase() != 'momo') return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      Row(children: [
        const Icon(Icons.swap_horiz_rounded, color: Colors.white38, size: 16), const SizedBox(width: 7),
        const Text('MOMO TRANSACTIONS', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8)),
      ]),
      const SizedBox(height: 9),
      ...List.generate(momoTransactionControllers.length, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: TextFormField(
            controller: momoTransactionControllers[index],
            style: const TextStyle(color: Colors.white, fontSize: 12),
            onChanged: (_) => setState(() {}),
            decoration: _flatInputDecoration('Transaction ID', Icons.receipt_long_outlined).copyWith(
              suffixIcon: momoTransactionAmountLoaded[index] ? const Icon(Icons.check_circle, color: Colors.green, size: 18) : null,
            ),
          )),
          const SizedBox(width: 6),
          SizedBox(height: 44, child: OutlinedButton(
            onPressed: momoTransactionControllers[index].text.trim().isEmpty ? null : () {
              if (_isDuplicateMomoTransactionId(index)) {
                _showErrorSnackBar('This transaction ID has already been entered.');
                return;
              }
              fetchMomoAmountForTransaction(index);
            },
            style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.blueGrey.shade600), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
            child: const Text('Check', style: TextStyle(fontSize: 11)),
          )),
          const SizedBox(width: 6),
          SizedBox(width: 90, child: TextField(
            controller: momoTransactionAmountControllers[index], readOnly: true,
            style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w700),
            decoration: _flatInputDecoration('GHS', null),
          )),
        ]),
      )),
      Align(alignment: Alignment.centerLeft, child: TextButton.icon(
        onPressed: () => setState(() {
          momoTransactionControllers.add(TextEditingController());
          momoTransactionAmountControllers.add(TextEditingController());
          momoTransactionAmountLoaded.add(false);
          momoTransactionTimers.add(null);
        }),
        icon: const Icon(Icons.add, size: 15), label: const Text('Add transaction', style: TextStyle(fontSize: 11)),
        style: TextButton.styleFrom(foregroundColor: Colors.blueGrey.shade200, padding: EdgeInsets.zero),
      )),
    ]);
  }

  InputDecoration _flatInputDecoration(String label, IconData? icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(.38), fontSize: 11),
      prefixIcon: icon == null ? null : Icon(icon, color: Colors.white38, size: 17),
      prefixText: icon == null && label == 'GHS' ? 'GHS ' : null,
      prefixStyle: const TextStyle(color: Colors.green),
      filled: true, fillColor: const Color(0xFF101D2D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.white.withOpacity(.06))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.white.withOpacity(.06))),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: Colors.blueGrey)),
    );
  }



  Widget _buildActionButtons() {
    final provider=Provider.of<CashierProvider>(context,listen: true);

    final invoiceId = provider.selectedInvoiceId;
    final paymentStatus = provider.selectedInvoice!.paymentStatus;
    bool printed = provider.selectedInvoice!.printed;
    final transmode = provider.selectedInvoice!.transMode;

    if (paymentStatus == 'returned_for_edit') {
      return const SizedBox.shrink();
    }

    if (paymentStatus != 'pending' || transmode=='credit') {
      return SizedBox(

        width: 150,
        child: OutlinedButton(
          onPressed: provider.isLoadingpayment
              ? null
              : () async {
            try {
              if (!printed) {
                await provider.printReceipt(
                    invoiceId!, provider.selectedInvoice!);
              }

              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PrintPreviewWidget(
                    invoiceData: provider.selectedInvoice!,
                    showPrintButton: !provider.selectedInvoice!.printed,
                  ),
                ),
              );
            } catch (e) {
              _showErrorSnackBar('Error generating PDF: $e');
            }
          },

          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.lightBlue),
            foregroundColor: Colors.lightBlue,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          child: provider.isLoadingpayment
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.lightBlue,
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.print),
              SizedBox(width: 8),
              Text('PRINT'),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMobileDetailsTab() {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    final invoice = provider.selectedInvoice!;
    final createdAt = (invoice.createdAt as Timestamp?)?.toDate();
    final printedAt = (invoice.printedat as Timestamp?)?.toDate();
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('INVOICE DETAILS', Icons.info_outline), const SizedBox(height: 10),
      _buildDetailRow('Receipt Number', invoice.receiptNumber),
      _buildDetailRow('Customer', _getCustomerName(invoice)),
      _buildDetailRow('Date', createdAt == null ? 'N/A' : _dateFormat.format(createdAt)),
      _buildDetailRow('Time', createdAt == null ? 'N/A' : _timeFormat.format(createdAt)),
      _buildDetailRow('Payment Mode', invoice.transMode),
      _buildDetailRow('Cashier', invoice.createdBy ?? 'N/A'),
      if (printedAt != null) _buildDetailRow('Printed', _dateTimeFormat.format(printedAt)),
      const SizedBox(height: 18),
      _buildInvoiceItemsCard(invoice),
      const SizedBox(height: 18),
      _sectionTitle('ACCOUNT SUMMARY', Icons.receipt_outlined), const SizedBox(height: 8),
      _buildAmountRow('Total Amount', (invoice.totalamount as num?)?.toDouble() ?? 0),
      if (((invoice.amountPaid as num?)?.toDouble() ?? 0) > 0) _buildAmountRow('Amount Paid', (invoice.amountPaid as num?)?.toDouble() ?? 0, color: Colors.green),
      if ((((invoice.totalamount as num?)?.toDouble() ?? 0) - ((invoice.amountPaid as num?)?.toDouble() ?? 0)) > 0) _buildAmountRow('Balance', ((invoice.totalamount as num?)?.toDouble() ?? 0) - ((invoice.amountPaid as num?)?.toDouble() ?? 0), color: Colors.orange),
    ]));
  }

  Widget _buildMobilePaymentTab() {
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), child: _buildPaymentSection());
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
      SizedBox(width: 105, child: Text(label, style: TextStyle(color: Colors.white.withOpacity(.35), fontSize: 11))),
      Expanded(child: Text(value, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.78), fontSize: 11, fontWeight: FontWeight.w500))),
    ]));
  }

  Widget _buildAmountRow(String label, double amount, {Color? color, bool isNumber = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 12))),
      Text(isNumber ? amount.toStringAsFixed(0) : 'GHS ${amount.toStringAsFixed(2)}', style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    ]));
  }



  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(.09), border: Border.all(color: color.withOpacity(.22)), borderRadius: BorderRadius.circular(5)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .4)),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(child: Container(color: const Color(0xFF0A1828), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.white24),
      const SizedBox(height: 16),
      const Text('Select an invoice', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Choose an invoice from the left to view details and process payment.', style: TextStyle(color: Colors.white.withOpacity(.35), fontSize: 12)),
    ]))));
  }

  void _resetSelection() {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    provider.resetSelection();
    setState(() {
      _showInvoiceList = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _isMobileView = screenWidth < 900;
    final provider = Provider.of<CashierProvider>(context, listen: false);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_fontScale),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1828),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF0D1B2A),
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 58,
          titleSpacing: 18,
          title: Row(children: [
            const Icon(Icons.point_of_sale_rounded, color: Colors.white70, size: 22),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Cashier', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              if (!_isMobileView) Text('Payments & receipts', style: TextStyle(color: Colors.white.withOpacity(.35), fontSize: 9)),
            ]),
          ]),
          actions: _buildAppBarActions(),
          bottom: _isMobileView && provider.selectedInvoice != null && !_showInvoiceList
              ? TabBar(controller: _tabController, indicatorColor: Colors.green, indicatorWeight: 2, labelColor: Colors.white, unselectedLabelColor: Colors.white38, labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), tabs: const [Tab(text: 'DETAILS'), Tab(text: 'PAYMENT')])
              : null,
        ),
        body: Form(key: _cashierFormKey, child: _isMobileView ? _buildMobileLayout() : _buildDesktopLayout()),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    final actions = <Widget>[];
    actions.add(IconButton(
      onPressed: _showFontSizeDialog,
      tooltip: 'Adjust Font Size',
      icon: const Icon(Icons.format_size_rounded, color: Colors.white54, size: 20),
    ));
    if (provider.selectedInvoice != null && _isMobileView) {
      actions.add(IconButton(onPressed: _resetSelection, tooltip: 'Back', icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20)));
    }
    if (provider.accesslevel != 'cashier') {
      actions.add(IconButton(onPressed: _showDateRangePicker, tooltip: 'Date range', icon: Icon(Icons.calendar_month_rounded, color: _isDateRangeActive ? Colors.blue.shade300 : Colors.white54, size: 20)));
    }
    if (provider.selectedInvoice != null && !_isMobileView) {
      actions.add(IconButton(onPressed: _resetSelection, tooltip: 'Close invoice', icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20)));
    }
    if (_isMobileView && _showInvoiceList) {
      actions.add(IconButton(onPressed: _showFilterModal, tooltip: 'Filter', icon: const Icon(Icons.filter_list_rounded, color: Colors.white54, size: 20)));
    }
    actions.add(IconButton(onPressed: () => provider.listenToInvoices(context), tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 20)));
    actions.add(PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white60),
      onSelected: (value) {
        if (value == 'logout') LogoutDialog.show(context);
        if (value == 'password') ChangePasswordDialog.changePassword(context);
        if (value == 'profile') Navigator.pushNamed(context, Routes.staffprofile);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'profile', child: Text('My Profile')),
        PopupMenuItem(value: 'password', child: Text('Change Password')),
        PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
    ));
    return actions;
  }
}

