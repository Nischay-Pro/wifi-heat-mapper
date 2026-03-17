import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

ThemeData buildPlatformTheme() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return _buildIosTheme();
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return _buildMaterialTheme();
  }
}

ThemeData _buildMaterialTheme() {
  return ThemeData(
    useMaterial3: true,
  );
}

ThemeData _buildIosTheme() {
  const baseColor = CupertinoColors.systemBlue;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: baseColor.color,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    cupertinoOverrideTheme: const CupertinoThemeData(
      primaryColor: baseColor,
      scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    ),
    colorScheme: colorScheme,
    scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground.color,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: CupertinoColors.systemGroupedBackground.color.withValues(alpha: 0.88),
      foregroundColor: CupertinoColors.label.color,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: CupertinoColors.systemBackground.color.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: CupertinoColors.separator.color.withValues(alpha: 0.24),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CupertinoColors.secondarySystemGroupedBackground.color.withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: CupertinoColors.separator.color.withValues(alpha: 0.2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: CupertinoColors.separator.color.withValues(alpha: 0.2),
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
