import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/storage/app_preferences.dart';

final measurementChimeControllerProvider =
    NotifierProvider<MeasurementChimeController, bool>(
      MeasurementChimeController.new,
    );

class MeasurementChimeController extends Notifier<bool> {
  AppPreferences get _preferences => ref.read(appPreferencesProvider);

  @override
  bool build() {
    return _preferences.getMeasurementChimeEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) {
      return;
    }

    await _preferences.setMeasurementChimeEnabled(enabled);
    state = enabled;
  }
}
