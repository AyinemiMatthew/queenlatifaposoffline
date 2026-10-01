import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class ProfitAndLossPage extends StatefulWidget {
  const ProfitAndLossPage({super.key});

  @override
  State<ProfitAndLossPage> createState() => _ProfitAndLossPageState();
}

class _ProfitAndLossPageState extends State<ProfitAndLossPage> {
  DateTimeRange? selectedDate;
  String? selectedBranch;
  String searchQuery = '';

  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _mutedTextColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _backgroundColor =>
      _isLightTheme ? Colors.white : Theme.of(context).scaffoldBackgroundColor;
  Color get _panelColor =>
      _isLightTheme ? Colors.white : const Color(0xFF1E293B);
  Color get _cardColor =>
      _isLightTheme ? Colors.white : const Color(0xFF172133);
  Color get _tableHeaderColor =>
      _isLightTheme ? Colors.white : const Color(0xFF1B263B);
  Color get _tableRowColor =>
      _isLightTheme ? Colors.white : const Color(0xFF111E2F);
  Color get _fieldColor => _isLightTheme
      ? Colors.white
      : Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _borderColor => _isLightTheme
      ? Colors.grey.shade300
      : Colors.white.withValues(alpha: 0.08);
  Color get _tableDividerColor => _isLightTheme
      ? Colors.grey.shade300
      : Colors.white.withValues(alpha: 0.06);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchBranches();
      context.read<Datafeed>().fetchProfitAndLossReport(
        selectedDate: selectedDate,
        selectedBranch: selectedBranch,
      );
    });
  }

  String _formatCurrency(double value) =>
      NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2).format(value);

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, _) {
        final summary = value.profitAndLossSummary;
        final rows = value.profitAndLossRows;
        final filteredRows = rows.where((row) {
          final query = searchQuery.trim().toLowerCase();
          if (query.isEmpty) return true;
          final account = (row['account'] ?? '').toString().toLowerCase();
          final type = (row['type'] ?? '').toString().toLowerCase();
          final branch = (row['branchName'] ?? '').toString().toLowerCase();
          final description = (row['description'] ?? '')
              .toString()
              .toLowerCase();
          return account.contains(query) ||
              type.contains(query) ||
              branch.contains(query) ||
              description.contains(query);
        }).toList();

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            backgroundColor: _backgroundColor,
            foregroundColor: _textColor,
            title: const Text('Profit and Loss'),
            centerTitle: true,
            actions: [
              ReusableDatePickerWidget(
                onDateSelected: (selection) {
                  setState(() => selectedDate = selection);
                  value.fetchProfitAndLossReport(
                    selectedDate: selectedDate,
                    selectedBranch: selectedBranch,
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.calendar_today_rounded, size: 22),
                ),
              ),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _panelColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderColor),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedDate == null && selectedBranch == null
                                ? 'Overall P&L view (all branches, all dates)'
                                : 'Filtered P&L view',
                            style: TextStyle(
                              color: _mutedTextColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (selectedDate != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'Period: ${DateFormat.yMMMd().format(selectedDate!.start)} - ${DateFormat.yMMMd().format(selectedDate!.end)}',
                                style: TextStyle(
                                  color: _mutedTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 700;

                              final branchField =
                                  DropdownButtonFormField<String?>(
                                    value: selectedBranch,
                                    dropdownColor: _fieldColor,
                                    style: TextStyle(
                                      color: _textColor,
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Branch',
                                      labelStyle: TextStyle(
                                        color: _mutedTextColor,
                                        fontSize: 12,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _borderColor,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _borderColor,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: _fieldColor,
                                    ),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('All Branches'),
                                      ),
                                      ...value.branches.map(
                                        (branch) => DropdownMenuItem<String?>(
                                          value: branch.id,
                                          child: Text(branch.branchname),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      setState(() => selectedBranch = val);
                                      value.fetchProfitAndLossReport(
                                        selectedDate: selectedDate,
                                        selectedBranch: selectedBranch,
                                      );
                                    },
                                  );

                              final searchField = TextFormField(
                                initialValue: searchQuery,
                                onChanged: (val) =>
                                    setState(() => searchQuery = val),
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search account, type, branch or note',
                                  hintStyle: TextStyle(
                                    color: _mutedTextColor,
                                    fontSize: 12,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: _mutedTextColor,
                                    size: 18,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: _borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: _borderColor),
                                  ),
                                  filled: true,
                                  fillColor: _fieldColor,
                                ),
                              );

                              return isMobile
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        branchField,
                                        const SizedBox(height: 8),
                                        searchField,
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                selectedDate = null;
                                                selectedBranch = null;
                                                searchQuery = '';
                                              });
                                              value.fetchProfitAndLossReport(
                                                selectedDate: null,
                                                selectedBranch: null,
                                              );
                                            },
                                            icon: Icon(
                                              Icons.refresh_rounded,
                                              color: _mutedTextColor,
                                            ),
                                            label: Text(
                                              'Reset filters',
                                              style: TextStyle(
                                                color: _mutedTextColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(flex: 4, child: branchField),
                                        const SizedBox(width: 10),
                                        Expanded(flex: 6, child: searchField),
                                        const SizedBox(width: 10),
                                        TextButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              selectedDate = null;
                                              selectedBranch = null;
                                              searchQuery = '';
                                            });
                                            value.fetchProfitAndLossReport(
                                              selectedDate: null,
                                              selectedBranch: null,
                                            );
                                          },
                                          icon: Icon(
                                            Icons.refresh_rounded,
                                            color: _mutedTextColor,
                                          ),
                                          label: Text(
                                            'Reset',
                                            style: TextStyle(
                                              color: _mutedTextColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: value.isLoadingProfitAndLoss
                          ? Center(
                              child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : rows.isEmpty
                          ? Center(
                              child: Text(
                                'No P&L data found for the selected period.',
                                style: TextStyle(color: _mutedTextColor),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _summaryCard(
                                        'Sales Revenue',
                                        summary['salesRevenue'] ?? 0.0,
                                        Colors.greenAccent,
                                      ),
                                      _summaryCard(
                                        'Cost of Goods Sold',
                                        summary['costOfGoodsSold'] ?? 0.0,
                                        Colors.orangeAccent,
                                      ),
                                      _summaryCard(
                                        'Gross Profit',
                                        summary['grossProfit'] ?? 0.0,
                                        Colors.lightBlueAccent,
                                      ),
                                      _summaryCard(
                                        'Operating Expenses',
                                        summary['operatingExpenses'] ?? 0.0,
                                        Colors.redAccent,
                                      ),
                                      _summaryCard(
                                        'Net Profit',
                                        summary['netProfit'] ?? 0.0,
                                        Colors.tealAccent,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    filteredRows.isEmpty
                                        ? 'No entries match your current search.'
                                        : 'Showing ${filteredRows.length} of ${rows.length} entries',
                                    style: TextStyle(
                                      color: _mutedTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildResponsiveTable(filteredRows),
                                ],
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
    );
  }

  Widget _buildResponsiveTable(List<Map<String, dynamic>> data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;

        if (isCompact) {
          return Column(
            children: data.map((row) {
              final amount = (row['amount'] ?? 0.0) as double;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row['account']?.toString() ?? 'Unknown account',
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          _formatCurrency(amount),
                          style: TextStyle(
                            color: _readableAccent(Colors.tealAccent),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${row['accountType'] ?? 'Other'} - ${row['type']?.toString().toUpperCase() ?? 'N/A'}',
                      style: TextStyle(color: _mutedTextColor, fontSize: 12),
                    ),
                    if ((row['branchName'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Branch: ${row['branchName']}',
                        style: TextStyle(color: _mutedTextColor, fontSize: 12),
                      ),
                    ],
                    if ((row['description'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Note: ${row['description']}',
                        style: TextStyle(color: _mutedTextColor, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: _tableDividerColor),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_tableHeaderColor),
              dataRowColor: WidgetStateProperty.resolveWith(
                (_) => _tableRowColor,
              ),
              columnSpacing: 18,
              horizontalMargin: 8,
              headingTextStyle: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              dataTextStyle: TextStyle(color: _textColor, fontSize: 12),
              columns: const [
                DataColumn(label: Text('Account')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Category'), numeric: true),
                DataColumn(label: Text('Amount'), numeric: true),
                DataColumn(label: Text('Branch')),
                DataColumn(label: Text('Date')),
              ],
              rows: data.map((row) {
                final amount = (row['amount'] ?? 0.0) as double;
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          row['account']?.toString() ?? 'Unknown account',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(row['type']?.toString().toUpperCase() ?? 'N/A'),
                    ),
                    DataCell(Text(row['accountType']?.toString() ?? 'Other')),
                    DataCell(
                      Text(
                        _formatCurrency(amount),
                        style: TextStyle(
                          color: _readableAccent(Colors.tealAccent),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(Text(row['branchName']?.toString() ?? '-')),
                    DataCell(
                      Text(
                        (row['date'] ?? '').toString().isNotEmpty
                            ? DateFormat('yyyy-MM-dd').format(
                                DateTime.tryParse(row['date'].toString()) ??
                                    DateTime.now(),
                              )
                            : '-',
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard(String title, double value, Color accent) {
    return SizedBox(
      width: 180,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: _mutedTextColor, fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              _formatCurrency(value),
              style: TextStyle(
                color: _readableAccent(accent),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _readableAccent(Color accent) =>
      _isLightTheme ? Color.lerp(accent, Colors.black, 0.45)! : accent;
}
