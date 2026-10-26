import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dashboardStats.dart';
import '../providers/Datafeed.dart';

class _DebtActivity {
  final DateTime date;
  double debtAdded = 0;
  double payments = 0;

  _DebtActivity(this.date);
}

class _DebtTrendPoint {
  final DateTime date;
  final double debtAdded;
  final double payments;
  final double balance;
  final FlSpot spot;

  const _DebtTrendPoint({
    required this.date,
    required this.debtAdded,
    required this.payments,
    required this.balance,
    required this.spot,
  });
}

class TotalDebtWidget extends StatefulWidget {
  final double cwidth;

  const TotalDebtWidget({super.key, required this.cwidth});

  @override
  State<TotalDebtWidget> createState() => _TotalDebtWidgetState();
}

class _TotalDebtWidgetState extends State<TotalDebtWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  double _currentDebt = 0.0;

  Stream<List<_DebtTrendPoint>> _debtHistoryStream({
    required Datafeed datafeed,
    required bool isSuperAdmin,
    required double currentDebt,
  }) {
    final salesQuery = datafeed.db
        .collection('sales')
        .where('companyId', isEqualTo: datafeed.companyid);
    final paymentsQuery = datafeed.db
        .collection('debtpayment')
        .where('companyid', isEqualTo: datafeed.companyid);

    return Stream<List<_DebtTrendPoint>>.multi((controller) {
      QuerySnapshot<Map<String, dynamic>>? salesSnapshot;
      QuerySnapshot<Map<String, dynamic>>? paymentsSnapshot;

      List<_DebtTrendPoint> buildPoints() {
        final activityByDate = <DateTime, _DebtActivity>{};

        DateTime? parseDate(dynamic value) {
          if (value is Timestamp) return value.toDate();
          if (value is DateTime) return value;
          return DateTime.tryParse(value?.toString() ?? '');
        }

        double amountOf(dynamic value) {
          if (value is num) return value.toDouble();
          return double.tryParse(value?.toString() ?? '') ?? 0;
        }

        bool matchesBranch(Map<String, dynamic> data) {
          return isSuperAdmin ||
              (data['branchId'] ?? data['branchid'] ?? '').toString() ==
                  datafeed.branchid;
        }

        void addActivity(
          DateTime date, {
          double debtAdded = 0,
          double payments = 0,
        }) {
          final day = DateTime(date.year, date.month, date.day);
          final activity = activityByDate.putIfAbsent(
            day,
            () => _DebtActivity(day),
          );
          activity.debtAdded += debtAdded;
          activity.payments += payments;
        }

        for (final document in salesSnapshot!.docs) {
          final sale = document.data();
          if (!matchesBranch(sale) || sale['isreturned'] == true) continue;

          final due = math.max(
            0.0,
            amountOf(sale['totalamount']) - amountOf(sale['amountPaid']),
          );
          final date =
              parseDate(sale['createdAt']) ?? parseDate(sale['dateymd']);
          if (due > 0 && date != null) {
            addActivity(date, debtAdded: due);
          }
        }

        for (final document in paymentsSnapshot!.docs) {
          final payment = document.data();
          if (!matchesBranch(payment)) continue;
          final date =
              parseDate(payment['createdat']) ?? parseDate(payment['date']);
          final amount = amountOf(payment['amount']);
          if (date != null && amount > 0) {
            addActivity(date, payments: amount);
          }
        }

        final activities = activityByDate.values.toList()
          ..sort((a, b) => a.date.compareTo(b.date));
        final netActivity = activities.fold<double>(
          0,
          (total, activity) => total + activity.debtAdded - activity.payments,
        );
        var balance = currentDebt - netActivity;
        final points = <_DebtTrendPoint>[
          _DebtTrendPoint(
            date: activities.isEmpty
                ? DateTime.now()
                : activities.first.date.subtract(const Duration(days: 1)),
            debtAdded: 0,
            payments: 0,
            balance: balance,
            spot: FlSpot(0, balance),
          ),
        ];

        for (var i = 0; i < activities.length; i++) {
          final activity = activities[i];
          balance += activity.debtAdded - activity.payments;
          points.add(
            _DebtTrendPoint(
              date: activity.date,
              debtAdded: activity.debtAdded,
              payments: activity.payments,
              balance: balance,
              spot: FlSpot((i + 1).toDouble(), balance),
            ),
          );
        }
        return points;
      }

      void emitIfReady() {
        if (salesSnapshot != null && paymentsSnapshot != null) {
          controller.add(buildPoints());
        }
      }

      final salesSubscription = salesQuery.snapshots().listen((snapshot) {
        salesSnapshot = snapshot;
        emitIfReady();
      }, onError: controller.addError);
      final paymentsSubscription = paymentsQuery.snapshots().listen((snapshot) {
        paymentsSnapshot = snapshot;
        emitIfReady();
      }, onError: controller.addError);

      controller.onCancel = () {
        salesSubscription.cancel();
        paymentsSubscription.cancel();
      };
    });
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _animation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  void _animateTo(double newValue) {
    _animation = Tween<double>(
      begin: _currentDebt,
      end: newValue,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _currentDebt = newValue;

    _controller
      ..reset()
      ..forward();
  }

  double _debtRatio(double debt, double stockValue) {
    if (stockValue <= 0) {
      return debt > 0 ? 1.0 : 0.0;
    }

    return debt / stockValue;
  }

  Color _debtColor(double debt, double stockValue) {
    final ratio = _debtRatio(debt, stockValue);
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (ratio <= 0.25) {
      return isLight ? const Color(0xFF15803D) : Colors.greenAccent;
    }

    if (ratio <= 0.50) {
      return isLight ? const Color(0xFFB45309) : Colors.orangeAccent;
    }

    if (ratio <= 0.75) {
      return isLight ? const Color(0xFFC2410C) : Colors.deepOrangeAccent;
    }

    return isLight ? const Color(0xFFB91C1C) : Colors.redAccent;
  }

  String _debtStatus(double debt, double stockValue) {
    // No stock value available
    if (stockValue <= 0) {
      if (debt > 0) {
        return "Critical";
      }

      return "Healthy";
    }

    final ratio = _debtRatio(debt, stockValue);

    if (ratio <= 0.25) {
      return "Healthy";
    }

    if (ratio <= 0.50) {
      return "Moderate";
    }

    if (ratio <= 0.75) {
      return "High Risk";
    }

    return "Critical Risk";
  }

  double _debtPercentage(double debt, double stockValue) {
    if (stockValue <= 0) {
      return debt > 0 ? 100.0 : 0.0;
    }

    return (debt / stockValue) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final datafeed = context.read<Datafeed>();

    return StreamBuilder<DashboardStats>(
      stream: datafeed.dashboardStatsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCard(debt: 0, stockValue: 0);
        }

        if (!snapshot.hasData) {
          return _buildCard(debt: 0, stockValue: 0);
        }

        final dashboard = snapshot.data!;
        final isSuperAdmin =
            datafeed.accesslevel.toString().toLowerCase() == 'super admin';
        final companyStockValue = isSuperAdmin
            ? dashboard.companyStockValue
            : dashboard.branchStockValue;

        final totalDebt = isSuperAdmin
            ? dashboard.companyCredit
            : dashboard.branchCredit;
        if (totalDebt != _currentDebt) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && totalDebt != _currentDebt) {
              _animateTo(totalDebt);
            }
          });
        }
        return StreamBuilder<List<_DebtTrendPoint>>(
          stream: _debtHistoryStream(
            datafeed: datafeed,
            isSuperAdmin: isSuperAdmin,
            currentDebt: totalDebt,
          ),
          builder: (context, historySnapshot) => _buildCard(
            debt: totalDebt,
            stockValue: companyStockValue,
            history: historySnapshot.data,
            historyError: historySnapshot.hasError,
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required double debt,
    required double stockValue,
    List<_DebtTrendPoint>? history,
    bool historyError = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = _debtColor(debt, stockValue);

    final status = _debtStatus(debt, stockValue);

    final percentage = _debtPercentage(debt, stockValue);

    return Container(
      width: widget.cwidth,
      height: 235,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TOTAL DEBT — All time",
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: color,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final value = _animation.value;
              final isNegative = value < 0;
              final displayValue = NumberFormat(
                '#,##0.00',
              ).format(isNegative ? value.abs() : value);

              return FittedBox(
                child: Text(
                  isNegative ? "GHS ($displayValue)" : "GHS $displayValue",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),

          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            "Debt is ${percentage.toStringAsFixed(1)}% of stock value",
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 60,
            child: historyError
                ? Center(
                    child: Text(
                      'Unable to load debt history',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  )
                : history == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : history.isEmpty
                ? Center(
                    child: Text(
                      'No debt activity recorded',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : _buildDebtChart(history, color, theme),
          ),

          const Spacer(),

          Row(
            children: [
              Icon(Icons.trending_up, color: color, size: 18),
              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  "Stock value: GHS ${NumberFormat('#,##0.00').format(stockValue)}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebtChart(
    List<_DebtTrendPoint> history,
    Color color,
    ThemeData theme,
  ) {
    final minBalance = history.map((point) => point.balance).reduce(math.min);
    final maxBalance = history.map((point) => point.balance).reduce(math.max);
    final range = math.max(1.0, maxBalance - minBalance);
    final spots = history.map((point) => point.spot).toList();

    return LineChart(
      LineChartData(
        minY: minBalance - range * 0.1,
        maxY: maxBalance + range * 0.1,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
              .map(
                (_) => TouchedSpotIndicatorData(
                  FlLine(color: Colors.transparent),
                  FlDotData(show: false),
                ),
              )
              .toList(),
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipHorizontalAlignment: FLHorizontalAlignment.left,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final point = history[spot.spotIndex];
              final date = DateFormat('d MMM yyyy').format(point.date);
              final lines = [
                date,
                if (point.debtAdded > 0)
                  'New debt: GHS ${NumberFormat('#,##0.00').format(point.debtAdded)}',
                if (point.payments > 0)
                  'Payments: GHS ${NumberFormat('#,##0.00').format(point.payments)}',
                'Balance: GHS ${NumberFormat('#,##0.00').format(point.balance)}',
              ];
              return LineTooltipItem(
                lines.join('\n'),
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontSize: 10,
                  height: 1.3,
                ),
                textAlign: TextAlign.left,
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
