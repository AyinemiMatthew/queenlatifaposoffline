import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/ReportProvider.dart';
import 'package:kologsoft/providers/item_provider.dart';
import 'package:provider/provider.dart';

import '../models/itemregmodel.dart';

class SyncItemtoZero extends StatefulWidget {
  const SyncItemtoZero({super.key});

  @override
  State<SyncItemtoZero> createState() => _SyncItemtoZeroState();
}

class _SyncItemtoZeroState extends State<SyncItemtoZero> {
  // ── Single-item fields
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  ItemModel? _selectedItem;
  bool _showSuggestions = false;
  bool _selecting = false;
  bool _selectedItemOrphaned = false;
  bool _checkingOrphan = false;
  int _orphanCheckToken = 0;

  // ── Shared fields
  String? _selectedBranchId;
  String? _selectedBranchName;
  bool _syncing = false;
  String? _resultMessage;
  bool _resultSuccess = false;

  // tab: 0 = single item, 1 = all items in branch
  int _tab = 0;
  int _bulkDone = 0;
  int _bulkTotal = 0;
  final List<String> _bulkLog = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<Datafeed>().fetchItems();
      context.read<Datafeed>().fetchBranches();
      context.read<ReportProvider>().fetchstockreport();
      if (!mounted) return;
      _searchController.addListener(_onSearchChanged);
    });
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_selecting) return;
    setState(() {
      _showSuggestions = _searchController.text.isNotEmpty;
      _selectedItem = null;
      _selectedItemOrphaned = false;
      _resultMessage = null;
    });
  }

  void _selectItem(ItemModel item) {
    _selecting = true;
    setState(() {
      _selectedItem = item;
      _searchController.text = item.name;
      _showSuggestions = false;
      _resultMessage = null;
    });
    _selecting = false;
    _searchFocus.unfocus();
    _refreshOrphanStatus();
  }

  Future<Set<String>> _fetchBranchStockReportItemIds(String branchId) async {
    await context.read<ReportProvider>().fetchstockreport(
      selectedDate: DateTimeRange(
        start: DateTime(2000, 1, 1),
        end: DateTime.now(),
      ),
      selectedBranch: branchId,
    );
    final stockreport = context.read<ReportProvider>().filterstockreport();
    return context.read<ItemProvider>().stockReportItemIds(stockreport);
  }

  Future<void> _refreshOrphanStatus() async {
    if (_selectedItem == null || _selectedBranchId == null) {
      setState(() => _selectedItemOrphaned = false);
      return;
    }
    final hasBranchBalance =
        _selectedItem!.branchbalance != null &&
        _selectedItem!.branchbalance!.containsKey(_selectedBranchId);
    if (!hasBranchBalance) {
      setState(() => _selectedItemOrphaned = false);
      return;
    }
    final token = ++_orphanCheckToken;
    setState(() => _checkingOrphan = true);
    final ids = await _fetchBranchStockReportItemIds(_selectedBranchId!);
    if (!mounted || token != _orphanCheckToken) return;
    setState(() {
      _selectedItemOrphaned = !ids.contains(_selectedItem!.id);
      _checkingOrphan = false;
    });
  }

  // Single item sync
  Future<void> _syncBalance() async {
    if (_selectedItem == null || _selectedBranchId == null) return;
    setState(() {
      _syncing = true;
      _resultMessage = null;
    });
    try {
      final balance = await context
          .read<ItemProvider>()
          .syncSingleBranchBalance(
            datafeed: context.read<Datafeed>(),
            itemId: _selectedItem!.id,
            branchId: _selectedBranchId!,
            resetToZero: _selectedItemOrphaned,
          );
      setState(() {
        _resultMessage = _selectedItemOrphaned
            ? 'Synced  ${_selectedItem!.name}  →  $_selectedBranchName  |  Reset to 0 pcs (not in stock report)'
            : 'Synced  ${_selectedItem!.name}  →  $_selectedBranchName  |  $balance pcs';
        _resultSuccess = true;
      });
    } catch (e) {
      setState(() {
        _resultMessage = 'Error: $e';
        _resultSuccess = false;
      });
    } finally {
      setState(() => _syncing = false);
    }
  }

  //Bulk sync: all items in selected branch

  Future<void> _syncAllItems() async {
    if (_selectedBranchId == null) return;

    final datafeed = context.read<Datafeed>();

    setState(() {
      _syncing = true;
      _bulkDone = 0;
      _bulkTotal = 0;
      _bulkLog.clear();
      _resultMessage = null;
    });

    try {
      // Build stock report for the selected branch
      await context.read<ReportProvider>().fetchstockreport(
        selectedDate: DateTimeRange(
          start: DateTime(2000, 1, 1),
          end: DateTime.now(),
        ),
        selectedBranch: _selectedBranchId,
      );

      final stockRows = context
          .read<ReportProvider>()
          .filterstockreport()
          .where((e) => (e['itemid'] ?? '').toString().isNotEmpty)
          .toList();
      final orphanedItems = context
          .read<ItemProvider>()
          .itemsMissingFromStockReport(
            items: datafeed.items,
            stockRows: stockRows,
            branchId: _selectedBranchId!,
          );

      if (stockRows.isEmpty && orphanedItems.isEmpty) {
        setState(() {
          _syncing = false;
          _resultSuccess = false;
          _resultMessage =
              'No stock report items found for $_selectedBranchName.';
        });
        return;
      }

      setState(() {
        _bulkTotal = stockRows.length + orphanedItems.length;
      });
      final summary = await context.read<ItemProvider>().syncBranchBalanceRows(
        datafeed: datafeed,
        branchId: _selectedBranchId!,
        stockRows: stockRows,
        zeroBalanceItems: orphanedItems,
        onProgress: (completed, _) {
          if (mounted) setState(() => _bulkDone = completed);
        },
      );
      _bulkLog
        ..clear()
        ..addAll(summary.entries.map((entry) => entry.message));

      setState(() {
        _syncing = false;
        _resultSuccess = summary.errorCount == 0;
        _resultMessage =
            'Done: ${summary.successCount} synced${summary.errorCount > 0 ? ', ${summary.errorCount} failed' : ''} — $_selectedBranchName';
      });
    } catch (e) {
      setState(() {
        _syncing = false;
        _resultSuccess = false;
        _resultMessage = 'Error syncing items: $e';
      });
    }
  }

  //UI helpers
  static const _cardBg = Color(0xFF162032);

  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _surfaceColor => _isLightTheme
      ? Theme.of(context).colorScheme.surface
      : const Color(0xFF111E2E);
  Color get _fieldFillColor => _isLightTheme
      ? Theme.of(context).colorScheme.surface
      : Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _mutedTextColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : Colors.white38;
  Color get _descriptionTextColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : Colors.white.withOpacity(0.55);
  Color get _secondaryTextColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : Colors.white54;
  Color get _faintTextColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : Colors.white24;
  Color get _quietTextColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : Colors.white30;
  Color get _prominentTextColor => _isLightTheme ? _textColor : Colors.white70;
  Color get _subtleTextColor => _isLightTheme ? _textColor : Colors.white60;
  Color get _cardColor => _isLightTheme ? _surfaceColor : _cardBg;
  Color get _subtleBorderColor => _isLightTheme
      ? Theme.of(context).colorScheme.outlineVariant
      : Colors.white10;
  Color get _suggestionBorderColor => _isLightTheme
      ? Theme.of(context).colorScheme.outlineVariant
      : const Color(0xFF3B8BEB).withOpacity(0.2);

  InputDecoration _dec(String label, {Widget? suffix}) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
    ),
    filled: true,
    fillColor: _fieldFillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffix,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.primary,
        width: 1.5,
      ),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        color: _mutedTextColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _isLightTheme ? _textColor : Colors.white70,
        ),
        title: Text(
          'Sync Branch Balance',
          style: TextStyle(
            color: _isLightTheme ? _textColor : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _subtleBorderColor, height: 1),
        ),
      ),
      body: Consumer<Datafeed>(
        builder: (context, provider, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 640;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 32,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _isLightTheme
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest
                                : const Color(0xFF1A3A5C).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isLightTheme
                                  ? _subtleBorderColor
                                  : const Color(0xFF3B8BEB).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sync_alt,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Sync a single item or all items in a branch.',
                                  style: TextStyle(
                                    color: _descriptionTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        //Tab toggle
                        Container(
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _subtleBorderColor),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              _tabBtn('Single Item', 0),
                              const SizedBox(width: 6),
                              _tabBtn('All Items in Branch', 1),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        Container(
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _subtleBorderColor),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _label('BRANCH'),
                              DropdownButtonFormField<String>(
                                value: _selectedBranchId,
                                isExpanded: true,
                                dropdownColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: _mutedTextColor,
                                ),
                                decoration: _dec('Select branch…'),
                                items: provider.branches
                                    .fold<Map<String, dynamic>>({}, (m, b) {
                                      if (b.id != null &&
                                          b.id!.isNotEmpty &&
                                          !m.containsKey(b.id))
                                        m[b.id!] = b;
                                      return m;
                                    })
                                    .values
                                    .map(
                                      (b) => DropdownMenuItem<String>(
                                        value: b.id as String,
                                        child: Text(
                                          b.branchname as String,
                                          style: TextStyle(color: _textColor),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _syncing
                                    ? null
                                    : (val) {
                                        final branch = provider.branches
                                            .firstWhere((b) => b.id == val);
                                        setState(() {
                                          _selectedBranchId = val;
                                          _selectedBranchName =
                                              branch.branchname;
                                          _resultMessage = null;
                                          _bulkLog.clear();
                                          _bulkDone = 0;
                                          _bulkTotal = 0;
                                        });
                                        // Auto-trigger sync based on current tab
                                        if (_tab == 0) {
                                          _refreshOrphanStatus();
                                        } else if (_tab == 1) {
                                          // All items tab: auto-start sync
                                          _syncAllItems();
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (_tab == 0) ...[
                          _buildSingleItemCard(provider),
                        ] else ...[
                          _buildBulkInfoCard(provider),
                        ],

                        const SizedBox(height: 14),

                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _canSync(provider) ? _onSync : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B8BEB),
                              disabledBackgroundColor: const Color(
                                0xFF3B8BEB,
                              ).withOpacity(0.25),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            icon: _syncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.sync,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                            label: Text(
                              _syncing
                                  ? (_tab == 1
                                        ? 'Syncing $_bulkDone / $_bulkTotal…'
                                        : 'Saving…')
                                  : (_tab == 1
                                        ? 'Sync All Items in Branch'
                                        : 'Save Balance Update'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                        if (_tab == 1 && _syncing && _bulkTotal > 0) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _bulkDone / _bulkTotal,
                              minHeight: 6,
                              backgroundColor: _isLightTheme
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest
                                  : Colors.white12,
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF3B8BEB),
                              ),
                            ),
                          ),
                        ],

                        if (_resultMessage != null) ...[
                          const SizedBox(height: 14),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _resultSuccess
                                  ? Colors.green.withOpacity(0.08)
                                  : Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _resultSuccess
                                    ? Colors.green.withOpacity(0.35)
                                    : Colors.red.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _resultSuccess
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  color: _resultSuccess
                                      ? Colors.green
                                      : Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _resultMessage!,
                                    style: TextStyle(
                                      color: _resultSuccess
                                          ? (_isLightTheme
                                                ? Colors.green[800]
                                                : Colors.green[300])
                                          : (_isLightTheme
                                                ? Colors.red[800]
                                                : Colors.red[300]),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (_tab == 1 && _bulkLog.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 240),
                            decoration: BoxDecoration(
                              color: _surfaceColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _subtleBorderColor),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(10),
                              itemCount: _bulkLog.length,
                              itemBuilder: (_, i) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  _bulkLog[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _bulkLog[i].startsWith('✓')
                                        ? (_isLightTheme
                                              ? Colors.green[800]
                                              : Colors.green[300])
                                        : _bulkLog[i].startsWith('⊘')
                                        ? (_isLightTheme
                                              ? Colors.orange[800]
                                              : Colors.orange[300])
                                        : (_isLightTheme
                                              ? Colors.red[800]
                                              : Colors.red[300]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _tabBtn(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: _syncing
            ? null
            : () => setState(() {
                _tab = index;
                _resultMessage = null;
                _bulkLog.clear();
                _bulkDone = 0;
                _bulkTotal = 0;
              }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(
                    0xFF3B8BEB,
                  ).withOpacity(_isLightTheme ? 0.1 : 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? const Color(0xFF3B8BEB).withOpacity(0.5)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? const Color(0xFF3B8BEB) : _mutedTextColor,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleItemCard(Datafeed provider) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _subtleBorderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('ITEM'),
          TextFormField(
            controller: _searchController,
            focusNode: _searchFocus,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
            ),
            onTap: () {
              if (_searchController.text.isNotEmpty) {
                setState(() => _showSuggestions = true);
              }
            },
            decoration: _dec(
              'Search by name or barcode',
              suffix: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, color: _mutedTextColor, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _selectedItem = null;
                          _selectedItemOrphaned = false;
                          _showSuggestions = false;
                          _resultMessage = null;
                        });
                      },
                    )
                  : Icon(Icons.search, color: _faintTextColor, size: 18),
            ),
          ),

          // selected chip
          if (_selectedItem != null && !_showSuggestions) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B8BEB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF3B8BEB).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF3B8BEB),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedItem!.name,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    _selectedItem!.barcode,
                    style: TextStyle(color: _mutedTextColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (_checkingOrphan) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _isLightTheme
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Checking stock report…',
                    style: TextStyle(color: _mutedTextColor, fontSize: 11),
                  ),
                ],
              ),
            ] else if (_selectedItemOrphaned) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Not found in stock report for $_selectedBranchName. Balance will be reset to 0.',
                        style: TextStyle(
                          color: _isLightTheme
                              ? Colors.orange[900]
                              : Colors.orange[300],
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // suggestions
          if (_showSuggestions) ...[
            const SizedBox(height: 6),
            _buildSuggestions(provider),
          ],
        ],
      ),
    );
  }

  Widget _buildBulkInfoCard(Datafeed provider) {
    if (_selectedBranchId == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _subtleBorderColor),
        ),
        child: Text(
          'Select a branch above to see how many items will be synced.',
          style: TextStyle(color: _mutedTextColor, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    final eligible = provider.items
        .where((i) => i.isActive == true)
        .where(
          (i) =>
              i.branchbalance != null &&
              i.branchbalance!.containsKey(_selectedBranchId),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _subtleBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFF3B8BEB),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${eligible.length} item${eligible.length == 1 ? '' : 's'} will be synced for $_selectedBranchName.',
                  style: TextStyle(color: _prominentTextColor, fontSize: 13),
                ),
              ),
            ],
          ),
          if (eligible.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: _subtleBorderColor, height: 1),
            const SizedBox(height: 10),
            // preview list (first 5)
            ...eligible
                .take(5)
                .map(
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: _faintTextColor,
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            i.name,
                            style: TextStyle(
                              color: _secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (eligible.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${eligible.length - 5} more…',
                  style: TextStyle(color: _quietTextColor, fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestions(Datafeed provider) {
    final query = _searchController.text.toLowerCase();
    final filtered = provider.items
        .where((i) => i.isActive == true)
        .where(
          (i) =>
              i.name.toLowerCase().contains(query) ||
              i.barcode.toLowerCase().contains(query) ||
              i.pcategory.toLowerCase().contains(query),
        )
        .take(10)
        .toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No items found for "$query"',
          style: TextStyle(color: _mutedTextColor, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _suggestionBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: filtered.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: _subtleBorderColor),
        itemBuilder: (context, index) {
          final item = filtered[index];
          final bb = item.branchbalance;
          final branchPieces = _selectedBranchId != null && bb != null
              ? (bb[_selectedBranchId] as Map<String, dynamic>?) != null
                    ? (bb[_selectedBranchId]
                          as Map<String, dynamic>?)!['netpieces']
                    : null
              : null;

          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3B8BEB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF3B8BEB),
                size: 16,
              ),
            ),
            title: Text(
              item.name,
              style: TextStyle(
                color: _textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '${item.pcategory}  ·  ${item.barcode}',
              style: TextStyle(color: _mutedTextColor, fontSize: 11),
            ),
            trailing: branchPieces != null
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isLightTheme
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$branchPieces pcs',
                      style: TextStyle(color: _subtleTextColor, fontSize: 11),
                    ),
                  )
                : Icon(Icons.chevron_right, color: _faintTextColor, size: 16),
            onTap: () => _selectItem(item),
          );
        },
      ),
    );
  }

  // Helpers
  bool _canSync(Datafeed provider) {
    if (_syncing || _selectedBranchId == null) return false;
    if (_tab == 0) return _selectedItem != null;
    // tab 1: need at least one eligible item
    return provider.items.any(
      (i) =>
          i.isActive == true &&
          i.branchbalance != null &&
          i.branchbalance!.containsKey(_selectedBranchId),
    );
  }

  void _onSync() {
    if (_tab == 0) {
      _syncBalance();
    } else {
      _syncAllItems();
    }
  }
}
