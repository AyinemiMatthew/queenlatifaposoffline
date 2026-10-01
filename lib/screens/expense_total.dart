import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class RespWidget extends StatelessWidget {
  final double cwidth;
  const RespWidget({super.key, required this.cwidth});

  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<Datafeed>();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      height: 235,
      width: cwidth,
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
                "Expense",
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.receipt_long,
                    color: Colors.green,

                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            child: StreamBuilder<double>(
              stream: datafeed.periodExpenseStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Unable to load ${datafeed.dashboardPeriodLabel} expenses: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  );
                }
                if (!snapshot.hasData) {
                  return Text(
                    "0.00 GHS\n${datafeed.dashboardPeriodLabel}",
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                    ),
                  );
                }
                final expense = snapshot.data!;
                return RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: expense.toStringAsFixed(2),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: " GHS\n",
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 20,
                        ),
                      ),
                      TextSpan(
                        text: datafeed.dashboardPeriodLabel,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.arrow_drop_up,
                color: Colors.redAccent,
                size: 22,
              ),
              const SizedBox(width: 4),
              Text(
                "11%",
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
              const SizedBox(width: 4),
              Text(
                "vs last month",
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "5",
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: "%\n",
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 20),
                ),
                TextSpan(
                  text: "Within this month",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
