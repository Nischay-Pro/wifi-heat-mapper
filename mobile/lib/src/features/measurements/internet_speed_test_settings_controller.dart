import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/storage/app_preferences.dart';

class InternetSpeedTestSettings {
  const InternetSpeedTestSettings({
    required this.backend,
    this.customLibrespeedUrl,
  });

  final InternetSpeedTestBackendPreference backend;
  final String? customLibrespeedUrl;

  String get backendLabel => switch (backend) {
    InternetSpeedTestBackendPreference.publicLibrespeed =>
      'Public Librespeed (Recommended)',
    InternetSpeedTestBackendPreference.customLibrespeed => 'Custom Librespeed',
    InternetSpeedTestBackendPreference.cloudflare => 'Cloudflare',
    InternetSpeedTestBackendPreference.measurementLab => 'Measurement Lab',
  };
}

final internetSpeedTestSettingsControllerProvider =
    NotifierProvider<
      InternetSpeedTestSettingsController,
      InternetSpeedTestSettings
    >(InternetSpeedTestSettingsController.new);

class InternetSpeedTestSettingsController
    extends Notifier<InternetSpeedTestSettings> {
  AppPreferences get _preferences => ref.read(appPreferencesProvider);

  @override
  InternetSpeedTestSettings build() {
    return InternetSpeedTestSettings(
      backend: _preferences.getInternetSpeedTestBackendPreference(),
      customLibrespeedUrl: _preferences.getCustomLibrespeedUrl(),
    );
  }

  Future<void> setBackend(InternetSpeedTestBackendPreference backend) async {
    if (state.backend == backend) {
      return;
    }

    await _preferences.setInternetSpeedTestBackendPreference(backend);
    state = InternetSpeedTestSettings(
      backend: backend,
      customLibrespeedUrl: state.customLibrespeedUrl,
    );
  }

  Future<void> setCustomLibrespeedUrl(String? value) async {
    final normalizedValue = value?.trim();
    if ((normalizedValue == null || normalizedValue.isEmpty) &&
        (state.customLibrespeedUrl == null ||
            state.customLibrespeedUrl!.isEmpty)) {
      return;
    }

    if (normalizedValue == null || normalizedValue.isEmpty) {
      await _preferences.clearCustomLibrespeedUrl();
      state = InternetSpeedTestSettings(
        backend: state.backend,
        customLibrespeedUrl: null,
      );
      return;
    }

    await _preferences.setCustomLibrespeedUrl(normalizedValue);
    state = InternetSpeedTestSettings(
      backend: state.backend,
      customLibrespeedUrl: normalizedValue,
    );
  }

  Future<void> saveCustomLibrespeedUrlAndSelect(String value) async {
    await setCustomLibrespeedUrl(value);
    await setBackend(InternetSpeedTestBackendPreference.customLibrespeed);
  }
}
