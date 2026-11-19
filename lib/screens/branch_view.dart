import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/branch.dart';
import '../providers/Datafeed.dart';
import '../providers/cashier_provider.dart';
import 'branch_reg.dart';

class BranchView extends StatefulWidget {
  const BranchView({super.key});

  @override
  State<BranchView> createState() => _BranchViewState();
}

class _BranchViewState extends State<BranchView> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? selectedDate;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchBranches();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BranchModel> filterbranches(List<BranchModel> branches) {
    if (searchQuery.isEmpty) return branches;

    final query = searchQuery.toLowerCase();
    return branches.where((s) {
      final Name = s.branchname.toLowerCase();
      final type = s.branchtype.toLowerCase();
      final staff = s.staff.toLowerCase();
      final updateby = s.updatedby.toLowerCase();
      final contact = s.branchcontact.toLowerCase();

      return Name.contains(query) ||
          type.contains(query) ||
          staff.contains(query) ||
          updateby.contains(query) ||
          contact.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final branhes = value.branches;
        final filterbranche = filterbranches(branhes);
        final theme = Theme.of(context);
        final isLight = theme.brightness == Brightness.light;
        final foregroundColor = theme.colorScheme.onSurface;
        final mutedColor = theme.colorScheme.onSurfaceVariant;
        final surfaceColor = isLight ? Colors.white : const Color(0xFF182232);
        final borderColor = isLight
            ? Colors.grey.shade300
            : Colors.white.withValues(alpha: 0.12);

        return Scaffold(
          backgroundColor: isLight ? Colors.white : const Color(0xFF101624),

          appBar: AppBar(
            title: const Text("Registered Branches"),
            backgroundColor: surfaceColor,
            foregroundColor: foregroundColor,
            actions: [
              IconButton(
                tooltip: "add branch",
                icon: const Icon(Icons.add),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BranchRegistration()),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => searchQuery = v),
                        style: TextStyle(color: foregroundColor),
                        decoration: InputDecoration(
                          hintText: "Search branches by name, type, contact...",
                          hintStyle: TextStyle(color: mutedColor),
                          prefixIcon: Icon(Icons.search, color: mutedColor),
                          filled: true,
                          fillColor: surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 5),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filterbranche.length,
                        itemBuilder: (context, index) {
                          final branch = filterbranche[index];

                          return Container(
                            padding: const EdgeInsets.all(14),
                            margin: EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.store,
                                    color: Colors.blue,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Text("${index +1}",style: TextStyle(color: Colors.white),),
                                      // SizedBox(height: 5,),
                                      Text(
                                        branch.branchname,
                                        style: TextStyle(
                                          color: foregroundColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Type: ${branch.branchtype}",
                                        style: TextStyle(
                                          color: mutedColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        "Contact: ${branch.branchcontact}",
                                        style: TextStyle(
                                          color: mutedColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        "Address: ${branch.address}",
                                        style: TextStyle(
                                          color: mutedColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => BranchRegistration(
                                              branch: branch,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Icon(
                                        Icons.edit,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    InkWell(
                                      onTap: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            backgroundColor: surfaceColor,
                                            title: Text(
                                              "Delete Branch?",
                                              style: TextStyle(
                                                color: foregroundColor,
                                              ),
                                            ),
                                            content: Text(
                                              "Are you sure you want to delete ${branch.branchname}?",
                                              style: TextStyle(
                                                color: mutedColor,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: Text(
                                                  "Cancel",
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
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
                                          final datafeed =
                                              Provider.of<CashierProvider>(
                                                context,
                                                listen: false,
                                              );

                                          // remove locally first (instant UI update)
                                          value.branches.removeWhere(
                                            (w) => w.id == branch.id,
                                          );

                                          // delete in firestore
                                          await db
                                              .collection('branches')
                                              .doc(branch.id)
                                              .delete();

                                          // optional provider delete
                                          await datafeed.deleteBranch(
                                            branch.id,
                                          );

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              backgroundColor: Colors.red,
                                              content: Text(
                                                "Branch deleted successfully",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Icon(
                                        Icons.delete_forever,
                                        color: theme.colorScheme.error,
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
