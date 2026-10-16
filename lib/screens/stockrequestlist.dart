import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/screens/stockrequest.dart';
import 'package:kologsoft/screens/supplyinvoice.dart';
import 'package:kologsoft/screens/transfers.dart';
import 'package:provider/provider.dart';
import '../providers/StockProvider.dart';

class StockRequestDetails extends StatefulWidget {
  const StockRequestDetails({super.key});
  @override
  State<StockRequestDetails> createState() => _StockRequestDetailsState();
}

class _StockRequestDetailsState extends State<StockRequestDetails> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  String searchQuery = "";
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isDateRangeActive = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final provider = Provider.of<StockProvider>(context, listen: false);
      await provider.getdata();
    });
  }

  Future<void> _showDateRangePicker() async {
    final DateTime? start = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (start != null) {
      final DateTime? end = await showDatePicker(
        context: context,
        initialDate: _endDate ?? start,
        firstDate: start,
        lastDate: DateTime.now(),
      );

      if (end != null) {
        setState(() {
          _startDate = DateTime(start.year, start.month, start.day);
          _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
          _isDateRangeActive = true;
        });
        if (_startDate == null || _endDate == null) return;
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

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Stock Requests",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isDateRangeActive
                    ? colors.secondaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_month,
                color: _isDateRangeActive
                    ? colors.onSecondaryContainer
                    : colors.onSurfaceVariant,
              ),
            ),
            onPressed: _showDateRangePicker,
            tooltip: 'Filter by date range',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.secondary,
        foregroundColor: colors.onSecondary,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewTransfer()),
          );
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  child: TextFormField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                    style: TextStyle(color: colors.onSurface),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      hintText: 'Search  ...',
                      hintStyle: TextStyle(color: colors.onSurfaceVariant),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colors.onSurfaceVariant,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: colors.onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  searchQuery = "";
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: colors.secondary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<StockProvider>(context, listen: false)
                    .stockStream(
                      collectionName: 'stock_request',
                      startDate: _isDateRangeActive ? _startDate : null,
                      endDate: _isDateRangeActive ? _endDate : null,
                      branchfield: 'branchid',
                      datefield: 'createdAt',
                    ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: colors.secondary),
                    );
                  }
                  if (!snapshot.hasData) {
                    return Center(
                      child: Text(
                        "No stock items",
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    );
                  }
                  final allDocs = snapshot.data!;

                  final filteredDocs = allDocs.where((doc) {
                    final data = doc as Map<String, dynamic>;
                    return data.values.any((value) {
                      if (value == null) return false;
                      return value.toString().toLowerCase().contains(
                        searchQuery,
                      );
                    });
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Text(
                        searchQuery.isEmpty
                            ? "No items requested yet"
                            : "No items found matching '$searchQuery'",
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc as Map<String, dynamic>;
                      final rawItems = data['items'];

                      List<Map<String, dynamic>> items = [];

                      if (rawItems is List) {
                        items = rawItems
                            .map((e) => Map<String, dynamic>.from(e))
                            .toList();
                      } else if (rawItems is Map) {
                        items = rawItems.entries.map((entry) {
                          return {
                            'key': entry.key,
                            ...Map<String, dynamic>.from(entry.value),
                          };
                        }).toList();
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${data['warehousename']}",
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: colors.secondaryContainer,
                                  foregroundColor: colors.onSecondaryContainer,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: colors.onSecondaryContainer,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...items.map((item) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.label,
                                        color: colors.secondary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${item['item']}",
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  Text(
                                    "Qty: ${(item['requestedquantity'] as num?)?.toDouble() ?? 0.0}",
                                    style: TextStyle(color: colors.onSurface),
                                  ),
                                  Text(
                                    "Mode: ${item['mode']}",
                                    style: TextStyle(color: colors.onSurface),
                                  ),
                                  Text(
                                    "Purchase price: ${item['price']}",
                                    style: TextStyle(color: colors.onSurface),
                                  ),
                                  Text(
                                    "Total: ${item['total']}",
                                    style: TextStyle(color: colors.onSurface),
                                  ),
                                  const SizedBox(height: 6),
                                  Divider(
                                    color: colors.outlineVariant,
                                    height: 20,
                                  ),
                                ],
                              );
                            }).toList(),

                            Text(
                              "Date: ${data['createdat'].toDate().toString().substring(0, 10)}",
                              style: TextStyle(color: colors.onSurface),
                            ),
                            Text(
                              "Staff: ${data['createdby'].toString()}",
                              style: TextStyle(color: colors.onSurface),
                            ),

                            Divider(color: colors.outlineVariant, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Total Amount: GHS ${data['gross'].toStringAsFixed(2) ?? 0}",
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.print_outlined,
                                        color: colors.secondary,
                                      ),
                                      onPressed: () async {
                                        try {
                                          generateInvoicePdf(data);
                                        } catch (e) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                "Error generating PDF: $e",
                                              ),
                                              backgroundColor: colors.error,
                                            ),
                                          );
                                        }
                                      },
                                    ),

                                    if (data['status']?.toLowerCase() ==
                                        'pending') ...[
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: colors.secondary,
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => StockRequest(
                                                docId: doc['docid'],
                                                data: data,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: colors.error,
                                        ),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text(
                                                "Delete Request Invoice",
                                              ),
                                              content: const Text(
                                                "Are you sure you want to delete this request invoice?",
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text("Cancel"),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            colors.error,
                                                        foregroundColor:
                                                            colors.onError,
                                                      ),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text("Delete"),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await db
                                                .collection('stock_request')
                                                .doc(doc['docid'])
                                                .delete();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    "Stock request deleted successfully",
                                                  ),
                                                  backgroundColor:
                                                      colors.secondary,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
