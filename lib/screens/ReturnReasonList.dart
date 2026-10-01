import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';
import 'package:kologsoft/screens/return_reasons.dart';
import 'package:kologsoft/screens/stocking_mode.dart';
import 'package:provider/provider.dart';

import '../models/ReasonsModel.dart';
import '../models/stocking_modeModel.dart';
import '../providers/Datafeed.dart';
import '../widgets/datepicker.dart';

class ReturnReasonLists extends StatefulWidget {
  @override
  _ReturnReasonListsState createState() => _ReturnReasonListsState();
}

class _ReturnReasonListsState extends State<ReturnReasonLists> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  String searchQuery = '';

  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchReturnreasons();
    });
  }

  List<ReasonsModel> filterstockingModes(List<ReasonsModel> reasonmodel) {
    if (searchQuery.isEmpty) return reasonmodel;

    final query = searchQuery.toLowerCase();
    return reasonmodel.where((s) {
      final Name = s.name.toLowerCase();
      final contact = s.staff.toLowerCase();
      return Name.contains(query) || contact.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth > 900
        ? screenWidth * 0.6
        : screenWidth * 0.95;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final backgroundColor = isLight ? Colors.white : const Color(0xFF101624);
    final surfaceColor = isLight ? Colors.white : const Color(0xFF1B263B);
    final foregroundColor = theme.colorScheme.onSurface;
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final borderColor = isLight
        ? Colors.grey.shade300
        : Colors.white.withValues(alpha: 0.1);

    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final reasons = filterstockingModes(value.returnitemreasons);

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text("Registered return reasons"),
            backgroundColor: surfaceColor,
            foregroundColor: foregroundColor,
            actions: [],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cardWidth),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextFormField(
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: TextStyle(color: foregroundColor),
                      decoration: InputDecoration(
                        hintText: 'Search Reasons...',
                        hintStyle: TextStyle(color: mutedColor),
                        prefixIcon: Icon(Icons.search, color: mutedColor),
                        filled: true,
                        fillColor: isLight
                            ? Colors.white
                            : const Color(0xFF22304A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: reasons.length,
                        itemBuilder: (context, index) {
                          final returnReasons = reasons[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        returnReasons.name,
                                        style: TextStyle(
                                          color: foregroundColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Staff: ${returnReasons.staff ?? ''}\nDate: ${returnReasons.date}",
                                        style: TextStyle(
                                          color: mutedColor,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit reason',
                                  icon: Icon(
                                    Icons.edit,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ReturnReasons(
                                          docId: returnReasons.id,
                                          data: returnReasons.toMap(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete reason',
                                  icon: Icon(
                                    Icons.delete,
                                    color: theme.colorScheme.error,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Delete record"),
                                        content: const Text(
                                          "Are you sure you want to delete this record?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  theme.colorScheme.error,
                                              foregroundColor:
                                                  theme.colorScheme.onError,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await db
                                          .collection('return_reasons')
                                          .doc(returnReasons.id)
                                          .delete();
                                      value.stockingModes.removeWhere(
                                        (test) => test.id == returnReasons.id,
                                      );

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "stocking mode deleted",
                                          ),
                                        ),
                                      );
                                      setState(() {});
                                    }
                                  },
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
