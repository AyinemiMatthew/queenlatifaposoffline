
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../providers/item_syncProvider.dart';

class SyncitemsregToStock extends StatelessWidget {
  const SyncitemsregToStock({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StockSyncProvider(),
      child: const _SyncView(),
    );
  }
}

class _SyncView extends StatefulWidget {
  const _SyncView();

  @override
  State<_SyncView> createState() => _SyncViewState();
}

class _SyncViewState extends State<_SyncView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<Datafeed>().fetchBranches());
  }


  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _onSync() async {
    final provider = context.read<StockSyncProvider>();
    final datafeed = context.read<Datafeed>();

    final outcome = await provider.syncStockFromApi(datafeed);
    if (outcome == null || !mounted) return;

    _snack(
      outcome.message,
      switch (outcome.level) {
        SyncLevel.success => Colors.green,
        SyncLevel.warning => Colors.orange,
        SyncLevel.error => Colors.red,
      },
    );

    if (outcome.showErrors) _showErrorsDialog(provider.errors);
  }

  void _showErrorsDialog(List<String> errors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Sync Errors (${errors.length})',
            style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Text(
              errors.isEmpty ? 'No errors.' : errors.join('\n\n'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showApiInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('API Stock Sync',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: Colors.lightBlue)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.watch<StockSyncProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        title: const Text('Bulk Stock Upload',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          if (!p.syncing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.lightBlue),
                onPressed: _showApiInfo,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildApiSection(p),
                  const SizedBox(height: 24),
                  if (!p.hasRun)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: Colors.white24),
                            SizedBox(height: 16),
                            Text('Load stock data from the API to begin',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _buildInfoCard(p),
                    const SizedBox(height: 24),
                    _buildStatusSummary(p),
                    const SizedBox(height: 24),
                    _buildProgressSection(p),
                    if (p.errors.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _showErrorsDialog(p.errors),
                          icon: const Icon(Icons.error_outline),
                          label: Text('View Errors (${p.errors.length})'),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiSection(StockSyncProvider p) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_download_outlined,
                  color: p.syncing ? Colors.orange : Colors.lightBlue,
                  size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('API Stock Sync',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text('Load warehouse stock and save it to itemsreg.',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.tealAccent,
                side: const BorderSide(color: Colors.tealAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: p.syncing ? null : _onSync,
              icon: p.syncing
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_download_outlined),
              label: const Text('Load Stock From API',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(StockSyncProvider p) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.teal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('API Sync Details',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                const SizedBox(height: 4),
                Text(p.fileInfo,
                    style:
                    const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary(StockSyncProvider p) {
    return Row(
      children: [
        _statusCard('Created', p.itemsCreated, Colors.green),
        const SizedBox(width: 12),
        _statusCard('Updated', p.itemsUpdated, Colors.lightBlue),
        const SizedBox(width: 12),
        _statusCard('Skipped', p.rowsSkipped, Colors.orange),
        const SizedBox(width: 12),
        _statusCard('Errors', p.errors.length, Colors.red),
      ],
    );
  }

  Widget _statusCard(String label, int count, Color accent) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: accent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    color: accent, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(StockSyncProvider p) {
    final progress = p.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sync Progress',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.lightBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Colors.lightBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? Colors.green : Colors.lightBlue),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Page ${p.currentPage} of ${p.totalPages} - ${p.rowsProcessed} of '
              '${p.totalItemsReported} rows processed',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}







//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cloud_functions/cloud_functions.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../providers/Datafeed.dart';
//
// class SyncitemsregToStock extends StatefulWidget {
//   const SyncitemsregToStock({super.key});
//
//   @override
//   State<SyncitemsregToStock> createState() => _SyncitemsregToStockState();
// }
//
// class _SyncitemsregToStockState extends State<SyncitemsregToStock> {
//   final FirebaseFirestore db = FirebaseFirestore.instance;
//
//   static const String _itemsCollection = 'itemsreg';
//   static const int _apiPageSize = 500;
//   static const int _maxRetries = 3;
//
//   bool syncing = false;
//
//   int currentPage = 0;
//   int totalPages = 0;
//   int totalItemsReported = 0;
//
//   int rowsProcessed = 0;
//   int itemsCreated = 0;
//   int itemsUpdated = 0;
//   int rowsSkipped = 0;
//
//   final List<String> errors = [];
//
//   String fileInfo = 'Ready to load stock data from API.';
//
//
//   String sanitize(String input) => input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^a-z0-9_]'), '');
//
//   /// Handles 160, 160.0, "160.0" and viewer artifacts like "160.0JS:160".
//   double _num(dynamic v) {
//     if (v == null) return 0;
//     if (v is num) return v.toDouble();
//     final cleaned = v.toString().replaceAll(RegExp(r'JS:.*$'), '').trim();
//     return double.tryParse(cleaned) ?? 0;
//   }
//
//   void _snack(String msg, Color color) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
//   }
//
//   String _branchSlug(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^a-z0-9_]'), '');
//   String _branchKey(String companyId, String branchName) =>'${companyId.toLowerCase()}${_branchSlug(branchName)}';
//
//   Map<String, dynamic> _branchEntry({
//     required String branchName,
//     required dynamic balance,
//     required double cost,
//     required String staff,
//   }) {
//     final qty = _num(balance);
//     return {
//       'name': branchName,
//       'quantity': qty,
//       'netpieces': qty,
//       'stockin_pieces': qty,
//       'stock_value': qty * cost,
//       'lastupdate': FieldValue.serverTimestamp(),
//       'updatedby': staff,
//     };
//   }
//
//
//   Future<Map<String, dynamic>> _fetchPage(int page) async {
//     Object? lastError;
//     for (var attempt = 1; attempt <= _maxRetries; attempt++) {
//       try {
//         final callable = FirebaseFunctions.instance.httpsCallable(
//           'fetchStockPage',
//           options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
//         );
//         final result = await callable.call({'page': page, 'limit': _apiPageSize});
//         final decoded = Map<String, dynamic>.from(result.data as Map);
//         if (decoded['success'] == false) {
//           throw decoded['message']?.toString() ?? 'API reported failure.';
//         }
//         print('Fetched page $page successfully.');
//         return decoded;
//       } catch (e) {
//         lastError = e;
//         if (attempt < _maxRetries) {
//           await Future.delayed(Duration(seconds: attempt * 2));
//         }
//       }
//     }
//     throw 'Page $page failed after $_maxRetries attempts: $lastError';
//   }
//
//   Future<void> _syncStockFromApi() async {
//     if (syncing) return;
//
//     final datafeed = context.read<Datafeed>();
//     await datafeed.getdata();
//
//     final companyId = datafeed.companyid.trim();
//     final companyName = datafeed.company;
//
//     if (companyId.isEmpty) {
//       _snack('No company context found. Please log in again.', Colors.red);
//       return;
//     }
//
//     setState(() {
//       syncing = true;
//       currentPage = 0;
//       totalPages = 0;
//       totalItemsReported = 0;
//       rowsProcessed = 0;
//       itemsCreated = 0;
//       itemsUpdated = 0;
//       rowsSkipped = 0;
//       errors.clear();
//       fileInfo = 'Loading stock data from API...';
//     });
//
//     try {
//       var page = 1;
//
//       var savedCount = 0;
//       //const maxItems = 10;
//       var acknowledgedCount = 0;
//       while (true) {
//         //if (savedCount >= maxItems) break;
//
//         final body = await _fetchPage(page);
//
//
//         totalPages =(body['total_pages'] as num?)?.toInt() ?? page;
//
//         totalItemsReported =(body['total_items'] as num?)?.toInt() ?? 0;
//
//         final rawRows = body['data'];
//
//         if (rawRows is! List || rawRows.isEmpty) break;
//
//         if (mounted) {
//           setState(() {
//             currentPage = page;
//             fileInfo = 'Processing page $page of $totalPages...';
//           });
//         }
//
//         // Filter records with a positive balance.
//         final validRows = rawRows
//             .whereType<Map>()
//             .map((r) => Map<String, dynamic>.from(r))
//             .where((row) {
//           final balanceData = row['balance'];
//
//           if (balanceData is! Map) return false;
//
//           return balanceData.values.any((value) {
//             final amount = value is num
//                 ? value.toDouble()
//                 : double.tryParse(value?.toString() ?? '') ?? 0.0;
//
//             return amount > 0;
//           });
//         })
//             //.take(maxItems - savedCount)
//             .toList();
//
//         // if (validRows.isNotEmpty) {
//         //   try {
//         //     await _savePage(
//         //       rows: validRows,
//         //       datafeed: datafeed,
//         //       companyId: companyId,
//         //       companyName: companyName,
//         //     );
//         //
//         //     savedCount += validRows.length;
//         //   } catch (e) {
//         //     errors.add('Page $page: $e');
//         //   }
//         // }
//         if (validRows.isNotEmpty) {
//           List<String> savedIds = [];
//
//           try {
//             savedIds = await _savePage(
//               rows: validRows,
//               datafeed: datafeed,
//               companyId: companyId,
//               companyName: companyName,
//             );
//
//             savedCount += validRows.length;
//           } catch (e) {
//             errors.add('Page $page: $e');
//           }
//
//           // Acknowledge only what was saved. A failure here is reported
//           // separately so a saved page isn't shown as failed.
//           if (savedIds.isNotEmpty) {
//             try {
//               await _acknowledgeApiStockIds(savedIds);
//               acknowledgedCount += savedIds.length;
//             } catch (e) {
//               errors.add('Page $page acknowledgment: $e');
//             }
//           }
//         }
//         rowsProcessed += rawRows.length;
//
//         if (mounted) setState(() {});
//
//         //if (savedCount >= maxItems || page >= totalPages) break;
//         if (page >= totalPages) break;
//         page++;
//       }
//       if (mounted) {
//         setState(() {
//           fileInfo = 'Done. $itemsCreated created, $itemsUpdated updated, '
//               '$rowsSkipped skipped,$acknowledgedCount acknowledged, ${errors.length} page error(s).';
//         });
//       }
//
//       _snack(
//         errors.isEmpty
//             ? 'Synced ${itemsCreated + itemsUpdated} items to $_itemsCollection.'
//             : 'Synced with ${errors.length} error(s).',
//         errors.isEmpty ? Colors.green : Colors.orange,
//       );
//       if (errors.isNotEmpty) _showErrorsDialog();
//     } catch (error) {
//       if (mounted) setState(() => fileInfo = 'API sync failed.');
//       print('Stock API sync failed: $error');
//       _snack('Stock API sync failed: $error', Colors.red);
//     } finally {
//       if (mounted) setState(() => syncing = false);
//     }
//   }
//   String _str(dynamic v) => (v ?? '').toString().trim();
//
//   Timestamp _parseCreated(dynamic date, dynamic time) {
//     final d = _str(date);
//     final t = _str(time);
//     final parsed = DateTime.tryParse(t.isEmpty ? d : '$d $t');
//     return Timestamp.fromDate(parsed ?? DateTime.now());
//   }
//
//   String _weekOf(DateTime dt) {
//     final start = DateTime(dt.year, 1, 1);
//     return (((dt.difference(start).inDays + start.weekday - 1) ~/ 7) + 1)
//         .toString();
//   }
//
//   Future<List<String>> _savePage({
//     required List<Map<String, dynamic>> rows,
//     required Datafeed datafeed,
//     required String companyId,
//     required String companyName,
//   }) async {
//     final Map<String, Map<String, dynamic>> docs = {};
//
//     for (final row in rows) {
//       final name = _str(row['name']);
//       if (name.isEmpty) {
//         rowsSkipped++;
//         continue;
//       }
//
//       final rowCompany = datafeed.companyid.trim();
//       if (rowCompany.isNotEmpty &&
//           rowCompany.toLowerCase() != companyId.toLowerCase()) {
//         rowsSkipped++;
//         continue;
//       }
//
//       final itemId = _str(row['id']);
//       var barcode = _str(row['barcode']);
//       if (barcode.toLowerCase() == name.toLowerCase()) barcode =name.toLowerCase();
//
//       // ---- modes ----
//       final modes = <String, dynamic>{};
//       final boxPieces = _num(row['boxpieces']);
//       final rawModes = row['modes'];
//       if (rawModes is List) {
//         for (final m in rawModes.whereType<Map>()) {
//           final modeName = _str(m['mode']);
//           if (modeName.isEmpty) continue;
//           modes[modeName] = {
//
//             'id': modeName,
//             'name': modeName,
//             'qty': _num(m['quantity']),
//             'sp': _num(m['sprice']),
//             'wp': _num(m['wprice']),
//             'rp': _num(m['price']),
//             'cp': _num(m['cprice']),
//             'barcode': barcode,
//           };
//         }
//       }
//       final hasSingle =
//       modes.keys.any((k) => k.trim().toLowerCase() == 'single');
//
//       if (!hasSingle) {
//         final retail = _num(row['selling_price']);
//         final wholesale = _num(row['wselling_price']);
//
//         modes['Single'] = {
//           'id': 'Single',
//           'name': 'Single',
//           'qty': 1,
//           'sp': retail,
//           'wp': retail,
//           'rp': retail,
//           'cp': _num(row['cost_price']),
//           'barcode': barcode,
//         };
//       }
//       final staffName = datafeed.staff;
//       final cost = _num(row['cost_price']);
//       final branchbalance = <String, dynamic>{};
//
//       void addBranch(String branchName, dynamic bal) {
//         final bn = branchName.trim();
//         if (bn.isEmpty) return;
//         branchbalance[_branchKey(companyId, bn)] = _branchEntry(
//           branchName: bn,
//           balance: bal,
//           cost: cost,
//           staff: staffName,
//         );
//       }
//
//       final balanceField = row['balance'];
//
//       if (balanceField is Map) {
//         balanceField.forEach((branchName, bal) {
//           addBranch(_str(branchName), bal);
//         });
//       } else {
//         final ownBranch = _str(row['branch']);
//         if (ownBranch.isNotEmpty) addBranch(ownBranch, balanceField);
//       }
//
//       final created = _parseCreated(row['date'], row['time']);
//       final createdDt = created.toDate();
//
//       final data = <String, dynamic>{
//         'id': _str(row['id']),
//         'name': name,
//         'company': companyName,
//         'companyid': companyId,
//         'barcode': barcode,
//         'pcategory': _str(row['category']),
//         'producttype': _str(row['product_type']).isEmpty ? 'product' : _str(row['product_type']),
//         'imageurl': _str(row['image']),
//         'cp': _num(row['cost_price']),
//         'retailprice': _num(row['selling_price']),
//         'wholesaleprice': _num(row['wselling_price']),
//         'retailmarkup': _str(row['rmarkup']),
//         'wholesalemarkup': _str(row['wmarkup']),
//         'sminqty': _str(row['sqty']),
//         'wminqty': _str(row['wsaleqty']),
//         'warehouse': _str(row['warehouse']),
//         'staff': _str(row['staff']),
//         'branchbalance': branchbalance,
//         'modes': modes,
//         'modemore': modes.length > 1 || boxPieces > 1,
//         'day': createdDt.day.toString(),
//         'week': _weekOf(createdDt),
//         'month': createdDt.month.toString(),
//         'year': createdDt.year.toString(),
//         '_createdFromSource': created,
//       };
//
//       final existing = docs[itemId];
//       if (existing == null) {
//         docs[itemId] = data;
//       } else {
//         (existing['branchbalance'] as Map<String, dynamic>)
//             .addAll(branchbalance);
//         (existing['modes'] as Map<String, dynamic>).addAll(modes);
//         if ((existing['barcode'] as String).isEmpty && barcode.isNotEmpty) {
//           existing['barcode'] = barcode;
//         }
//       }
//     }
//
//     //if (docs.isEmpty) return;
//
//     final col = db.collection(_itemsCollection);
//     final snaps = await Future.wait(docs.keys.map((id) => col.doc(id).get()));
//     final existingIds = {
//       for (final s in snaps)
//         if (s.exists) s.id,
//     };
//
//     final batch = db.batch();
//     final staffName = datafeed.staff;
//
//     docs.forEach((id, data) {
//       final isNew = !existingIds.contains(id);
//       final sourceCreated = data.remove('_createdFromSource');
//
//       final payload = <String, dynamic>{
//         ...data,
//         'updatedat': FieldValue.serverTimestamp(),
//         'updatedby': staffName,
//         'lastModified': FieldValue.serverTimestamp(),
//         if (isNew) ...{
//           'createdat': sourceCreated,
//           'isActive': true,
//           'isHamper': false,
//         },
//       };
//
//       batch.set(col.doc(id), payload, SetOptions(merge: true));
//       isNew ? itemsCreated++ : itemsUpdated++;
//       print(payload);
//     });
//
//     await batch.commit();
//     return docs.keys.toList();
//   }
//
//   double get progress => totalPages == 0 ? 0 : (currentPage / totalPages).clamp(0.0, 1.0);
//
//   void _showErrorsDialog() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         backgroundColor: Theme.of(context).colorScheme.surface,
//         title: Text('Sync Errors (${errors.length})',
//             style: const TextStyle(color: Colors.white)),
//         content: SizedBox(
//           width: 520,
//           child: SingleChildScrollView(
//             child: Text(
//               errors.isEmpty ? 'No errors.' : errors.join('\n\n'),
//               style: const TextStyle(color: Colors.white70, fontSize: 12),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showApiInfo() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         backgroundColor: Theme.of(context).colorScheme.surface,
//         title: const Text('API Stock Sync',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close',
//                 style: TextStyle(color: Colors.lightBlue)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     Future.microtask(() => context.read<Datafeed>().fetchBranches());
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isMobile = MediaQuery.of(context).size.width < 768;
//     final hasRun = rowsProcessed > 0 || syncing;
//
//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
//         title: const Text('Bulk Stock Upload',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
//         elevation: 0,
//         actions: [
//           if (!syncing)
//             Padding(
//               padding: const EdgeInsets.only(right: 16),
//               child: IconButton(
//                 icon: const Icon(Icons.help_outline, color: Colors.lightBlue),
//                 onPressed: _showApiInfo,
//               ),
//             ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: EdgeInsets.symmetric(
//               horizontal: isMobile ? 16 : 24, vertical: 20),
//           child: Center(
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 1200),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildApiSection(),
//                   const SizedBox(height: 24),
//                   if (!hasRun)
//                     const Padding(
//                       padding: EdgeInsets.only(top: 24),
//                       child: Center(
//                         child: Column(
//                           children: [
//                             Icon(Icons.inventory_2_outlined,
//                                 size: 64, color: Colors.white24),
//                             SizedBox(height: 16),
//                             Text('Load stock data from the API to begin',
//                                 style: TextStyle(color: Colors.white54)),
//                           ],
//                         ),
//                       ),
//                     )
//                   else ...[
//                     _buildInfoCard(),
//                     const SizedBox(height: 24),
//                     _buildStatusSummary(),
//                     const SizedBox(height: 24),
//                     _buildProgressSection(),
//                     if (errors.isNotEmpty) ...[
//                       const SizedBox(height: 24),
//                       Align(
//                         alignment: Alignment.centerRight,
//                         child: ElevatedButton.icon(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.red.shade700,
//                             foregroundColor: Colors.white,
//                           ),
//                           onPressed: _showErrorsDialog,
//                           icon: const Icon(Icons.error_outline),
//                           label: Text('View Errors (${errors.length})'),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildApiSection() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Theme.of(context).colorScheme.surfaceContainerHighest,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.white12),
//       ),
//       padding: const EdgeInsets.all(20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.cloud_download_outlined,
//                   color: syncing ? Colors.orange : Colors.lightBlue, size: 24),
//               const SizedBox(width: 12),
//               const Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text('API Stock Sync',
//                         style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 16,
//                             fontWeight: FontWeight.w600)),
//                     SizedBox(height: 4),
//                     Text('Load warehouse stock and save it to itemsreg.',
//                         style: TextStyle(color: Colors.white54, fontSize: 12)),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             height: 48,
//             child: OutlinedButton.icon(
//               style: OutlinedButton.styleFrom(
//                 foregroundColor: Colors.tealAccent,
//                 side: const BorderSide(color: Colors.tealAccent),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8)),
//               ),
//               onPressed: syncing ? null : _syncStockFromApi,
//               icon: syncing
//                   ? const SizedBox(
//                   width: 18,
//                   height: 18,
//                   child: CircularProgressIndicator(strokeWidth: 2))
//                   : const Icon(Icons.cloud_download_outlined),
//               label: const Text('Load Stock From API',
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInfoCard() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Theme.of(context).colorScheme.surfaceContainerHighest,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.teal.withOpacity(0.3)),
//       ),
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           const Icon(Icons.info_outline, color: Colors.teal, size: 20),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('API Sync Details',
//                     style: TextStyle(
//                         color: Colors.white70,
//                         fontWeight: FontWeight.w600,
//                         fontSize: 12)),
//                 const SizedBox(height: 4),
//                 Text(fileInfo,
//                     style:
//                     const TextStyle(color: Colors.white54, fontSize: 13)),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatusSummary() {
//     return Row(
//       children: [
//         _statusCard('Created', itemsCreated, Colors.green),
//         const SizedBox(width: 12),
//         _statusCard('Updated', itemsUpdated, Colors.lightBlue),
//         const SizedBox(width: 12),
//         _statusCard('Skipped', rowsSkipped, Colors.orange),
//         const SizedBox(width: 12),
//         _statusCard('Errors', errors.length, Colors.red),
//       ],
//     );
//   }
//
//   Widget _statusCard(String label, int count, Color accent) {
//     return Expanded(
//       child: Container(
//         decoration: BoxDecoration(
//           color: accent.withOpacity(0.2),
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: accent.withOpacity(0.5)),
//         ),
//         padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//         child: Column(
//           children: [
//             Text('$count',
//                 style: TextStyle(
//                     color: accent, fontSize: 24, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 4),
//             Text(label,
//                 style: const TextStyle(color: Colors.white70, fontSize: 12)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildProgressSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             const Text('Sync Progress',
//                 style: TextStyle(
//                     color: Colors.white70, fontWeight: FontWeight.w600)),
//             Container(
//               padding:
//               const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.lightBlue.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(4),
//               ),
//               child: Text('${(progress * 100).toStringAsFixed(0)}%',
//                   style: const TextStyle(
//                       color: Colors.lightBlue,
//                       fontWeight: FontWeight.w600,
//                       fontSize: 12)),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         ClipRRect(
//           borderRadius: BorderRadius.circular(8),
//           child: LinearProgressIndicator(
//             value: progress,
//             minHeight: 8,
//             backgroundColor: Colors.white12,
//             valueColor: AlwaysStoppedAnimation<Color>(
//                 progress == 1.0 ? Colors.green : Colors.lightBlue),
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Page $currentPage of $totalPages - $rowsProcessed of '
//               '$totalItemsReported rows processed',
//           style: const TextStyle(color: Colors.white54, fontSize: 12),
//         ),
//       ],
//     );
//   }
//   Future<void> _acknowledgeApiStockIds(List<String> ids) async {
//     final recordIds = ids.where((id) => id.trim().isNotEmpty).toList();
//     if (recordIds.isEmpty) return;
//
//     try {
//       final callable = FirebaseFunctions.instance.httpsCallable(
//         'ackItems',
//         options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
//       );
//
//       final result = await callable.call({'ids': recordIds});
//       final data = Map<String, dynamic>.from(result.data as Map);
//
//       final updated = (data['updated'] as num?)?.toInt() ?? 0;
//       debugPrint('CALLBACK: updated $updated of ${recordIds.length} ids');
//     } on FirebaseFunctionsException catch (e) {
//       debugPrint('CALLBACK ERROR: ${e.code} ${e.message}');
//       throw 'Acknowledgment failed: ${e.message}';
//     }
//   }
//   // Future<void> _acknowledgeApiStockIds(List<String> ids) async {
//   //   try {
//   //     final recordIds = ids.where((id) => id.trim().isNotEmpty).toList();
//   //     if (recordIds.isEmpty) return;
//   //     final payload = {'ids': recordIds};
//   //     const String _stockCallbackApiUrl ='https://queenlatifahenterprise.com/pos/firebase/itemreg_callback';
//   //
//   //     final response = await http.post(
//   //       Uri.parse(_stockCallbackApiUrl),
//   //       headers: const {
//   //         'Content-Type': 'application/json',
//   //         'Accept': 'application/json',
//   //       },
//   //       body: jsonEncode(payload),
//   //     );
//   //
//   //     debugPrint('CALLBACK STATUS: ${response.statusCode}');
//   //
//   //     debugPrint('CALLBACK BODY: ${response.body}');
//   //
//   //     if (response.statusCode < 200 || response.statusCode >= 300) {
//   //       throw 'API acknowledgment returned HTTP '
//   //           '${response.statusCode}.';
//   //     }
//   //   } catch (e, stackTrace) {
//   //     debugPrint('CALLBACK ERROR: $e');
//   //
//   //     debugPrint(stackTrace.toString());
//   //
//   //     rethrow;
//   //   }
//   // }
//
// }