
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/Datafeed.dart';

class ImportBranchesButton extends StatefulWidget {
  const ImportBranchesButton({super.key});

  @override
  State<ImportBranchesButton> createState() =>
      _ImportBranchesButtonState();
}

class _ImportBranchesButtonState extends State<ImportBranchesButton> {
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
        'syncBranches',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 120),
        ),
      );

      final result = await callable.call();
      final d = Map<String, dynamic>.from(result.data as Map);

      // Refresh branches for dropdowns and other screens.
      if (mounted) {
        await context.read<Datafeed>().fetchBranches();
      }

      final created = (d['created'] as num?)?.toInt() ?? 0;
      final updated = (d['updated'] as num?)?.toInt() ?? 0;
      final total = (d['total'] as num?)?.toInt() ?? 0;
      final duplicates = (d['duplicates'] as num?)?.toInt() ?? 0;
      final invalid = (d['invalid'] as num?)?.toInt() ?? 0;

      final errors = (d['errors'] as List?)?.length ?? 0;
      final skipped = duplicates + invalid;
      final imported = created + updated;

      _snack(
        'Imported $imported of $total branches '
            '($created new, $updated updated).'
            '${skipped > 0 ? ' $skipped skipped.' : ''}'
            '${errors > 0 ? ' Some chunks failed, check the logs.' : ''}',
        errors == 0
            ? Colors.green.shade700
            : Colors.orange.shade800,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('syncBranches error: ${e.code} ${e.message}');

      _snack(
        e.message ?? 'Branch import failed.',
        Colors.red.shade700,
      );
    } catch (e) {
      debugPrint('syncBranches error: $e');

      _snack(
        'Branch import failed: $e',
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;

          final iconBox = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.store_rounded,
              color: colors.onPrimaryContainer,
              size: 25,
            ),
          );

          final description = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Import Branches',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Synchronize your branch records from the server.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          );

          final importButton = FilledButton(
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
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 12),
                    Expanded(child: description),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: importButton,
                ),
              ],
            );
          }

          return Row(
            children: [
              iconBox,
              const SizedBox(width: 14),
              Expanded(child: description),
              const SizedBox(width: 12),
              importButton,
            ],
          );
        },
      ),
    );
  }
}
