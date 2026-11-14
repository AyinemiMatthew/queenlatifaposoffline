import 'package:flutter/material.dart';

class StockRowsPerPageMenu extends StatelessWidget {
  const StockRowsPerPageMenu({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          theme.colorScheme.surfaceContainerHighest,
        ),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      menuChildren: [
        for (final option in const [10, 15, 20, 50, 100])
          MenuItemButton(
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                theme.colorScheme.onSurface,
              ),
            ),
            onPressed: () => onChanged(option),
            child: Text('$option'),
          ),
      ],
      builder: (context, controller, child) => TextButton(
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
          minimumSize: const Size(0, 36),
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(compact ? 'Rows: $value' : 'Rows per page: $value'),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
