import 'package:mobile/src/models/internet_measurement_result.dart';

enum InternetSpeedTestPhase {
  idle,
  measuringLatency,
  testingDownload,
  testingUpload,
  completed,
  failed,
}

class InternetSpeedTestProgress {
  const InternetSpeedTestProgress({
    required this.phase,
    required this.overallProgress,
    required this.progress,
    this.activeStageLabel,
    this.downloadBps,
    this.idleJitterMs,
    this.idleLatencyMs,
    this.idlePacketLossPercent,
    this.phaseJitterMs,
    this.phaseLatencyMs,
    this.phasePacketLossPercent,
    this.streamCount,
    this.uploadBps,
    this.errorMessage,
  });

  final InternetSpeedTestPhase phase;
  final double overallProgress;
  final double progress;
  final String? activeStageLabel;
  final double? downloadBps;
  final double? idleJitterMs;
  final double? idleLatencyMs;
  final double? idlePacketLossPercent;
  final double? phaseJitterMs;
  final double? phaseLatencyMs;
  final double? phasePacketLossPercent;
  final int? streamCount;
  final double? uploadBps;
  final String? errorMessage;

  InternetSpeedTestProgress mergeWith(InternetSpeedTestProgress next) {
    return InternetSpeedTestProgress(
      phase: next.phase,
      overallProgress: next.overallProgress,
      progress: next.progress,
      activeStageLabel: next.activeStageLabel ?? activeStageLabel,
      downloadBps: next.downloadBps ?? downloadBps,
      idleJitterMs: next.idleJitterMs ?? idleJitterMs,
      idleLatencyMs: next.idleLatencyMs ?? idleLatencyMs,
      idlePacketLossPercent:
          next.idlePacketLossPercent ?? idlePacketLossPercent,
      phaseJitterMs: next.phaseJitterMs ?? phaseJitterMs,
      phaseLatencyMs: next.phaseLatencyMs ?? phaseLatencyMs,
      phasePacketLossPercent:
          next.phasePacketLossPercent ?? phasePacketLossPercent,
      streamCount: next.streamCount ?? streamCount,
      uploadBps: next.uploadBps ?? uploadBps,
      errorMessage: next.errorMessage ?? errorMessage,
    );
  }
}

typedef InternetSpeedTestProgressCallback =
    void Function(InternetSpeedTestProgress progress);

abstract class MeasurementTest {
  const MeasurementTest();

  Future<InternetMeasurementResult> recordInternetMeasurement({
    required InternetSpeedTestProgressCallback onProgress,
  });
}

class UnavailableMeasurement extends MeasurementTest {
  const UnavailableMeasurement(this.message);

  final String message;

  @override
  Future<InternetMeasurementResult> recordInternetMeasurement({
    required InternetSpeedTestProgressCallback onProgress,
  }) {
    throw StateError(message);
  }
}

typedef LocalMeasurementProgressCallback =
    void Function(double progress, String activeStageLabel);

abstract class LocalMeasurementTest {
  const LocalMeasurementTest();

  Future<InternetMeasurementResult?> recordLocalMeasurement({
    String? bindAddress,
    LocalMeasurementProgressCallback? onProgress,
  });
}

class DisabledLocalMeasurement extends LocalMeasurementTest {
  const DisabledLocalMeasurement();

  @override
  Future<InternetMeasurementResult?> recordLocalMeasurement({
    String? bindAddress,
    LocalMeasurementProgressCallback? onProgress,
  }) async => null;
}

class UnavailableLocalMeasurement extends LocalMeasurementTest {
  const UnavailableLocalMeasurement({required this.message});

  final String message;

  @override
  Future<InternetMeasurementResult?> recordLocalMeasurement({
    String? bindAddress,
    LocalMeasurementProgressCallback? onProgress,
  }) {
    throw StateError(message);
  }
}
