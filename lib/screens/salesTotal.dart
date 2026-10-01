import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

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
    final salesColor = isLight
        ? const Color(0xFF167D3D)
        : Colors.greenAccent;
    final creditColor = isLight
        ? const Color(0xFFB42318)
        : Colors.redAccent;
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
                "Total Sales",
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
                  child: Icon(
                    Icons.shopping_cart,
                    color: salesColor,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<PeriodDashboardSummary>(
            stream: datafeed.periodDashboardSummaryStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Unable to load ${datafeed.dashboardPeriodLabel} sales: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }
              final cashTotal = snapshot.hasData
                  ? snapshot.data!.cash.toStringAsFixed(2)
                  : '0.00';
              final creditTotal = snapshot.hasData
                  ? snapshot.data!.credit.toStringAsFixed(2)
                  : '0.00';
              final salesTotal = snapshot.data?.sales ?? 0;
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
                  Text(
                    "${datafeed.dashboardPeriodLabel} Sales",
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: salesColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: salesColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              //"GHS ${NumberFormat('#,##0.00').format(cashTotal)}",
                              "GHS ${cashTotal}",
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
                          child: const Center(
                            child: Icon(
                              Icons.bookmark_added_outlined,
                              color: Colors.white,
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: creditColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: creditColor, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Credit Sales",
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              // "GHS ${NumberFormat('#,##0.00').format(creditTotal)}",
                              "GHS $creditTotal",
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
                          child: const Center(
                            child: Text(
                              "!",
                              style: TextStyle(
                                color: Colors.white,
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
      ),
    );
  }
}
