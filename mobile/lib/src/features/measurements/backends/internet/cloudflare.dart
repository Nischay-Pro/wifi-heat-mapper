import 'package:mobile/src/features/measurements/backends/core/base.dart';
import 'package:mobile/src/features/measurements/backends/core/engine.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';

class CloudflareBackend extends MeasurementTest {
  const CloudflareBackend(this.engine);

  final InternetSpeedTestEngine engine;

  @override
  Future<InternetMeasurementResult> recordInternetMeasurement({
    required InternetSpeedTestProgressCallback onProgress,
  }) {
    return engine.recordConfiguredMeasurement(
      backend: const BackendConfig.cloudflare(),
      onProgress: onProgress,
    );
  }
}
