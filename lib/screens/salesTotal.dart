import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/sales_summary.dart';
import '../providers/Datafeed.dart';

class _SalesLoadingPlaceholder extends StatefulWidget {
  final bool showTotal;

  const _SalesLoadingPlaceholder({this.showTotal = false});

  @override
  State<_SalesLoadingPlaceholder> createState() =>
      _SalesLoadingPlaceholderState();
}

class _SalesLoadingPlaceholderState extends State<_SalesLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final placeholderColor = isDarkMode
        ? colorScheme.surfaceContainerHighest
        : const Color(0xFFD1D5DB);
    final minimumOpacity = isDarkMode ? 0.4 : 0.55;

    Widget bar({required double width, required double height}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: placeholderColor,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: minimumOpacity + (_controller.value * (1 - minimumOpacity)),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showTotal) ...[
            bar(width: 132, height: 24),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [bar(width: 82, height: 12), bar(width: 96, height: 12)],
          ),
          const SizedBox(height: 8),
          Container(
            height: 38,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: placeholderColor.withValues(
                alpha: isDarkMode ? 0.45 : 0.35,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                bar(width: 94, height: 14),
                bar(width: 64, height: 12),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: bar(width: 122, height: 12),
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

class WorkPlaceWidget extends StatefulWidget {
  final double cwidth;
  const WorkPlaceWidget({super.key, required this.cwidth});

  @override
  State<WorkPlaceWidget> createState() => _WorkPlaceWidgetState();
}

class _WorkPlaceWidgetState extends State<WorkPlaceWidget> {
  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<Datafeed>();
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final salesColor = isLight ? const Color(0xFF167D3D) : Colors.greenAccent;
    final creditColor = isLight ? const Color(0xFFB42318) : Colors.redAccent;
    final statusForeground = isLight ? Colors.white : colorScheme.surface;
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
                "Total Sales ",
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: salesColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.shopping_cart, color: salesColor, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<double>(
            stream: datafeed.dashboardTotalSalesStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Unable to load ${datafeed.dashboardPeriodLabel} sales: '
                  '${snapshot.error}',
                  style: TextStyle(color: colorScheme.error),
                );
              }
              if (!snapshot.hasData) {
                return const _SalesLoadingPlaceholder(showTotal: true);
              }

              final salesTotal = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    child: Text(
                      "GHS ${NumberFormat('#,##0.00').format(salesTotal)}",
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  StreamBuilder<SalesSummary>(
                    stream: datafeed.StodayTotalsStream(),
                    builder: (context, dailySnapshot) {
                      if (dailySnapshot.hasError) {
                        return Text(
                          "Unable to load today's cash and credit sales: "
                          '${dailySnapshot.error}',
                          style: TextStyle(color: colorScheme.error),
                        );
                      }
                      if (!dailySnapshot.hasData) {
                        return const _SalesLoadingPlaceholder();
                      }

                      final cashTotal = dailySnapshot.data!.cash;
                      final creditTotal = dailySnapshot.data!.credit;
                      final salesToday = dailySnapshot.data!.totalToday;
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sales Today',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'GHS ${NumberFormat('#,##0.00').format(salesToday)}',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: salesColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: salesColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "GHS ${NumberFormat('#,##0.00').format(cashTotal)}",
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "Cash Sales",
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: -6,
                                bottom: -6,
                                child: Container(
                                  height: 20,
                                  width: 20,
                                  decoration: BoxDecoration(
                                    color: salesColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.bookmark_added_outlined,
                                      color: statusForeground,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: creditColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: creditColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Credit Sales",
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      "GHS ${NumberFormat('#,##0.00').format(creditTotal)}",
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: -6,
                                bottom: -6,
                                child: Container(
                                  height: 20,
                                  width: 20,
                                  decoration: BoxDecoration(
                                    color: creditColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      "!",
                                      style: TextStyle(
                                        color: statusForeground,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
