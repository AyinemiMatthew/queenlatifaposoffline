import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/models/account_type_model.dart';
import 'package:kologsoft/screens/account_type_reg.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class AccountTypeView extends StatefulWidget {
  const AccountTypeView({super.key});

  @override
  State<AccountTypeView> createState() => _AccountTypeViewState();
}

class _AccountTypeViewState extends State<AccountTypeView> {
  List<AccountTypeModel> accountList = [];

  final FirebaseFirestore db = FirebaseFirestore.instance;
  TextEditingController searchController = TextEditingController();
  String searchText = "";

  Stream<List<AccountTypeModel>> getAllAccounts() {
    final provider = Provider.of<Datafeed>(context, listen: false);
    return db
        .collection('accounts')
        .where('companyId', isEqualTo: provider.companyid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return AccountTypeModel.fromJson(doc.data());
          }).toList();
        });
  }

  @override
  void initState() {
    super.initState();
    getAllAccounts();
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
        title: Text("Account Types"),
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              width: 700,
              child: TextField(
                controller: searchController,
                style: TextStyle(color: foregroundColor),
                decoration: InputDecoration(
                  hintText: "Search account...",
                  hintStyle: TextStyle(color: secondaryColor),
                  prefixIcon: Icon(Icons.search, color: secondaryColor),
                  filled: true,
                  fillColor: cardColor,
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

          // LIST
          Expanded(
            child: StreamBuilder<List<AccountTypeModel>>(
              stream: getAllAccounts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("No accounts found"));
                }

                final accountList = snapshot.data!;

                // FILTERED LIST
                final filteredList = accountList.where((acc) {
                  return acc.name.toLowerCase().contains(searchText) ||
                      acc.accountClass.toLowerCase().contains(searchText) ||
                      acc.subAccount.toLowerCase().contains(searchText) ||
                      acc.accountClassType.toLowerCase().contains(searchText);
                }).toList();

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filteredList.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final acc = filteredList[index];

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
                                child: Icon(Icons.store, color: Colors.blue),
                              ),

                              SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.name,
                                      style: TextStyle(
                                        color: foregroundColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Class: ${acc.accountClass}",
                                      style: TextStyle(
                                        color: secondaryColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      "Subclass: ${acc.subAccount}",
                                      style: TextStyle(
                                        color: secondaryColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "SubType: ${acc.accountClassType}",
                                      style: TextStyle(
                                        color: secondaryColor,
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
                                              AccountTypeReg(account: acc),
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      Icons.edit,
                                      color: Colors.orange,
                                    ),
                                  ),

                                  SizedBox(width: 8),

                                  InkWell(
                                    onTap: () async {
                                      await db
                                          .collection('accounts')
                                          .doc(acc.id)
                                          .delete();
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
