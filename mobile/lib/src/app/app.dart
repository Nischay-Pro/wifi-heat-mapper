import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_theme.dart';
import 'package:mobile/src/app/theme_mode_controller.dart';
import 'package:mobile/src/features/connect/server_connect_page.dart';
import 'package:mobile/src/services/server_api.dart';
import 'package:mobile/src/storage/app_preferences.dart';

class WhmMobileApp extends ConsumerWidget {
  const WhmMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(themeModeControllerProvider);
    final themeMode = switch (themePreference) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };

    return MaterialApp(
      title: clientName,
      theme: buildPlatformTheme(brightness: Brightness.light),
      darkTheme: buildPlatformTheme(brightness: Brightness.dark),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 100),
      home: const ServerConnectPage(),
    );
  }
}
