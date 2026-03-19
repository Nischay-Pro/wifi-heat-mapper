import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/storage/app_preferences.dart';

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, AppThemePreference>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<AppThemePreference> {
  AppPreferences get _preferences => ref.read(appPreferencesProvider);

  @override
  AppThemePreference build() {
    return _preferences.getThemePreference();
  }

  Future<void> setPreference(AppThemePreference preference) async {
    if (state == preference) {
      return;
    }

    await _preferences.setThemePreference(preference);
    state = preference;
  }

  ThemeMode get themeMode => switch (state) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };
}
