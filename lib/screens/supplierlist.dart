import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/screens/supplierscreen.dart';
import 'package:provider/provider.dart';

import '../models/appModuls.dart';
import '../models/suppliermodel.dart';
import '../providers/Datafeed.dart';

class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  String searchQuery = '';
  List<Supplier> _filteredSuppliers(List<Supplier> suppliers) {
    if (searchQuery.isEmpty) return suppliers;

    final query = searchQuery.toLowerCase();
    return suppliers.where((s) {
      final supplierName = s.supplier.toLowerCase();
      final contact = s.contact.toLowerCase();
      return supplierName.contains(query) || contact.contains(query);
    }).toList();
  }

  final ScrollController _scrollController = ScrollController();
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchSuppliers();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final listWidth = screenWidth > 900
        ? screenWidth * 0.6
        : screenWidth * 0.95;

    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final filteredSuppliers = _filteredSuppliers(value.suppliers);
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isLight = theme.brightness == Brightness.light;
        final backgroundColor = isLight
            ? Colors.white
            : const Color(0xFF101624);
        final surfaceColor = isLight ? Colors.white : const Color(0xFF1B263B);
        final borderColor = isLight
            ? Colors.grey.shade300
            : const Color(0xFF334155);

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text('Supplier List'),
            backgroundColor: surfaceColor,
            foregroundColor: colorScheme.onSurface,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Container(
                  width: listWidth,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (v) => setState(() => searchQuery = v),
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search suppliers...',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          filled: true,
                          fillColor: surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8),
                            ),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ---------- Supplier List ----------
                      Expanded(
                        child: filteredSuppliers.isEmpty
                            ? Center(
                                child: Text(
                                  'No suppliers found',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ScrollbarTheme(
                                data: ScrollbarThemeData(
                                  thumbColor: MaterialStateProperty.all(
                                    Color(0xFF415A77),
                                  ),
                                  trackColor: MaterialStateProperty.all(
                                    isLight
                                        ? Colors.grey.shade300
                                        : const Color(0xFF101624),
                                  ),
                                  thickness: MaterialStateProperty.all(10),
                                  radius: const Radius.circular(10),
                                  thumbVisibility: MaterialStateProperty.all(
                                    true,
                                  ),
                                ),
                                child: Scrollbar(
                                  controller: _scrollController,
                                  thickness: 10,
                                  thumbVisibility: true,
                                  interactive: true,
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: filteredSuppliers.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final supplier = filteredSuppliers[index];

                                      return Card(
                                        color: surfaceColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          side: BorderSide(color: borderColor),
                                        ),
                                        elevation: isLight ? 0 : 1,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              // Numbering
                                              Text(
                                                '${index + 1}.',
                                                style: TextStyle(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),

                                              // Supplier info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      supplier.supplier,
                                                      style: TextStyle(
                                                        color: colorScheme
                                                            .onSurface,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Contact: ${supplier.contact}',
                                                      style: TextStyle(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Edit & Delete buttons
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (value.canEdit(
                                                    AppModules.settings,
                                                  ))
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.edit,
                                                        color:
                                                            colorScheme.primary,
                                                      ),
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                SupplierRegistration(
                                                                  supplier:
                                                                      supplier,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  if (value.canDelete(
                                                    AppModules.settings,
                                                  ))
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.delete,
                                                        color:
                                                            colorScheme.error,
                                                      ),
                                                      onPressed: () async {
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (_) => AlertDialog(
                                                            backgroundColor:
                                                                surfaceColor,
                                                            title: Text(
                                                              'Delete Supplier',
                                                              style: TextStyle(
                                                                color: colorScheme
                                                                    .onSurface,
                                                              ),
                                                            ),
                                                            content: Text(
                                                              'Are you sure you want to delete this supplier?',
                                                              style: TextStyle(
                                                                color: colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                      false,
                                                                    ),
                                                                child: Text(
                                                                  'Cancel',
                                                                  style: TextStyle(
                                                                    color: colorScheme
                                                                        .primary,
                                                                  ),
                                                                ),
                                                              ),
                                                              TextButton(
                                                                style: TextButton.styleFrom(
                                                                  backgroundColor:
                                                                      colorScheme
                                                                          .error,
                                                                  foregroundColor:
                                                                      colorScheme
                                                                          .onError,
                                                                ),
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                      true,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Delete',
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        );

                                                        if (confirm ?? false) {
                                                          if (!value.canDelete(
                                                            AppModules.settings,
                                                          )) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                  'Permission denied',
                                                                ),
                                                              ),
                                                            );
                                                            return;
                                                          }
                                                          try {
                                                            await value
                                                                .deleteSupplier(
                                                                  supplier.id,
                                                                );
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              const SnackBar(
                                                                backgroundColor:
                                                                    Colors.red,
                                                                content: Text(
                                                                  'Supplier deleted successfully',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          } catch (e) {
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'Failed to delete: $e',
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      },
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
