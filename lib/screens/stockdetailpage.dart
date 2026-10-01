import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/StockProvider.dart';

class StockDetailsPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const StockDetailsPage({
    super.key,
    required this.data,
  });

  @override
  State<StockDetailsPage> createState() => _StockDetailsPageState();
}

class _StockDetailsPageState extends State<StockDetailsPage> {

  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();
  late List<Map<String, dynamic>> items;

  @override
  void initState() {
    super.initState();

    final rawItems = widget.data['items'];

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
    } else {
      items = [];
    }
  }
  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: Text(
          "Invoice ${widget.data['invoice']}",
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,

            children: [

              Text(
                "Supplier: ${widget.data['suppliername']}",
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

            const SizedBox(height: 10),

            Text(
              "Branch: ${widget.data['branchname']}",
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1200,
                  minWidth: 800,
                ),

                child: Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                    ),
                  ),

                  child: Scrollbar(
                    controller: verticalController,
                    thumbVisibility: true,

                    child: SingleChildScrollView(
                      controller: verticalController,
                      scrollDirection: Axis.vertical,

                      child: Scrollbar(
                        controller: horizontalController,
                        thumbVisibility: true,
                        notificationPredicate: (_) => true,

                        child: SingleChildScrollView(
                          controller: horizontalController,
                          scrollDirection: Axis.horizontal,

                          child: Center(
                            child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              colorScheme.surfaceContainerHighest,
                            ),

                            dataRowColor: WidgetStateProperty.all(
                              colorScheme.surface,
                            ),
                            dividerThickness: 1,
                            columnSpacing: 40,

                            headingTextStyle: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),

                            dataTextStyle: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                            ),

                            columns: const [
                              DataColumn(label: Text("#")),
                              DataColumn(label: Text("Product Name")),
                              DataColumn(label: Text("Qty")),
                              DataColumn(label: Text("Unit Cost")),
                              DataColumn(label: Text("Total Cost")),
                              DataColumn(label: Text("Sync data")),
                            ],

                            rows: List.generate(items.length, (index) {

                              final item = items[index];

                              final qty =
                                  double.tryParse(item['quantity'].toString()) ?? 0;

                              final unitCost =
                                  double.tryParse(item['price'].toString()) ?? 0;

                              final total =
                                  double.tryParse(item['total'].toString()) ?? 0;

                              return DataRow(

                                color: WidgetStatePropertyAll<Color?>(
                                  colorScheme.surface,
                                ),

                                cells: [

                                  DataCell(
                                    Text('${index + 1}'),
                                  ),

                                  DataCell(
                                    Text(item['item'].toString()),
                                  ),

                                  DataCell(
                                    Text(qty.toString()),
                                  ),

                                  DataCell(
                                    Text(
                                      "GHS ${unitCost.toStringAsFixed(2)}",
                                    ),
                                  ),

                                  DataCell(
                                    Text(
                                      "GHS ${total.toStringAsFixed(2)}",
                                    ),
                                  ),
                                  DataCell(
                                    (widget.data['syncstatus'] == true ||
                                        item['syncstatus'] == true)
                                        ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 22,
                                    ):
                                          ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.secondary,
                                        foregroundColor: colorScheme.onSecondary,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () {
                                        _handleSync(
                                          context,
                                          widget.data,
                                          item,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.sync,
                                        size: 16,
                                      ),
                                      label: const Text("Sync"),
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
                ),
              ),
            ),
            )],
        ),

    ),));
  }
  Future<void> _handleSync(
      BuildContext context,
      Map<String, dynamic> data,
      Map<String, dynamic> item,
      ) async {
    final overlay = Overlay.of(context);

    final overlayEntry = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    bool overlayRemoved = false;

    void removeOverlay() {
      if (!overlayRemoved) {
        overlayRemoved = true;

        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      }
    }

    try {
      final provider = Provider.of<StockProvider>(
        context,
        listen: false,
      );

      await provider.syncsingleTransactionToReport(
        data['docid'],
        item,
      );

      if (!mounted) {
        removeOverlay();
        return;
      }

      setState(() {
        final index = items.indexWhere(
              (element) =>
          element['itemid']?.toString() ==
              item['itemid']?.toString(),
        );

        if (index != -1) {
          items[index]['syncstatus'] = true;
        }
      });

      removeOverlay();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${item['item']} synced successfully",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      removeOverlay();

      if (!mounted) return;

      debugPrint("Sync failed: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sync failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

}