import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/models/account_type_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import 'account_type_reg.dart';

class AccountTypeList extends StatelessWidget {
  final String accountClass;
  const AccountTypeList({super.key, required this.accountClass});

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final query = value.db
            .collection('accounts')
            .where('companyId', isEqualTo: value.companyid)
            .where('accountClass', isEqualTo: accountClass)
            .orderBy('name');
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colorScheme = Theme.of(context).colorScheme;
        final pageColor = isDark
            ? const Color(0xFF101A23)
            : colorScheme.surface;
        final appBarColor = isDark
            ? const Color(0xFF0D1A26)
            : colorScheme.surface;
        final cardColor = isDark
            ? const Color(0xFF182232)
            : colorScheme.surface;
        final foregroundColor = isDark ? Colors.white : colorScheme.onSurface;
        final secondaryColor = isDark
            ? Colors.white70
            : colorScheme.onSurfaceVariant;
        return Scaffold(
          backgroundColor: pageColor,
          appBar: AppBar(
            title: Text('$accountClass Accounts'),
            backgroundColor: appBarColor,
            foregroundColor: foregroundColor,
            elevation: 2,
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blue,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AccountTypeReg(
                    account: AccountTypeModel(accountClass: accountClass),
                  ),
                ),
              );
            },
            child: Icon(Icons.add, color: foregroundColor),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load accounts: ${snapshot.error}',
                    style: TextStyle(color: secondaryColor),
                  ),
                );
              }

              final accounts = snapshot.data?.docs ?? const [];
              if (accounts.isEmpty) {
                return Center(
                  child: Text(
                    'No accounts found for this class.',
                    style: TextStyle(color: secondaryColor),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final doc = accounts[index];
                  final data = doc.data();
                  final account = AccountTypeModel.fromJson(data);
                  final details = [
                    account.accountClass,
                    account.accountClassType,
                    account.subAccount,
                  ].where((value) => value.trim().isNotEmpty).toList();

                  return Card(
                    color: cardColor,
                    child: ListTile(
                      leading: Icon(
                        Icons.account_balance_wallet,
                        color: secondaryColor,
                      ),
                      title: Text(
                        account.name,
                        style: TextStyle(color: foregroundColor),
                      ),
                      subtitle: Text(
                        details.join(' • '),
                        style: TextStyle(color: secondaryColor),
                      ),
                      trailing: Icon(Icons.edit, color: secondaryColor),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AccountTypeReg(account: account),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
