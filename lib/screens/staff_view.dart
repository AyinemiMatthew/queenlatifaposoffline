import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/appModuls.dart';
import 'package:kologsoft/models/staffmodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/screens/staff.dart';
import 'package:kologsoft/screens/userpermissionscreen.dart';
import 'package:provider/provider.dart';

class StaffView extends StatefulWidget {
  const StaffView({super.key});

  @override
  State<StaffView> createState() => _StaffViewState();
}

class _StaffViewState extends State<StaffView> {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  List<StaffModel> staffList = [];

  //final FirebaseFirestore db = FirebaseFirestore.instance;
  TextEditingController searchController = TextEditingController();
  String searchText = "";

  Stream<List<StaffModel>> getAllAccounts() {
    final provider = Provider.of<Datafeed>(context, listen: false);
    return db
        .collection('staff')
        .where('companyid', isEqualTo: provider.companyid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return StaffModel.fromMap(doc.data());
          }).toList();
        });
  }

  final TextEditingController _searchController = TextEditingController();
  late Future<List<QueryDocumentSnapshot>> _staffsFuture;

  Future<List<QueryDocumentSnapshot>> _getStaffs() async {
    QuerySnapshot snapshot = await db.collection('staff').get();
    return snapshot.docs;
  }

  void _refreshStaffs() {
    setState(() {
      _staffsFuture = _getStaffs();
    });
  }

  @override
  void initState() {
    super.initState();
    _staffsFuture = _getStaffs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(StaffModel staff, String query) {
    if (query.isEmpty) {
      return true;
    }
    final normalized = query.toLowerCase();
    return staff.name.toLowerCase().contains(normalized) ||
        staff.email.toLowerCase().contains(normalized) ||
        staff.phone.toLowerCase().contains(normalized) ||
        staff.branchname.toLowerCase().contains(normalized) ||
        staff.accesslevel.toLowerCase().contains(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeBrightness = Theme.of(context).brightness;
    final branchIconColor = themeBrightness == Brightness.dark
        ? colorScheme.onSurface
        : colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Staff View"),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: TextField(
                  controller: searchController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: "Search account...",
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(
                      Icons.search,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
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
          ),

          // LIST
          Expanded(
            child: StreamBuilder<List<StaffModel>>(
              stream: getAllAccounts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No accounts found"));
                }

                final staffList = snapshot.data!;

                // FILTERED LIST
                final filteredList = staffList.where((acc) {
                  return _matchesSearch(acc, searchText);
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
                        final acc = filteredList[index];
                        final provider = Provider.of<Datafeed>(
                          context,
                          listen: false,
                        );

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: branchIconColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.store,
                                  color: branchIconColor,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.name,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Email: ${acc.email}",
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      "Contact: ${acc.phone}",
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Access Level: ${acc.accesslevel}",
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Branch: ${acc.branchname}",
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 10,
                                          color: (acc.isLoggedIn ?? false)
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          (acc.isLoggedIn ?? false)
                                              ? "Online"
                                              : "Offline",
                                          style: TextStyle(
                                            color: (acc.isLoggedIn ?? false)
                                                ? Colors.green
                                                : Colors.redAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      (acc.isLoggedIn ?? false)
                                          ? "Last Login: ${acc.lastLogin != null ? DateFormat('dd MMM yyyy, hh:mm a').format(acc.lastLogin!.toDate()) : 'Unknown'}"
                                          : "Last Logout: ${acc.lastLogout != null ? DateFormat('dd MMM yyyy, hh:mm a').format(acc.lastLogout!.toDate()) : 'Never'}",
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Row(
                                children: [
                                  Tooltip(
                                    message: 'Permissions',
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                UserPermissionScreen(
                                                  userId: acc.email,
                                                  userName: acc.name,
                                                  isEditing: true,
                                                ),
                                          ),
                                        );
                                      },
                                      child: const Icon(
                                        Icons.admin_panel_settings,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),
                                  if (provider.canEdit(
                                    AppModules.userManagement,
                                  ))
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => Staff(staff: acc),
                                          ),
                                        );
                                      },
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.orange,
                                      ),
                                    ),

                                  const SizedBox(width: 8),
                                  if (provider.canDelete(
                                    AppModules.userManagement,
                                  ))
                                    InkWell(
                                      onTap: () async {
                                        if (!provider.canDelete(
                                          AppModules.userManagement,
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
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) => AlertDialog(
                                            title: const Text(
                                              'Delete Staff Account',
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete ${acc.name} (${acc.email})? This action cannot be undone.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  dialogContext,
                                                ).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      colorScheme.error,
                                                  foregroundColor:
                                                      colorScheme.onError,
                                                ),
                                                onPressed: () => Navigator.of(
                                                  dialogContext,
                                                ).pop(true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (!mounted || confirm != true) return;

                                        await db
                                            .collection('staff')
                                            .doc(acc.email)
                                            .delete();
                                        _refreshStaffs();
                                      },
                                      child: const Icon(
                                        Icons.delete_forever,
                                        color: Colors.red,
                                      ),
                                    ),
                                  if ((acc.tempPassword ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    Tooltip(
                                      message: 'Copy temporary password',
                                      child: InkWell(
                                        onTap: () async {
                                          final pswd = acc.tempPassword ?? '';
                                          await Clipboard.setData(
                                            ClipboardData(text: pswd),
                                          );

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Temporary password copied',
                                              ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons
                                                .key_rounded, // or Icons.content_copy_rounded
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                        ),
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
