import 'package:flutter/material.dart';

InputDecoration decorationInput(
  BuildContext context,
  String label, {
  String? hint,
  String? prefix,
}) {
  final theme = Theme.of(context);
  final isLight = theme.brightness == Brightness.light;
  final colors = theme.colorScheme;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    labelStyle: TextStyle(
      color: isLight ? colors.onSurfaceVariant : Colors.white70,
    ),
    hintStyle: TextStyle(
      color: isLight ? colors.onSurfaceVariant : Colors.white30,
      fontSize: 12,
    ),
    filled: true,
    fillColor: isLight
        ? colors.surfaceContainerHighest
        : const Color(0xFF22304A),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: isLight ? colors.outline : Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.blue),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}
