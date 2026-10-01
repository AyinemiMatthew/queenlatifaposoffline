import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/screens/transfers.dart';
import 'package:provider/provider.dart';
import 'package:kologsoft/screens/transferinvoice.dart';

import '../constants/constants.dart';
import '../models/appModuls.dart';
import '../providers/Datafeed.dart';
import '../providers/StockProvider.dart';


import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class StockTransferDetails extends StatefulWidget {
  const StockTransferDetails({super.key});

  @override
  State<StockTransferDetails> createState() => _StockTransferDetailsState();
}

class _StockTransferDetailsState extends State<StockTransferDetails> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String searchQuery = "";
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeActive = false;

  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _secondaryTextColor => _textColor.withOpacity(0.7);
  Color get _mutedTextColor => _textColor.withOpacity(0.54);
  Color get _subtleTextColor => _textColor.withOpacity(0.3);
  Color get _dividerColor => _textColor.withOpacity(0.24);
  Color get _borderColor => _textColor.withOpacity(0.1);
  Color get _surfaceColor => _isDarkMode
      ? const Color(0xFF22304A)
      : Theme.of(context).colorScheme.surface;
  Color get _cardColor => _isDarkMode
      ? const Color(0xFF1B263B)
      : Theme.of(context).colorScheme.surface;
  Color get _alternateCardColor => _isDarkMode
      ? const Color(0xFF0D1B2A)
      : Theme.of(context).colorScheme.surfaceContainerHighest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<StockProvider>(context, listen: false);
      await provider.getdata();
    });
  }

  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  Future<void> _showDateRangePicker() async {
    final DateTime? start = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        if (theme.brightness != Brightness.dark) return child!;
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: Colors.blue,
              onPrimary: _textColor,
              surface: const Color(0xFF22304A),
              onSurface: _textColor,
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
          final theme = Theme.of(context);
          if (theme.brightness != Brightness.dark) return child!;
          return Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: Colors.blue,
                onPrimary: _textColor,
                surface: const Color(0xFF22304A),
                onSurface: _textColor,
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
      }
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isDateRangeActive = false;
    });
  }

  String _generateTransferId(Map<String, dynamic> data, int index) {
    final date = data['createdat']?.toDate() ?? DateTime.now();
    final id = data['docid']?.toString().substring(0, 6) ?? '${index + 1}';
    return 'TRF-${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}${index + 1}';
  }

  List<Widget> _buildAppBarActions() {
    final stock = Provider.of<StockProvider>(context);
    final actions = <Widget>[
      IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isDateRangeActive
                ? Colors.blue.shade800.withOpacity(0.3)
                : _textColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.calendar_month,
            color: _isDateRangeActive
                ? (_isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700)
                : _secondaryTextColor,
          ),
        ),
        onPressed: _showDateRangePicker,
        tooltip: 'Filter by date range',
      ),
      IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _textColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.refresh, color: _secondaryTextColor),
        ),
        onPressed: stock.subscribePendingRequests,
        tooltip: 'Refresh',
      ),
      const SizedBox(width: 8),
    ];

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode
          ? const Color(0xFF101624)
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Stock Transfer"),
        actions: _buildAppBarActions(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF415A77),
        child: Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewTransfer()),
          );
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  child: TextFormField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      fillColor: _surfaceColor,
                      hintText: 'Search transfers...',
                      hintStyle: TextStyle(color: _mutedTextColor),
                      prefixIcon: Icon(Icons.search, color: _mutedTextColor),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: _mutedTextColor),
                        onPressed: () {
                          setState(() {
                            searchQuery = "";
                          });
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ),
              ),

              // Date Range Badge
              if (_startDate != null && _endDate != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isDarkMode
                        ? Colors.blue.shade900.withOpacity(0.3)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isDarkMode
                          ? Colors.blue.shade700.withOpacity(0.3)
                          : Colors.blue.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.date_range, size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}',
                        style: TextStyle(
                          color: _isDarkMode ? _textColor : Colors.blue.shade900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _clearDateRange,
                        child: Icon(Icons.close, size: 14, color: Colors.blue),
                      ),
                    ],
                  ),
                ),

              // List/Table View
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: Provider.of<StockProvider>(context, listen: false).stockStream(
                    collectionName: 'stock_transfer',
                    startDate: _isDateRangeActive ? _startDate : null,
                    endDate: _isDateRangeActive ? _endDate : null,
                    branchfield: 'staffbranchid', datefield: 'transferdate',
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          "No transfers yet",
                          style: TextStyle(color: _secondaryTextColor),
                        ),
                      );
                    }

                    final allDocs = snapshot.data!;

                    final filteredDocs = allDocs.where((doc) {
                      return doc.values.any((value) {
                        if (value == null) return false;
                        return value.toString().toLowerCase().contains(searchQuery);
                      });
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Text(
                          searchQuery.isEmpty
                              ? "No transfers available"
                              : "No transfers found matching '$searchQuery'",
                          style: TextStyle(color: _secondaryTextColor),
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 800;
                        return isMobile
                            ? ListView.builder(
                          controller: verticalController,
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final data = filteredDocs[index];
                            final dynamic rawTransferId = data['transferid'];

                            final String transferId;

                            if (rawTransferId is String && rawTransferId.isNotEmpty) {
                              transferId = rawTransferId;
                            } else if (rawTransferId is Timestamp) {
                              transferId = rawTransferId.millisecondsSinceEpoch.toString();
                            } else {
                              transferId = _generateTransferId(data, index);
                            }
                            final fromBranch = data['supplywarehousename'] ?? 'N/A';
                            final toBranch = data['recievebranchname'] ?? 'N/A';
                            final status = data['status']?.toLowerCase() ?? 'completed';

                            // Calculate stock value
                            double stockValue = 0;
                            final rawItems = data['items'];
                            List<Map<String, dynamic>> items = [];

                            if (rawItems is List) {
                              items = rawItems.map((e) => Map<String, dynamic>.from(e)).toList();
                              stockValue = items.fold(0, (sum, item) => sum + (item['total'] ?? 0));
                            } else if (rawItems is Map) {
                              items = rawItems.entries.map((entry) {
                                return {
                                  'key': entry.key,
                                  ...Map<String, dynamic>.from(entry.value),
                                };
                              }).toList();
                              stockValue = items.fold(0, (sum, item) => sum + (item['total'] ?? 0));
                            }
                            final value= Provider.of<Datafeed>(context, listen: false);

                            return Card(
                              color: index.isEven
                                  ? _alternateCardColor
                                  : _cardColor,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Transfer ID and Status
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.blueGrey,
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: _textColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          transferId,
                                          style: TextStyle(
                                            color: _isDarkMode
                                                ? Colors.blueAccent
                                                : Colors.blue.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'pending'
                                                ? Colors.orange.shade900.withOpacity(0.3)
                                                : Colors.green.shade900.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              color: status == 'pending'
                                                  ? (_isDarkMode
                                                      ? Colors.orange
                                                      : Colors.orange.shade800)
                                                  : (_isDarkMode
                                                      ? Colors.green
                                                      : Colors.green.shade700),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // Transfer Branch → Receiving Branch
                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        "Transfer Branch",
                                        style: TextStyle(
                                          color: _mutedTextColor,
                                        ),
                                      ),
                                      subtitle: Text(
                                        fromBranch,
                                        style: TextStyle(
                                          color: _textColor,
                                        ),
                                      ),
                                    ),

                                    ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        "Receiving Branch",
                                        style: TextStyle(
                                          color: _mutedTextColor,
                                        ),
                                      ),
                                      subtitle: Text(
                                        toBranch,
                                        style: TextStyle(
                                          color: _textColor,
                                        ),
                                      ),
                                    ),

                                    // Date and Staff
                                    Text(
                                      "Entry Date: ${data['createdat']?.toDate().toString().substring(0, 10) ?? 'N/A'}",
                                      style: TextStyle(
                                        color: _secondaryTextColor,
                                      ),
                                    ),
                                    Text(
                                      "Date: ${data['transferdate']?.toDate().toString().substring(0, 10) ?? 'N/A'}",
                                      style: TextStyle(
                                        color: _secondaryTextColor,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      "Staff: ${data['createdby']?.toString() ?? 'N/A'}",
                                      style: TextStyle(
                                        color: _textColor,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    // Stock Value
                                    Text(
                                      "Stock Value: GHS ${stockValue.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        color: _isDarkMode
                                            ? Colors.greenAccent
                                            : Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    Divider(
                                      color: _dividerColor,
                                    ),

                                    // Action Buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.visibility,
                                            color: _isDarkMode
                                                ? Colors.tealAccent
                                                : Colors.teal.shade700,
                                          ),
                                          onPressed: () {
                                            _showTransferDetails(context, data, items, transferId);
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.print,
                                            color: Colors.blueGrey,
                                          ),
                                          onPressed: () async {
                                            try {
                                              await generateInvoicePdf(data,items);
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text("Error generating PDF: $e"),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                        if (status == 'pending') ...[
                                          if(value.canEdit(AppModules.stock))
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit,
                                              color: Colors.amber,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => NewTransfer(
                                                    docId: data['docid'],
                                                    data: data,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          if(value.canDelete(AppModules.stock))
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  backgroundColor: _cardColor,
                                                  title: Text(
                                                    "Delete Transfer Invoice",
                                                    style: TextStyle(color: _textColor),
                                                  ),
                                                  content: Text(
                                                    "Are you sure you want to delete this transfer invoice?",
                                                    style: TextStyle(color: _secondaryTextColor),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: Text(
                                                        "Cancel",
                                                        style: TextStyle(color: _mutedTextColor),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.redAccent,
                                                      ),
                                                      child: Text("Delete"),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                LoadingDialog.show(
                                                  context,
                                                  message: "Please wait...",
                                                );

                                                try {
                                                  final stockProvider = context.read<StockProvider>();
                                                  final insufficientItems = <String>[];

                                                  for (final item in items) {
                                                    final itemId = (item['itemid'] ?? '').toString();
                                                    final itemName = (item['item'] ?? '').toString();

                                                    final piecesToReverse =
                                                        (item['pieces'] as num?)?.toDouble() ?? 0;

                                                    final availableBalance =
                                                    await stockProvider.fetchItemCurrentBalance(
                                                      itemId: itemId,
                                                      selectedBranch: data['recievebranchid'],
                                                    );

                                                    if (availableBalance < piecesToReverse) {
                                                      insufficientItems.add(
                                                        '$itemName\n'
                                                            'Available: ${availableBalance.toInt()} pcs\n'
                                                            'Required: ${piecesToReverse.toInt()} pcs',
                                                      );
                                                    }
                                                  }

                                                  if (insufficientItems.isNotEmpty) {
                                                    if (!context.mounted) return;
                                                    LoadingDialog.hide();
                                                    await showDialog(
                                                      context: context,
                                                      builder: (_) => AlertDialog(
                                                        title: Text("Cannot Delete Transfer"),
                                                        content: SingleChildScrollView(
                                                          child: Text(
                                                            "The following items no longer have enough stock in "
                                                                "${data['recievebranchname']} to reverse this transfer:\n\n"
                                                                "${insufficientItems.join('\n\n')}",
                                                          ),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context),
                                                            child: Text(
                                                              "OK",
                                                              style: TextStyle(
                                                                color: _textColor,
                                                              ),
                                                            ),
                                                          ),                                                        ],
                                                      ),
                                                    );

                                                    return;
                                                  }

                                                  await db.runTransaction((transaction) async {
                                                    final transferRef =
                                                    db.collection('stock_transfer').doc(data['docid']);

                                                    final transferSnap = await transaction.get(transferRef);

                                                    if (!transferSnap.exists) {
                                                      throw Exception("Transfer not found");
                                                    }

                                                    final transferData = transferSnap.data()!;

                                                    final deletedRef = db
                                                        .collection('deletedstock')
                                                        .doc('${data['docid']}_${DateTime.now().millisecondsSinceEpoch}'); // or use a timestamp if you want multiple copies

                                                    final archiveData = Map<String, dynamic>.from(transferData);

                                                    archiveData.addAll({
                                                      'deletedat': FieldValue.serverTimestamp(),
                                                      'deletedby': context.read<Datafeed>().staff,
                                                      'deletetype': 'stocktransfer',
                                                      'reason': 'Deleted Stock Transfer',
                                                      'originaldocid': data['docid'],
                                                    });

                                                    // Archive
                                                    transaction.set(deletedRef, archiveData);

                                                    // Delete original
                                                    transaction.delete(transferRef);
                                                  });
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text("Stock transfer deleted successfully"),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text("Failed to delete transfer: $e"),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                } finally {
                                                  if (context.mounted) {
                                                    LoadingDialog.hide();
                                                  }
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                            : Scrollbar(
                          controller: verticalController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: SingleChildScrollView(
                            controller: verticalController,
                            scrollDirection: Axis.vertical,
                            child: Scrollbar(
                              controller: horizontalController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              notificationPredicate: (_) => true,
                              child: SingleChildScrollView(
                                controller: horizontalController,
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: isMobile ? 800 : constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      _cardColor,
                                    ),
                                    columnSpacing: 10,
                                    headingTextStyle: TextStyle(
                                      color: _textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    dataTextStyle: TextStyle(
                                      color: _textColor,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('#')),
                                      DataColumn(label: Text('Transfer ID')),
                                      DataColumn(label: Text('From Branch')),
                                      DataColumn(label: Text('To Branch')),
                                      DataColumn(label: Text('Entry Date')),
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Staff')),
                                      //DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Stock Value')),
                                      DataColumn(label: Text('Action')),
                                    ],
                                    rows: List.generate(filteredDocs.length, (index) {
                                      final data = filteredDocs[index];
                                      final dynamic rawTransferId = data['transferid'];

                                      final String transferId;

                                      if (rawTransferId is String && rawTransferId.isNotEmpty) {
                                        transferId = rawTransferId;
                                      } else if (rawTransferId is Timestamp) {
                                        transferId = rawTransferId.millisecondsSinceEpoch.toString();
                                      } else {
                                        transferId = _generateTransferId(data, index);
                                      }
                                      final fromBranch = data['supplywarehousename'] ?? 'N/A';
                                      final toBranch = data['recievebranchname'] ?? 'N/A';
                                      final status = data['status']?.toLowerCase() ?? 'completed';

                                      // Calculate stock value
                                      double stockValue = 0;
                                      final rawItems = data['items'];
                                      List<Map<String, dynamic>> items = [];

                                      if (rawItems is List) {
                                        items = rawItems.map((e) => Map<String, dynamic>.from(e)).toList();
                                        stockValue = items.fold(0, (sum, item) => sum + (item['total'] ?? 0));
                                      } else if (rawItems is Map) {
                                        items = rawItems.entries.map((entry) {
                                          return {
                                            'key': entry.key,
                                            ...Map<String, dynamic>.from(entry.value),
                                          };
                                        }).toList();
                                        stockValue = items.fold(0, (sum, item) => sum + (item['total'] ?? 0));
                                      }
                                      final value= Provider.of<Datafeed>(context, listen: false);

                                      return DataRow(
                                        color: WidgetStateProperty.resolveWith<Color?>(
                                              (Set<WidgetState> states) {
                                            return index.isEven
                                                ? _alternateCardColor
                                                : _cardColor;
                                          },
                                        ),
                                        cells: [
                                          DataCell(Text('${index + 1}')),
                                          DataCell(
                                            Text(
                                              transferId,
                                              style: TextStyle(
                                                color: _isDarkMode
                                                    ? Colors.blueAccent
                                                    : Colors.blue.shade800,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(fromBranch)),
                                          DataCell(Text(toBranch)),
                                          DataCell(
                                            Text(
                                              data['createdat']?.toDate().toString().substring(0, 10) ?? 'N/A',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              data['transferdate']?.toDate().toString().substring(0, 10) ?? 'N/A',
                                            ),
                                          ),
                                          DataCell(
                                            Text(data['createdby']?.toString() ?? 'N/A'),
                                          ),
                                          // DataCell(
                                          //   Container(
                                          //     padding: const EdgeInsets.symmetric(
                                          //       horizontal: 8,
                                          //       vertical: 4,
                                          //     ),
                                          //     decoration: BoxDecoration(
                                          //       color: status == 'pending'
                                          //           ? Colors.orange.shade900.withOpacity(0.3)
                                          //           : Colors.green.shade900.withOpacity(0.3),
                                          //       borderRadius: BorderRadius.circular(4),
                                          //     ),
                                          //     child: Text(
                                          //       status.toUpperCase(),
                                          //       style: TextStyle(
                                          //         color: status == 'pending' ? Colors.orange : Colors.green,
                                          //         fontSize: 10,
                                          //         fontWeight: FontWeight.bold,
                                          //       ),
                                          //     ),
                                          //   ),
                                          // ),
                                          DataCell(
                                            Text(
                                              "GHS ${stockValue.toStringAsFixed(2)}",
                                              style: TextStyle(
                                                color: _isDarkMode
                                                    ? Colors.greenAccent
                                                    : Colors.green.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.visibility,
                                                    color: _isDarkMode
                                                        ? Colors.tealAccent
                                                        : Colors.teal.shade700,
                                                    size: 20,
                                                  ),
                                                  onPressed: () {
                                                    _showTransferDetails(context, data, items, transferId);
                                                  },
                                                  tooltip: 'View',
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.print,
                                                    color: Colors.blueGrey,
                                                    size: 20,
                                                  ),
                                                  onPressed: () async {
                                                    try {
                                                      await generateInvoicePdf(data,items);
                                                    } catch (e) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text("Error generating PDF: $e"),
                                                          backgroundColor: Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  tooltip: 'Print',
                                                ),
                                                if (status == 'pending') ...[
                                                  if(value.canEdit(AppModules.stock))

                                                    IconButton(
                                                    icon: Icon(
                                                      Icons.edit,
                                                      color: Colors.amber,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => NewTransfer(
                                                            docId: data['docid'],
                                                            data: data,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    tooltip: 'Edit',
                                                  ),
                                                  if(value.canDelete(AppModules.stock))

                                                    IconButton(
                                                    icon: Icon(
                                                      Icons.delete,
                                                      color: Colors.redAccent,
                                                      size: 20,
                                                    ),
                                                    onPressed: () async {
                                                      final confirm = await showDialog<bool>(
                                                        context: context,
                                                        builder: (_) => AlertDialog(
                                                          backgroundColor: _cardColor,
                                                          title: Text(
                                                            "Delete Transfer Invoice",
                                                            style: TextStyle(color: _textColor),
                                                          ),
                                                          content: Text(
                                                            "Are you sure you want to delete this transfer invoice?",
                                                            style: TextStyle(color: _secondaryTextColor),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () => Navigator.pop(context, false),
                                                              child: Text(
                                                                "Cancel",
                                                                style: TextStyle(color: _mutedTextColor),
                                                              ),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () => Navigator.pop(context, true),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.redAccent,
                                                              ),
                                                              child: Text("Delete"),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirm == true) {
                                                        LoadingDialog.show(
                                                          context,
                                                          message: "Please wait...",
                                                        );

                                                        try {
                                                          final stockProvider = context.read<StockProvider>();
                                                          final insufficientItems = <String>[];

                                                          for (final item in items) {
                                                            final itemId = (item['itemid'] ?? '').toString();
                                                            final itemName = (item['item'] ?? '').toString();

                                                            final piecesToReverse =
                                                                (item['pieces'] as num?)?.toDouble() ?? 0;

                                                            final availableBalance =
                                                            await stockProvider.fetchItemCurrentBalance(
                                                              itemId: itemId,
                                                              selectedBranch: data['recievebranchid'],
                                                            );

                                                            if (availableBalance < piecesToReverse) {
                                                              insufficientItems.add(
                                                                '$itemName\n'
                                                                    'Available: ${availableBalance.toInt()} pcs\n'
                                                                    'Required: ${piecesToReverse.toInt()} pcs\n'
                                                              );
                                                            }
                                                          }

                                                          if (insufficientItems.isNotEmpty) {
                                                            if (!context.mounted) return;
                                                            LoadingDialog.hide();
                                                            await showDialog(
                                                              context: context,
                                                              builder: (_) => AlertDialog(
                                                                title: Text("Cannot Delete Transfer"),
                                                                content: SingleChildScrollView(
                                                                  child: Text(
                                                                    "The following items no longer have enough stock in "
                                                                        "${data['recievebranchname']} to reverse this transfer:\n\n"
                                                                        "${insufficientItems.join('\n\n')}",
                                                                  ),
                                                                ),
                                                                actions: [
                                                                  OutlinedButton(
                                                                    style: OutlinedButton.styleFrom(
                                                                      foregroundColor: _textColor,
                                                                      side: BorderSide(color: _mutedTextColor),
                                                                    ),
                                                                    onPressed: () => Navigator.pop(context),
                                                                    child: Text("Ok"),
                                                                  ),
                                                                ],
                                                              ),
                                                            );

                                                            return;
                                                          }

                                                          await db.runTransaction((transaction) async {
                                                            final transferRef =
                                                            db.collection('stock_transfer').doc(data['docid']);

                                                            final transferSnap = await transaction.get(transferRef);

                                                            if (!transferSnap.exists) {
                                                              throw Exception("Transfer not found");
                                                            }

                                                            final transferData = transferSnap.data()!;

                                                            final deletedRef = db
                                                                .collection('deletedstock')
                                                                .doc('${data['docid']}_${DateTime.now().millisecondsSinceEpoch}'); // or use a timestamp if you want multiple copies

                                                            final archiveData = Map<String, dynamic>.from(transferData);

                                                            archiveData.addAll({
                                                              'deletedat': FieldValue.serverTimestamp(),
                                                              'deletedby': context.read<Datafeed>().staff,
                                                              'deletetype': 'stocktransfer',
                                                              'reason': 'Deleted Stock Transfer',
                                                              'originaldocid': data['docid'],
                                                            });

                                                            // Archive
                                                            transaction.set(deletedRef, archiveData);

                                                            // Delete original
                                                            transaction.delete(transferRef);
                                                          });
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(
                                                                content: Text("Stock transfer deleted successfully"),
                                                                backgroundColor: Colors.green,
                                                              ),
                                                            );
                                                          }
                                                        } catch (e) {
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Text("Failed to delete transfer: $e"),
                                                                backgroundColor: Colors.red,
                                                              ),
                                                            );
                                                          }
                                                        } finally {
                                                          if (context.mounted) {
                                                            LoadingDialog.hide();
                                                          }
                                                        }
                                                      }
                                                    },
                                                    tooltip: 'Delete',
                                                  ),
                                                  if(data['syncstatus']!= true)
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.sync,
                                                      color: Colors.blue,
                                                      size: 20,
                                                    ),
                                                    onPressed: () async {
                                                      print("Syncing stock transfer reports for docid: ${data['docid']}");
                                                      bool loading = false;
                                                      setState(() => loading = true);
                                                      LoadingDialog.show(
                                                        context,
                                                        message: "Please wait...",
                                                      );
                                                      await context.read<StockProvider>().syncStockTransfers(data['docid']);

                                                      setState(() => loading = false);
                                                       LoadingDialog.hide();

                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text("Stock transfer reports updated."),
                                                        ),
                                                      );
                                                    },
                                                  )
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }),

                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferDetails(
      BuildContext context,
      Map<String, dynamic> data,
      List<Map<String, dynamic>> items,
      String transferId,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _subtleTextColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Transfer Details',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow('Transfer ID', transferId),
                    _buildDetailRow('From', data['supplywarehousename'] ?? 'N/A'),
                    _buildDetailRow('To', data['recievebranchname'] ?? 'N/A'),
                    _buildDetailRow('Date', data['createdat']?.toDate().toString().substring(0, 10) ?? 'N/A'),
                    _buildDetailRow('Staff', data['createdby']?.toString() ?? 'N/A'),
                    _buildDetailRow('Status', data['status']?.toUpperCase() ?? 'COMPLETED'),
                    const SizedBox(height: 16),
                    Text(
                      'Items',
                      style: TextStyle(
                        color: _isDarkMode
                            ? Colors.amberAccent
                            : Colors.amber.shade800,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.map((item) => Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['item'] ?? 'Unknown',
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Qty: ${item['quantity']}', style: TextStyle(color: _secondaryTextColor)),
                          Text('Price: GHS ${item['price']}', style: TextStyle(color: _secondaryTextColor)),
                          Text('Total: GHS ${item['total']}', style: TextStyle(color: _secondaryTextColor)),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Stock Value',
                            style: TextStyle(
                              color: _textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'GHS ${items.fold(0.0, (sum, item) => sum + (item['total'] ?? 0)).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.greenAccent
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: _mutedTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}