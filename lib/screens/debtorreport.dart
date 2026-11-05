import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';

import '../models/branch.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class DebtorReport extends StatefulWidget {
  const DebtorReport({super.key});

  @override
  State<DebtorReport> createState() => _DebtorReportState();
}

class _DebtorReportState extends State<DebtorReport> {
  DateTimeRange? selectedDate;
  String? _selectedBranch;
  String _searchQuery = '';
  bool _searchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;
  late final ScrollController _dvController;
  late final ScrollController _dhController;

  static String _capitalizeFirst(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  @override
  void initState() {
    super.initState();
    selectedDate = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
    _dvController = ScrollController();
    _dhController = ScrollController();

    final feed = context.read<Datafeed>();
    final initialBranch =
        (feed.accesslevel.toLowerCase() != 'super admin' &&
            feed.branchid.isNotEmpty)
        ? feed.branchid
        : _selectedBranch;
    Future.microtask(() {
      feed.fetchBranches();
      feed.fetchDebtorReport(
        selectedBranch: initialBranch,
        selectedDate: selectedDate,
      );
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _dvController.dispose();
    _dhController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _reportAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _reportBalance(dynamic value) => _reportAmount(value).abs();

  Future<void> _runReportAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report export failed: $error')));
    }
  }

  String _branchLabel(List<BranchModel> branches, String? branchId) {
    if (branchId == null || branchId.isEmpty) return 'All Branches';
    for (final branch in branches) {
      if (branch.id == branchId) return branch.branchname;
    }
    return branchId;
  }

  String _periodLabel(DateTimeRange? range) {
    if (range == null) return 'All dates';
    final dateFormat = DateFormat.yMMMd();
    return '${dateFormat.format(range.start)} – ${dateFormat.format(range.end)}';
  }

  Widget _buildTotalsFooter({
    required double totalDebit,
    required double totalCredit,
    required double totalBalance,
  }) {
    final theme = Theme.of(context);
    final totals = [
      ('Debit total(GHS)', ' ${totalDebit.toStringAsFixed(2)}'),
      ('Credit total(GHS)', ' ${totalCredit.toStringAsFixed(2)}'),
      ('Balance total(GHS)', (totalBalance.toStringAsFixed(2))),
    ];

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 540) {
              return Column(
                children: [
                  for (final total in totals)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            total.$1,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            total.$2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var index = 0; index < totals.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totals[index].$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          totals[index].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryTile(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(right: 8, top: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Consumer<Datafeed>(
      builder: (context, feed, child) {
        final isRestrictedBranch =
            feed.accesslevel.toLowerCase() != 'super admin' &&
            feed.branchid.isNotEmpty;
        final effectiveBranch = isRestrictedBranch
            ? feed.branchid
            : _selectedBranch;

        final branches = feed.branches;
        final summaryRows = feed.debtorReportRows;
        final filteredRows = _searchQuery.isEmpty
            ? summaryRows
            : summaryRows.where((row) {
                final branchName = (row['branchName'] ?? '')
                    .toString()
                    .toLowerCase();
                final customerName = (row['customerName'] ?? '')
                    .toString()
                    .toLowerCase();
                final customerId = (row['customerId'] ?? '')
                    .toString()
                    .toLowerCase();
                final contact = (row['contact'] ?? '').toString().toLowerCase();
                return branchName.contains(_searchQuery.toLowerCase()) ||
                    customerName.contains(_searchQuery.toLowerCase()) ||
                    customerId.contains(_searchQuery.toLowerCase()) ||
                    contact.contains(_searchQuery.toLowerCase());
              }).toList();

        final totalDebit = filteredRows.fold<double>(
          0,
          (total, row) =>
              total + _reportAmount(row['creditBalance'] ?? row['totalDebt']),
        );
        final totalCredit = filteredRows.fold<double>(
          0,
          (total, row) =>
              total + _reportAmount(row['amountPaid'] ?? row['paid']),
        );
        final totalBalance = filteredRows.fold<double>(
          0,
          (total, row) => total + _reportBalance(row['balance']),
        );
        final totalDebt = totalDebit;
        final totalPaid = totalCredit;
        final isLoading = feed.isLoadingDebtorReport;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.brightness == Brightness.light
                ? theme.colorScheme.surface
                : theme.colorScheme.primary,
            foregroundColor: theme.brightness == Brightness.light
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onPrimary,
            title: _searchExpanded
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (query) =>
                        setState(() => _searchQuery = query.trim()),
                    style: TextStyle(
                      color: theme.brightness == Brightness.light
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search debtors',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_branchLabel(branches, effectiveBranch)} Debtor Report',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _periodLabel(selectedDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
            actions: [
              if (!_searchExpanded)
                PopupMenuButton<String>(
                  tooltip: 'Select branch',
                  enabled: !isRestrictedBranch,
                  initialValue: effectiveBranch ?? '',
                  onSelected: isRestrictedBranch
                      ? null
                      : (branchId) {
                          final selected = branchId.isEmpty ? null : branchId;
                          setState(() => _selectedBranch = selected);
                          feed.fetchDebtorReport(
                            selectedBranch: selected,
                            selectedDate: selectedDate,
                          );
                        },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: '', child: Text('All Branches')),
                    ...branches
                        .where((branch) => branch.id.isNotEmpty)
                        .map(
                          (branch) => PopupMenuItem(
                            value: branch.id,
                            child: Text(branch.branchname),
                          ),
                        ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.store_outlined),
                  ),
                ),
              if (!_searchExpanded)
                ReusableDatePickerWidget(
                  onDateSelected: (range) {
                    setState(() => selectedDate = range);
                    feed.fetchDebtorReport(
                      selectedDate: range,
                      selectedBranch: effectiveBranch,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.calendar_today_rounded, size: 20),
                  ),
                ),
              if (!_searchExpanded)
                PopupMenuButton<String>(
                  tooltip: 'Export report',
                  enabled: filteredRows.isNotEmpty,
                  onSelected: (action) {
                    switch (action) {
                      case 'pdf':
                        _runReportAction(
                          () => _printSummary(
                            filteredRows,
                            totalDebt,
                            totalPaid,
                            feed.company,
                            saveToFile: true,
                          ),
                        );
                        break;
                      case 'print':
                        _runReportAction(
                          () => _printSummary(
                            filteredRows,
                            totalDebt,
                            totalPaid,
                            feed.company,
                          ),
                        );
                        break;
                      case 'excel':
                        _runReportAction(
                          () => _exportSummaryExcel(
                            filteredRows,
                            feed.company,
                            effectiveBranch,
                          ),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'pdf',
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_outlined),
                        title: Text('Save PDF'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'print',
                      child: ListTile(
                        leading: Icon(Icons.print_outlined),
                        title: Text('Print'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'excel',
                      child: ListTile(
                        leading: Icon(Icons.table_view_outlined),
                        title: Text('Download Excel'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.more_vert),
                  ),
                ),
              IconButton(
                tooltip: _searchExpanded ? 'Close search' : 'Search',
                onPressed: () {
                  setState(() {
                    _searchExpanded = !_searchExpanded;
                    if (!_searchExpanded) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
                icon: Icon(_searchExpanded ? Icons.close : Icons.search),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: screenWidth),
                child: Column(
                  children: [
                    Visibility(
                      visible: false,
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withOpacity(
                              0.08,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (selectedDate != null) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Debt payment range',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.28),
                                      ),
                                    ),
                                    child: Text(
                                      '${DateFormat.yMMMd().format(selectedDate!.start)}'
                                      '-'
                                      '${DateFormat.yMMMd().format(selectedDate!.end)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isMobile = constraints.maxWidth < 700;

                                final uniqueBranches = <String, dynamic>{};
                                for (final b in branches) {
                                  uniqueBranches[b.id] = b;
                                }

                                final branchDropdown =
                                    DropdownButtonFormField<String?>(
                                      initialValue: effectiveBranch,
                                      dropdownColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 13,
                                      ),
                                      isDense: true,
                                      decoration: InputDecoration(
                                        labelText: 'Branch',
                                        labelStyle: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.outline,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFF415A77),
                                          ),
                                        ),
                                        fillColor: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        filled: true,
                                      ),
                                      items: [
                                        DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('All Branches'),
                                        ),
                                        ...uniqueBranches.values.map(
                                          (b) => DropdownMenuItem<String?>(
                                            value: b.id,
                                            child: Text(b.branchname),
                                          ),
                                        ),
                                      ],
                                      onChanged: isRestrictedBranch
                                          ? null
                                          : (val) {
                                              setState(
                                                () => _selectedBranch = val,
                                              );
                                              feed.fetchDebtorReport(
                                                selectedBranch: val,
                                                selectedDate: selectedDate,
                                              );
                                            },
                                    );

                                final searchField = TextFormField(
                                  onChanged: (value) => setState(() {
                                    _searchQuery = value;
                                  }),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search customer, ID, contact, or branch',
                                    hintStyle: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      size: 18,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Color(0xFF415A77),
                                      ),
                                    ),
                                  ),
                                );

                                final printButton = ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.print_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Print',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: filteredRows.isEmpty
                                      ? null
                                      : () => _runReportAction(
                                          () => _printSummary(
                                            filteredRows,
                                            totalDebt,
                                            totalPaid,
                                            feed.company,
                                          ),
                                        ),
                                );

                                final savePdfButton = OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Save PDF'),
                                  onPressed: filteredRows.isEmpty
                                      ? null
                                      : () => _runReportAction(
                                          () => _printSummary(
                                            filteredRows,
                                            totalDebt,
                                            totalPaid,
                                            feed.company,
                                            saveToFile: true,
                                          ),
                                        ),
                                );

                                final excelButton = OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.table_view_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Excel'),
                                  onPressed: filteredRows.isEmpty
                                      ? null
                                      : () => _runReportAction(
                                          () => _exportSummaryExcel(
                                            filteredRows,
                                            feed.company,
                                            effectiveBranch,
                                          ),
                                        ),
                                );

                                final exportButtons = Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    savePdfButton,
                                    printButton,
                                    excelButton,
                                  ],
                                );

                                if (isMobile) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      branchDropdown,
                                      const SizedBox(height: 8),
                                      searchField,
                                      const SizedBox(height: 8),
                                      exportButtons,
                                    ],
                                  );
                                }

                                if (constraints.maxWidth < 1050) {
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: branchDropdown),
                                          const SizedBox(width: 10),
                                          Expanded(child: searchField),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      exportButtons,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(flex: 2, child: branchDropdown),
                                    const SizedBox(width: 10),
                                    Expanded(flex: 3, child: searchField),
                                    const SizedBox(width: 10),
                                    exportButtons,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isMobileSummary =
                                    constraints.maxWidth < 600;

                                final branchFilterLabel =
                                    effectiveBranch == null ||
                                        effectiveBranch.isEmpty
                                    ? 'All'
                                    : (branches
                                          .firstWhere(
                                            (branch) =>
                                                branch.id == effectiveBranch,
                                            orElse: () => BranchModel(
                                              id: '',
                                              branchname: effectiveBranch,
                                            ),
                                          )
                                          .branchname);

                                if (isMobileSummary) {
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _summaryTile(
                                              context,
                                              'Total Debt',
                                              'GHS ${totalDebt.toStringAsFixed(2)}',
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _summaryTile(
                                              context,
                                              'Total Paid',
                                              'GHS ${totalPaid.toStringAsFixed(2)}',
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _summaryTile(
                                              context,
                                              'Debtors',
                                              '${filteredRows.length}',
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _summaryTile(
                                              context,
                                              'Branch filter',
                                              branchFilterLabel,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      child: _summaryTile(
                                        context,
                                        'Total Debt',
                                        'GHS ${totalDebt.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _summaryTile(
                                        context,
                                        'Total Paid',
                                        'GHS ${totalPaid.toStringAsFixed(2)}',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _summaryTile(
                                        context,
                                        'Debtors',
                                        '${filteredRows.length}',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _summaryTile(
                                        context,
                                        'Branch filter',
                                        branchFilterLabel,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : filteredRows.isEmpty
                          ? Center(
                              child: Text(
                                'No debtor records found',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                            )
                          : Align(
                              alignment: Alignment.topLeft,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isDesktop = constraints.maxWidth > 700;
                                  if (isDesktop) {

                                    return LayoutBuilder(
                                      builder: (context, constraints) {
                                        const widths = [32, 240, 150, 150, 150];
                                        final gap =
                                            ((constraints.maxWidth -
                                                        widths.reduce(
                                                          (a, b) => a + b,
                                                        ) -
                                                        32) /
                                                    (widths.length - 1))
                                                .clamp(4.0, 60.0)
                                                .toDouble();
                                        final double contentWidth =
                                            widths.reduce((a, b) => a + b) +
                                            (widths.length - 1) * gap +
                                            32;
                                        final double tableWidth =
                                            constraints.maxWidth > contentWidth
                                            ? constraints.maxWidth
                                            : contentWidth;

                                        Widget rowOf(
                                          List<Widget> cells, {
                                          Color? color,
                                        }) {
                                          return Container(
                                            color: color,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            constraints: const BoxConstraints(
                                              minHeight: 44,
                                              maxHeight: 60,
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              children: [
                                                for (
                                                  int i = 0;
                                                  i < cells.length;
                                                  i++
                                                ) ...[
                                                  SizedBox(
                                                    width: widths[i].toDouble(),
                                                    child: cells[i],
                                                  ),
                                                  if (i != cells.length - 1)
                                                    SizedBox(width: gap),
                                                ],
                                              ],
                                            ),
                                          );
                                        }

                                        return ScrollbarTheme(
                                          data: ScrollbarThemeData(
                                            thumbColor:
                                                MaterialStateProperty.all(
                                                  theme.colorScheme.primary
                                                      .withOpacity(0.9),
                                                ),
                                            trackColor:
                                                MaterialStateProperty.all(
                                                  theme
                                                      .colorScheme
                                                      .surfaceVariant,
                                                ),
                                            thickness:
                                                MaterialStateProperty.all(10),
                                            radius: const Radius.circular(8),
                                          ),
                                          child: Scrollbar(
                                            controller: _horizontalController,
                                            thumbVisibility: true,
                                            trackVisibility: true,
                                            notificationPredicate: (n) =>
                                                n.depth == 1,
                                            child: SingleChildScrollView(
                                              controller: _horizontalController,
                                              scrollDirection: Axis.horizontal,
                                              child: SizedBox(
                                                width: tableWidth,
                                                height:
                                                    constraints
                                                        .maxHeight
                                                        .isFinite
                                                    ? constraints.maxHeight
                                                    : null,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Container(
                                                      color: theme
                                                          .colorScheme
                                                          .surfaceVariant,
                                                      child: rowOf([
                                                        Text(
                                                          '#',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        Text(
                                                          'Customer',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        Text(
                                                          'Debit(GHS)',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        Text(
                                                          'Credit(GHS)',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        Text(
                                                          'Balance(GHS)',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ]),
                                                    ),
                                                    Divider(
                                                      height: 0.5,
                                                      thickness: 0.5,
                                                      color: theme
                                                          .colorScheme
                                                          .outline
                                                          .withOpacity(0.1),
                                                    ),
                                                    Expanded(
                                                      child: Scrollbar(
                                                        controller:
                                                            _verticalController,
                                                        thumbVisibility: true,
                                                        trackVisibility: true,
                                                        child: ListView.separated(
                                                          controller:
                                                              _verticalController,
                                                          itemCount:
                                                              filteredRows
                                                                  .length,
                                                          separatorBuilder: (_, _) => Divider(
                                                            height: 1,
                                                            thickness: 1,
                                                            color:
                                                                theme.brightness ==
                                                                    Brightness
                                                                        .dark
                                                                ? theme
                                                                      .colorScheme
                                                                      .outline
                                                                : theme
                                                                      .colorScheme
                                                                      .outlineVariant,
                                                          ),
                                                          itemBuilder: (context, index) {
                                                            final debtor =
                                                                filteredRows[index];

                                                            return InkWell(
                                                              onTap: () => _openCustomerTransactions(
                                                                context,
                                                                customerId:
                                                                    debtor['customerId']
                                                                        ?.toString() ??
                                                                    '',
                                                                customerName:
                                                                    debtor['customerName']
                                                                        ?.toString() ??
                                                                    'Customer',
                                                                selectedBranch:
                                                                    effectiveBranch,
                                                                contact:
                                                                    debtor['contact']
                                                                        ?.toString(),
                                                                creditLimit:
                                                                    debtor['creditLimit']
                                                                        ?.toString(),
                                                              ),
                                                              child: rowOf(
                                                                [
                                                                  Text(
                                                                    '${index + 1}',
                                                                    style: TextStyle(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    _capitalizeFirst(
                                                                      debtor['customerName']
                                                                              ?.toString() ??
                                                                          '',
                                                                    ),
                                                                    style: TextStyle(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    _reportAmount(
                                                                      debtor['creditBalance'] ??
                                                                          debtor['totalDebt'],
                                                                    ).toStringAsFixed(
                                                                      2,
                                                                    ),
                                                                    style: TextStyle(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    _reportAmount(
                                                                      debtor['amountPaid'] ??
                                                                          debtor['paid'],
                                                                    ).toStringAsFixed(
                                                                      2,
                                                                    ),
                                                                    style: TextStyle(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    _reportBalance(
                                                                      debtor['balance'],
                                                                    ).toStringAsFixed(
                                                                      2,
                                                                    ),
                                                                    style: TextStyle(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                ],
                                                                color: theme
                                                                    .colorScheme
                                                                    .surface,
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        border: Border(
                                                          top: BorderSide(
                                                            color: theme
                                                                .colorScheme
                                                                .outlineVariant,
                                                          ),
                                                        ),
                                                      ),
                                                      child: rowOf([
                                                        const SizedBox.shrink(),
                                                        Text(
                                                          'Total(GHS)',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        Text(
                                                          ' ${totalDebit.toStringAsFixed(2)}',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        Text(
                                                          ' ${totalCredit.toStringAsFixed(2)}',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        Text(
                                                          ' ${totalBalance.toStringAsFixed(2)}',
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ]),
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
                                  return ListView.separated(
                                    itemCount: filteredRows.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final debtor = filteredRows[index];
                                      return InkWell(
                                        onTap: () => _openCustomerTransactions(
                                          context,
                                          customerId:
                                              debtor['customerId']
                                                  ?.toString() ??
                                              '',
                                          customerName:
                                              debtor['customerName']
                                                  ?.toString() ??
                                              'Customer',
                                          selectedBranch: effectiveBranch,
                                          contact: debtor['contact']
                                              ?.toString(),
                                          creditLimit: debtor['creditLimit']
                                              ?.toString(),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _capitalizeFirst(
                                                  debtor['customerName']
                                                          ?.toString() ??
                                                      '',
                                                ),
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          theme.brightness ==
                                                              Brightness.dark
                                                          ? theme
                                                                .colorScheme
                                                                .onSurface
                                                          : theme
                                                                .colorScheme
                                                                .primary,
                                                    ),
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                runSpacing: 8,
                                                children: [
                                                  _chip(
                                                    context,
                                                    'Branch',
                                                    debtor['branchName']
                                                            ?.toString() ??
                                                        '-',
                                                  ),
                                                  _chip(
                                                    context,
                                                    'Debit',
                                                    'GHS ${_reportAmount(debtor['creditBalance'] ?? debtor['totalDebt']).toStringAsFixed(2)}',
                                                  ),
                                                  _chip(
                                                    context,
                                                    'Credit',
                                                    'GHS ${_reportAmount(debtor['amountPaid'] ?? debtor['paid']).toStringAsFixed(2)}',
                                                  ),
                                                  _chip(
                                                    context,
                                                    'Balance',
                                                    'GHS ${_reportBalance(debtor['balance']).toStringAsFixed(2)}',
                                                  ),
                                                ],
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
                    ),
                    if (screenWidth <= 700)
                      _buildTotalsFooter(
                        totalDebit: totalDebit,
                        totalCredit: totalCredit,
                        totalBalance: totalBalance,
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

  void _openCustomerTransactions(
    BuildContext context, {
    required String customerId,
    required String customerName,
    String? selectedBranch,
    String? contact,
    String? creditLimit,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DebtorTransactionsPage(
          customerId: customerId,
          customerName: customerName,
          contact: contact,
          creditLimit: creditLimit,
          selectedBranch: selectedBranch,
          selectedDate: selectedDate,
        ),
      ),
    );
  }

  Future<void> showCustomerDetailLegacy(
    BuildContext context, {
    required String customerId,
    required String customerName,
    String? selectedBranch,
    String? contact,
    String? creditLimit,
  }) async {
    final provider = Provider.of<Datafeed>(context, listen: false);
    final normalizedBranch = selectedBranch?.trim().isEmpty == true
        ? null
        : selectedBranch;
    provider.fetchDebtPaymentTransactions(
      selectedDate: selectedDate,
      selectedBranch: normalizedBranch,
      customerId: customerId,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<Datafeed>(
          builder: (context, feed, _) {
            final isLoading = feed.isLoadingDebtPaymentTransactions;
            final transactions = feed.debtPaymentTransactions;
            final totalAmount = transactions.fold<double>(0.0, (sum, item) {
              final amount = item['amount'];
              if (amount is num) return sum + amount.toDouble();
              return sum + double.tryParse(amount?.toString() ?? '0')!;
            });

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_DebtorReportState._capitalizeFirst(customerName)} - Debt Payments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),

              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.72,
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : transactions.isEmpty
                    ? Center(
                        child: Text(
                          'No debt payments found',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.72),
                              ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = constraints.maxWidth < 600;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _chip(
                                      context,
                                      'Transactions',
                                      '${transactions.length}',
                                    ),
                                    _chip(
                                      context,
                                      'Total amount',
                                      'GHS ${totalAmount.toStringAsFixed(2)}',
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: isMobile
                                    ? ListView.builder(
                                        controller: _dvController,
                                        itemCount: transactions.length,
                                        itemBuilder: (context, index) {
                                          final tx = transactions[index];
                                          final amount =
                                              (tx['amount'] is num
                                                  ? (tx['amount'] as num)
                                                        .toStringAsFixed(2)
                                                  : double.tryParse(
                                                      tx['amount']
                                                              ?.toString() ??
                                                          '0',
                                                    )?.toStringAsFixed(2)) ??
                                              '0.00';

                                          return Card(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                            margin: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              side: BorderSide(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline
                                                    .withOpacity(0.2),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '#${index + 1}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurface,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          tx['customername']
                                                                  ?.toString() ??
                                                              '-',
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.onSurface,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                      Text(
                                                        'GHS $amount',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      ).brightness ==
                                                                      Brightness
                                                                          .dark
                                                                  ? Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .secondary
                                                                  : Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .primary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    tx['date']?.toString() ??
                                                        '-',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withOpacity(
                                                                    0.7,
                                                                  ),
                                                        ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 6,
                                                    children: [
                                                      _chip(
                                                        context,
                                                        'Payment',
                                                        tx['paymentmethod']
                                                                ?.toString() ??
                                                            '-',
                                                      ),
                                                      _chip(
                                                        context,
                                                        'Reference',
                                                        tx['reference']
                                                                ?.toString() ??
                                                            tx['id']
                                                                ?.toString() ??
                                                            '-',
                                                      ),
                                                      _chip(
                                                        context,
                                                        'Staff',
                                                        tx['createdby']
                                                                ?.toString() ??
                                                            tx['staff']
                                                                ?.toString() ??
                                                            '-',
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : LayoutBuilder(
                                        builder: (context, tableConstraints) {
                                          const widths = [
                                            32,
                                            100,
                                            150,
                                            90,
                                            110,
                                            130,
                                            110,
                                          ];
                                          final gap =
                                              ((tableConstraints.maxWidth -
                                                          widths.reduce(
                                                            (a, b) => a + b,
                                                          ) -
                                                          32) /
                                                      (widths.length - 1))
                                                  .clamp(4.0, 18.0)
                                                  .toDouble();
                                          final double contentWidth =
                                              widths.reduce((a, b) => a + b) +
                                              (widths.length - 1) * gap +
                                              32;
                                          final double tableWidth =
                                              tableConstraints.maxWidth >
                                                  contentWidth
                                              ? tableConstraints.maxWidth
                                              : contentWidth;

                                          Widget rowOf(
                                            List<Widget> cells, {
                                            Color? color,
                                          }) {
                                            return Container(
                                              color: color,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              constraints: const BoxConstraints(
                                                minHeight: 44,
                                                maxHeight: 60,
                                              ),
                                              alignment: Alignment.center,
                                              child: Row(
                                                children: [
                                                  for (
                                                    int i = 0;
                                                    i < cells.length;
                                                    i++
                                                  ) ...[
                                                    SizedBox(
                                                      width: widths[i]
                                                          .toDouble(),
                                                      child: cells[i],
                                                    ),
                                                    if (i != cells.length - 1)
                                                      SizedBox(width: gap),
                                                  ],
                                                ],
                                              ),
                                            );
                                          }

                                          return ScrollbarTheme(
                                            data: ScrollbarThemeData(
                                              thumbColor:
                                                  MaterialStateProperty.all(
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.9),
                                                  ),
                                              trackColor:
                                                  MaterialStateProperty.all(
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .surfaceVariant,
                                                  ),
                                              thickness:
                                                  MaterialStateProperty.all(10),
                                              radius: const Radius.circular(8),
                                            ),
                                            child: Scrollbar(
                                              controller: _dhController,
                                              thumbVisibility: true,
                                              trackVisibility: true,
                                              notificationPredicate: (n) =>
                                                  n.depth == 1,
                                              child: SingleChildScrollView(
                                                controller: _dhController,
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: SizedBox(
                                                  width: tableWidth,
                                                  height:
                                                      tableConstraints
                                                          .maxHeight
                                                          .isFinite
                                                      ? tableConstraints
                                                            .maxHeight
                                                      : null,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      Container(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceVariant,
                                                        child: rowOf([
                                                          Text(
                                                            '#',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurface,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                          Text(
                                                            'Date',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurface,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                          Text(
                                                            'Customer',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurface,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                          Text(
                                                            'Amount',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurface,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                          Text(
                                                            'Payment',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurface,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                          Text(
                                                            'Reference',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurface,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                          Text(
                                                            'Staff',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurface,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ]),
                                                      ),
                                                      Divider(
                                                        height: 0.5,
                                                        thickness: 0.5,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .outline
                                                            .withOpacity(0.1),
                                                      ),
                                                      Expanded(
                                                        child: Scrollbar(
                                                          controller:
                                                              _dvController,
                                                          thumbVisibility: true,
                                                          trackVisibility: true,
                                                          child: ListView.builder(
                                                            controller:
                                                                _dvController,
                                                            itemCount:
                                                                transactions
                                                                    .length,
                                                            itemBuilder: (context, index) {
                                                              final tx =
                                                                  transactions[index];
                                                              final amount =
                                                                  (tx['amount']
                                                                          is num
                                                                      ? (tx['amount']
                                                                                as num)
                                                                            .toStringAsFixed(
                                                                              2,
                                                                            )
                                                                      : double.tryParse(
                                                                          tx['amount']?.toString() ??
                                                                              '0',
                                                                        )?.toStringAsFixed(
                                                                          2,
                                                                        )) ??
                                                                  '0.00';

                                                              return rowOf(
                                                                [
                                                                  Text(
                                                                    '${index + 1}',
                                                                    style: TextStyle(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurface,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    tx['date']
                                                                            ?.toString() ??
                                                                        '-',
                                                                    style: TextStyle(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurface,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    tx['customername']
                                                                            ?.toString() ??
                                                                        '-',
                                                                    style: TextStyle(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurface,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    amount,
                                                                    style: TextStyle(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurface,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    tx['paymentmethod']
                                                                            ?.toString() ??
                                                                        '-',
                                                                    style: TextStyle(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurface,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    tx['reference']
                                                                            ?.toString() ??
                                                                        tx['id']
                                                                            ?.toString() ??
                                                                        '-',
                                                                    style: TextStyle(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurface,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    tx['createdby']
                                                                            ?.toString() ??
                                                                        tx['staff']
                                                                            ?.toString() ??
                                                                        '-',
                                                                    style: TextStyle(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurface,
                                                                    ),
                                                                  ),
                                                                ],
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.surface,
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
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              actions: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(
                    'Print / Download',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: transactions.isEmpty
                      ? null
                      : () => _DebtorReportState._printDetail(
                          transactions,
                          customerName,
                          Provider.of<Datafeed>(context, listen: false).company,
                          contact,
                          creditLimit,
                        ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Close',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportSummaryExcel(
    List<Map<String, dynamic>> rows,
    String company,
    String? branch,
  ) async {
    final excelFile = xls.Excel.createExcel();
    final sheet = excelFile['Debtor Report'];
    sheet.appendRow([xls.TextCellValue(company.toUpperCase())]);
    sheet.appendRow([xls.TextCellValue('Branch: ${branch ?? 'All branches'}')]);
    sheet.appendRow([
      xls.TextCellValue(
        selectedDate == null
            ? 'Date: All dates'
            : 'Period: ${DateFormat('yyyy-MM-dd').format(selectedDate!.start)}'
                  ' to ${DateFormat('yyyy-MM-dd').format(selectedDate!.end)}',
      ),
    ]);
    sheet.appendRow([
      xls.TextCellValue(''),
      xls.TextCellValue('Customer'),
      xls.TextCellValue('Debit'),
      xls.TextCellValue('Credit'),
      xls.TextCellValue('Balance'),
    ]);

    var totalDebit = 0.0;
    var totalCredit = 0.0;
    var totalBalance = 0.0;
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final debit = _reportAmount(row['creditBalance'] ?? row['totalDebt']);
      final credit = _reportAmount(row['amountPaid'] ?? row['paid']);
      final balance = _reportBalance(row['balance']);
      totalDebit += debit;
      totalCredit += credit;
      totalBalance += balance;
      sheet.appendRow([
        xls.IntCellValue(index + 1),
        xls.TextCellValue(
          _capitalizeFirst(row['customerName']?.toString() ?? ''),
        ),
        xls.DoubleCellValue(debit),
        xls.DoubleCellValue(credit),
        xls.DoubleCellValue(balance),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue(''),
      xls.TextCellValue('TOTAL'),
      xls.DoubleCellValue(totalDebit),
      xls.DoubleCellValue(totalCredit),
      xls.DoubleCellValue(totalBalance),
    ]);

    final bytes = excelFile.encode();
    if (bytes == null) {
      throw Exception('Failed to encode the debtor report as Excel.');
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await FileSaver.instance.saveFile(
      name: 'debtor_report_$timestamp',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<void> _printSummary(
    List<Map<String, dynamic>> rows,
    double totalDebt,
    double totalPaid,
    String company, {
    bool saveToFile = false,
  }) async {
    final pdf = pw.Document(title: 'Debtor Report');
    final totalBalance = rows.fold<double>(
      0,
      (runningTotal, row) => runningTotal + _reportBalance(row['balance']),
    );
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    pw.Widget cell(
      String text, {
      bool header = false,
      bool bold = false,
      bool right = false,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: (header || bold) ? boldFont : baseFont,
            fontSize: 9,
            color: PdfColors.black,
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (_) => [
          // Header
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                company,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 24,
                  color: PdfColors.black,
                ),
              ),
              pw.Text(
                'Debtors Report',
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: 12,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: 9,
                      color: PdfColors.black,
                    ),
                  ),
                  if (selectedDate != null)
                    pw.Text(
                      'Period: ${DateFormat('d MMM y').format(selectedDate!.start)} - ${DateFormat('d MMM y').format(selectedDate!.end)}',
                      style: pw.TextStyle(
                        font: baseFont,
                        fontSize: 9,
                        color: PdfColors.black,
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 16),
            ],
          ),

          // Financial Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'FINANCIAL SUMMARY',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'Debit total',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'GHS ${totalDebt.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 13,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Credit total',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'GHS ${totalPaid.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 13,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Balance',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'GHS ${totalBalance.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 13,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Total Debtors',
                          style: pw.TextStyle(
                            font: baseFont,
                            fontSize: 9,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          rows.length.toString(),
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 13,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Debtors Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(20),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                children: [
                  cell('#', header: true),
                  cell('CUSTOMER', header: true),
                  cell('DEBIT', header: true, right: true),
                  cell('CREDIT', header: true, right: true),
                  cell('BALANCE', header: true, right: true),
                ],
              ),
              ...rows.asMap().entries.map((entry) {
                final index = entry.key;
                final debtor = entry.value;
                final debit = _reportAmount(
                  debtor['creditBalance'] ?? debtor['totalDebt'],
                );
                final credit = _reportAmount(
                  debtor['amountPaid'] ?? debtor['paid'],
                );
                final balance = _reportBalance(debtor['balance']);
                return pw.TableRow(
                  children: [
                    cell('${index + 1}'),
                    cell(
                      _capitalizeFirst(
                        debtor['customerName']?.toString() ?? '',
                      ),
                    ),
                    cell('GHS ${debit.toStringAsFixed(2)}', right: true),
                    cell('GHS ${credit.toStringAsFixed(2)}', right: true),
                    cell('GHS ${balance.toStringAsFixed(2)}', right: true),
                  ],
                );
              }),
              pw.TableRow(
                children: [
                  cell('', bold: true),
                  cell('GRAND TOTAL', bold: true),
                  cell(
                    'GHS ${totalDebt.toStringAsFixed(2)}',
                    right: true,
                    bold: true,
                  ),
                  cell(
                    'GHS ${totalPaid.toStringAsFixed(2)}',
                    right: true,
                    bold: true,
                  ),
                  cell(
                    'GHS ${totalBalance.toStringAsFixed(2)}',
                    right: true,
                    bold: true,
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'This is a computer-generated document. No signature required.',
            style: pw.TextStyle(
              font: baseFont,
              fontSize: 8,
              color: PdfColors.black,
            ),
          ),
        ],
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(thickness: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                    font: baseFont,
                    fontSize: 8,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (saveToFile) {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      await FileSaver.instance.saveFile(
        name: 'debtor_report_$timestamp',
        bytes: await pdf.save(),
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      return;
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> _printDetail(
    List<Map<String, dynamic>> transactions,
    String customerName,
    String company,
    String? contact,
    String? creditLimit, {
    bool saveToFile = false,
  }) async {
    final pdf = pw.Document(title: '$customerName Debt Payment History');
    final baseFont = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    pw.Widget cell(String text, {bool header = false, bool right = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: header ? boldFont : baseFont,
            fontSize: 8,
            color: PdfColors.black,
          ),
        ),
      );
    }

    String dateLabel(Map<String, dynamic> transaction) {
      final value =
          transaction['createdat'] ??
          transaction['createdAt'] ??
          transaction['date'];
      final parsed = value is Timestamp
          ? value.toDate()
          : value is DateTime
          ? value
          : DateTime.tryParse(value?.toString() ?? '');
      return parsed == null
          ? value?.toString() ?? '-'
          : DateFormat.yMMMd().format(parsed);
    }

    double amountOf(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    final totalOpening = transactions.fold<double>(
      0,
      (total, tx) =>
          total +
          amountOf(
            tx['openingBalance'] ?? tx['openingbalance'] ?? tx['opening'],
          ).abs(),
    );
    final totalAmount = transactions.fold<double>(
      0,
      (total, tx) => total + amountOf(tx['amount']),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (_) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                company,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 16,
                  color: PdfColors.black,
                ),
              ),
              pw.Text(
                'Debt payment history',
                style: pw.TextStyle(font: baseFont, fontSize: 11),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Customer: ${_DebtorReportState._capitalizeFirst(customerName)}',
                style: pw.TextStyle(font: baseFont, fontSize: 9),
              ),
              pw.Text(
                'Contact: ${contact ?? '-'}    Credit limit: ${creditLimit ?? '-'}',
                style: pw.TextStyle(font: baseFont, fontSize: 9),
              ),
              pw.Text(
                'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(font: baseFont, fontSize: 9),
              ),
            ],
          ),
          if (transactions.isNotEmpty)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.4),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1.4),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.6),
                6: const pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  children: [
                    cell('#', header: true),
                    cell('DATE', header: true),
                    cell('OPENING BALANCE', header: true, right: true),
                    cell('AMOUNT', header: true, right: true),
                    cell('PAYMENT METHOD', header: true),
                    cell('REFERENCE', header: true),
                    cell('STAFF', header: true),
                  ],
                ),
                ...transactions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tx = entry.value;
                  return pw.TableRow(
                    children: [
                      cell('${index + 1}'),
                      cell(dateLabel(tx)),
                      cell(
                        amountOf(
                          tx['openingBalance'] ??
                              tx['openingbalance'] ??
                              tx['opening'],
                        ).abs().toStringAsFixed(2),
                        right: true,
                      ),
                      cell(
                        amountOf(tx['amount']).toStringAsFixed(2),
                        right: true,
                      ),
                      cell(
                        tx['paymentmethod']?.toString() ??
                            tx['account']?.toString() ??
                            '-',
                      ),
                      cell(
                        tx['reference']?.toString() ??
                            tx['id']?.toString() ??
                            '-',
                      ),
                      cell(
                        tx['createdby']?.toString() ??
                            tx['staff']?.toString() ??
                            '-',
                      ),
                    ],
                  );
                }),
              ],
            )
          else
            pw.Text(
              'No payment records found',
              style: pw.TextStyle(font: baseFont),
            ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Opening balance total: GHS ${totalOpening.toStringAsFixed(2)}',
            style: pw.TextStyle(font: boldFont, fontSize: 9),
          ),
          pw.Text(
            'Amount total: GHS ${totalAmount.toStringAsFixed(2)}',
            style: pw.TextStyle(font: boldFont, fontSize: 9),
          ),
        ],
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(font: baseFont, fontSize: 8),
          ),
        ),
      ),
    );

    if (saveToFile) {
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      await FileSaver.instance.saveFile(
        name: 'debt_payment_history_$timestamp',
        bytes: await pdf.save(),
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      return;
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  BranchModel branchEmpty() => BranchModel(id: '', branchname: 'All Branches');
}

class DebtorTransactionsPage extends StatefulWidget {
  const DebtorTransactionsPage({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.selectedDate,
    this.selectedBranch,
    this.contact,
    this.creditLimit,
  });

  final String customerId;
  final String customerName;
  final DateTimeRange? selectedDate;
  final String? selectedBranch;
  final String? contact;
  final String? creditLimit;

  @override
  State<DebtorTransactionsPage> createState() => _DebtorTransactionsPageState();
}

class _DebtorTransactionsPageState extends State<DebtorTransactionsPage> {
  static const List<double> _historyColumnWidths = [
    48,
    130,
    150,
    130,
    170,
    180,
    150,
  ];

  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
    context.read<Datafeed>().fetchDebtPaymentTransactions(
      selectedDate: widget.selectedDate,
      selectedBranch: widget.selectedBranch,
      customerId: widget.customerId,
    );
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _openingAmount(Map<String, dynamic> transaction) {
    return _amount(
      transaction['openingBalance'] ??
          transaction['openingbalance'] ??
          transaction['opening'],
    ).abs();
  }

  DateTime? _transactionDate(Map<String, dynamic> transaction) {
    final value =
        transaction['createdat'] ??
        transaction['createdAt'] ??
        transaction['date'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
    for (final format in ['dd-MM-yyyy', 'MM/dd/yyyy']) {
      final parsed = DateFormat(format).tryParse(text);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _dateLabel(Map<String, dynamic> transaction) {
    final parsed = _transactionDate(transaction);
    return parsed == null
        ? transaction['date']?.toString() ?? '-'
        : DateFormat.yMMMd().format(parsed);
  }

  Future<void> _runHistoryAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('History export failed: $error')));
    }
  }

  Future<void> _exportHistoryExcel(
    List<Map<String, dynamic>> transactions,
    String company,
  ) async {
    final excelFile = xls.Excel.createExcel();
    final sheet = excelFile['Debt Payment History'];
    sheet.appendRow([xls.TextCellValue(company)]);
    sheet.appendRow([
      xls.TextCellValue(
        'Customer: ${_DebtorReportState._capitalizeFirst(widget.customerName)}',
      ),
    ]);
    sheet.appendRow([
      xls.TextCellValue(
        widget.selectedDate == null
            ? 'Period: All dates'
            : 'Period: ${DateFormat('yyyy-MM-dd').format(widget.selectedDate!.start)}'
                  ' to ${DateFormat('yyyy-MM-dd').format(widget.selectedDate!.end)}',
      ),
    ]);
    sheet.appendRow([
      xls.TextCellValue('#'),
      xls.TextCellValue('Date'),
      xls.TextCellValue('Opening balance'),
      xls.TextCellValue('Amount'),
      xls.TextCellValue('Payment method'),
      xls.TextCellValue('Reference'),
      xls.TextCellValue('Staff'),
    ]);

    var totalOpening = 0.0;
    var totalAmount = 0.0;
    for (var index = 0; index < transactions.length; index++) {
      final transaction = transactions[index];
      final opening = _openingAmount(transaction);
      final amount = _amount(transaction['amount']);
      totalOpening += opening;
      totalAmount += amount;
      sheet.appendRow([
        xls.IntCellValue(index + 1),
        xls.TextCellValue(_dateLabel(transaction)),
        xls.DoubleCellValue(opening),
        xls.DoubleCellValue(amount),
        xls.TextCellValue(
          transaction['paymentmethod']?.toString() ??
              transaction['account']?.toString() ??
              '-',
        ),
        xls.TextCellValue(
          transaction['reference']?.toString() ??
              transaction['id']?.toString() ??
              '-',
        ),
        xls.TextCellValue(
          transaction['createdby']?.toString() ??
              transaction['staff']?.toString() ??
              '-',
        ),
      ]);
    }
    sheet.appendRow([
      xls.TextCellValue(''),
      xls.TextCellValue('TOTAL'),
      xls.DoubleCellValue(totalOpening),
      xls.DoubleCellValue(totalAmount),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
      xls.TextCellValue(''),
    ]);

    final bytes = excelFile.encode();
    if (bytes == null) {
      throw Exception('Failed to encode debt payment history as Excel.');
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await FileSaver.instance.saveFile(
      name: 'debt_payment_history_${widget.customerId}_$timestamp',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<Datafeed>(
      builder: (context, feed, _) {
        final transactions =
            List<Map<String, dynamic>>.of(feed.debtPaymentTransactions)
              ..sort((a, b) {
                final dateA = _transactionDate(a);
                final dateB = _transactionDate(b);
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateB.compareTo(dateA);
              });
        final totalOpening = transactions.fold<double>(
          0,
          (runningTotal, row) => runningTotal + _openingAmount(row),
        );
        final totalAmount = transactions.fold<double>(
          0,
          (runningTotal, row) => runningTotal + _amount(row['amount']),
        );

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            actions: [
              IconButton(
                tooltip: 'Print',
                onPressed:
                    transactions.isEmpty ||
                        feed.isLoadingDebtPaymentTransactions
                    ? null
                    : () => _runHistoryAction(
                        () => _DebtorReportState._printDetail(
                          transactions,
                          _DebtorReportState._capitalizeFirst(
                            widget.customerName,
                          ),
                          feed.company,
                          widget.contact,
                          widget.creditLimit,
                        ),
                      ),
                icon: const Icon(Icons.print_outlined),
              ),
              IconButton(
                tooltip: 'Save PDF',
                onPressed:
                    transactions.isEmpty ||
                        feed.isLoadingDebtPaymentTransactions
                    ? null
                    : () => _runHistoryAction(
                        () => _DebtorReportState._printDetail(
                          transactions,
                          _DebtorReportState._capitalizeFirst(
                            widget.customerName,
                          ),
                          feed.company,
                          widget.contact,
                          widget.creditLimit,
                          saveToFile: true,
                        ),
                      ),
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
              IconButton(
                tooltip: 'Export Excel',
                onPressed:
                    transactions.isEmpty ||
                        feed.isLoadingDebtPaymentTransactions
                    ? null
                    : () => _runHistoryAction(
                        () => _exportHistoryExcel(transactions, feed.company),
                      ),
                icon: const Icon(Icons.table_view_outlined),
              ),
            ],
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _DebtorReportState._capitalizeFirst(widget.customerName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Debt payments',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: feed.isLoadingDebtPaymentTransactions
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colorScheme.primary,
                        ),
                      )
                    : transactions.isEmpty
                    ? Center(
                        child: Text(
                          'No debt payment records found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const widths = _historyColumnWidths;
                          final gap =
                              ((constraints.maxWidth -
                                          widths.reduce((a, b) => a + b) -
                                          32) /
                                      (widths.length - 1))
                                  .clamp(4.0, 20.0)
                                  .toDouble();
                          final contentWidth =
                              widths.reduce((a, b) => a + b) +
                              (widths.length - 1) * gap +
                              32;
                          final tableWidth = constraints.maxWidth > contentWidth
                              ? constraints.maxWidth
                              : contentWidth;

                          Widget row(List<Widget> cells, {Color? color}) {
                            return Container(
                              color: color,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Row(
                                children: [
                                  for (
                                    var index = 0;
                                    index < cells.length;
                                    index++
                                  ) ...[
                                    SizedBox(
                                      width: widths[index],
                                      child: cells[index],
                                    ),
                                    if (index < cells.length - 1)
                                      SizedBox(width: gap),
                                  ],
                                ],
                              ),
                            );
                          }

                          final headers = [
                            '#',
                            'Date',
                            'Opening balance',
                            'Amount',
                            'Payment method',
                            'Reference',
                            'Staff',
                          ];

                          return Scrollbar(
                            controller: _horizontalController,
                            thumbVisibility: true,
                            notificationPredicate: (notification) =>
                                notification.depth == 1,
                            child: SingleChildScrollView(
                              controller: _horizontalController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: Column(
                                  children: [
                                    row(
                                      headers
                                          .map(
                                            (label) => Text(
                                              label,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color:
                                                        colorScheme.onSurface,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          )
                                          .toList(),
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                    ),
                                    Expanded(
                                      child: Scrollbar(
                                        controller: _verticalController,
                                        thumbVisibility: true,
                                        child: ListView.separated(
                                          controller: _verticalController,
                                          itemCount: transactions.length,
                                          separatorBuilder: (_, _) => Divider(
                                            height: 1,
                                            thickness: 1,
                                            color:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? colorScheme.outline
                                                : colorScheme.outlineVariant,
                                          ),
                                          itemBuilder: (context, index) {
                                            final transaction =
                                                transactions[index];
                                            final rowValues = [
                                              '${index + 1}',
                                              _dateLabel(transaction),
                                              _openingAmount(
                                                transaction,
                                              ).toStringAsFixed(2),
                                              _amount(
                                                transaction['amount'],
                                              ).toStringAsFixed(2),
                                              transaction['paymentmethod']
                                                      ?.toString() ??
                                                  transaction['account']
                                                      ?.toString() ??
                                                  '-',
                                              transaction['reference']
                                                      ?.toString() ??
                                                  transaction['id']
                                                      ?.toString() ??
                                                  '-',
                                              transaction['createdby']
                                                      ?.toString() ??
                                                  transaction['staff']
                                                      ?.toString() ??
                                                  '-',
                                            ];
                                            return row(
                                              rowValues
                                                  .map(
                                                    (value) => Text(
                                                      value,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .onSurface,
                                                          ),
                                                    ),
                                                  )
                                                  .toList(),
                                              color: colorScheme.surface,
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
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const widths = _historyColumnWidths;
                      final gap =
                          ((constraints.maxWidth -
                                      widths.reduce((a, b) => a + b)) /
                                  (widths.length - 1))
                              .clamp(4.0, 20.0)
                              .toDouble();
                      final rowWidth =
                          widths.reduce((a, b) => a + b) +
                          (widths.length - 1) * gap;
                      final cells = <Widget>[
                        const SizedBox.shrink(),
                        Text(
                          'TOTAL',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'GHS ${totalOpening.abs().toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'GHS ${totalAmount.abs().toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox.shrink(),
                        const SizedBox.shrink(),
                        const SizedBox.shrink(),
                      ];
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: rowWidth,
                          child: Row(
                            children: [
                              for (
                                var index = 0;
                                index < cells.length;
                                index++
                              ) ...[
                                SizedBox(
                                  width: widths[index],
                                  child: cells[index],
                                ),
                                if (index < cells.length - 1)
                                  SizedBox(width: gap),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
