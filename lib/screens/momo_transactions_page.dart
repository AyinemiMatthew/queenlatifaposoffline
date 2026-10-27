import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class MomoTransactionsPage extends StatefulWidget {
  const MomoTransactionsPage({super.key});

  @override
  State<MomoTransactionsPage> createState() => _MomoTransactionsPageState();
}

class _MomoTransactionsPageState extends State<MomoTransactionsPage> {
  static final _dayFormat = DateFormat('EEEE, d MMMM yyyy');
  static final _timeFormat = DateFormat('h:mm a');
  static final _queryDayFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
  static final _amountFormat = NumberFormat.currency(
    locale: 'en_GH',
    symbol: 'GHS ',
    decimalDigits: 2,
  );

  late final Datafeed _datafeed;
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  List<_MomoTransaction> _transactions = [];
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  // UI-only state: which status the list is currently showing.
  _TransactionStatus? _statusFilter;

  // ---------------------------------------------------------------------------
  // BUSINESS LOGIC (unchanged)
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _datafeed = context.read<Datafeed>();
    Future.microtask(_loadTransactions);
  }

  Future<void> _loadTransactions() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final companyId = _datafeed.companyid;
      if (companyId.isEmpty) {
        throw StateError('No company is selected.');
      }

      final day = DateUtils.dateOnly(_selectedDay);
      final nextDay = day.add(const Duration(days: 1));
      final snapshot = await _datafeed.db
          .collection('momo')
          .where('companyid', isEqualTo: companyId)
          .where(
        'timestamp',
        isGreaterThanOrEqualTo: _queryDayFormat.format(day),
      )
          .where('timestamp', isLessThan: _queryDayFormat.format(nextDay))
          .get();
      final transactions =
      snapshot.docs
          .map((doc) => _MomoTransaction.fromMap(doc.id, doc.data()))
          .toList()
        ..sort(
              (a, b) => (b.timestamp ?? DateTime(0)).compareTo(
            a.timestamp ?? DateTime(0),
          ),
        );

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _transactions = transactions;
        _loading = false;
      });
    } catch (error) {
      print('Error loading transactions: $error');
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2000),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      helpText: 'SELECT TRANSACTION DAY',
    );
    if (picked == null || DateUtils.isSameDay(picked, _selectedDay)) return;
    setState(() => _selectedDay = DateUtils.dateOnly(picked));
    await _loadTransactions();
  }

  double get _pendingTotal => _transactions
      .where((transaction) => transaction.status == _TransactionStatus.pending)
      .fold(0, (total, transaction) => total + transaction.amount);

  double get _completedTotal => _transactions
      .where(
        (transaction) => transaction.status == _TransactionStatus.completed,
  )
      .fold(0, (total, transaction) => total + transaction.amount);

  double get _totalAmount =>
      _transactions.fold(0, (total, transaction) => total + transaction.amount);

  bool get _isToday => DateUtils.isSameDay(_selectedDay, DateTime.now());

  int _countFor(_TransactionStatus status) =>
      _transactions.where((transaction) => transaction.status == status).length;

  // ---------------------------------------------------------------------------
  // UI-ONLY HELPERS
  // ---------------------------------------------------------------------------

  /// Quick-pick a day from the day strip (same two steps as _selectDay).
  Future<void> _goToDay(DateTime day) async {
    if (DateUtils.isSameDay(day, _selectedDay)) return;
    setState(() => _selectedDay = DateUtils.dateOnly(day));
    await _loadTransactions();
  }

  List<_MomoTransaction> get _visibleTransactions => _statusFilter == null
      ? _transactions
      : _transactions.where((t) => t.status == _statusFilter).toList();

  void _showDetails(_MomoTransaction t) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DetailsSheet(
        transaction: t,
        dayFormat: _dayFormat,
        timeFormat: _timeFormat,
        amountFormat: _amountFormat,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = _visibleTransactions;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('MoMo transactions'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh transactions',
            onPressed: _loading ? null : _loadTransactions,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTransactions,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _DayStrip(
                    selectedDay: _selectedDay,
                    onDaySelected: _goToDay,
                    onPickDate: _selectDay,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isToday ? 'Today' : 'Selected day',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dayFormat.format(_selectedDay),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HeroCard(
                    amount: _amountFormat.format(_totalAmount),
                    count: _transactions.length,
                    loading: _loading,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: 'Completed',
                          amount: _amountFormat.format(_completedTotal),
                          count: _countFor(_TransactionStatus.completed),
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Pending',
                          amount: _amountFormat.format(_pendingTotal),
                          count: _countFor(_TransactionStatus.pending),
                          icon: Icons.schedule_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _StatusFilterBar(
                    selected: _statusFilter,
                    total: _transactions.length,
                    completed: _countFor(_TransactionStatus.completed),
                    pending: _countFor(_TransactionStatus.pending),
                    onChanged: (s) => setState(() => _statusFilter = s),
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const _LoadingSkeleton()
                  else if (_error != null)
                    _MessageState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Could not load transactions',
                      message: _error!,
                      action: FilledButton.tonalIcon(
                        onPressed: _loadTransactions,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    )
                  else if (_transactions.isEmpty)
                      _MessageState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No MoMo transactions',
                        message: 'There are no transactions for this day.',
                        action: OutlinedButton.icon(
                          onPressed: _selectDay,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text('Try another date'),
                        ),
                      )
                    else if (visible.isEmpty)
                        _MessageState(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'Nothing here',
                          message: 'No transactions match this status.',
                          action: TextButton(
                            onPressed: () => setState(() => _statusFilter = null),
                            child: const Text('Show all'),
                          ),
                        )
                      else
                        ...visible.map(
                              (transaction) => _TransactionTile(
                            transaction: transaction,
                            timeFormat: _timeFormat,
                            amountFormat: _amountFormat,
                            onTap: () => _showDetails(transaction),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DAY STRIP
// =============================================================================

class _DayStrip extends StatelessWidget {
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onPickDate;

  const _DayStrip({
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final days = List.generate(7, (i) => today.subtract(Duration(days: i)));
    final isCustom = !days.any((d) => DateUtils.isSameDay(d, selectedDay));

    return SizedBox(
      height: 70,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Calendar picker (shows the chosen date when it is outside the strip)
          GestureDetector(
            onTap: onPickDate,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isCustom ? 78 : 56,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isCustom
                    ? colors.primary
                    : colors.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: isCustom ? colors.onPrimary : colors.onSurface,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCustom ? DateFormat('d MMM').format(selectedDay) : 'Pick',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCustom ? colors.onPrimary : colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final day in days)
            _DayChip(
              day: day,
              isToday: DateUtils.isSameDay(day, today),
              selected: DateUtils.isSameDay(day, selectedDay),
              onTap: () => onDaySelected(day),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fg = selected ? colors.onPrimary : colors.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary
              : colors.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isToday ? 'Today' : DateFormat('EEE').format(day),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg.withValues(alpha: selected ? 0.9 : 0.65),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SUMMARY
// =============================================================================

class _HeroCard extends StatelessWidget {
  final String amount;
  final int count;
  final bool loading;

  const _HeroCard({
    required this.amount,
    required this.count,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, Color.lerp(colors.primary, Colors.black, 0.4)!],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: colors.onPrimary.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                'Total amount',
                style: TextStyle(
                  color: colors.onPrimary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${loading ? '…' : count} ${count == 1 ? 'payment' : 'payments'}',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              loading ? 'GHS —' : amount,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: colors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String amount;
  final int count;
  final IconData icon;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STATUS FILTER
// =============================================================================

class _StatusFilterBar extends StatelessWidget {
  final _TransactionStatus? selected;
  final int total;
  final int completed;
  final int pending;
  final ValueChanged<_TransactionStatus?> onChanged;

  const _StatusFilterBar({
    required this.selected,
    required this.total,
    required this.completed,
    required this.pending,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transactions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_TransactionStatus?>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.comfortable,
            ),
            segments: [
              ButtonSegment(value: null, label: Text('All ($total)')),
              ButtonSegment(
                value: _TransactionStatus.completed,
                label: Text('Completed ($completed)'),
              ),
              ButtonSegment(
                value: _TransactionStatus.pending,
                label: Text('Pending ($pending)'),
              ),
            ],
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TILE
// =============================================================================

Color _statusColor(_TransactionStatus s, ColorScheme colors) => switch (s) {
  _TransactionStatus.completed => const Color(0xFF10B981),
  _TransactionStatus.pending => const Color(0xFFF59E0B),
  _ => colors.error,
};

String _statusLabel(_MomoTransaction t) => switch (t.status) {
  _TransactionStatus.completed => 'Completed',
  _TransactionStatus.pending => 'Pending',
  _ => t.rawStatus.isEmpty ? 'Other' : t.rawStatus,
};

class _TransactionTile extends StatelessWidget {
  final _MomoTransaction transaction;
  final DateFormat timeFormat;
  final NumberFormat amountFormat;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.transaction,
    required this.timeFormat,
    required this.amountFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(transaction.status, colors);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status accent bar
                Container(width: 5, color: statusColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            color: statusColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.sender.isEmpty
                                    ? 'Unknown sender'
                                    : transaction.sender,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  _DetailLabel(
                                    icon: Icons.schedule_rounded,
                                    text: transaction.timestamp == null
                                        ? 'Time unavailable'
                                        : timeFormat.format(
                                      transaction.timestamp!,
                                    ),
                                  ),
                                  if (transaction.transactionId.isNotEmpty)
                                    _DetailLabel(
                                      icon: Icons.tag_rounded,
                                      text: transaction.transactionId,
                                    ),
                                  if (transaction.staff.isNotEmpty)
                                    _DetailLabel(
                                      icon: Icons.person_outline_rounded,
                                      text: transaction.staff,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              amountFormat.format(transaction.amount),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            _StatusBadge(
                              label: _statusLabel(transaction),
                              color: statusColor,
                              icon: transaction.status ==
                                  _TransactionStatus.completed
                                  ? Icons.check_circle_rounded
                                  : transaction.status ==
                                  _TransactionStatus.pending
                                  ? Icons.schedule_rounded
                                  : Icons.info_outline_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// DETAILS SHEET
// =============================================================================

class _DetailsSheet extends StatelessWidget {
  final _MomoTransaction transaction;
  final DateFormat dayFormat;
  final DateFormat timeFormat;
  final NumberFormat amountFormat;

  const _DetailsSheet({
    required this.transaction,
    required this.dayFormat,
    required this.timeFormat,
    required this.amountFormat,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(transaction.status, colors);
    final ts = transaction.timestamp;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              amountFormat.format(transaction.amount),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _StatusBadge(
              label: _statusLabel(transaction),
              color: statusColor,
              icon: transaction.status == _TransactionStatus.completed
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
            ),
            const SizedBox(height: 20),
            _SheetRow(
              label: 'Sender',
              value: transaction.sender.isEmpty ? '—' : transaction.sender,
            ),
            _SheetRow(
              label: 'Date',
              value: ts == null ? '—' : dayFormat.format(ts),
            ),
            _SheetRow(
              label: 'Time',
              value: ts == null ? '—' : timeFormat.format(ts),
            ),
            _SheetRow(
              label: 'Transaction ID',
              value: transaction.transactionId.isEmpty
                  ? '—'
                  : transaction.transactionId,
              copyable: transaction.transactionId.isNotEmpty,
            ),
            _SheetRow(
              label: 'Staff',
              value: transaction.staff.isEmpty ? '—' : transaction.staff,
            ),
            _SheetRow(label: 'Record ID', value: transaction.id, copyable: true),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;

  const _SheetRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (copyable)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$label copied')));
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// LOADING / MESSAGE STATES
// =============================================================================

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(
        4,
            (_) => Container(
          height: 74,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

// =============================================================================
// MODEL (unchanged)
// =============================================================================

enum _TransactionStatus { completed, pending, other }

class _MomoTransaction {
  final String id;
  final String sender;
  final String transactionId;
  final String staff;
  final String rawStatus;
  final double amount;
  final DateTime? timestamp;
  final _TransactionStatus status;

  const _MomoTransaction({
    required this.id,
    required this.sender,
    required this.transactionId,
    required this.staff,
    required this.rawStatus,
    required this.amount,
    required this.timestamp,
    required this.status,
  });

  factory _MomoTransaction.fromMap(String id, Map<String, dynamic> data) {
    final rawStatus = (data['status'] ?? '').toString().trim();
    final normalizedStatus = rawStatus.toLowerCase();
    final status = switch (normalizedStatus) {
      'saved' ||
      'success' ||
      'complete' ||
      'completed' => _TransactionStatus.completed,
      'pending' => _TransactionStatus.pending,
      _ => _TransactionStatus.other,
    };
    final rawAmount = data['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0;

    return _MomoTransaction(
      id: id,
      sender: (data['sender'] ?? '').toString(),
      transactionId: (data['transactionId'] ?? '').toString(),
      staff: (data['staff'] ?? '').toString(),
      rawStatus: rawStatus,
      amount: amount,
      timestamp: _parseTimestamp(data['timestamp']),
      status: status,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }
}