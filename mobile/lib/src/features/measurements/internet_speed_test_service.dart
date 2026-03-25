import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/features/measurements/backends/core/base.dart';
import 'package:mobile/src/features/measurements/backends/core/engine.dart';
import 'package:mobile/src/features/measurements/backends/internet/cloudflare.dart';
import 'package:mobile/src/features/measurements/backends/internet/custom_librespeed.dart';
import 'package:mobile/src/features/measurements/backends/internet/measurement_lab.dart';
import 'package:mobile/src/features/measurements/backends/internet/public_librespeed.dart';
import 'package:mobile/src/features/measurements/internet_speed_test_settings_controller.dart';
import 'package:mobile/src/storage/app_preferences.dart';

export 'package:mobile/src/features/measurements/backends/core/base.dart';

final internetSpeedTestServiceProvider = Provider<MeasurementTest>((ref) {
  final settings = ref.watch(internetSpeedTestSettingsControllerProvider);
  final engine = InternetSpeedTestEngine(
    httpSettings: settings.http,
    measurementLabSettings: settings.measurementLab,
  );

  switch (settings.backend) {
    case InternetSpeedTestBackendPreference.publicLibrespeed:
      return PublicLibrespeedBackend(engine);
    case InternetSpeedTestBackendPreference.customLibrespeed:
      final customUrl = settings.customLibrespeedUrl;
      final customBaseUri = customUrl == null
          ? null
          : normalizedCustomLibrespeedBaseUri(customUrl);
      if (customBaseUri == null) {
        return const UnavailableMeasurement(
          AppMessages.customLibrespeedUrlRequired,
        );
      }

      return CustomLibrespeedBackend(engine, customBaseUri.toString());
    case InternetSpeedTestBackendPreference.cloudflare:
      return CloudflareBackend(engine);
    case InternetSpeedTestBackendPreference.measurementLab:
      return MeasurementLabBackend(engine);
  }
});
