import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dashboardStats.dart';
import '../providers/Datafeed.dart';

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

  List<FlSpot> get _trendSpots => const [
    FlSpot(0, 3),
    FlSpot(1, 4),
    FlSpot(2, 3.5),
    FlSpot(3, 5),
    FlSpot(4, 6),
    FlSpot(5, 7),
    FlSpot(6, 5),
  ];

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

        return StreamBuilder<PeriodDashboardSummary>(
          stream: context.watch<Datafeed>().periodDashboardSummaryStream(),
          builder: (context, periodSnapshot) {
            if (periodSnapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load period debt: ${periodSnapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            final periodDebt = periodSnapshot.data?.credit ?? 0;
            if (periodDebt != _currentDebt) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && periodDebt != _currentDebt) {
                  _animateTo(periodDebt);
                }
              });
            }
            return _buildCard(
              debt: periodDebt,
              stockValue: companyStockValue,
            );
          },
        );
      },
    );
  }

  Widget _buildCard({required double debt, required double stockValue}) {
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
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.12)),
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
                "TOTAL DEBT — ${context.watch<Datafeed>().dashboardPeriodLabel}",
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
          // AnimatedBuilder(
          //   animation: _animation,
          //   builder: (context, child) {
          //     return FittedBox(
          //       child: Text(
          //         "GHS ${NumberFormat('#,##0.00').format(_animation.value)}",
          //         style: TextStyle(
          //           fontSize: 22,
          //           fontWeight: FontWeight.bold,
          //           color: color,
          //         ),
          //       ),
          //     );
          //   },
          // ),

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
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _trendSpots,
                    isCurved: true,
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
            ),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
