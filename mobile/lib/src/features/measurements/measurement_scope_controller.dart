import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/storage/app_preferences.dart';

final measurementScopeControllerProvider =
    NotifierProvider<MeasurementScopeController, MeasurementScopePreference>(
      MeasurementScopeController.new,
    );

class MeasurementScopeController extends Notifier<MeasurementScopePreference> {
  AppPreferences get _preferences => ref.read(appPreferencesProvider);

  @override
  MeasurementScopePreference build() {
    return _preferences.getMeasurementScopePreference();
  }

  Future<void> setScope(MeasurementScopePreference scope) async {
    if (state == scope) {
      return;
    }

    await _preferences.setMeasurementScopePreference(scope);
    state = scope;
  }
}
