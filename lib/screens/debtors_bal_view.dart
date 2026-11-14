import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/debtorsbalmodel.dart';
import 'package:kologsoft/screens/debtors_balance.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class DebtorsBalView extends StatefulWidget {
  const DebtorsBalView({super.key});

  @override
  State<DebtorsBalView> createState() => _DebtorsBalViewState();
}

class _DebtorsBalViewState extends State<DebtorsBalView> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  TextEditingController searchController = TextEditingController();
  String searchText = "";
  late final stockprovider = Provider.of<Datafeed>(context, listen: false);

  Stream<List<DebtorsBalModel>> getAllDebtors() {
    return db
        .collection('debtorsbalance')
        .where('companyId', isEqualTo: stockprovider.companyid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DebtorsBalModel.fromJson({
          ...doc.data(),
          'transid': doc.id,
        });
      }).toList();
    });
  }
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Debtors Balance View"),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: 700,
              child: TextField(
                controller: searchController,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: "Search debtor...",
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    searchText = value.toLowerCase();
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DebtorsBalModel>>(
              stream: getAllDebtors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: \\${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No debtors found"));
                }
                final debtorsList = snapshot.data!;
                final filteredList = debtorsList.where((debtor) {
                  return debtor.name.toLowerCase().contains(searchText);
                }).toList();
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final d = filteredList[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isLightTheme
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.name,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Amount: GHS ${d.amount}",
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      "Date: ${d.date != null ? DateFormat.yMMMd().format(d.date!) : ''}",
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
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
                                          builder: (_) =>
                                              DebtorsBalance(debtors: d),
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.orange,
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  InkWell(
                                    onTap: () async {
                                      print(d.transid);
                                      print(d.amount);
                                      await db.collection('debtorsbalance').doc(d.transid).delete();
                                      await db.collection('customers').doc(d.id).
                                      update({'creditBalance': FieldValue.increment(-double.parse(d.amount),),});
                                    },
                                    child: const Icon(
                                      Icons.delete_forever,
                                      color: Colors.redAccent,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
