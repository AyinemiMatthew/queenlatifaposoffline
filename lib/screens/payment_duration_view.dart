import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/models/paymentdurationmodel.dart';
import 'package:kologsoft/screens/payment_duration_reg.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class PaymentDurationView extends StatefulWidget {
  const PaymentDurationView({super.key});

  @override
  State<PaymentDurationView> createState() => _PaymentDurationViewState();
}

class _PaymentDurationViewState extends State<PaymentDurationView> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  List<PaymentDurationModel> paymentDurationList = [];
  TextEditingController searchController = TextEditingController();
  String searchText = "";

  Stream<List<PaymentDurationModel>> getAllPaymentDurations() {
    return db.collection('paymentdurationreg').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return PaymentDurationModel.fromJson(doc.data());
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    getAllPaymentDurations();
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
        title: Text("REGISTERED PAYMENT DURATIONS"),
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
            child: StreamBuilder<List<PaymentDurationModel>>(
              stream: getAllPaymentDurations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text("Not found"));
                }

                final paymentDurationList = snapshot.data!;

                // FILTERED LIST
                final filteredList = paymentDurationList.where((acc) {
                  return acc.paymentname.toLowerCase().contains(searchText);
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
                                      acc.paymentname,
                                      style: TextStyle(
                                        color: foregroundColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Duration: ${acc.duration}",
                                      style: TextStyle(
                                        color: secondaryColor,
                                        fontSize: 13,
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
                                              PaymentDurationReg(payment: acc),
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
                                          .collection('paymentdurationreg')
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
