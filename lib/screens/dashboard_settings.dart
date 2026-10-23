import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../providers/routes.dart';

class DashboardSettings extends StatelessWidget {
  const DashboardSettings({super.key});

  Future<void> _selectMonth(BuildContext context, Datafeed datafeed) async {
    var selectedYear = datafeed.dashboardMonth.year;
    var selectedMonth = datafeed.dashboardMonth.month;
    final currentYear = DateTime.now().year;
    final monthNames = List.generate(
      12,
      (index) => DateFormat('MMMM').format(DateTime(2026, index + 1)),
    );
    final month = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select summary month'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedYear,
                decoration: const InputDecoration(labelText: 'Year'),
                items: [
                  for (var year = 2000; year <= currentYear; year++)
                    DropdownMenuItem(value: year, child: Text('$year')),
                ],
                onChanged: (year) {
                  if (year == null) return;
                  setDialogState(() {
                    selectedYear = year;
                    if (selectedYear == currentYear &&
                        selectedMonth > DateTime.now().month) {
                      selectedMonth = DateTime.now().month;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedMonth,
                decoration: const InputDecoration(labelText: 'Month'),
                items: [
                  for (
                    var monthNumber = 1;
                    monthNumber <=
                        (selectedYear == currentYear
                            ? DateTime.now().month
                            : 12);
                    monthNumber++
                  )
                    DropdownMenuItem(
                      value: monthNumber,
                      child: Text(monthNames[monthNumber - 1]),
                    ),
                ],
                onChanged: (monthNumber) {
                  if (monthNumber != null) {
                    setDialogState(() => selectedMonth = monthNumber);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(DateTime(selectedYear, selectedMonth)),
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
    if (month == null || !context.mounted) return;

    try {
      await datafeed.setDashboardMonth(month);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save dashboard month: $error')),
      );
    }
  }

  Future<void> _savePeriod(
    BuildContext context,
    Datafeed datafeed,
    String period,
  ) async {
    try {
      await datafeed.setDashboardPeriod(period);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save dashboard period: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final darkMode = theme.brightness == Brightness.dark;
    final activeThumbColor = darkMode ? Colors.greenAccent : null;
    final activeTrackColor = darkMode ? Colors.green.shade700 : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Settings')),
      body: Consumer<Datafeed>(
        builder: (context, datafeed, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistics period',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All Time shows cumulative totals. Yearly uses the calendar year. '
                      'Weekly runs Monday through Sunday. Monthly lets you select a month.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: datafeed.dashboardPeriod,
                      decoration: const InputDecoration(
                        labelText: 'Dashboard period',
                        border: OutlineInputBorder(),
                      ),
                      items: Datafeed.dashboardPeriods
                          .map(
                            (period) => DropdownMenuItem(
                              value: period,
                              child: Text(
                                period == 'all-time'
                                    ? 'All Time'
                                    : '${period[0].toUpperCase()}${period.substring(1)}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (period) {
                        if (period != null) {
                          _savePeriod(context, datafeed, period);
                        }
                      },
                    ),
                    if (datafeed.dashboardPeriod == 'monthly') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _selectMonth(context, datafeed),
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          'Summary month: ${datafeed.dashboardPeriodLabel}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.tune, color: colors.onSurface),
                    title: Text(
                      'Set Reorder Level',
                      style: TextStyle(color: colors.onSurface),
                    ),
                    subtitle: Text(
                      'Current: ${datafeed.reorderLevel.toStringAsFixed(0)}',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    onTap: () =>
                        Navigator.pushNamed(context, Routes.reordercount),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.redeem),
                    title: const Text('Enable Bundle / Hamper'),
                    value: datafeed.hamperEnabled,
                    activeThumbColor: activeThumbColor,
                    activeTrackColor: activeTrackColor,
                    onChanged: datafeed.toggleHamper,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.rule),
                    title: const Text('Enable Stock Check'),
                    value: datafeed.stockCheckEnabled,
                    activeThumbColor: activeThumbColor,
                    activeTrackColor: activeTrackColor,
                    onChanged: datafeed.toggleStockCheck,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.confirmation_number),
                    title: const Text('Enable Receipt Numbering'),
                    subtitle: const Text('Numbers restart at 1 each day'),
                    value: datafeed.receiptNumberingEnabled,
                    activeThumbColor: activeThumbColor,
                    activeTrackColor: activeTrackColor,
                    onChanged: datafeed.toggleReceiptNumbering,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
