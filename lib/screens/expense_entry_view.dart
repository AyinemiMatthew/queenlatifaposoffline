import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/appModuls.dart';
import 'package:kologsoft/models/expense_entry_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/screens/expense_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

class ExpenseEntryView extends StatefulWidget {
  const ExpenseEntryView({super.key});

  @override
  State<ExpenseEntryView> createState() => _ExpenseEntryViewState();
}

class _ExpenseEntryViewState extends State<ExpenseEntryView> {
  List<ExpenseEntryModel> expenseList = [];
  List<ExpenseEntryModel> _visibleExpenses = [];
  DateTimeRange? _selectedDateRange;

  final FirebaseFirestore db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  late Future<List<ExpenseEntryModel>> _expensesFuture;

  // ---- pagination state (NEW) ----
  int _page = 0;
  int _pageSize = 10;
  String _lastQuery = '';
  static const List<int> _pageSizes = [10, 25, 50, 100];

  Future<List<ExpenseEntryModel>> _getExpenses() async {
    final datafeed = context.read<Datafeed>();
    final snapshot = await db.collection('expenses').get();

    return snapshot.docs
        .map((doc) {
      final data = doc.data();
      data['id'] = (data['id'] ?? '').toString().isNotEmpty
          ? data['id']
          : doc.id;
      return ExpenseEntryModel.fromJson(data);
    })
        .where(
          (expense) =>
      expense.deletedby.isEmpty &&
          (datafeed.companyid.isEmpty ||
              expense.companyid == datafeed.companyid),
    )
        .toList()
      ..sort((a, b) {
        final aDate = a.expenseDate ?? a.date ?? DateTime(1900);
        final bDate = b.expenseDate ?? b.date ?? DateTime(1900);
        return bDate.compareTo(aDate); // Most recent first
      });
  }


  Future<void> getAll() async {
    try {
      final datafeed = context.read<Datafeed>();
      Query<Map<String, dynamic>> query = db
          .collection('expenses')
          .where('companyId', isEqualTo: datafeed.companyid);
      if (datafeed.accesslevel.toLowerCase() != 'super admin' &&
          datafeed.branchid.isNotEmpty) {
        query = query.where('branchId', isEqualTo: datafeed.branchid);
      }
      final news = await query.get();
      expenseList = news.docs.map((doc) {
        final data = doc.data();
        data['id'] = (data['id'] ?? '').toString().isNotEmpty
            ? data['id']
            : doc.id;
        return ExpenseEntryModel.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error loading expenses: $e');
    }
  }

  void _refreshExpenses() {
    setState(() {
      _expensesFuture = _getExpenses();
    });
  }

  @override
  void initState() {
    getAll();
    super.initState();
    _expensesFuture = _getExpenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(ExpenseEntryModel expense, String query) {
    if (query.isEmpty) {
      return true;
    }
    final normalized = query.toLowerCase();
    return expense.expenseName.toLowerCase().contains(normalized) ||
        expense.category.toLowerCase().contains(normalized) ||
        expense.vendorName.toLowerCase().contains(normalized) ||
        expense.description.toLowerCase().contains(normalized) ||
        expense.receiptNumber.toLowerCase().contains(normalized);
  }

  List<ExpenseEntryModel> _filterExpenses(List<ExpenseEntryModel> source) {
    final query = _searchController.text.trim();
    final filtered = source.where((expense) {
      final matchesQuery = _matchesSearch(expense, query);
      final expenseDate = expense.expenseDate ?? expense.date;
      final matchesDate =
          _selectedDateRange == null ||
              (expenseDate != null &&
                  !expenseDate.isBefore(_selectedDateRange!.start) &&
                  !expenseDate.isAfter(_selectedDateRange!.end));
      return matchesQuery && matchesDate;
    }).toList();

    filtered.sort((a, b) {
      final aDate = a.expenseDate ?? a.date ?? DateTime(1900);
      final bDate = b.expenseDate ?? b.date ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      initialEntryMode: DatePickerEntryMode.calendar,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.brightness == Brightness.dark
              ? theme
              : theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              surface: Colors.white,
            ),
            dialogTheme: theme.dialogTheme.copyWith(
              backgroundColor: Colors.white,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
              child: Material(color: Colors.transparent, child: child!),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _page = 0; // NEW: back to the first page
      });
    }
  }


  Future<void> _exportExpensesExcel(List<ExpenseEntryModel> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
      return;
    }
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Expenses'];
      excel.setDefaultSheet('Expenses');
      excel.delete('Sheet1');

      xl.CellValue t(String v) => xl.TextCellValue(v);
      xl.CellValue n(double v) => xl.DoubleCellValue(v);

      sheet.appendRow([
        t('Date'),
        t('Invoice No.'),
        t('Branch'),
        t('Expense Name'),
        t('Vendor'),
        t('Category'),
        t('Payment Method'),
        t('Payment Account'),
        t('Amount'),
        t('Receipt No.'),
        t('Description'),
      ]);

      double total = 0;
      for (final e in items) {
        final d = e.expenseDate ?? e.date ?? DateTime.now();
        total += e.amount;
        sheet.appendRow([
          t(DateFormat('dd/MM/yyyy').format(d)),
          t(e.createdAtTimestamp?.toString() ?? ''),
          t(e.expensebranchName),
          t(e.expenseName),
          t(e.vendorName),
          t(e.category),
          t(e.paymentMethod),
          t(e.subAccountName),
          n(e.amount),
          t(e.receiptNumber),
          t(e.description),
        ]);
      }
      sheet.appendRow([
        t(''), t(''), t(''), t(''), t(''), t(''), t(''),
        t('Total'),
        n(total),
      ]);

      final out = excel.encode();
      if (out == null) throw 'Could not build the Excel file';

      await FileSaver.instance.saveFile(
        name: 'expenses_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
        bytes: Uint8List.fromList(out),
        fileExtension: 'xlsx', // use `ext:` on file_saver 0.2.x
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel file saved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NEW: delete dialog moved out of the row so the 3-dot menu can call it.
  Future<void> _confirmAndDelete(
      ExpenseEntryModel expense,
      ColorScheme colors,
      bool isDark,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? colors.surface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Expense',
            style: TextStyle(color: colors.onSurface),
          ),
          content: Text(
            'Delete ${expense.expenseName}?',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteExpense(expense);
    }
  }

  // NEW: pagination footer used under both the table and the card list.
  Widget _expensePager({
    required int total,
    required int page,
    required ColorScheme colors,
    required Color panelHeaderColor,
    required Color secondaryTextColor,
  }) {
    final pages = total == 0 ? 1 : (total / _pageSize).ceil();
    final start = total == 0 ? 0 : page * _pageSize + 1;
    final end = total == 0 ? 0 : ((page + 1) * _pageSize).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: panelHeaderColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 2,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rows per page',
                style: TextStyle(color: secondaryTextColor, fontSize: 13),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _pageSize,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(12),
                items: _pageSizes
                    .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _pageSize = v;
                      _page = 0;
                    });
                  }
                },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$start-$end of $total',
                style: TextStyle(color: secondaryTextColor, fontSize: 13),
              ),
              IconButton(
                tooltip: 'First page',
                onPressed: page > 0 ? () => setState(() => _page = 0) : null,
                icon: const Icon(Icons.first_page_rounded),
              ),
              IconButton(
                tooltip: 'Previous',
                onPressed:
                page > 0 ? () => setState(() => _page = page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${page + 1} / $pages',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: page < pages - 1
                    ? () => setState(() => _page = page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              IconButton(
                tooltip: 'Last page',
                onPressed: page < pages - 1
                    ? () => setState(() => _page = pages - 1)
                    : null,
                icon: const Icon(Icons.last_page_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _printExpenses(List<ExpenseEntryModel> expenses) async {
    final datafeed = context.read<Datafeed>();

    final pdf = pw.Document();

    final totalAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);

    /// Group totals by category
    final Map<String, double> categoryTotals = {};

    for (final e in expenses) {
      categoryTotals.update(
        e.category,
            (value) => value + e.amount,
        ifAbsent: () => e.amount,
      );
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(30),
        footer: (context) {
          return pw.Column(
            children: [
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        header: (context) {
          return pw.Column(
            children: [
              pw.Text(
                datafeed.company,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'EXPENSE ENTRIES REPORT',
                  style: const pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.grey700,
                  ),
                ),
              ),

              pw.SizedBox(height: 15),
              pw.Divider(),
            ],
          );
        },
        build: (context) {
          return [

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Report:', 'Expense Entries'),
                    _infoRow('Records:', '${expenses.length}'),
                    _infoRow('Company:', datafeed.company),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Branch:', datafeed.branch),
                    _infoRow(
                      'Date:',
                      DateFormat('dd MMM yyyy').format(DateTime.now()),
                    ),
                    _infoRow('Staff:', datafeed.staff),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 25),

            /// =========================
            /// TABLE
            /// =========================
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: const [
                'Date',
                'Invoice',
                'Expense Name',
                'Vendor',
                'Category',
                //'Payment Method',
                'Payment Account',
                'Amount',
              ],
              data: expenses.map((e) {
                final expenseDate = e.expenseDate ?? e.date ?? DateTime.now();

                return [
                  DateFormat('dd/MM/yyyy').format(expenseDate),
                  e.createdAtTimestamp,
                  e.expenseName,
                  e.vendorName,
                  e.category,
                  //e.paymentMethod,
                  e.subAccountName,
                  NumberFormat.currency(symbol: 'GHS ').format(e.amount),
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 20),

            /// =========================
            /// TOTAL BOX
            /// =========================
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 280,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Records:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text('${expenses.length}'),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL:',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          NumberFormat.currency(
                            symbol: 'GHS ',
                          ).format(totalAmount),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Widget _buildExpenseCard(ExpenseEntryModel expense) {
    final expenseDate = expense.expenseDate ?? expense.date ?? DateTime.now();
    final datafeed = context.read<Datafeed>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final secondaryTextColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant;
    final cardColor = isDark ? const Color(0xFF223449) : Colors.white;
    final amountColor = isDark ? Colors.white : Colors.green.shade800;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  expense.expenseName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                NumberFormat.currency(symbol: '₵').format(expense.amount),
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Date: ${DateFormat('dd/MM/yyyy').format(expenseDate)}',
            style: TextStyle(color: secondaryTextColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Vendor: ${expense.vendorName}',
            style: TextStyle(color: secondaryTextColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Category: ${expense.category}',
            style: TextStyle(color: secondaryTextColor),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (datafeed.canEdit(AppModules.accounts))
                IconButton(
                  tooltip: 'Edit',
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  iconSize: 18,
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExpenseEntry(expense: expense),
                      ),
                    ).then((_) => _refreshExpenses());
                  },
                ),

              IconButton(
                tooltip: 'Print',
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                iconSize: 18,
                icon: Icon(Icons.print_outlined, color: secondaryTextColor),
                onPressed: () => _printExpenses([expense]),
              ),
              if (datafeed.canDelete(AppModules.accounts))
                IconButton(
                  tooltip: 'Delete',
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  iconSize: 18,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        final dialogTheme = Theme.of(context);
                        return AlertDialog(
                          backgroundColor:
                          dialogTheme.brightness == Brightness.dark
                              ? dialogTheme.colorScheme.surface
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            'Delete Expense',
                            style: TextStyle(
                              color: dialogTheme.brightness == Brightness.dark
                                  ? Colors.white
                                  : dialogTheme.colorScheme.onSurface,
                            ),
                          ),
                          content: Text(
                            'Delete ${expense.expenseName}?',
                            style: TextStyle(
                              color: dialogTheme.brightness == Brightness.dark
                                  ? Colors.white
                                  : dialogTheme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          actions: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor:
                                dialogTheme.brightness == Brightness.dark
                                    ? Colors.white
                                    : dialogTheme.colorScheme.primary,
                              ),
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirm == true) {
                      await _deleteExpense(expense);
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(ExpenseEntryModel expense) async {
    try {
      final datafeed = context.read<Datafeed>();
      expense.deletedby = datafeed.staff;
      expense.deletedat = DateTime.now();

      await db.collection('expenses').doc(expense.id).update({
        'deletedby': expense.deletedby,
        'deletedat': expense.deletedat?.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _refreshExpenses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printExpenseInvoice(ExpenseEntryModel expense) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              /// Company Name
              pw.Center(
                child: pw.Text(
                  expense.companyName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),

              pw.SizedBox(height: 5),

              pw.Center(
                child: pw.Text(
                  'EXPENSE ENTRY INVOICE',
                  style: const pw.TextStyle(
                    fontSize: 20,
                    color: PdfColors.grey700,
                  ),
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),

              /// Header information
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoRow(
                        'Invoice Number:',
                        expense.createdAtTimestamp?.toString() ?? '',
                      ),
                      _infoRow('Vendor:', expense.vendorName),
                      _infoRow('Payment:', expense.paymentMethod),
                    ],
                  ),

                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _infoRow('Branch:', expense.expensebranchName ?? expense.branchName),
                      _infoRow(
                        'Date:',
                        DateFormat('dd MMM yyyy').format(DateTime.now()),
                      ),
                      _infoRow('Staff:', expense.staff),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              /// Expense table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // Date
                  1: const pw.FlexColumnWidth(2), // Receipt
                  2: const pw.FlexColumnWidth(3), // Expense
                  3: const pw.FlexColumnWidth(3), // Category
                  4: const pw.FlexColumnWidth(3), // Account
                  5: const pw.FlexColumnWidth(3), // Amount
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _tableHeader('DATE'),
                      _tableHeader('RECEIPT'),
                      _tableHeader('EXPENSE'),
                      _tableHeader('CATEGORY'),
                      _tableHeader('PAYMENT ACCOUNT'),
                      _tableHeader('AMOUNT (GHS)'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableCell(
                        DateFormat('dd/MM/yyyy').format(
                          expense.expenseDate ?? expense.date ?? DateTime.now(),
                        ),
                      ),
                      _tableCell(expense.receiptNumber),
                      _tableCell(expense.expenseName),
                      _tableCell(expense.category),
                      _tableCell(expense.subAccountName),
                      _tableCell(
                        NumberFormat.currency(
                          symbol: ''
                        ).format(expense.amount),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              /// Description
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Description',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(expense.description),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              /// Total box
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 250,
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Expenses:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text('1'),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL:',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.Text(
                            NumberFormat.currency(
                              symbol: 'GHS ',
                            ).format(expense.amount),
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              pw.Divider(),

              pw.Text(
                'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : colors.onSurface;
    final secondaryTextColor = isDark ? Colors.white : colors.onSurfaceVariant;
    final screenColor = isDark ? const Color(0xFF101624) : Colors.white;
    final panelColor = isDark ? const Color(0xFF182232) : Colors.white;
    final panelHeaderColor = isDark ? const Color(0xFF223449) : Colors.white;
    final actionBackgroundColor = isDark
        ? const Color(0xFF22304A)
        : colors.surfaceContainerHighest;
    final amountColor = isDark ? Colors.white : Colors.green.shade800;
    // NEW: stripe colour for alternate rows
    final stripeColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : colors.primary.withValues(alpha: 0.05);

    return Scaffold(
      backgroundColor: screenColor,
      appBar: AppBar(
        title: const Text("EXPENSE ENTRIES"),
        backgroundColor: isDark ? const Color(0xFF1B263B) : Colors.white,
        foregroundColor: textColor,
        iconTheme: IconThemeData(color: textColor),
      ),

      body: FutureBuilder<List<ExpenseEntryModel>>(
        future: _expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: TextStyle(color: isDark ? Colors.white : colors.error),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: secondaryTextColor),
                  const SizedBox(height: 16),
                  Text(
                    "No expenses found.",
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ExpenseEntry()),
                      ).then((_) => _refreshExpenses());
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add Expense"),
                  ),
                ],
              ),
            );
          }

          final expenses = snapshot.data!;

          double amount = expenses.fold(
            0,
                (total, expense) => total + expense.amount,
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: textColor),
                            cursorColor: colors.primary,
                            decoration: InputDecoration(
                              hintText:
                              "Search expenses by name, category, vendor...",
                              hintStyle: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 12,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: secondaryTextColor,
                              ),
                              filled: true,
                              fillColor: panelColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colors.outlineVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Filter by date',
                          style: IconButton.styleFrom(
                            foregroundColor: textColor,
                            backgroundColor: _selectedDateRange != null
                                ? Colors.blue.shade800.withValues(alpha: 0.45)
                                : actionBackgroundColor,
                            disabledForegroundColor: colors.onSurface
                                .withValues(alpha: 0.38),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                          ),
                          icon: const Icon(Icons.calendar_month),
                          onPressed: _pickDateRange,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Print expenses',
                          style: IconButton.styleFrom(
                            foregroundColor: textColor,
                            backgroundColor: actionBackgroundColor,
                            disabledForegroundColor: colors.onSurface
                                .withValues(alpha: 0.38),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                          ),
                          icon: const Icon(Icons.print_outlined),
                          onPressed: () => _printExpenses(_visibleExpenses),
                        ),
                        // NEW: Excel download button
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Download Excel',
                          style: IconButton.styleFrom(
                            foregroundColor: textColor,
                            backgroundColor: actionBackgroundColor,
                            disabledForegroundColor: colors.onSurface
                                .withValues(alpha: 0.38),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                          ),
                          icon: const Icon(Icons.table_chart_outlined),
                          onPressed: () =>
                              _exportExpensesExcel(_visibleExpenses),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade700, Colors.blue.shade900],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Total Expenses",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              NumberFormat.currency(symbol: '₵').format(amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${expenses.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedDateRange != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filtered from ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} to ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedDateRange = null;
                                _page = 0; // NEW
                              });
                            },
                            child: Text(
                              'Clear filter',
                              style: TextStyle(
                                color: isDark ? Colors.white : colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        // NEW: a new search always starts from page 1
                        final currentQuery = _searchController.text.trim();
                        if (currentQuery != _lastQuery) {
                          _lastQuery = currentQuery;
                          _page = 0;
                        }

                        final filtered = _filterExpenses(expenses);
                        _visibleExpenses = filtered;

                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              "No matching expense found.",
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }

                        // NEW: pagination over the filtered list
                        final totalPages = (filtered.length / _pageSize).ceil();
                        final page = totalPages == 0
                            ? 0
                            : (_page > totalPages - 1 ? totalPages - 1 : _page);
                        final pageItems = filtered
                            .skip(page * _pageSize)
                            .take(_pageSize)
                            .toList();
                        final pager = _expensePager(
                          total: filtered.length,
                          page: page,
                          colors: colors,
                          panelHeaderColor: panelHeaderColor,
                          secondaryTextColor: secondaryTextColor,
                        );

                        Widget headCell(String label, int flex) => Expanded(
                          flex: flex,
                          child: Text(
                            label,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );

                        Widget bodyCell(
                            String text,
                            int flex, {
                              Color? color,
                              FontWeight? weight,
                            }) =>
                            Expanded(
                              flex: flex,
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: color ?? secondaryTextColor,
                                  fontWeight: weight,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: panelColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.outlineVariant),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final useCards = constraints.maxWidth < 700;
                                final datafeed = context.read<Datafeed>();

                                if (useCards) {
                                  return Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: panelHeaderColor,
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(12),
                                          ),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: colors.outlineVariant,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Expense Entries',
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Card view',
                                              style: TextStyle(
                                                color: secondaryTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView.separated(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          itemCount: pageItems.length,
                                          separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                            return _buildExpenseCard(
                                              pageItems[index],
                                            );
                                          },
                                        ),
                                      ),
                                      pager,
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    // ---------------- Table header ----------------
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: panelHeaderColor,
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(12),
                                        ),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: colors.outlineVariant,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          headCell('Date', 3),
                                          headCell('Invoice No.', 3),
                                          headCell('Branch', 3),
                                          headCell('Expense Name', 3),
                                          headCell('Vendor', 3),
                                          headCell('Category', 3),
                                          headCell('Payment Method', 2),
                                          headCell('Payment Account', 2),
                                          headCell('Amount (GHS)', 2),
                                          SizedBox(
                                            width: 56,
                                            child: Text(
                                              'Actions',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ---------------- Striped rows (this page) ----------------
                                    Expanded(
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        itemCount: pageItems.length,
                                        separatorBuilder: (_, __) => Divider(
                                          height: 1,
                                          color: colors.outlineVariant,
                                        ),
                                        itemBuilder: (context, index) {
                                          final expense = pageItems[index];
                                          final expenseDate =
                                              expense.expenseDate ??
                                                  expense.date ??
                                                  DateTime.now();

                                          return Container(
                                            color: index.isEven
                                                ? Colors.transparent
                                                : stripeColor,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                              children: [
                                                bodyCell(
                                                  DateFormat(
                                                    'dd/MM/yyyy',
                                                  ).format(expenseDate),
                                                  3,
                                                ),
                                                bodyCell(
                                                  expense.createdAtTimestamp
                                                      ?.toString() ??
                                                      '',
                                                  3,
                                                  color: textColor,
                                                ),
                                                bodyCell(
                                                  expense.expensebranchName,
                                                  3,
                                                  color: textColor,
                                                ),
                                                bodyCell(
                                                  expense.expenseName,
                                                  3,
                                                  color: textColor,
                                                ),
                                                bodyCell(expense.vendorName, 3),
                                                bodyCell(expense.category, 3),
                                                bodyCell(
                                                  expense.paymentMethod,
                                                  2,
                                                ),
                                                bodyCell(
                                                  expense.subAccountName,
                                                  2,
                                                ),
                                                bodyCell(
                                                  NumberFormat.currency(
                                                    symbol: '',
                                                  ).format(expense.amount),
                                                  2,
                                                  color: amountColor,
                                                  weight: FontWeight.bold,
                                                ),

                                                // ---------------- 3-dot actions menu ----------------
                                                SizedBox(
                                                  width: 56,
                                                  child: Center(
                                                    child: PopupMenuButton<String>(
                                                      tooltip: 'Actions',
                                                      icon: Icon(
                                                        Icons.more_vert,
                                                        color:
                                                        secondaryTextColor,
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      shape:
                                                      RoundedRectangleBorder(
                                                        borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                      ),
                                                      onSelected: (value) async {
                                                        switch (value) {
                                                          case 'edit':
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (_) =>
                                                                    ExpenseEntry(
                                                                      expense:
                                                                      expense,
                                                                    ),
                                                              ),
                                                            ).then(
                                                                  (_) =>
                                                                  _refreshExpenses(),
                                                            );
                                                            break;
                                                          case 'delete':
                                                            await _confirmAndDelete(
                                                              expense,
                                                              colors,
                                                              isDark,
                                                            );
                                                            break;
                                                          case 'print':
                                                            _printExpenseInvoice(
                                                              expense,
                                                            );
                                                            break;
                                                        }
                                                      },
                                                      itemBuilder: (_) => [
                                                        if (datafeed.canEdit(
                                                          AppModules.accounts,
                                                        ))
                                                          const PopupMenuItem<
                                                              String
                                                          >(
                                                            value: 'edit',
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.edit,
                                                                  color: Colors
                                                                      .orange,
                                                                  size: 18,
                                                                ),
                                                                SizedBox(
                                                                  width: 10,
                                                                ),
                                                                Text('Edit'),
                                                              ],
                                                            ),
                                                          ),
                                                        if (datafeed.canDelete(
                                                          AppModules.accounts,
                                                        ))
                                                          const PopupMenuItem<
                                                              String
                                                          >(
                                                            value: 'delete',
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .delete_forever,
                                                                  color:
                                                                  Colors.red,
                                                                  size: 18,
                                                                ),
                                                                SizedBox(
                                                                  width: 10,
                                                                ),
                                                                Text('Delete'),
                                                              ],
                                                            ),
                                                          ),
                                                        const PopupMenuItem<
                                                            String
                                                        >(
                                                          value: 'print',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .print_outlined,
                                                                size: 18,
                                                              ),
                                                              SizedBox(
                                                                width: 10,
                                                              ),
                                                              Text('Print'),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                    // ---------------- Pagination footer ----------------
                                    pager,
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
pw.Widget _infoRow(String title, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$title ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: value),
        ],
      ),
    ),
  );
}

pw.Widget _tableHeader(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue900,
      ),
    ),
  );
}

pw.Widget _tableCell(String text) {
  return pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(text));
}
