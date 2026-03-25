import 'package:mobile/src/features/measurements/backends/core/base.dart';
import 'package:mobile/src/features/measurements/backends/core/engine.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';

class PublicLibrespeedBackend extends MeasurementTest {
  const PublicLibrespeedBackend(this.engine);

  final InternetSpeedTestEngine engine;

  @override
  Future<InternetMeasurementResult> recordInternetMeasurement({
    required InternetSpeedTestProgressCallback onProgress,
  }) {
    return engine.recordConfiguredMeasurement(
      backend: const BackendConfig.publicLibrespeed(),
      onProgress: onProgress,
    );
  }
}
