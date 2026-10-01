import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/models/activity_chart_model.dart';
import 'package:kologsoft/screens/activity_chart_reg.dart';
import 'package:provider/provider.dart';

import '../models/activity_model.dart';
import '../providers/Datafeed.dart';

class ActivityChartView extends StatefulWidget {
  const ActivityChartView({super.key});

  @override
  State<ActivityChartView> createState() => _ActivityChartViewState();
}

class _ActivityChartViewState extends State<ActivityChartView> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  late Future<List<QueryDocumentSnapshot>> _activityFuture;

  Future<List<QueryDocumentSnapshot>> _getActivityChart() async {
    final provider = Provider.of<Datafeed>(context, listen: false);

    QuerySnapshot snapshot = await db
        .collection('activity_chart')
        .where('companyId', isEqualTo: provider.companyid)
        .get();
    return snapshot.docs;
  }

  void _refreshActivities() {
    setState(() {
      _activityFuture = _getActivityChart();
    });
  }

  bool _matchesSearch(ActivityModel activity, String query) {
    if (query.isEmpty) {
      return true;
    }
    final normalized = query.toLowerCase();
    return activity.activityName.toLowerCase().contains(normalized);
  }

  @override
  void initState() {
    super.initState();
    _activityFuture = _getActivityChart();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final pageColor = isDark ? const Color(0xFF101624) : colorScheme.surface;
    final appBarColor = isDark ? const Color(0xFF1B263B) : colorScheme.surface;
    final cardColor = isDark ? const Color(0xFF182232) : colorScheme.surface;
    final foregroundColor = isDark ? Colors.white : colorScheme.onSurface;
    final secondaryColor = isDark
        ? Colors.white70
        : colorScheme.onSurfaceVariant;
    final subtleBorderColor = isDark
        ? Colors.white12
        : colorScheme.outlineVariant;
    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
        title: Text("Activities"),
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _activityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                "No account found.",
                style: TextStyle(color: secondaryColor, fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!;

          final activities = docs.map((doc) {
            final activity = ActivityModel.fromJson(
              doc.data() as Map<String, dynamic>,
            );
            if (activity.id.isEmpty) {
              activity.id = doc.id;
            }
            return activity;
          }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: foregroundColor),
                      decoration: InputDecoration(
                        hintText: "Search Activity by name...",
                        hintStyle: TextStyle(color: secondaryColor),
                        prefixIcon: Icon(Icons.search, color: secondaryColor),
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        final indexedAccounts = List.generate(
                          activities.length,
                          (index) => MapEntry(index, activities[index]),
                        );
                        final filtered = indexedAccounts
                            .where(
                              (entry) => _matchesSearch(
                                entry.value,
                                value.text.trim(),
                              ),
                            )
                            .toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              "No matching activity found.",
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            final doc = docs[entry.key];
                            final acc = entry.value;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: subtleBorderColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.store,
                                      color: Colors.blue,
                                    ),
                                  ),

                                  SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          acc.activityName,
                                          style: TextStyle(
                                            color: foregroundColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          "Debit Account: ${acc.debitAccountName}",
                                          style: TextStyle(
                                            color: secondaryColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          "Credit Account: ${acc.creditAccountName}",
                                          style: TextStyle(
                                            color: secondaryColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(height: 4),
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
                                              builder: (_) =>
                                                  ActivityChartReg(chart: acc),
                                            ),
                                          ).then((_) => _refreshActivities());
                                        },
                                        child: Icon(
                                          Icons.edit,
                                          color: Colors.orange,
                                        ),
                                      ),

                                      SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: Text("Delete Activity"),
                                              content: Text(
                                                "Delete ${acc.activityName}?",
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: Text("Cancel"),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: Text(
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
                                                .collection('activity_chart')
                                                .doc(doc.id)
                                                .delete();

                                            if (!mounted) return;
                                            _refreshActivities();
                                          }
                                        },
                                        child: Icon(
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
