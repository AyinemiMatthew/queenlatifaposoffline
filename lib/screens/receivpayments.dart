import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import '../models/debtors.dart';
import '../providers/cashier_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../widgets/momopaymentwidget.dart';

bool _isLightTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color _paymentForeground(BuildContext context) => _isLightTheme(context)
    ? Theme.of(context).colorScheme.onSurface
    : Colors.white;

Color _paymentMutedForeground(BuildContext context) => _isLightTheme(context)
    ? Theme.of(context).colorScheme.onSurfaceVariant
    : Colors.white70;

Color _paymentSurface(BuildContext context, Color darkColor) =>
    _isLightTheme(context)
    ? Theme.of(context).colorScheme.surfaceContainerHighest
    : darkColor;

Color _paymentBorder(BuildContext context) => _isLightTheme(context)
    ? Theme.of(context).colorScheme.outlineVariant
    : Colors.white12;

Color _paymentFormBorder(BuildContext context) => _isLightTheme(context)
    ? Theme.of(context).colorScheme.outlineVariant
    : Colors.white24;

ThemeData _paymentDatePickerTheme(BuildContext context) {
  final theme = Theme.of(context);
  return theme.copyWith(
    colorScheme: theme.colorScheme.copyWith(
      primary: Colors.blue,
      onPrimary: _paymentForeground(context),
      surface: _isLightTheme(context)
          ? theme.colorScheme.surface
          : const Color(0xFF22304A),
      onSurface: _paymentForeground(context),
    ),
  );
}

class ReceivepaymentsPage extends StatefulWidget {
  const ReceivepaymentsPage({super.key});

  @override
  State<ReceivepaymentsPage> createState() => _ReceivepaymentsPageState();
}

class _ReceivepaymentsPageState extends State<ReceivepaymentsPage> {
  final TextEditingController _searchController = TextEditingController();
  Debtor? _selectedDebtor;
  List<Debtor> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  bool _ignoreSearchListener = false;
  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_ignoreSearchListener) return;

    _searchDebounce?.cancel();

    final query = _searchController.text.trim();

    if (_selectedDebtor != null) {
      setState(() {
        _selectedDebtor = null;
      });
    }

    if (query.length < 3) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      final provider = Provider.of<CashierProvider>(context, listen: false);

      _performSearch(provider, query);
    });
  }

  Future<void> _performSearch(CashierProvider provider, String query) async {
    if (query.trim().length < 3) return;

    if (!mounted) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await provider.loadcustomers(query.trim());

      if (!mounted) return;

      final firstFive = results.take(5).toList();

      setState(() {
        _searchResults = firstFive;
        _isSearching = false;
      });

      debugPrint('Found ${_searchResults.length} customers for "$query"');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _searchResults = [];
        _isSearching = false;
      });

      debugPrint('Customer search failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CashierProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: _isLightTheme(context)
              ? Theme.of(context).scaffoldBackgroundColor
              : const Color(0xFF0A1A2F),
          appBar: AppBar(
            title: Text(
              'Receive Payment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: _paymentSurface(context, const Color(0xFF0D2A4A)),
            foregroundColor: _paymentForeground(context),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {
                  _searchDebounce?.cancel();

                  _ignoreSearchListener = true;

                  _searchController.clear();

                  _ignoreSearchListener = false;

                  setState(() {
                    _selectedDebtor = null;
                    _searchResults = [];
                    _isSearching = false;
                  });
                },
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  // Summary Cards
                  const SizedBox(height: 12),

                  // Search Bar with Search Button
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        width: 400,
                        decoration: BoxDecoration(
                          color: _paymentSurface(
                            context,
                            const Color(0xFF1E3A5F),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: _paymentForeground(context)),
                          decoration: InputDecoration(
                            hintText: 'Search customer by name',
                            hintStyle: TextStyle(
                              color: (_isLightTheme(context)
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : Colors.grey.shade400),
                            ),
                            prefixIcon: Icon(
                              Icons.person_search,
                              color: _paymentMutedForeground(context),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: _paymentSurface(
                              context,
                              const Color(0xFF1E3A5F),
                            ),

                            suffixIcon: _isSearching
                                ? Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              _paymentForeground(context),
                                            ),
                                      ),
                                    ),
                                  )
                                : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: Colors.grey),
                                    onPressed: () {
                                      _searchDebounce?.cancel();

                                      _searchController.clear();

                                      setState(() {
                                        _selectedDebtor = null;
                                        _searchResults = [];
                                        _isSearching = false;
                                      });
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Single Record Display
                  _selectedDebtor != null
                      ? _buildSingleDebtorCard(provider)
                      : _searchResults.isNotEmpty
                      ? _buildSearchResults(provider)
                      : _buildEmptyState(provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(CashierProvider provider) {
    final hasData = provider.filteredDebtors.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasData ? Icons.search : Icons.people_outline,
            size: 64,
            color: (_isLightTheme(context)
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Text(
            hasData
                ? 'Search for a customer to recieve deposit payment'
                : 'No customer found',
            style: TextStyle(
              color: (_isLightTheme(context)
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Colors.grey.shade400),
              fontSize: 16,
            ),
          ),
          // if (hasData) ...[
          //   const SizedBox(height: 8),
          //   Text(
          //     '${provider.filteredDebtors.length} debtors available',
          //     style: TextStyle(color: (_isLightTheme(context) ? Theme.of(context).colorScheme.onSurfaceVariant : Colors.grey.shade500), fontSize: 12),
          //   ),
          // ],
        ],
      ),
    );
  }

  Widget _buildSingleDebtorCard(CashierProvider provider) {
    final debtor = _selectedDebtor!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: DebtorDetailCard(
        debtor: debtor,
        onReceivePayment: () {
          _showPaymentDialog(context, debtor, provider);
        },
        onViewDetails: () {
          _showDebtorDetails(context, debtor);
        },
        onBack: () {
          _searchDebounce?.cancel();

          _ignoreSearchListener = true;

          _searchController.clear();

          _ignoreSearchListener = false;

          setState(() {
            _selectedDebtor = null;
            _searchResults = [];
            _isSearching = false;
          });
        },
      ),
    );
  }

  _showPaymentDialog(
    BuildContext context,
    Debtor debtor,
    CashierProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentFormDialog(
        debtor: debtor,
        onPaymentSubmitted: (payment) {
          provider.addPaymentToDebtor(debtor.id, payment);
          // Refresh the selected debtor after payment
          provider.loadcustomers(_selectedDebtor!.name).then((_) {
            Debtor? updatedDebtor;
            try {
              updatedDebtor = provider.filteredDebtors.firstWhere(
                (d) => d.id == debtor.id,
              );
            } catch (e) {
              updatedDebtor = null;
            }
            if (updatedDebtor != null) {
              setState(() {
                _selectedDebtor = updatedDebtor;
              });
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment of GHS ${payment.amount} recorded for ${debtor.name}',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _showDebtorDetails(BuildContext context, Debtor debtor) async {
    final provider = Provider.of<CashierProvider>(context, listen: false);
    await provider.loadDebtorDetails(customerid: debtor.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DebtorDetailsDialog(
        debtor: debtor,
        onPaymentAdded: (payment) {
          provider.addPaymentToDebtor(debtor.id, payment);
          Navigator.pop(context);

          // Refresh the selected debtor after payment

          provider.loadcustomers(_selectedDebtor!.name).then((_) {
            Debtor? updatedDebtor;
            try {
              updatedDebtor = provider.filteredDebtors.firstWhere(
                (d) => d.id == debtor.id,
              );
            } catch (e) {
              updatedDebtor = null;
            }
            if (updatedDebtor != null) {
              setState(() {
                _selectedDebtor = updatedDebtor;
              });
            }
          });
        },
      ),
    );
  }

  Widget _buildSearchResults(CashierProvider provider) {
    final results = _searchResults.take(5).toList();

    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;

    final width = screenWidth < 600 ? screenWidth * 0.95 : screenWidth * 0.28;

    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: _paymentSurface(context, const Color(0xFF22304A)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: _isLightTheme(context)
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: results.length,
          itemExtent: 48.0,
          itemBuilder: (context, index) {
            final debtor = results[index];

            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              leading: CircleAvatar(
                radius: 17,
                backgroundColor: Colors.blue.shade700,
                child: Text(
                  debtor.name.isNotEmpty ? debtor.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              title: Text(
                debtor.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _paymentForeground(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: 12,
                    color: _paymentMutedForeground(context).withOpacity(0.75),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      debtor.contact,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _paymentMutedForeground(context),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: _paymentMutedForeground(context).withOpacity(0.75),
                size: 13,
              ),
              onTap: () {
                setState(() {
                  _selectedDebtor = debtor;
                  _searchResults = [];
                });
              },
            );
          },
        ),
      ),
    );
  }
}

class DebtorDetailCard extends StatelessWidget {
  final Debtor debtor;
  final VoidCallback onReceivePayment;
  final VoidCallback onViewDetails;
  final VoidCallback onBack;

  const DebtorDetailCard({
    super.key,
    required this.debtor,
    required this.onReceivePayment,
    required this.onViewDetails,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _isLightTheme(context)
        ? Color.lerp(debtor.statusColor, Colors.black, 0.2)!
        : debtor.statusColor;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _paymentSurface(context, const Color(0xFF1E3A5F)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button and header
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: Icon(
                    Icons.arrow_back,
                    color: _paymentForeground(context),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: _paymentSurface(
                      context,
                      const Color(0xFF0D2A4A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debtor.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _paymentForeground(context),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: (_isLightTheme(context)
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Colors.grey.shade500),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            debtor.contact,
                            style: TextStyle(
                              color: (_isLightTheme(context)
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : Colors.grey.shade400),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    debtor.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Progress',
                      style: TextStyle(
                        color: (_isLightTheme(context)
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Colors.grey.shade400),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${(debtor.paymentProgress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _paymentForeground(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: debtor.paymentProgress,
                    backgroundColor: (_isLightTheme(context)
                        ? Theme.of(context).colorScheme.surface
                        : Colors.grey.shade800),
                    color: statusColor,
                    minHeight: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Financial Details in a Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _paymentSurface(context, const Color(0xFF0D2A4A)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDetailColumn(
                      context,
                      'Total Debt',
                      'GHS ${NumberFormat('#,##0.00').format(debtor.creditBalance)}',
                      _paymentForeground(context),
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: (_isLightTheme(context)
                        ? Theme.of(context).colorScheme.outlineVariant
                        : Colors.grey.shade700),
                  ),
                  Expanded(
                    child: _buildDetailColumn(
                      context,
                      'Amount Paid',
                      'GHS ${NumberFormat('#,##0.00').format(debtor.amountpaid)}',
                      _isLightTheme(context)
                          ? Colors.green.shade800
                          : Colors.green.shade400,
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: (_isLightTheme(context)
                        ? Theme.of(context).colorScheme.outlineVariant
                        : Colors.grey.shade700),
                  ),
                  Expanded(
                    child: _buildDetailColumn(
                      context,
                      'Balance',
                      debtor.balance < 0
                          ? 'GHS (${NumberFormat('#,##0.00').format(debtor.balance.abs())})'
                          : 'GHS ${NumberFormat('#,##0.00').format(debtor.balance)}',
                      _isLightTheme(context)
                          ? Colors.orange.shade800
                          : Colors.orange.shade400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Additional Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _paymentSurface(context, const Color(0xFF0D2A4A)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(context, 'Customer ID', debtor.id),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    'Customer Since',
                    DateFormat('MMM dd, yyyy').format(debtor.createdAt!),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    'Credit Limit',
                    debtor.creditLimit.isEmpty
                        ? 'N/A'
                        : 'GHS ${debtor.creditLimit}',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    'Branch',
                    debtor.branchName.isEmpty ? 'N/A' : debtor.branchName,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onReceivePayment,
                    icon: Icon(Icons.payment, size: 20),
                    label: Text(
                      'Receive Payment',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onViewDetails,
                  icon: Icon(Icons.history, size: 20),
                  label: Text('History', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _paymentSurface(
                      context,
                      const Color(0xFF0D2A4A),
                    ),
                    foregroundColor: _paymentForeground(context),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: BorderSide(
                      color: (_isLightTheme(context)
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Colors.grey.shade700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailColumn(
    BuildContext context,
    String label,
    String amount,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: (_isLightTheme(context)
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Colors.grey.shade500),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: (_isLightTheme(context)
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Colors.grey.shade500),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(color: _paymentForeground(context), fontSize: 13),
        ),
      ],
    );
  }
}

class DebtorCard extends StatelessWidget {
  final Debtor debtor;
  final VoidCallback onReceivePayment;
  final VoidCallback onViewDetails;

  const DebtorCard({
    super.key,
    required this.debtor,
    required this.onReceivePayment,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _isLightTheme(context)
        ? Color.lerp(debtor.statusColor, Colors.black, 0.2)!
        : debtor.statusColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _paymentSurface(context, const Color(0xFF1E3A5F)),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debtor.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _paymentForeground(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: (_isLightTheme(context)
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : Colors.grey.shade500),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              debtor.contact,
                              style: TextStyle(
                                color: (_isLightTheme(context)
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : Colors.grey.shade400),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      debtor.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Progress',
                        style: TextStyle(
                          color: (_isLightTheme(context)
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Colors.grey.shade400),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(debtor.paymentProgress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: _paymentForeground(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: debtor.paymentProgress,
                      backgroundColor: (_isLightTheme(context)
                          ? Theme.of(context).colorScheme.surface
                          : Colors.grey.shade800),
                      color: statusColor,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAmountColumn(
                    context,
                    'Total Debt',
                    'GHS ${NumberFormat('#,##0.00').format(debtor.creditBalance)}',
                    _paymentForeground(context),
                  ),
                  _buildAmountColumn(
                    context,
                    'Amount Paid',
                    'GHS ${NumberFormat('#,##0.00').format(debtor.amountpaid)}',
                    _paymentForeground(context),
                  ),
                  _buildAmountColumn(
                    context,
                    'Balance',
                    'GHS ${NumberFormat('#,##0.00').format(debtor.balance)}',
                    _isLightTheme(context)
                        ? Colors.orange.shade800
                        : Colors.orange.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onReceivePayment,
                      icon: Icon(Icons.payment, size: 18),
                      label: Text('Receive Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onViewDetails,
                    icon: Icon(Icons.chevron_right),
                    color: (_isLightTheme(context)
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Colors.grey.shade400),
                    style: IconButton.styleFrom(
                      backgroundColor: _paymentSurface(
                        context,
                        const Color(0xFF0D2A4A),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountColumn(
    BuildContext context,
    String label,
    String amount,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: (_isLightTheme(context)
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Colors.grey.shade500),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class PaymentFormDialog extends StatefulWidget {
  final Debtor debtor;
  final Function(Payment) onPaymentSubmitted;

  const PaymentFormDialog({
    super.key,
    required this.debtor,
    required this.onPaymentSubmitted,
  });

  @override
  State<PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<PaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  String? _selectedAccount;
  List<String> _linkedAccounts = [];
  String method = "";
  DateTime _selectedDate = DateTime.now();
  final List<String> momoNetworks = [
    'MTN',
    'Vodafone',
    'AirtelTigo',
    'Telecel',
  ];
  IconData _getNetworkIcon(String network) {
    switch (network.toLowerCase()) {
      case 'mtn':
        return Icons.network_cell;
      case 'vodafone':
        return Icons.signal_cellular_alt;
      case 'airteltigo':
        return Icons.wifi;
      case 'telecel':
        return Icons.phone_android;
      default:
        return Icons.sim_card;
    }
  }

  Color _getNetworkColor(String network) {
    switch (network.toLowerCase()) {
      case 'mtn':
        return const Color(0xFFFFCC00); // MTN Yellow
      case 'vodafone':
        return const Color(0xFFE60000); // Vodafone Red
      case 'airteltigo':
        return const Color(0xFFED1C24); // AirtelTigo Red
      case 'telecel':
        return const Color(0xFF662D91); // Telecel Purple
      default:
        return Colors.grey;
    }
  }

  TextEditingController? accountNumberController = TextEditingController();
  TextEditingController? _contactController = TextEditingController();
  TextEditingController? referenceController = TextEditingController();
  List<String> _paymentMethods = [];
  String paymentMethod = '';
  bool isLoading = false;

  // MOMO Transaction Variables
  List<TextEditingController> momoTransactionControllers = [
    TextEditingController(),
  ];
  List<TextEditingController> momoTransactionAmountControllers = [
    TextEditingController(),
  ];
  List<bool> momoTransactionAmountLoaded = [false];
  List<Timer?> momoTransactionTimers = [null];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<CashierProvider>(context, listen: false);
      await provider.getdata();
      provider.fetchPaymentMethods();
      _paymentMethods = provider.allowedPaymentMethods;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();

    // Dispose MOMO transaction controllers
    for (var controller in momoTransactionControllers) {
      controller.dispose();
    }
    for (var controller in momoTransactionAmountControllers) {
      controller.dispose();
    }
    for (var timer in momoTransactionTimers) {
      timer?.cancel();
    }

    super.dispose();
  }

  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final now = DateTime.now();
  int weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday) / 7).ceil();
  }

  void updateMomoPaidTotal() {
    final total = momoTransactionAmountControllers
        .map((controller) => double.tryParse(controller.text.trim()) ?? 0)
        .fold(0.0, (sum, value) => sum + value);
    setState(() {
      _amountController.text = total.toStringAsFixed(2);
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
            content: Text(
              'Transaction ID $transactionId has already been used',
            ),
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
            content: Text(
              'Unable to parse amount for transaction $transactionId',
            ),
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
        momoTransactionAmountControllers[index].text = amount.toStringAsFixed(
          2,
        );
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

  String? momoType;
  bool validateMomoTransactions() {
    final transactionEntries = <Map<String, dynamic>>[];
    for (int i = 0; i < momoTransactionControllers.length; i++) {
      final transactionId = momoTransactionControllers[i].text.trim();
      final amountText = momoTransactionAmountControllers[i].text.trim();
      final transactionAmount = double.tryParse(amountText);

      if (transactionId.isEmpty && amountText.isEmpty) continue;

      if (transactionId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enter transaction ID ${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      if (amountText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enter amount for transaction ${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      if (!momoTransactionAmountLoaded[i]) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submit transaction ID ${i + 1} to load amount'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      if (transactionAmount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid amount for transaction ${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      if (transactionAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Amount must be greater than 0 for transaction ${i + 1}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      transactionEntries.add({
        'transactionId': transactionId,
        'amount': transactionAmount,
      });
    }

    if (transactionEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least one MOMO transaction ID and amount'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  Map<String, dynamic> getMomoTransactionMap() {
    final transactionMap = <String, dynamic>{};
    for (int i = 0; i < momoTransactionControllers.length; i++) {
      final transactionId = momoTransactionControllers[i].text.trim();
      final amount = double.tryParse(
        momoTransactionAmountControllers[i].text.trim(),
      );
      if (transactionId.isEmpty || amount == null) continue;
      transactionMap[transactionId] = {'id': transactionId, 'amount': amount};
    }
    return transactionMap;
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefix,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _paymentMutedForeground(context)),
      hintText: hint,
      hintStyle: TextStyle(color: _paymentForeground(context)),
      prefixIcon: prefix != null
          ? Icon(prefix, color: _paymentMutedForeground(context))
          : null,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _paymentFormBorder(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue),
      ),
      fillColor: _paymentSurface(context, const Color(0xFF22304A)),
      filled: true,
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate MOMO transactions if payment method is MOMO
    if (paymentMethod.toLowerCase() == 'momo' && momoType == 'merchant') {
      if (!validateMomoTransactions()) {
        return;
      }
    }

    double amount = double.parse(_amountController.text);

    try {
      setState(() {
        isLoading = true;
      });
      final provider = Provider.of<CashierProvider>(context, listen: false);
      final paymentId =
          '${widget.debtor.id}${DateTime.now().millisecondsSinceEpoch}${provider.staffPosition}';
      double runningbalance = widget.debtor.balance - amount;

      final paymentMethodKey = paymentMethod.toLowerCase();
      final paymentMethodStore = paymentMethodKey == 'mobile money'
          ? 'momo'
          : paymentMethodKey;
      final selectedNetwork =
          provider.selectedNetworks[widget.debtor.id] ?? 'mtn';
      final momoTransactionIds = paymentMethodStore == 'momo'
          ? getMomoTransactionMap()
          : null;
      final paymentAccountName = paymentMethodStore == 'momo'
          ? selectedNetwork.toUpperCase()
          : (_selectedAccount ?? '');
      final paymentAccountNumber = paymentMethodStore == 'momo'
          ? accountNumberController?.text.trim() ?? ''
          : (_selectedAccount ?? '');
      final paymentReference = _referenceController.text.trim().isEmpty
          ? (paymentMethodStore == 'momo'
                ? paymentAccountNumber
                : 'Payment on ${DateFormat('yyyy-MM-dd').format(_selectedDate)}')
          : _referenceController.text.trim();

      final payment = Payment(
        id: paymentId,
        amount: amount,
        account: _selectedAccount!,
        reference: paymentReference,
        paymentMethod: paymentMethodStore,
        customerid: widget.debtor.id,
        customername: widget.debtor.name,
        createdat: widget.debtor.createdAt!,
        companyid: widget.debtor.companyId,
        companyname: widget.debtor.companyName,
        createdby: widget.debtor.staff,
        contact: widget.debtor.staff,
        runningbalance: runningbalance,
      );

      final paymentEntry = {
        'accountName': paymentAccountName,
        'accountNumber': paymentAccountNumber,
        'amount': payment.amount,
        'method': paymentMethodStore,
        'reference': paymentReference,
        'status': paymentMethodStore == 'momo' ? false : true,
        if (momoTransactionIds != null && momoTransactionIds.isNotEmpty)
          'transactionIds': momoTransactionIds,
      };

      Map<String, dynamic> paymentData = {
        'contact': widget.debtor.contact,
        'companyid': widget.debtor.companyId,
        'companyname': widget.debtor.companyName,
        'id': payment.id,
        'customerid': payment.customerid,
        'customername': payment.customername,
        'amount': payment.amount,
        'balance': payment.runningbalance,
        'account': payment.account,
        'reference': payment.reference,
        'paymentmethod': payment.paymentMethod,
        'payments': [paymentEntry],
        'createdat': FieldValue.serverTimestamp(),
        'createdby': widget.debtor.staff,
        'oldamount': 0,
        'transType': "debt payment",
        'branchName': widget.debtor.branchName,
        'branchId': widget.debtor.branchId,
        'staffemail': provider.staffemail,
        'date': today,
        'year': now.year.toString(), // 2026
        'month': '${now.year}.${now.month}', // 2026.5
        'week': '${now.year}.${weekNumber(now)}', // 2026.32
        'day': DateFormat('EEEE').format(now),
      };
      final formatter = NumberFormat.currency(
        locale: 'en_GH',
        symbol: 'GHS',
        decimalDigits: 2,
      );

      String smsamount = formatter.format(payment.amount);
      String smsbalance = formatter.format(runningbalance);

      await provider.debptpayment(paymentData);
      final smsRecord = {
        'companyid': provider.companyid,
        'branchid': provider.branchid,
        'staff': provider.staff,
        'message':
            "Dear ${payment.customername},We acknowledge receipt of your payment of ${smsamount}.Your remaining balance is ${smsbalance}. Thank you.",
        'senderid': "",
        'recipient': widget.debtor.contact,
        'type': 'single',
        'bulkFilterType': null,
        'status': 'pending',
        'successMessage': '',
        'failureReason': '',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      await provider.db.collection('sms_logs').add(smsRecord);

      if (paymentMethodStore == 'momo' && momoTransactionIds != null) {
        for (final transactionId in momoTransactionIds.keys) {
          final query = await FirebaseFirestore.instance
              .collection('momo')
              .where('transactionId', isEqualTo: transactionId)
              .where('companyid', isEqualTo: provider.companyid)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            await query.docs.first.reference.update({
              'status': 'saved',
              'paymentids': FieldValue.arrayUnion([paymentId]),
            });
          }
        }
      }

      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful'),
          backgroundColor: Colors.green,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, payment);
    } catch (e) {
      print('Payment error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save payment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CashierProvider>(
      builder: (context, provider, _) {
        String invoiceId = widget.debtor.id;
        String? selectedNetwork = provider.selectedNetworks[invoiceId];
        paymentMethod =
            provider.selectedPaymentMethods[invoiceId] ??
            'select payment method';
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          width: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: _paymentSurface(context, const Color(0xFF0A1A2F)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (_isLightTheme(context)
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Colors.grey.shade600),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Header

              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade800,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.payment,
                            color: _paymentForeground(context),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receive Payment',
                                style: TextStyle(
                                  fontSize: 14,

                                  color: _paymentForeground(context),
                                ),
                              ),

                              Text(
                                'Customer: ${widget.debtor.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: (_isLightTheme(context)
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant
                                      : Colors.grey.shade400),
                                  fontSize: 14,
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

              Flexible(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                //color: Colors.orange.shade900.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _paymentForeground(context),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Current Balance:',
                                    style: TextStyle(
                                      color: _paymentForeground(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      widget.debtor.balance < 0
                                          ? 'GHS (${NumberFormat('#,##0.00').format(widget.debtor.balance.abs())})'
                                          : 'GHS ${NumberFormat('#,##0.00').format(widget.debtor.balance)}',
                                      textAlign: TextAlign.end,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _paymentForeground(context),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Amount
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              style: TextStyle(
                                color: _paymentForeground(context),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Amount to pay',
                                labelStyle: TextStyle(
                                  color: _paymentMutedForeground(context),
                                ),
                                prefixText: 'GHS ',
                                prefixStyle: TextStyle(
                                  color: _paymentForeground(context),
                                ),
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  color: _paymentForeground(context),
                                ),
                                filled: true,
                                fillColor: _paymentSurface(
                                  context,
                                  const Color(0xFF1E3A5F),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter amount';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid amount';
                                }
                                if (double.parse(value) <= 0) {
                                  return 'Amount must be greater than 0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            // Payment Method
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _paymentSurface(
                                  context,
                                  const Color(0xFF1E3A5F),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _paymentForeground(context),
                                  width: 0.5,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _paymentMethods.contains(paymentMethod)
                                      ? paymentMethod
                                      : null,
                                  hint: Text(
                                    'Select payment method',
                                    style: TextStyle(
                                      color: _paymentMutedForeground(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                  dropdownColor: _paymentSurface(
                                    context,
                                    const Color(0xFF1E3A5F),
                                  ),
                                  style: TextStyle(
                                    color: _paymentForeground(context),
                                  ),
                                  isExpanded: true,
                                  items: _paymentMethods.map((String method) {
                                    return DropdownMenuItem<String>(
                                      value: method,
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getPaymentIcon(method),
                                            size: 18,
                                            color: _paymentMutedForeground(
                                              context,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(method),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? value) {
                                    if (value != null && value.isNotEmpty) {
                                      final methodKey = value
                                          .toLowerCase()
                                          .replaceAll('_', ' ')
                                          .trim();

                                      setState(() {
                                        paymentMethod = methodKey;
                                        _selectedAccount = null;
                                        provider.selectedPaymentMethods[invoiceId] =
                                            methodKey;
                                        if (value.toLowerCase() == 'momo') {
                                          provider.selectedNetworks[invoiceId] =
                                              'mtn';
                                        } else {
                                          provider.selectedNetworks[invoiceId] =
                                              null;
                                        }
                                        if (methodKey != 'momo') {
                                          provider.selectedNetworks[invoiceId] =
                                              null;
                                        }

                                        if (methodKey != 'card') {
                                          provider.selectedCardTypes[invoiceId] =
                                              null;
                                        }

                                        if (value != null && value.isNotEmpty) {
                                          print(
                                            'Selected payment method: $methodKey',
                                          );
                                          _linkedAccounts =
                                              provider.linkedAccounts[methodKey]
                                                  ?.toList() ??
                                              [];
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // "hubtel" or "merchant"
                            if (paymentMethod.toLowerCase() == 'momo') ...[
                              const SizedBox(height: 8),

                              MomoPaymentFields(
                                selectedNetwork: selectedNetwork,
                                momoType: momoType,
                                networks: momoNetworks,

                                onNetworkChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      provider.selectedNetworks[invoiceId] =
                                          value;
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
                            ],

                            // if (paymentMethod.toLowerCase() == 'momo') ...[
                            //   // Select Network
                            //   Container(
                            //     padding: const EdgeInsets.symmetric(horizontal: 12),
                            //     decoration: BoxDecoration(
                            //       color: _paymentSurface(context, const Color(0xFF1E3A5F)),
                            //       borderRadius: BorderRadius.circular(12),
                            //       border: Border.all(
                            //         color: _paymentForeground(context),
                            //         width: 0.5,
                            //       ),
                            //     ),
                            //     child: DropdownButtonFormField<String>(
                            //       value: selectedNetwork,
                            //       dropdownColor: _paymentSurface(context, const Color(0xFF1E3A5A)),
                            //       style: TextStyle(color: _paymentForeground(context)),
                            //       decoration: InputDecoration(
                            //         labelText: 'Select Network',
                            //         labelStyle: TextStyle(color: _paymentForeground(context).withOpacity(0.7)),
                            //         prefixIcon: Icon(Icons.sim_card, color: _paymentMutedForeground(context)),
                            //         filled: true,
                            //         fillColor: _paymentSurface(context, const Color(0xFF1E3A5A)),
                            //         border: OutlineInputBorder(
                            //           borderRadius: BorderRadius.circular(12),
                            //           borderSide: BorderSide.none,
                            //         ),
                            //       ),
                            //       items: momoNetworks.map((network) {
                            //         return DropdownMenuItem(
                            //           value: network.toLowerCase(),
                            //           child: Row(
                            //             children: [
                            //               Icon(_getNetworkIcon(network),
                            //                   color: _getNetworkColor(network), size: 20),
                            //               const SizedBox(width: 8),
                            //               Text(network, style: TextStyle(color: _paymentForeground(context))),
                            //             ],
                            //           ),
                            //         );
                            //       }).toList(),
                            //       onChanged: (value) {
                            //         if (value != null) {
                            //           setState(() {
                            //             provider.selectedNetworks[invoiceId] = value;
                            //           });
                            //         }
                            //       },
                            //       validator: (value) {
                            //         if (paymentMethod.toLowerCase() == 'momo' && value == null) {
                            //           return 'Please select a network';
                            //         }
                            //         return null;
                            //       },
                            //     ),
                            //   ),
                            //
                            //   const SizedBox(height: 12),
                            //
                            //   // New dropdown for Hubtel vs Merchant
                            //   Container(
                            //     padding: const EdgeInsets.symmetric(horizontal: 12),
                            //     decoration: BoxDecoration(
                            //       color: _paymentSurface(context, const Color(0xFF1E3A5F)),
                            //       borderRadius: BorderRadius.circular(12),
                            //       border: Border.all(
                            //         color: _paymentForeground(context),
                            //         width: 0.5,
                            //       ),
                            //     ),
                            //     child: DropdownButtonFormField<String>(
                            //       value: momoType,
                            //       dropdownColor: _paymentSurface(context, const Color(0xFF1E3A5A)),
                            //       style: TextStyle(color: _paymentForeground(context)),
                            //       decoration: InputDecoration(
                            //         labelText: 'Payment Type',
                            //         labelStyle: TextStyle(color: _paymentForeground(context).withOpacity(0.7)),
                            //         prefixIcon: Icon(Icons.account_balance_wallet, color: _paymentMutedForeground(context)),
                            //         filled: true,
                            //         fillColor: _paymentSurface(context, const Color(0xFF1E3A5A)),
                            //         border: OutlineInputBorder(
                            //           borderRadius: BorderRadius.circular(12),
                            //           borderSide: BorderSide.none,
                            //         ),
                            //       ),
                            //       items: const [
                            //         DropdownMenuItem(value: 'hubtel', child: Text('Hubtel')),
                            //         DropdownMenuItem(value: 'merchant', child: Text('Merchant')),
                            //       ],
                            //       onChanged: (value) {
                            //         setState(() {
                            //           momoType = value;
                            //         });
                            //       },
                            //       validator: (value) {
                            //         if (paymentMethod.toLowerCase() == 'momo' && value == null) {
                            //           return 'Please select payment type';
                            //         }
                            //         return null;
                            //       },
                            //     ),
                            //   ),
                            //   const SizedBox(height: 12),
                            // ],
                            //
                            // if (paymentMethod.toLowerCase() == 'momo' && momoType == 'merchant') ...[
                            //   _buildMomoTransactionFields(),
                            //   const SizedBox(height: 12),
                            //
                            // ],
                            // if (paymentMethod.toLowerCase() == 'momo' && momoType == 'hubtel') ...[
                            //   TextFormField(
                            //     controller: _contactController,
                            //     style: TextStyle(color: _paymentMutedForeground(context)),
                            //     decoration:_inputDecoration(label: "Phone Number",
                            //       prefix: Icons.phone,
                            //       hint: 'Enter contact number',
                            //     ),
                            //     keyboardType: TextInputType.phone,
                            //     inputFormatters: [
                            //       FilteringTextInputFormatter.allow(
                            //         RegExp(r'[0-9+]'),
                            //       ),
                            //       LengthLimitingTextInputFormatter(13),
                            //     ],
                            //     validator: (v) {
                            //       if (v == null || v.isEmpty) return 'Required';
                            //       // Remove spaces and check format
                            //       String cleaned = v.replaceAll(' ', '');
                            //       // Ghana phone: 0XXXXXXXXX (10 digits) or +233XXXXXXXXX (13 chars)
                            //       if (cleaned.startsWith('+233')) {
                            //         if (cleaned.length != 13 ||
                            //             !RegExp(r'^\+233\d{9}$').hasMatch(cleaned)) {
                            //           return 'Invalid format. Use +233XXXXXXXXX';
                            //         }
                            //       } else if (cleaned.startsWith('0')) {
                            //         if (cleaned.length != 10 ||
                            //             !RegExp(r'^0\d{9}$').hasMatch(cleaned)) {
                            //           return 'Invalid format. Use 0XXXXXXXXX';
                            //         }
                            //       } else {
                            //         return 'Phone must start with 0 or +233';
                            //       }
                            //       return null;
                            //     },
                            //   ),
                            //   const SizedBox(height: 12),
                            //
                            // ],
                            if (paymentMethod.toLowerCase() ==
                                    'bank_transfer' ||
                                paymentMethod.toLowerCase() == 'cheque') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _paymentSurface(
                                    context,
                                    const Color(0xFF1E3A5F),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _paymentForeground(context),
                                    width: 0.5,
                                  ),
                                ),
                                child: TextFormField(
                                  controller: referenceController,
                                  style: TextStyle(
                                    color: _paymentForeground(context),
                                  ),
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    labelText: 'Reference Number',
                                    labelStyle: TextStyle(
                                      color: _paymentForeground(
                                        context,
                                      ).withOpacity(0.7),
                                    ),
                                    hintText: 'Enter Reference Number',
                                    hintStyle: TextStyle(
                                      color: _paymentForeground(
                                        context,
                                      ).withOpacity(0.3),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.receipt,
                                      color: _paymentMutedForeground(context),
                                    ),
                                    filled: true,
                                    fillColor: _paymentSurface(
                                      context,
                                      const Color(0xFF1E3A5A),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (paymentMethod.toLowerCase() ==
                                            'cheque' &&
                                        (value == null || value.isEmpty)) {
                                      return 'Please enter reference number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildLinkedAccountDropdown(),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: _paymentDatePickerTheme(
                                          context,
                                        ).colorScheme,
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: _paymentSurface(
                                    context,
                                    const Color(0xFF1E3A5F),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _paymentForeground(context),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(_selectedDate),
                                      style: TextStyle(
                                        color: _paymentForeground(context),
                                      ),
                                    ),
                                    Icon(
                                      Icons.calendar_today,
                                      color: _paymentMutedForeground(context),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Note/Reference
                            TextFormField(
                              controller: _referenceController,
                              style: TextStyle(
                                color: _paymentForeground(context),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Narration',
                                labelStyle: TextStyle(
                                  color: _paymentMutedForeground(context),
                                ),
                                hintText: 'Invoice number, description, etc.',
                                hintStyle: TextStyle(
                                  color: _paymentMutedForeground(context),
                                ),
                                filled: true,
                                fillColor: _paymentSurface(
                                  context,
                                  const Color(0xFF1E3A5F),
                                ),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 15),

                            // Submit Button
                            Center(
                              child: SizedBox(
                                width: 200,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _submitPayment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: isLoading
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          'Record Payment',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinkedAccountDropdown() {
    final hasMethod = paymentMethod.isNotEmpty;
    final hasAccounts = _linkedAccounts.isNotEmpty;

    return DropdownButtonFormField<String>(
      value: _selectedAccount,
      decoration: InputDecoration(
        labelText: 'Payment Account',
        prefixIcon: Icon(
          Icons.account_balance_outlined,
          color: _paymentMutedForeground(context),
        ),
        labelStyle: TextStyle(color: _paymentMutedForeground(context)),
        hintText: !hasMethod
            ? 'Select payment method first'
            : !hasAccounts
            ? 'No accounts available'
            : null,
        hintStyle: TextStyle(color: _paymentForeground(context)),
        filled: true,
        fillColor: _paymentSurface(context, const Color(0xFF1E3A5F)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _paymentBorder(context)),
        ),
      ),
      dropdownColor: _paymentSurface(context, const Color(0xFF1E3A5F)),
      style: TextStyle(color: _paymentForeground(context)),

      onChanged: (!hasMethod || !hasAccounts)
          ? null
          : (value) {
              setState(() {
                _selectedAccount = value!;
              });
            },

      items: _linkedAccounts.map((accountName) {
        return DropdownMenuItem<String>(
          value: accountName,
          child: Text(accountName),
        );
      }).toList(),

      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a payment account';
        }
        return null;
      },
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'Mobile Money':
        return Icons.phone_android;
      case 'Bank Transfer':
        return Icons.account_balance;
      case 'Cash':
        return Icons.money;
      case 'Cheque':
        return Icons.receipt;
      case 'Credit Card':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  bool _isDuplicateMomoTransactionId(int currentIndex) {
    final currentId = momoTransactionControllers[currentIndex].text
        .trim()
        .toLowerCase();

    if (currentId.isEmpty) {
      return false;
    }

    for (int i = 0; i < momoTransactionControllers.length; i++) {
      if (i == currentIndex) {
        continue;
      }

      final otherId = momoTransactionControllers[i].text.trim().toLowerCase();

      if (otherId.isNotEmpty && otherId == currentId) {
        return true;
      }
    }

    return false;
  }

  Widget _buildMomoTransactionFields() {
    if (paymentMethod.toLowerCase() != 'momo') {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'MOMO Transactions',
          style: TextStyle(
            color: _paymentMutedForeground(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            for (
              int index = 0;
              index < momoTransactionControllers.length;
              index++
            )
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _paymentSurface(context, const Color(0xFF1E3A5F)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: momoTransactionAmountLoaded[index]
                          ? Colors.green.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction ${index + 1}',
                        style: TextStyle(
                          color: _paymentMutedForeground(context),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: momoTransactionControllers[index],
                              style: TextStyle(
                                color: _paymentForeground(context),
                              ),
                              keyboardType: TextInputType.text,
                              onChanged: (value) {
                                setState(() {});
                              },
                              decoration: InputDecoration(
                                labelText: 'Transaction ID',
                                labelStyle: TextStyle(
                                  color: _paymentForeground(
                                    context,
                                  ).withOpacity(0.7),
                                ),
                                hintText: 'e.g., MTN12345678',
                                hintStyle: TextStyle(
                                  color: _paymentForeground(
                                    context,
                                  ).withOpacity(0.3),
                                ),
                                prefixIcon: Icon(
                                  Icons.receipt_long,
                                  color: _paymentMutedForeground(context),
                                ),
                                filled: true,
                                fillColor: _paymentSurface(
                                  context,
                                  const Color(0xFF0D1B2A),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                momoTransactionControllers[index].text
                                    .trim()
                                    .isEmpty
                                ? null
                                : () {
                                    if (_isDuplicateMomoTransactionId(index)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'This transaction ID has already been entered.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    fetchMomoAmountForTransaction(index);
                                  },
                            child: Text(
                              'Submit',
                              style: TextStyle(
                                color: _paymentForeground(context),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: momoTransactionAmountControllers[index],
                        readOnly: true,
                        style: TextStyle(color: _paymentForeground(context)),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          labelStyle: TextStyle(
                            color: _paymentForeground(context).withOpacity(0.7),
                          ),
                          prefixText: 'GHS ',
                          prefixStyle: TextStyle(color: Colors.green),
                          filled: true,
                          fillColor: _paymentSurface(
                            context,
                            const Color(0xFF0D1B2A),
                          ),
                          suffixIcon: momoTransactionAmountLoaded[index]
                              ? Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    momoTransactionControllers.add(TextEditingController());
                    momoTransactionAmountControllers.add(
                      TextEditingController(),
                    );
                    momoTransactionAmountLoaded.add(false);
                    momoTransactionTimers.add(null);
                  });
                },
                icon: Icon(Icons.add, color: Colors.blue),
                label: Text(
                  'Add Transaction',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DebtorDetailsDialog extends StatelessWidget {
  final Debtor debtor;
  final Function(Payment) onPaymentAdded;

  const DebtorDetailsDialog({
    super.key,
    required this.debtor,
    required this.onPaymentAdded,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CashierProvider>(context);
    final payments = provider.debtordetails;
    double runningTotal = 0;
    final sortedPayments = List<Payment>.from(payments)
      ..sort((a, b) => a.createdat.compareTo(b.createdat));
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: _paymentSurface(context, const Color(0xFF0A1A2F)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: (_isLightTheme(context)
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Colors.grey.shade600),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade800,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 28,
                          color: _paymentForeground(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debtor.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _paymentForeground(context),
                            ),
                          ),
                          // Text(
                          //   'ID: ${debtor.id}',
                          //   style: TextStyle(color: (_isLightTheme(context) ? Theme.of(context).colorScheme.onSurfaceVariant : Colors.grey.shade400), fontSize: 12),
                          // ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Contact Information
                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _paymentForeground(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _infoTile(context, Icons.phone, 'Phone', debtor.contact),
                  _infoTile(context, Icons.email, 'Email', "debtor's email"),
                  _infoTile(
                    context,
                    Icons.calendar_today,
                    'Customer Since',
                    DateFormat('MMM dd, yyyy').format(debtor.createdAt!),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Financial Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _paymentForeground(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _paymentSurface(context, const Color(0xFF1E3A5F)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _financialRow(
                          context,
                          'Total Debt',
                          'GHS ${NumberFormat('#,##0.00').format(debtor.creditBalance)}',
                          _paymentForeground(context),
                        ),
                        Divider(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        _financialRow(
                          context,
                          'Amount Paid',
                          'GHS ${NumberFormat('#,##0.00').format(debtor.amountpaid)}',
                          _paymentForeground(context),
                        ),
                        Divider(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        _financialRow(
                          context,
                          'Balance',
                          debtor.balance < 0
                              ? 'GHS (${NumberFormat('#,##0.00').format(debtor.balance.abs())})'
                              : 'GHS ${NumberFormat('#,##0.00').format(debtor.balance)}',
                          _isLightTheme(context)
                              ? Colors.orange.shade800
                              : Colors.orange,
                          bold: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _paymentForeground(context),
                        ),
                      ),
                      IconButton(
                        color: Colors.green,
                        onPressed: () => _downloadPdf(context, payments),
                        icon: Icon(Icons.print),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (provider.isLoadingDetails)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (payments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.history, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No payments recorded yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedPayments.length,
                      itemBuilder: (context, index) {
                        final payment = sortedPayments[index];
                        runningTotal += payment.amount;
                        double runningbalance =
                            debtor.creditBalance - runningTotal;
                        return _paymentHistoryTile(
                          context,
                          payment,
                          debtor.creditBalance,
                          runningbalance,
                        );
                      },
                    ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => PaymentFormDialog(
                                debtor: debtor,
                                onPaymentSubmitted: (payment) {
                                  onPaymentAdded(payment);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Payment of GHS ${payment.amount} recorded',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          icon: Icon(Icons.payment),
                          label: Text(
                            'Record Payment',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: (_isLightTheme(context)
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Colors.grey.shade500),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: (_isLightTheme(context)
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Colors.grey.shade400),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _paymentForeground(context),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialRow(
    BuildContext context,
    String label,
    String value,
    Color color, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: (_isLightTheme(context)
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Colors.grey.shade400),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: bold ? 18 : 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentHistoryTile(
    BuildContext context,
    Payment payment,
    double creditbalance,
    double runningbalance,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _paymentSurface(context, const Color(0xFF0D2A4A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getPaymentIcon(payment.paymentMethod),
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GHS ${NumberFormat('#,##0.00').format(payment.amount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _paymentForeground(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (_isLightTheme(context)
                      ? Theme.of(context).colorScheme.surface
                      : Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  payment.paymentMethod,
                  style: TextStyle(
                    fontSize: 10,
                    color: _paymentMutedForeground(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Balance: GHS ${NumberFormat('#,##0.00').format(runningbalance)}",
            style: TextStyle(
              color: (_isLightTheme(context)
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Colors.grey.shade500),
              fontSize: 12,
            ),
          ),
          Text(
            DateFormat('MMM dd, yyyy').format(payment.createdat),
            style: TextStyle(
              color: (_isLightTheme(context)
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Colors.grey.shade500),
              fontSize: 12,
            ),
          ),
          if (payment.reference.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ref: ${payment.reference}',
              style: TextStyle(
                color: (_isLightTheme(context)
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Colors.grey.shade500),
                fontSize: 11,
              ),
            ),
          ],
          Text(
            'Account: ${payment.account}',
            style: TextStyle(
              color: (_isLightTheme(context)
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Colors.grey.shade600),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'Mobile Money':
        return Icons.phone_android;
      case 'Bank Transfer':
        return Icons.account_balance;
      case 'Cash':
        return Icons.money;
      default:
        return Icons.payment;
    }
  }

  Future<void> _downloadPdf(
    BuildContext context,
    List<Payment> payments,
  ) async {
    final pdf = pw.Document();

    // Calculate summary statistics
    final totalPaid = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final currentBalance = debtor.creditBalance - totalPaid;
    final sortedPayments = List<Payment>.from(payments)
      ..sort((a, b) => a.createdat.compareTo(b.createdat));

    pdf.addPage(
      pw.MultiPage(
        //pageFormat:pw.PageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header Section
            _buildHeaderSection(),

            pw.SizedBox(height: 30),

            // Summary Cards Section
            _buildSummarySection(totalPaid, currentBalance),

            pw.SizedBox(height: 30),

            // Payment History Section
            _buildPaymentHistorySection(sortedPayments, debtor.creditBalance),

            pw.SizedBox(height: 20),

            // Footer
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'Debtor_Statement_${debtor.name}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // Helper method for header section
  pw.Widget _buildHeaderSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "${debtor.companyName.toUpperCase()}",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  "Debtor Statement of Account",
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
        pw.SizedBox(height: 20),

        // Debtor Information Box
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "DEBTOR INFORMATION",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  _buildInfoRow("Name:", debtor.name),
                  pw.SizedBox(width: 40),
                  _buildInfoRow("Contact:", debtor.contact),
                  pw.SizedBox(width: 40),
                  _buildInfoRow("Credit Limit:", debtor.creditLimit),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method for summary section
  pw.Widget _buildSummarySection(double totalPaid, double currentBalance) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            "FINANCIAL SUMMARY",
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryCard(
                "Total Debt",
                "GHS ${debtor.creditBalance.toStringAsFixed(2)}",
                PdfColors.red700,
              ),
              _buildSummaryCard(
                "Amount Paid",
                "GHS ${totalPaid.toStringAsFixed(2)}",
                PdfColors.green700,
              ),
              _buildSummaryCard(
                "Balance",
                currentBalance < 0
                    ? "GHS (${currentBalance.abs().toStringAsFixed(2)})"
                    : "GHS ${currentBalance.toStringAsFixed(2)}",
                currentBalance > 0 ? PdfColors.orange700 : PdfColors.green700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method for payment history section
  pw.Widget _buildPaymentHistorySection(
    List<Payment> payments,
    double initialDebt,
  ) {
    if (payments.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        alignment: pw.Alignment.center,
        child: pw.Text(
          "No payment records found",
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
      );
    }

    double runningTotal = 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "PAYMENT HISTORY",
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 15),

        // Table Header
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue100,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(4),
              topRight: pw.Radius.circular(4),
            ),
          ),
          child: pw.Row(
            children: [
              _buildTableHeaderCell("Date", flex: 2),
              _buildTableHeaderCell("Amount (GHS)", flex: 2),
              _buildTableHeaderCell("Method", flex: 2),
              _buildTableHeaderCell("Balance (GHS)", flex: 2),
              _buildTableHeaderCell("Reference", flex: 3),
            ],
          ),
        ),

        // Table Rows
        pw.Column(
          children: payments.asMap().entries.map((entry) {
            final index = entry.key;
            final payment = entry.value;
            runningTotal += payment.amount;
            final runningBalance = initialDebt - runningTotal;

            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200),
                ),
              ),
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
                ),
                color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                child: pw.Row(
                  children: [
                    _buildTableCell(
                      DateFormat('yyyy-MM-dd').format(payment.createdat),
                      flex: 2,
                    ),
                    _buildTableCell(
                      payment.amount.toStringAsFixed(2),
                      flex: 2,
                      isAmount: true,
                    ),
                    _buildTableCell(
                      _getPaymentMethodDisplay(payment.paymentMethod),
                      flex: 2,
                    ),
                    _buildTableCell(
                      runningBalance.toStringAsFixed(2),
                      flex: 2,
                      isAmount: true,
                    ),
                    _buildTableCell(
                      payment.reference.isNotEmpty ? payment.reference : "-",
                      flex: 3,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        pw.SizedBox(height: 10),

        // Summary Row
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(4),
              bottomRight: pw.Radius.circular(4),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                "Total Paid: GHS ${runningTotal.toStringAsFixed(2)}",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method for footer
  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "This is a computer-generated document. No signature required.",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
            pw.Text(
              "Page 1 of 1",
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

  // Helper widget for info row
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        pw.SizedBox(width: 5),
        pw.Text(value, style: pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  // Helper widget for summary card
  pw.Widget _buildSummaryCard(String title, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Helper widget for table header cell
  pw.Widget _buildTableHeaderCell(String text, {required int flex}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          color: PdfColors.blue900,
        ),
      ),
    );
  }

  // Helper widget for table cell
  pw.Widget _buildTableCell(
    String text, {
    required int flex,
    bool isAmount = false,
  }) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        isAmount ? "GHS $text" : text,
        style: pw.TextStyle(fontSize: 10),
      ),
    );
  }

  String _getPaymentMethodDisplay(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'mobile_money':
        return 'Mobile Money';
      default:
        return method;
    }
  }
}
