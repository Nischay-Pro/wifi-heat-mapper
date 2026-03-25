import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/features/measurements/backends/core/base.dart';
import 'package:mobile/src/features/measurements/backends/local/iperf.dart';
import 'package:mobile/src/features/measurements/local_measurement_settings_controller.dart';

final localMeasurementTestProvider = Provider<LocalMeasurementTest>((ref) {
  final settings = ref.watch(localMeasurementSettingsControllerProvider);

  if (!settings.hasServerConfigured) {
    return const DisabledLocalMeasurement();
  }

  if (settings.modes.enabledCount == 0) {
    return const DisabledLocalMeasurement();
  }

  if (!Platform.isAndroid) {
    return UnavailableLocalMeasurement(
      message: AppMessages.intranetUnavailable,
    );
  }

  return IperfBackend(settings: settings);
});
