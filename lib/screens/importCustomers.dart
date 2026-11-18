
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class ImportCustomersButton extends StatefulWidget {
  const ImportCustomersButton({super.key});

  @override
  State<ImportCustomersButton> createState() =>
      _ImportCustomersButtonState();
}

class _ImportCustomersButtonState extends State<ImportCustomersButton> {
  bool _loading = false;

  void _snack(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _import() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'syncCustomers',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 300),
        ),
      );

      final result = await callable.call();
      final d = Map<String, dynamic>.from(result.data as Map);

      final errors = (d['errors'] as List?)?.length ?? 0;
      final ackError = d['ackError'];
      final clean = errors == 0 && ackError == null;

      final saved = d['saved'] ?? 0;
      final total = d['total'] ?? 0;
      final created = d['created'] ?? 0;
      final updated = d['updated'] ?? 0;
      final acknowledged = d['acknowledged'] ?? 0;
      final duplicates = d['duplicates'] ?? 0;

      _snack(
        'Imported $saved of $total customers '
            '($created new, $updated updated, '
            '$acknowledged acknowledged).'
            '${duplicates > 0 ? ' $duplicates duplicates skipped.' : ''}'
            '${clean ? '' : ' Some steps failed, check the logs.'}',
        clean ? Colors.green.shade700 : Colors.orange.shade800,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('syncCustomers error: ${e.code} ${e.message}');
      _snack(
        e.message ?? 'Customer import failed.',
        Colors.red.shade700,
      );
    } catch (e) {
      debugPrint('syncCustomers error: $e');
      _snack(
        'Customer import failed: $e',
        Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          // Icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.cloud_download_rounded,
              color: colors.onPrimaryContainer,
              size: 25,
            ),
          ),

          const SizedBox(width: 14),

          // Title and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Import Customers',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Synchronize customer records from your server.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Import button
          FilledButton(
            onPressed: _loading ? null : _import,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              elevation: 0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _loading
                  ? const SizedBox(
                key: ValueKey('loading'),
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Row(
                key: ValueKey('import'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_rounded, size: 18),
                  SizedBox(width: 7),
                  Text(
                    'Import',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
