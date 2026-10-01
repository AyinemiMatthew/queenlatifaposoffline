import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/configurevatmodel.dart';
import '../providers/Datafeed.dart';
import 'configurevat.dart';

class ConfigurevatView extends StatefulWidget {
  const ConfigurevatView({super.key});

  @override
  State<ConfigurevatView> createState() => _ConfigurevatViewState();
}

class _ConfigurevatViewState extends State<ConfigurevatView> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';

  @override
  void initState() {
    super.initState();

    ///  initState
    Future.microtask(() {
      context.read<Datafeed>().fetchVat();
    });
  }

  List<ConfigureVatModel> filterVat(List<ConfigureVatModel> list) {
    if (searchQuery.isEmpty) return list;

    final query = searchQuery.toLowerCase();

    return list.where((v) {
      return v.producttype.toLowerCase().contains(query) ||
          v.vatrate.toLowerCase().contains(query) ||
          v.computationalmethod.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, value, child) {
        final vatList = value.vatList;
        final filtered = filterVat(vatList);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text("VAT Configuration"),
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),

          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF415A77),
            child: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConfigureVatreg()),
              );

              /// REFRESH AFTER ADD
              // context.read<Datafeed>().fetchVat();
            },
          ),

          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    /// SEARCH
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: "Search VAT...",
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// LIST
                    Expanded(
                      child: value.isloadingvatlist
                          ? Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : vatList.isEmpty
                          ? Center(
                              child: Text(
                                "No VAT Found",
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final vat = filtered[index];

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(top: 10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    children: [
                                      /// ICON
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.receipt,
                                          color: Colors.green,
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      /// DETAILS
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              vat.producttype,
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),

                                            Text(
                                              "VAT Type: ${vat.vatrate}",
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                                fontSize: 13,
                                              ),
                                            ),

                                            Text(
                                              "Computation: ${vat.computationalmethod}",
                                              style: TextStyle(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      /// ACTIONS
                                      Row(
                                        children: [
                                          /// EDIT
                                          InkWell(
                                            onTap: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ConfigureVatreg(vat: vat),
                                                ),
                                              );

                                              //context.read<Datafeed>().fetchVat();
                                            },
                                            child: const Icon(
                                              Icons.edit,
                                              color: Colors.orange,
                                            ),
                                          ),

                                          const SizedBox(width: 10),

                                          /// DELETE
                                          InkWell(
                                            onTap: () async {
                                              final confirm =
                                                  await showDialog<bool>(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      backgroundColor: Theme.of(
                                                        context,
                                                      ).colorScheme.surface,
                                                      title: Text(
                                                        "Delete VAT?",
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                      content: Text(
                                                        "Delete ${vat.producttype} VAT?",
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                false,
                                                              ),
                                                          child: const Text(
                                                            "Cancel",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                context,
                                                                true,
                                                              ),
                                                          child: const Text(
                                                            "Delete",
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                              if (confirm == true) {
                                                await db
                                                    .collection('vat')
                                                    .doc(vat.id)
                                                    .delete();
                                                setState(() {
                                                  vatList.removeWhere(
                                                    (item) => item.id == vat.id,
                                                  );
                                                  filtered.removeWhere(
                                                    (item) => item.id == vat.id,
                                                  );
                                                });

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    backgroundColor:
                                                        Colors.green,
                                                    content: Text(
                                                      "VAT deleted successfully",
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Icon(
                                              Icons.delete_forever,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
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
}
