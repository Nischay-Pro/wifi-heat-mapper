import 'package:mobile/src/features/measurements/backends/core/base.dart';
import 'package:mobile/src/features/measurements/backends/core/engine.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';

class MeasurementLabBackend extends MeasurementTest {
  const MeasurementLabBackend(this.engine);

  final InternetSpeedTestEngine engine;

  @override
  Future<InternetMeasurementResult> recordInternetMeasurement({
    required InternetSpeedTestProgressCallback onProgress,
  }) {
    return engine.recordMeasurementLab(onProgress: onProgress);
  }
}
