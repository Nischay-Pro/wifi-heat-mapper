import 'package:mobile/src/features/measurements/backends/core/base.dart';
import 'package:mobile/src/features/measurements/backends/core/engine.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';

class CustomLibrespeedBackend extends MeasurementTest {
  const CustomLibrespeedBackend(this.engine, this.baseUri);

  final InternetSpeedTestEngine engine;
  final String baseUri;

  @override
  Future<InternetMeasurementResult> recordInternetMeasurement({
    required InternetSpeedTestProgressCallback onProgress,
  }) {
    return engine.recordConfiguredMeasurement(
      backend: BackendConfig.librespeed(
        backendName: 'custom_librespeed',
        baseUri: baseUri,
      ),
      onProgress: onProgress,
    );
  }
}
