import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/features/measurements/internet_speed_test_settings_controller.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';
import 'package:mobile/src/storage/app_preferences.dart';

final internetSpeedTestServiceProvider = Provider<InternetSpeedTestService>((
  ref,
) {
  final settings = ref.watch(internetSpeedTestSettingsControllerProvider);

  switch (settings.backend) {
    case InternetSpeedTestBackendPreference.publicLibrespeed:
      return const InternetSpeedTestService._backend(
        _BackendConfig.publicLibrespeed(),
      );
    case InternetSpeedTestBackendPreference.customLibrespeed:
      final customUrl = settings.customLibrespeedUrl;
      final customBaseUri = customUrl == null
          ? null
          : _normalizedCustomLibrespeedBaseUri(customUrl);
      if (customBaseUri == null) {
        return const InternetSpeedTestService.unavailable(
          AppMessages.customLibrespeedUrlRequired,
        );
      }

      return InternetSpeedTestService._backend(
        _BackendConfig.librespeed(
          backendName: 'custom_librespeed',
          baseUri: customBaseUri.toString(),
        ),
      );
    case InternetSpeedTestBackendPreference.cloudflare:
      return InternetSpeedTestService._backend(
        const _BackendConfig.cloudflare(),
      );
    case InternetSpeedTestBackendPreference.measurementLab:
      return InternetSpeedTestService._backend(
        const _BackendConfig.measurementLab(),
      );
  }
});

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

class InternetSpeedTestService {
  const InternetSpeedTestService._backend(this._backendConfig)
    : unavailableMessage = null;

  const InternetSpeedTestService.unavailable(this.unavailableMessage)
    : _backendConfig = null;

  final _BackendConfig? _backendConfig;
  final String? unavailableMessage;

  static const int _uploadChunkSizeBytes = 256 * 1000;
  static const int _loadedLatencyProbeIntervalMs = 400;
  static const int _idleLatencySampleCount = 10;
  static const int _streamCount = 4;
  static const List<_StageDefinition> _downloadStages = [
    _StageDefinition(bytes: 100 * 1000, label: '100 KB'),
    _StageDefinition(bytes: 1 * 1000 * 1000, label: '1 MB'),
    _StageDefinition(bytes: 10 * 1000 * 1000, label: '10 MB'),
    _StageDefinition(bytes: 25 * 1000 * 1000, label: '25 MB'),
    _StageDefinition(bytes: 100 * 1000 * 1000, label: '100 MB'),
    _StageDefinition(bytes: 250 * 1000 * 1000, label: '250 MB'),
  ];
  static const List<_StageDefinition> _uploadStages = [
    _StageDefinition(bytes: 100 * 1000, label: '100 KB'),
    _StageDefinition(bytes: 1 * 1000 * 1000, label: '1 MB'),
    _StageDefinition(bytes: 10 * 1000 * 1000, label: '10 MB'),
    _StageDefinition(bytes: 25 * 1000 * 1000, label: '25 MB'),
    _StageDefinition(bytes: 50 * 1000 * 1000, label: '50 MB'),
  ];

  static final int totalDownloadPlannedBytes = _sumStageBytes(_downloadStages);
  static final int totalUploadPlannedBytes = _sumStageBytes(_uploadStages);

  Future<InternetMeasurementResult> recordInternetMeasurement({
    required InternetSpeedTestProgressCallback onProgress,
  }) async {
    if (unavailableMessage != null) {
      throw StateError(unavailableMessage!);
    }

    final backend = _backendConfig!;
    if (backend.kind == _BackendKind.measurementLab) {
      throw UnsupportedError(AppMessages.measurementLabNotImplemented);
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final resolvedBackend = await _resolveBackend(client, backend);

      onProgress(
        const InternetSpeedTestProgress(
          phase: InternetSpeedTestPhase.measuringLatency,
          overallProgress: 0.02,
          progress: 0,
        ),
      );

      final idleLatency = await _measureIdleLatency(client, resolvedBackend);
      onProgress(
        InternetSpeedTestProgress(
          phase: InternetSpeedTestPhase.testingDownload,
          overallProgress: 0.02,
          progress: 0,
          activeStageLabel: '${_downloadStages.first.label} download',
          idleLatencyMs: idleLatency.latencyMs,
          idleJitterMs: idleLatency.jitterMs,
          idlePacketLossPercent: idleLatency.packetLossPercent,
          streamCount: _streamCount,
        ),
      );

      final download = await _measureTransferSequence(
        client: client,
        phase: InternetSpeedTestPhase.testingDownload,
        backend: resolvedBackend,
        stages: _downloadStages,
        idleLatency: idleLatency,
        existingDownloadSamples: const [],
        onProgress: onProgress,
      );

      onProgress(
        InternetSpeedTestProgress(
          phase: InternetSpeedTestPhase.testingUpload,
          overallProgress: download.overallProgress,
          progress: 0,
          activeStageLabel: '${_uploadStages.first.label} upload',
          idleLatencyMs: idleLatency.latencyMs,
          idleJitterMs: idleLatency.jitterMs,
          idlePacketLossPercent: idleLatency.packetLossPercent,
          downloadBps: download.transferP90Bps,
          phaseLatencyMs: download.loadedLatency.latencyMs,
          phaseJitterMs: download.loadedLatency.jitterMs,
          phasePacketLossPercent: download.loadedLatency.packetLossPercent,
          streamCount: _streamCount,
        ),
      );

      final upload = await _measureTransferSequence(
        client: client,
        phase: InternetSpeedTestPhase.testingUpload,
        backend: resolvedBackend,
        stages: _uploadStages,
        idleLatency: idleLatency,
        existingDownloadSamples: download.samplesBps,
        onProgress: onProgress,
      );

      final result = InternetMeasurementResult(
        backend: backend.backendName,
        idleLatencyMs: idleLatency.latencyMs,
        idleJitterMs: idleLatency.jitterMs,
        idlePacketLossPercent: idleLatency.packetLossPercent,
        streamCount: _streamCount,
        downloadBps: download.transferP90Bps,
        downloadElapsedMs: download.elapsedMs,
        downloadLoadedLatencyMs: download.loadedLatency.latencyMs,
        downloadLoadedJitterMs: download.loadedLatency.jitterMs,
        downloadLoadedPacketLossPercent:
            download.loadedLatency.packetLossPercent,
        downloadSize: download.bytesTransferred.toDouble(),
        downloadSamplesBps: download.samplesBps,
        uploadBps: upload.transferP90Bps,
        uploadElapsedMs: upload.elapsedMs,
        uploadLoadedLatencyMs: upload.loadedLatency.latencyMs,
        uploadLoadedJitterMs: upload.loadedLatency.jitterMs,
        uploadLoadedPacketLossPercent: upload.loadedLatency.packetLossPercent,
        uploadSize: upload.bytesTransferred.toDouble(),
        uploadSamplesBps: upload.samplesBps,
      );

      onProgress(
        InternetSpeedTestProgress(
          phase: InternetSpeedTestPhase.completed,
          overallProgress: 1,
          progress: 1,
          activeStageLabel: 'Completed',
          idleLatencyMs: result.idleLatencyMs,
          idleJitterMs: result.idleJitterMs,
          idlePacketLossPercent: result.idlePacketLossPercent,
          phaseLatencyMs: result.uploadLoadedLatencyMs,
          phaseJitterMs: result.uploadLoadedJitterMs,
          phasePacketLossPercent: result.uploadLoadedPacketLossPercent,
          downloadBps: result.downloadBps,
          streamCount: result.streamCount,
          uploadBps: result.uploadBps,
        ),
      );

      return result;
    } finally {
      client.close(force: true);
    }
  }

  Future<_LatencyStats> _measureIdleLatency(
    HttpClient client,
    _ResolvedBackend backend,
  ) async {
    final samples = <double>[];
    var failures = 0;
    Object? lastError;

    for (var index = 0; index < _idleLatencySampleCount; index++) {
      try {
        samples.add(await _measureSingleLatencySample(client, backend));
      } catch (error) {
        failures += 1;
        lastError = error;
      }
    }

    if (samples.isEmpty && lastError != null) {
      throw lastError;
    }

    return _LatencyStats.fromSamples(
      samples,
      totalAttempts: _idleLatencySampleCount,
      failedAttempts: failures,
    );
  }

  Future<double> _measureSingleLatencySample(
    HttpClient client,
    _ResolvedBackend backend,
  ) async {
    final latencyUri = _buildLatencyUri(backend);
    final stopwatch = Stopwatch()..start();
    final request = await client.getUrl(latencyUri);
    final response = await request.close();
    await response.drain<void>();
    stopwatch.stop();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Internet test latency request failed with status ${response.statusCode}.',
        uri: latencyUri,
      );
    }

    return stopwatch.elapsedMilliseconds.toDouble();
  }

  Future<_TransferStats> _measureTransferSequence({
    required HttpClient client,
    required InternetSpeedTestPhase phase,
    required _ResolvedBackend backend,
    required List<_StageDefinition> stages,
    required _LatencyStats idleLatency,
    required List<double> existingDownloadSamples,
    required InternetSpeedTestProgressCallback onProgress,
  }) async {
    final phaseTotalBytes = _sumStageBytes(stages);
    final overallTotalBytes =
        totalDownloadPlannedBytes + totalUploadPlannedBytes;
    final overallBytesBeforePhase =
        phase == InternetSpeedTestPhase.testingDownload
        ? 0
        : totalDownloadPlannedBytes;

    var completedPhaseBytes = 0;
    var totalBytesTransferred = 0;
    var totalElapsedMs = 0.0;
    final phaseSamples = <double>[];
    _TransferStats? lastStage;

    for (final stage in stages) {
      lastStage = await _runStageMeasurement(
        client: client,
        phase: phase,
        backend: backend,
        stage: stage,
        idleLatency: idleLatency,
        phaseBytesCompletedBeforeStage: completedPhaseBytes,
        phaseTotalBytes: phaseTotalBytes,
        overallBytesCompletedBeforeStage:
            overallBytesBeforePhase + completedPhaseBytes,
        overallTotalBytes: overallTotalBytes,
        existingDownloadSamples: existingDownloadSamples,
        accumulatedPhaseSamples: phaseSamples,
        onProgress: onProgress,
      );

      completedPhaseBytes += stage.bytes;
      totalBytesTransferred += lastStage.bytesTransferred;
      totalElapsedMs += lastStage.elapsedMs;
      phaseSamples.addAll(lastStage.samplesBps);
    }

    return _TransferStats(
      bytesTransferred: totalBytesTransferred,
      elapsedMs: totalElapsedMs,
      transferP90Bps: _percentile90(phaseSamples),
      overallProgress: _overallProgress(
        completedOverallBytes: overallBytesBeforePhase + completedPhaseBytes,
        totalOverallBytes: overallTotalBytes,
      ),
      loadedLatency: lastStage?.loadedLatency ?? const _LatencyStats(),
      samplesBps: List<double>.unmodifiable(phaseSamples),
    );
  }

  Future<_TransferStats> _runStageMeasurement({
    required HttpClient client,
    required InternetSpeedTestPhase phase,
    required _ResolvedBackend backend,
    required _StageDefinition stage,
    required _LatencyStats idleLatency,
    required int phaseBytesCompletedBeforeStage,
    required int phaseTotalBytes,
    required int overallBytesCompletedBeforeStage,
    required int overallTotalBytes,
    required List<double> existingDownloadSamples,
    required List<double> accumulatedPhaseSamples,
    required InternetSpeedTestProgressCallback onProgress,
  }) async {
    final stopLoadedLatency = Completer<void>();
    final loadedLatencyProbe = _collectLoadedLatencySamples(
      backend,
      stopLoadedLatency.future,
    );
    final stopwatch = Stopwatch()..start();
    final sampler = _PerSecondSampler();

    try {
      final bytesTransferred = await _runTransferLoop(
        client: client,
        phase: phase,
        backend: backend,
        stage: stage,
        onBytesTransferred: (totalBytes) {
          sampler.capture(totalBytes: totalBytes, elapsed: stopwatch.elapsed);
          final stageP90Bps = _percentile90(sampler.previewSamples);
          final aggregateSamples = [
            ...accumulatedPhaseSamples,
            ...sampler.previewSamples,
          ];
          final aggregateP90Bps = _percentile90(aggregateSamples);

          onProgress(
            InternetSpeedTestProgress(
              phase: phase,
              overallProgress: _overallProgress(
                completedOverallBytes:
                    overallBytesCompletedBeforeStage + totalBytes,
                totalOverallBytes: overallTotalBytes,
              ),
              progress: _phaseProgress(
                completedPhaseBytes:
                    phaseBytesCompletedBeforeStage + totalBytes,
                totalPhaseBytes: phaseTotalBytes,
              ),
              activeStageLabel:
                  '${stage.label} ${phase == InternetSpeedTestPhase.testingDownload ? 'download' : 'upload'}',
              idleLatencyMs: idleLatency.latencyMs,
              idleJitterMs: idleLatency.jitterMs,
              idlePacketLossPercent: idleLatency.packetLossPercent,
              downloadBps: phase == InternetSpeedTestPhase.testingDownload
                  ? aggregateP90Bps ?? stageP90Bps
                  : _percentile90(existingDownloadSamples),
              streamCount: _streamCount,
              uploadBps: phase == InternetSpeedTestPhase.testingUpload
                  ? aggregateP90Bps ?? stageP90Bps
                  : null,
            ),
          );
        },
      );

      stopwatch.stop();
      stopLoadedLatency.complete();
      final loadedLatency = await loadedLatencyProbe;
      final stageSamples = sampler.finish(
        totalBytes: bytesTransferred,
        elapsed: stopwatch.elapsed,
      );

      return _TransferStats(
        bytesTransferred: bytesTransferred,
        elapsedMs: stopwatch.elapsedMilliseconds.toDouble(),
        transferP90Bps: _percentile90(stageSamples),
        overallProgress: _overallProgress(
          completedOverallBytes:
              overallBytesCompletedBeforeStage + bytesTransferred,
          totalOverallBytes: overallTotalBytes,
        ),
        loadedLatency: loadedLatency,
        samplesBps: List<double>.unmodifiable(stageSamples),
      );
    } catch (_) {
      if (!stopLoadedLatency.isCompleted) {
        stopLoadedLatency.complete();
      }
      rethrow;
    }
  }

  Future<int> _runTransferLoop({
    required HttpClient client,
    required InternetSpeedTestPhase phase,
    required _ResolvedBackend backend,
    required _StageDefinition stage,
    required void Function(int totalBytesTransferred) onBytesTransferred,
  }) async {
    if (phase == InternetSpeedTestPhase.testingDownload) {
      final streamSizes = _streamByteSizes(
        totalBytes: stage.bytes,
        streamCount: _streamCount,
      );
      var totalBytesReceived = 0;

      await Future.wait(
        List.generate(streamSizes.length, (streamIndex) async {
          final perStreamBytes = streamSizes[streamIndex];
          final streamUri = _buildDownloadUri(backend, perStreamBytes);
          final streamRequest = await client.getUrl(streamUri);
          final streamResponse = await streamRequest.close();

          if (streamResponse.statusCode < 200 ||
              streamResponse.statusCode >= 300) {
            throw HttpException(
              'Internet download test failed with status ${streamResponse.statusCode}.',
              uri: streamUri,
            );
          }

          await for (final chunk in streamResponse) {
            totalBytesReceived += chunk.length;
            onBytesTransferred(totalBytesReceived);
          }
        }),
      );

      return totalBytesReceived;
    }

    final chunk = Uint8List(_uploadChunkSizeBytes);
    final streamSizes = _streamByteSizes(
      totalBytes: stage.bytes,
      streamCount: _streamCount,
    );
    var totalBytesSent = 0;

    await Future.wait(
      List.generate(streamSizes.length, (streamIndex) async {
        final perStreamBytes = streamSizes[streamIndex];
        final uploadUri = _buildUploadUri(backend);
        final uploadRequest = await client.postUrl(uploadUri);
        uploadRequest.headers.contentType = ContentType.binary;
        uploadRequest.contentLength = perStreamBytes;

        var streamBytesSent = 0;
        while (streamBytesSent < perStreamBytes) {
          final remainingBytes = perStreamBytes - streamBytesSent;
          final chunkLength = min(_uploadChunkSizeBytes, remainingBytes);
          uploadRequest.add(chunk.sublist(0, chunkLength));
          streamBytesSent += chunkLength;
          totalBytesSent += chunkLength;
          await uploadRequest.flush();
          onBytesTransferred(totalBytesSent);
        }

        final response = await uploadRequest.close();
        await response.drain<void>();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Internet upload test failed with status ${response.statusCode}.',
            uri: uploadUri,
          );
        }
      }),
    );

    return totalBytesSent;
  }

  List<int> _streamByteSizes({
    required int totalBytes,
    required int streamCount,
  }) {
    final baseSize = totalBytes ~/ streamCount;
    final remainder = totalBytes % streamCount;

    return List<int>.generate(streamCount, (index) {
      return baseSize + (index < remainder ? 1 : 0);
    }).where((value) => value > 0).toList(growable: false);
  }

  Future<_LatencyStats> _collectLoadedLatencySamples(
    _ResolvedBackend backend,
    Future<void> stopSignal,
  ) async {
    final probeClient = HttpClient();
    probeClient.connectionTimeout = const Duration(seconds: 10);
    final samples = <double>[];
    var totalAttempts = 0;
    var failedAttempts = 0;

    try {
      while (true) {
        final stopRequested = await Future.any<bool>([
          stopSignal.then((_) => true),
          Future<bool>.delayed(
            const Duration(milliseconds: _loadedLatencyProbeIntervalMs),
            () => false,
          ),
        ]);

        if (stopRequested) {
          break;
        }

        try {
          totalAttempts += 1;
          samples.add(await _measureSingleLatencySample(probeClient, backend));
        } on Object {
          failedAttempts += 1;
        }
      }
    } finally {
      probeClient.close(force: true);
    }

    return _LatencyStats.fromSamples(
      samples,
      totalAttempts: totalAttempts,
      failedAttempts: failedAttempts,
    );
  }

  double _phaseProgress({
    required int completedPhaseBytes,
    required int totalPhaseBytes,
  }) {
    if (totalPhaseBytes <= 0) {
      return 0;
    }

    return (completedPhaseBytes / totalPhaseBytes).clamp(0.0, 1.0);
  }

  double _overallProgress({
    required int completedOverallBytes,
    required int totalOverallBytes,
  }) {
    if (totalOverallBytes <= 0) {
      return 0;
    }

    return (completedOverallBytes / totalOverallBytes).clamp(0.0, 1.0);
  }

  static int _sumStageBytes(List<_StageDefinition> stages) {
    return stages.fold<int>(0, (sum, stage) => sum + stage.bytes);
  }

  double? _percentile90(List<double> values) {
    if (values.isEmpty) {
      return null;
    }

    final sorted = [...values]..sort();
    final rank = ((sorted.length - 1) * 0.9).ceil();
    return sorted[rank.clamp(0, sorted.length - 1)];
  }

  Future<_ResolvedBackend> _resolveBackend(
    HttpClient client,
    _BackendConfig backend,
  ) async {
    switch (backend.kind) {
      case _BackendKind.cloudflare:
        return _ResolvedBackend(
          backendName: backend.backendName,
          downloadUriBuilder: (bytes) =>
              Uri.parse('${backend.baseUri}__down?bytes=$bytes'),
          uploadUriBuilder: () => Uri.parse('${backend.baseUri}__up'),
          latencyUriBuilder: () =>
              Uri.parse('${backend.baseUri}__down?bytes=1'),
        );
      case _BackendKind.librespeed:
        if (backend.usePublicServerList) {
          return _resolvePublicLibrespeedBackend(client, backend);
        }

        return _resolvedCustomLibrespeedBackend(backend);
      case _BackendKind.measurementLab:
        throw UnsupportedError(AppMessages.measurementLabNotImplemented);
    }
  }

  Future<_ResolvedBackend> _resolvePublicLibrespeedBackend(
    HttpClient client,
    _BackendConfig backend,
  ) async {
    final serverListUri = Uri.parse(
      '${backend.baseUri}backend-servers/servers.php',
    );
    final request = await client.getUrl(serverListUri);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Public Librespeed server list request failed with status ${response.statusCode}.',
        uri: serverListUri,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const FormatException(
        'Public Librespeed server list is malformed.',
      );
    }

    final servers = decoded
        .whereType<Map>()
        .map(
          (entry) => entry.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false);
    if (servers.isEmpty) {
      throw const FormatException('Public Librespeed server list is empty.');
    }

    final selectionClient = HttpClient();
    selectionClient.connectionTimeout = const Duration(seconds: 4);

    try {
      final candidates = await Future.wait(
        servers.map(
          (server) => _probeLibrespeedServer(
            selectionClient,
            backend.backendName,
            server,
          ),
        ),
      );

      final reachable = candidates
          .whereType<_ResolvedBackendCandidate>()
          .toList(growable: false);
      if (reachable.isEmpty) {
        throw const HttpException(
          'Could not reach any public Librespeed backend server.',
        );
      }

      reachable.sort(
        (left, right) => left.latencyMs.compareTo(right.latencyMs),
      );
      return reachable.first.backend;
    } finally {
      selectionClient.close(force: true);
    }
  }

  Future<_ResolvedBackendCandidate?> _probeLibrespeedServer(
    HttpClient client,
    String backendName,
    Map<String, Object?> server,
  ) async {
    final serverValue = server['server']?.toString();
    final serverBase =
        serverValue == null ? null : _normalizedEndpointBaseUri(serverValue);
    final pingPath = server['pingURL']?.toString();
    final downloadPath = server['dlURL']?.toString();
    final uploadPath = server['ulURL']?.toString();
    if (serverBase == null ||
        pingPath == null ||
        downloadPath == null ||
        uploadPath == null) {
      return null;
    }

    final resolvedBackend = _ResolvedBackend(
      backendName: backendName,
      downloadUriBuilder: (bytes) {
        final chunkCount = max(1, min(1024, (bytes / (1024 * 1024)).ceil()));
        return serverBase.resolve(
          '$downloadPath?cors=true&r=${_nonce()}&ckSize=$chunkCount',
        );
      },
      uploadUriBuilder: () =>
          serverBase.resolve('$uploadPath?cors=true&r=${_nonce()}'),
      latencyUriBuilder: () =>
          serverBase.resolve('$pingPath?cors=true&r=${_nonce()}'),
    );

    try {
      final latency = await _measureSingleLatencySample(
        client,
        resolvedBackend,
      ).timeout(const Duration(seconds: 4));
      return _ResolvedBackendCandidate(
        backend: resolvedBackend,
        latencyMs: latency,
      );
    } on Object {
      return null;
    }
  }

  _ResolvedBackend _resolvedCustomLibrespeedBackend(_BackendConfig backend) {
    final base = _normalizedEndpointBaseUri(backend.baseUri)!;
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    final usesBackendRoot =
        basePath.endsWith('/backend/') || basePath == 'backend/';

    Uri resolvePath(String relativePath) {
      return base.resolve(
        usesBackendRoot ? relativePath : 'backend/$relativePath',
      );
    }

    return _ResolvedBackend(
      backendName: backend.backendName,
      downloadUriBuilder: (bytes) {
        final chunkCount = max(1, min(1024, (bytes / (1024 * 1024)).ceil()));
        return resolvePath(
          'garbage.php?cors=true&r=${_nonce()}&ckSize=$chunkCount',
        );
      },
      uploadUriBuilder: () => resolvePath('empty.php?cors=true&r=${_nonce()}'),
      latencyUriBuilder: () => resolvePath('empty.php?cors=true&r=${_nonce()}'),
    );
  }
}

enum _BackendKind { cloudflare, librespeed, measurementLab }

class _BackendConfig {
  const _BackendConfig.publicLibrespeed()
    : kind = _BackendKind.librespeed,
      backendName = 'public_librespeed',
      baseUri = 'https://librespeed.org/',
      usePublicServerList = true;

  const _BackendConfig.cloudflare()
    : kind = _BackendKind.cloudflare,
      backendName = 'cloudflare',
      baseUri = 'https://speed.cloudflare.com/',
      usePublicServerList = false;

  const _BackendConfig.librespeed({
    required this.backendName,
    required this.baseUri,
  }) : kind = _BackendKind.librespeed,
       usePublicServerList = false;

  const _BackendConfig.measurementLab()
    : kind = _BackendKind.measurementLab,
      backendName = 'measurement_lab',
      baseUri = 'https://speed.measurementlab.net/',
      usePublicServerList = false;

  final _BackendKind kind;
  final String backendName;
  final String baseUri;
  final bool usePublicServerList;
}

Uri? _normalizedEndpointBaseUri(String rawValue) {
  final parsed = Uri.tryParse(rawValue.trim());
  if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
    return null;
  }

  if (parsed.scheme != 'http' && parsed.scheme != 'https') {
    return null;
  }

  final normalizedPath = parsed.path.endsWith('/')
      ? parsed.path
      : '${parsed.path}/';
  return parsed.replace(path: normalizedPath, query: null, fragment: null);
}

Uri? _normalizedCustomLibrespeedBaseUri(String rawValue) {
  return _normalizedEndpointBaseUri(rawValue);
}

Uri _buildLatencyUri(_ResolvedBackend backend) => backend.latencyUriBuilder();

Uri _buildUploadUri(_ResolvedBackend backend) => backend.uploadUriBuilder();

Uri _buildDownloadUri(_ResolvedBackend backend, int bytes) =>
    backend.downloadUriBuilder(bytes);

class _ResolvedBackend {
  const _ResolvedBackend({
    required this.backendName,
    required this.downloadUriBuilder,
    required this.uploadUriBuilder,
    required this.latencyUriBuilder,
  });

  final String backendName;
  final Uri Function(int bytes) downloadUriBuilder;
  final Uri Function() uploadUriBuilder;
  final Uri Function() latencyUriBuilder;
}

class _ResolvedBackendCandidate {
  const _ResolvedBackendCandidate({
    required this.backend,
    required this.latencyMs,
  });

  final _ResolvedBackend backend;
  final double latencyMs;
}

String _nonce() => DateTime.now().microsecondsSinceEpoch.toString();

class _LatencyStats {
  const _LatencyStats({this.latencyMs, this.jitterMs, this.packetLossPercent});

  factory _LatencyStats.fromSamples(
    List<double> samples, {
    int? totalAttempts,
    int failedAttempts = 0,
  }) {
    if (samples.isEmpty) {
      return _LatencyStats(
        packetLossPercent: totalAttempts == null || totalAttempts == 0
            ? null
            : (failedAttempts / totalAttempts) * 100,
      );
    }

    final sortedSamples = [...samples]..sort();
    final median = sortedSamples[sortedSamples.length ~/ 2];
    if (samples.length < 2) {
      return _LatencyStats(latencyMs: median);
    }

    var distanceSum = 0.0;
    for (var index = 1; index < samples.length; index++) {
      distanceSum += (samples[index] - samples[index - 1]).abs();
    }

    return _LatencyStats(
      latencyMs: median,
      jitterMs: distanceSum / (samples.length - 1),
      packetLossPercent: totalAttempts == null || totalAttempts == 0
          ? null
          : (failedAttempts / totalAttempts) * 100,
    );
  }

  final double? latencyMs;
  final double? jitterMs;
  final double? packetLossPercent;
}

class _TransferStats {
  const _TransferStats({
    required this.bytesTransferred,
    required this.elapsedMs,
    required this.transferP90Bps,
    required this.overallProgress,
    required this.loadedLatency,
    required this.samplesBps,
  });

  final int bytesTransferred;
  final double elapsedMs;
  final double? transferP90Bps;
  final double overallProgress;
  final _LatencyStats loadedLatency;
  final List<double> samplesBps;
}

class _StageDefinition {
  const _StageDefinition({required this.bytes, required this.label});

  final int bytes;
  final String label;
}

class _PerSecondSampler {
  final List<double> _samples = <double>[];
  int _lastBytes = 0;
  int _lastElapsedMs = 0;

  void capture({required int totalBytes, required Duration elapsed}) {
    final elapsedMs = elapsed.inMilliseconds;
    final deltaMs = elapsedMs - _lastElapsedMs;
    if (deltaMs < 1000) {
      return;
    }

    final deltaBytes = totalBytes - _lastBytes;
    _samples.add((deltaBytes * 8 * 1000) / max(deltaMs, 1));
    _lastBytes = totalBytes;
    _lastElapsedMs = elapsedMs;
  }

  List<double> finish({required int totalBytes, required Duration elapsed}) {
    final elapsedMs = elapsed.inMilliseconds;
    final deltaBytes = totalBytes - _lastBytes;
    final deltaMs = elapsedMs - _lastElapsedMs;

    if (deltaBytes > 0 && deltaMs > 0) {
      _samples.add((deltaBytes * 8 * 1000) / deltaMs);
      _lastBytes = totalBytes;
      _lastElapsedMs = elapsedMs;
    } else if (_samples.isEmpty && totalBytes > 0 && elapsedMs > 0) {
      _samples.add((totalBytes * 8 * 1000) / elapsedMs);
    }

    return List<double>.unmodifiable(_samples);
  }

  List<double> get previewSamples => List<double>.unmodifiable(_samples);
}
