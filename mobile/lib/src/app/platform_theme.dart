import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

ThemeData buildPlatformTheme({
  required Brightness brightness,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return _buildIosTheme(brightness: brightness);
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return _buildMaterialTheme(brightness: brightness);
  }
}

ThemeData _buildMaterialTheme({
  required Brightness brightness,
}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4C8DFF),
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  final scaffoldColor = isDark ? const Color(0xFF111317) : const Color(0xFFF3F5F8);
  final surfaceColor = isDark ? const Color(0xFF1A1D22) : Colors.white;
  final surfaceBorder = isDark ? const Color(0xFF2A2E35) : const Color(0xFFD8DEE8);
  final navColor = isDark ? const Color(0xFF171A1F) : const Color(0xFFEDEFF3);
  final navIndicatorColor = isDark ? const Color(0xFF353A42) : const Color(0xFFD9DEE7);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldColor,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: surfaceBorder),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navColor,
      indicatorColor: navIndicatorColor,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return colorScheme.onSurface.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
          return colorScheme.onSurface.withValues(alpha: 0.06);
        }
        return null;
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(kMinInteractiveDimension),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(kMinInteractiveDimension),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    ),
  );
}

ThemeData _buildIosTheme({
  required Brightness brightness,
}) {
  const baseColor = CupertinoColors.systemBlue;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: baseColor.color,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  final scaffoldColor = isDark
      ? CupertinoColors.black
      : CupertinoColors.systemGroupedBackground.color;
  final cardColor = isDark
      ? const Color(0xCC1C1C1E)
      : CupertinoColors.systemBackground.color.withValues(alpha: 0.72);
  final separatorColor = isDark
      ? CupertinoColors.separator.darkColor.withValues(alpha: 0.30)
      : CupertinoColors.separator.color.withValues(alpha: 0.24);
  final fieldColor = isDark
      ? const Color(0xFF232327)
      : CupertinoColors.secondarySystemGroupedBackground.color.withValues(alpha: 0.9);
  final foregroundColor = isDark ? CupertinoColors.white : CupertinoColors.label.color;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: baseColor,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldColor,
    ),
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scaffoldColor.withValues(alpha: 0.88),
      foregroundColor: foregroundColor,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: separatorColor,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: separatorColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: separatorColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: baseColor.color.withValues(alpha: 0.6),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(kMinInteractiveDimension),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(kMinInteractiveDimension),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );
}
