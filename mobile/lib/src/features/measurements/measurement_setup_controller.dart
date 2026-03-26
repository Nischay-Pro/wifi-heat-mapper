import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/features/measurements/internet_speed_test_settings_controller.dart';
import 'package:mobile/src/features/measurements/local_measurement_settings_controller.dart';
import 'package:mobile/src/features/measurements/measurement_scope_controller.dart';
import 'package:mobile/src/storage/app_preferences.dart';

class MeasurementSetupStatus {
  const MeasurementSetupStatus({
    required this.scope,
    required this.internetConfigured,
    required this.localConfigured,
  });

  final MeasurementScopePreference scope;
  final bool internetConfigured;
  final bool localConfigured;

  bool get requiresInternet => scope.includesInternet;
  bool get requiresLocal => scope.includesLocal;

  bool get isComplete =>
      (!requiresInternet || internetConfigured) &&
      (!requiresLocal || localConfigured);
}

final measurementSetupStatusProvider = Provider<MeasurementSetupStatus>((ref) {
  final scope = ref.watch(measurementScopeControllerProvider);
  final internet = ref.watch(internetSpeedTestSettingsControllerProvider);
  final local = ref.watch(localMeasurementSettingsControllerProvider);

  final internetConfigured =
      !scope.includesInternet || _isInternetConfigured(internet);
  final localConfigured =
      !scope.includesLocal ||
      (local.hasServerConfigured && local.modes.enabledCount > 0);

  return MeasurementSetupStatus(
    scope: scope,
    internetConfigured: internetConfigured,
    localConfigured: localConfigured,
  );
});

bool _isInternetConfigured(InternetSpeedTestSettings settings) {
  switch (settings.backend) {
    case InternetSpeedTestBackendPreference.customLibrespeed:
      final customUrl = settings.customLibrespeedUrl;
      if (customUrl == null || customUrl.trim().isEmpty) {
        return false;
      }

      final parsed = Uri.tryParse(customUrl.trim());
      return parsed != null &&
          parsed.hasScheme &&
          parsed.hasAuthority &&
          (parsed.scheme == 'http' || parsed.scheme == 'https');
    case InternetSpeedTestBackendPreference.publicLibrespeed:
    case InternetSpeedTestBackendPreference.cloudflare:
    case InternetSpeedTestBackendPreference.measurementLab:
      return true;
  }
}
