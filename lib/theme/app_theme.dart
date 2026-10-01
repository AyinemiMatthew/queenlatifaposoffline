import 'package:flutter/material.dart';

class AppTheme {
  static final light = _buildTheme(isLight: true);
  static final dark = _buildTheme(isLight: false);

  static ThemeData _buildTheme({required bool isLight}) {
    final colorScheme = isLight
        ? const ColorScheme.light(
            primary: Color(0xFF1F2937),
            onPrimary: Colors.white,
            secondary: Color(0xFF1769AA),
            onSecondary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF111827),
            surfaceContainerHighest: Colors.white,
            onSurfaceVariant: Color(0xFF4B5563),
            outline: Color(0xFFD1D5DB),
            outlineVariant: Color(0xFFE5E7EB),
            error: Color(0xFFB3261E),
            onError: Colors.white,
          )
        : const ColorScheme.dark(
            primary: Color(0xFF0D1A26),
            onPrimary: Colors.white,
            secondary: Color(0xFF90CAF9),
            onSecondary: Colors.black,
            surface: Color(0xFF122033),
            onSurface: Color(0xFFE8EDF5),
            surfaceContainerHighest: Color(0xFF1B263B),
            onSurfaceVariant: Color(0xFFB5C0D0),
            outline: Color(0xFF39465D),
            outlineVariant: Color(0xFF303D52),
            error: Color(0xFFFF5252),
            onError: Colors.white,
          );

    final textTheme = _buildTextTheme(colorScheme);
    final background = isLight ? Colors.white : const Color(0xFF101624);
    final surface = isLight ? Colors.white : const Color(0xFF112132);
    final border = isLight ? const Color(0xFFD1D5DB) : const Color(0xFF39465D);

    return ThemeData(
      brightness: isLight ? Brightness.light : Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: 'KologSoft',
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      cardColor: surface,
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: isLight ? 0 : 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        textStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        surfaceTintColor: Colors.transparent,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight
            ? const Color(0xFF1F2937)
            : const Color(0xFFE8EDF5),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isLight ? Colors.white : const Color(0xFF111827),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: colorScheme.outlineVariant,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: colorScheme.onSurface,
        elevation: isLight ? 0 : 2,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: colorScheme.surfaceContainerHighest,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.primary,
        ),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isLight ? const Color(0xFF415A77) : null,
          foregroundColor: isLight ? colorScheme.onPrimary : null,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isLight ? const Color(0xFF415A77) : null,
        foregroundColor: isLight ? colorScheme.onPrimary : null,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isLight ? colorScheme.primary : null,
          side: isLight ? BorderSide(color: colorScheme.outline) : null,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isLight ? colorScheme.primary : null,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: isLight ? colorScheme.onSurfaceVariant : null,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.titleSmall?.copyWith(
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        iconColor: colorScheme.onSurfaceVariant,
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return null;
        }),
        checkColor: WidgetStatePropertyAll(colorScheme.onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(colorScheme.primary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.28);
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.secondary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
      useMaterial3: true,
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    const family = 'KologSoft';

    TextStyle style({
      required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.35,
      double letterSpacing = 0,
    }) => TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

    return TextTheme(
      displayLarge: style(
        size: 32,
        weight: FontWeight.w700,
        color: colorScheme.onSurface,
        height: 1.15,
        letterSpacing: -0.5,
      ),
      displayMedium: style(
        size: 28,
        weight: FontWeight.w700,
        color: colorScheme.onSurface,
        height: 1.2,
        letterSpacing: -0.35,
      ),
      displaySmall: style(
        size: 24,
        weight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      headlineLarge: style(
        size: 22,
        weight: FontWeight.w700,
        color: colorScheme.onSurface,
        height: 1.25,
      ),
      headlineMedium: style(
        size: 20,
        weight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: 1.3,
      ),
      headlineSmall: style(
        size: 18,
        weight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: 1.3,
      ),
      titleLarge: style(
        size: 18,
        weight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: 1.3,
      ),
      titleMedium: style(
        size: 16,
        weight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: 1.35,
      ),
      titleSmall: style(
        size: 14,
        weight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: 1.35,
      ),
      bodyLarge: style(
        size: 16,
        weight: FontWeight.w400,
        color: colorScheme.onSurface,
        height: 1.5,
      ),
      bodyMedium: style(
        size: 14,
        weight: FontWeight.w400,
        color: colorScheme.onSurface,
        height: 1.45,
      ),
      bodySmall: style(
        size: 12,
        weight: FontWeight.w400,
        color: colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
      labelLarge: style(
        size: 14,
        weight: FontWeight.w600,
        color: colorScheme.onSurface,
        height: 1.3,
      ),
      labelMedium: style(
        size: 12,
        weight: FontWeight.w600,
        color: colorScheme.onSurfaceVariant,
        height: 1.3,
      ),
      labelSmall: style(
        size: 11,
        weight: FontWeight.w500,
        color: colorScheme.onSurfaceVariant,
        height: 1.3,
      ),
    );
  }
}
