import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/features/measurements/backends/core/base.dart';
import 'package:mobile/src/features/measurements/internet_speed_test_settings_controller.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';

class InternetSpeedTestEngine {
  const InternetSpeedTestEngine({
    required HttpInternetSpeedTestAdvancedSettings httpSettings,
    required MeasurementLabAdvancedSettings measurementLabSettings,
  }) : _httpSettings = httpSettings,
       _measurementLabSettings = measurementLabSettings;

  final HttpInternetSpeedTestAdvancedSettings _httpSettings;
  final MeasurementLabAdvancedSettings _measurementLabSettings;

  static const int _measurementLabUploadChunkSizeBytes = 256 * 1000;
  static const Duration _measurementLabUploadYield = Duration(milliseconds: 4);
  static const String _ndt7SubProtocol = 'net.measurementlab.ndt.v7';
  static const int _loadedLatencyProbeIntervalMs = 400;
  static const List<_StageDefinition> _defaultDownloadStages = [
    _StageDefinition(bytes: 100 * 1000, label: '100 KB'),
    _StageDefinition(bytes: 1 * 1000 * 1000, label: '1 MB'),
    _StageDefinition(bytes: 10 * 1000 * 1000, label: '10 MB'),
    _StageDefinition(bytes: 25 * 1000 * 1000, label: '25 MB'),
    _StageDefinition(bytes: 100 * 1000 * 1000, label: '100 MB'),
    _StageDefinition(bytes: 250 * 1000 * 1000, label: '250 MB'),
  ];
  static const List<_StageDefinition> _defaultUploadStages = [
    _StageDefinition(bytes: 100 * 1000, label: '100 KB'),
    _StageDefinition(bytes: 1 * 1000 * 1000, label: '1 MB'),
    _StageDefinition(bytes: 10 * 1000 * 1000, label: '10 MB'),
    _StageDefinition(bytes: 25 * 1000 * 1000, label: '25 MB'),
    _StageDefinition(bytes: 50 * 1000 * 1000, label: '50 MB'),
  ];

  List<_StageDefinition> get _downloadStages => _stagesFromBytes(
    _httpSettings.downloadStageBytes,
    _defaultDownloadStages,
  );

  List<_StageDefinition> get _uploadStages =>
      _stagesFromBytes(_httpSettings.uploadStageBytes, _defaultUploadStages);

  int get totalDownloadPlannedBytes => _sumStageBytes(_downloadStages);
  int get totalUploadPlannedBytes => _sumStageBytes(_uploadStages);
  int get _idleLatencySampleCount => _httpSettings.latencySampleCount;
  int get _streamCount => _httpSettings.parallelStreams;

  Future<InternetMeasurementResult> recordConfiguredMeasurement({
    required BackendConfig backend,
    required InternetSpeedTestProgressCallback onProgress,
  }) async {
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
          downloadBps: download.transferMeanBps,
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
        downloadBps: download.transferMeanBps,
        downloadElapsedMs: download.elapsedMs,
        downloadLoadedLatencyMs: download.loadedLatency.latencyMs,
        downloadLoadedJitterMs: download.loadedLatency.jitterMs,
        downloadLoadedPacketLossPercent:
            download.loadedLatency.packetLossPercent,
        downloadSize: download.bytesTransferred.toDouble(),
        downloadSamplesBps: download.samplesBps,
        uploadBps: upload.transferMeanBps,
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

  Future<InternetMeasurementResult> recordMeasurementLab({
    required InternetSpeedTestProgressCallback onProgress,
  }) async {
    final downloadDuration = Duration(
      seconds: _measurementLabSettings.downloadDurationSeconds,
    );
    final uploadDuration = Duration(
      seconds: _measurementLabSettings.uploadDurationSeconds,
    );
    const streamCount = 1;

    onProgress(
      const InternetSpeedTestProgress(
        phase: InternetSpeedTestPhase.measuringLatency,
        overallProgress: 0.02,
        progress: 0,
      ),
    );

    final session = await _discoverMeasurementLabSession(
      downloadDuration: downloadDuration,
      uploadDuration: uploadDuration,
    );

    final download = await _runMeasurementLabPhase(
      phase: InternetSpeedTestPhase.testingDownload,
      session: session,
      plannedDuration: downloadDuration,
      overallBase: 0.02,
      overallWeight: 0.48,
      existingDownloadSamples: const [],
      onProgress: onProgress,
    );

    onProgress(
      InternetSpeedTestProgress(
        phase: InternetSpeedTestPhase.testingUpload,
        overallProgress: download.overallProgress,
        progress: 0,
        activeStageLabel: 'Measurement Lab upload',
        downloadBps: download.transferMeanBps,
        phaseLatencyMs: download.loadedLatency.latencyMs,
        phaseJitterMs: download.loadedLatency.jitterMs,
        streamCount: streamCount,
      ),
    );

    final upload = await _runMeasurementLabPhase(
      phase: InternetSpeedTestPhase.testingUpload,
      session: session,
      plannedDuration: uploadDuration,
      overallBase: 0.5,
      overallWeight: 0.5,
      existingDownloadSamples: download.samplesBps,
      onProgress: onProgress,
    );

    final result = InternetMeasurementResult(
      backend: 'measurement_lab',
      streamCount: streamCount,
      downloadBps: download.transferMeanBps,
      downloadElapsedMs: download.elapsedMs,
      downloadLoadedLatencyMs: download.loadedLatency.latencyMs,
      downloadLoadedJitterMs: download.loadedLatency.jitterMs,
      downloadSize: download.bytesTransferred.toDouble(),
      downloadSamplesBps: download.samplesBps,
      uploadBps: upload.transferMeanBps,
      uploadElapsedMs: upload.elapsedMs,
      uploadLoadedLatencyMs: upload.loadedLatency.latencyMs,
      uploadLoadedJitterMs: upload.loadedLatency.jitterMs,
      uploadSize: upload.bytesTransferred.toDouble(),
      uploadSamplesBps: upload.samplesBps,
    );

    onProgress(
      InternetSpeedTestProgress(
        phase: InternetSpeedTestPhase.completed,
        overallProgress: 1,
        progress: 1,
        activeStageLabel: 'Completed',
        downloadBps: result.downloadBps,
        phaseLatencyMs: result.uploadLoadedLatencyMs,
        phaseJitterMs: result.uploadLoadedJitterMs,
        streamCount: result.streamCount,
        uploadBps: result.uploadBps,
      ),
    );

    return result;
  }

  Future<_MeasurementLabSession> _discoverMeasurementLabSession({
    required Duration downloadDuration,
    required Duration uploadDuration,
  }) async {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 10);
    const discoveryUri =
        'https://locate.measurementlab.net/v2/nearest/ndt/ndt7?format=json';

    try {
      final request = await httpClient.getUrl(Uri.parse(discoveryUri));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'whm-mobile/0.1.0');
      final response = await request.close();
      final body = await utf8.decodeStream(response);

      if (response.statusCode == 204) {
        throw HttpException(AppMessages.measurementLabUnavailable);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Measurement Lab discovery failed with status ${response.statusCode}.',
          uri: Uri.parse(discoveryUri),
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Measurement Lab discovery response is malformed.',
        );
      }

      final results = decoded['results'];
      if (results is! List || results.isEmpty) {
        throw HttpException(AppMessages.measurementLabUnavailable);
      }

      final first = results.first;
      if (first is! Map<String, dynamic>) {
        throw const FormatException(
          'Measurement Lab server record is malformed.',
        );
      }

      final urls = first['urls'];
      final host = first['hostname'];
      if (urls is! Map || host is! String) {
        throw const FormatException('Measurement Lab server URLs are missing.');
      }

      final downloadUrl = urls['wss:///ndt/v7/download']?.toString();
      final uploadUrl = urls['wss:///ndt/v7/upload']?.toString();
      if (downloadUrl == null || uploadUrl == null) {
        throw const FormatException(
          'Measurement Lab did not return NDT7 URLs.',
        );
      }

      return _MeasurementLabSession(
        host: host,
        downloadUrl: Uri.parse(downloadUrl),
        uploadUrl: Uri.parse(uploadUrl),
        downloadDuration: downloadDuration,
        uploadDuration: uploadDuration,
      );
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<_TransferStats> _runMeasurementLabPhase({
    required InternetSpeedTestPhase phase,
    required _MeasurementLabSession session,
    required Duration plannedDuration,
    required double overallBase,
    required double overallWeight,
    required List<double> existingDownloadSamples,
    required InternetSpeedTestProgressCallback onProgress,
  }) async {
    final url = phase == InternetSpeedTestPhase.testingDownload
        ? session.downloadUrl
        : session.uploadUrl;
    final sampler = _PerSecondSampler();
    final loadedLatency = <double>[];
    late final WebSocket socket;
    Timer? progressTimer;
    Timer? loadedProbeTimer;
    final phaseStart = DateTime.now();
    int bytesTransferred = 0;
    bool testRunning = false;
    bool phaseCompleted = false;
    Object? protocolError;

    try {
      socket = await WebSocket.connect(
        url.toString(),
        protocols: const [_ndt7SubProtocol],
      );
      if (socket.protocol != _ndt7SubProtocol) {
        throw WebSocketException(
          'Measurement Lab websocket did not negotiate NDT7.',
        );
      }

      final done = Completer<void>();

      Future<void> recordLoadedLatency() async {
        try {
          final latency = await _measureLoadedLatencySample(session.host);
          if (latency != null) {
            _appendLimitedSample(
              loadedLatency,
              latency,
              _measurementLabSettings.latencySampleCount,
            );
          }
        } on Object {
          // Keep the active test running if a loaded RTT probe fails.
        }
      }

      progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final elapsed = DateTime.now().difference(phaseStart);
        sampler.capture(totalBytes: bytesTransferred, elapsed: elapsed);
        final progress =
            (elapsed.inMilliseconds / plannedDuration.inMilliseconds).clamp(
              0.0,
              1.0,
            );
        final previewBps = _sustainedBps(
          bytesTransferred: bytesTransferred,
          elapsed: elapsed,
        );
        onProgress(
          InternetSpeedTestProgress(
            phase: phase,
            overallProgress: (overallBase + (progress * overallWeight)).clamp(
              0.0,
              1.0,
            ),
            progress: progress,
            activeStageLabel: phase == InternetSpeedTestPhase.testingDownload
                ? 'Measurement Lab download'
                : 'Measurement Lab upload',
            downloadBps: phase == InternetSpeedTestPhase.testingDownload
                ? previewBps
                : _meanBps(existingDownloadSamples),
            uploadBps: phase == InternetSpeedTestPhase.testingUpload
                ? previewBps
                : null,
            phaseLatencyMs: loadedLatency.isEmpty ? null : loadedLatency.last,
            streamCount: 1,
          ),
        );
      });

      loadedProbeTimer = Timer.periodic(
        const Duration(milliseconds: _loadedLatencyProbeIntervalMs),
        (_) => recordLoadedLatency(),
      );

      socket.listen(
        (event) async {
          try {
            if (event is String) {
              if (event.isEmpty) {
                return;
              }

              final decoded = jsonDecode(event);
              if (decoded is! Map<String, dynamic>) {
                return;
              }

              if (decoded['ConnectionInfo'] != null) {
                testRunning = true;
                return;
              }

              final testMsg = decoded['TestMsg'];
              if (testMsg is String) {
                final parsed = int.tryParse(testMsg);
                if (phase == InternetSpeedTestPhase.testingUpload) {
                  if (parsed == null || parsed <= 0) {
                    return;
                  }

                  final random = Random();
                  final chunk = Uint8List(_measurementLabUploadChunkSizeBytes);
                  while (!phaseCompleted &&
                      DateTime.now().difference(phaseStart) < plannedDuration) {
                    for (var index = 0; index < chunk.length; index++) {
                      chunk[index] = random.nextInt(256);
                    }
                    socket.add(chunk);
                    bytesTransferred += chunk.length;
                    await Future<void>.delayed(_measurementLabUploadYield);
                  }
                  phaseCompleted = true;
                  await socket.close();
                  if (!done.isCompleted) {
                    done.complete();
                  }
                }
                return;
              }

              if (decoded['TestResult'] != null ||
                  decoded['Web100'] != null ||
                  decoded['BBRInfo'] != null) {
                phaseCompleted = true;
                if (!done.isCompleted) {
                  done.complete();
                }
              }
            } else if (event is List<int>) {
              if (phase == InternetSpeedTestPhase.testingDownload) {
                bytesTransferred += event.length;
                if (!testRunning) {
                  testRunning = true;
                }
                if (DateTime.now().difference(phaseStart) >= plannedDuration) {
                  phaseCompleted = true;
                  await socket.close();
                }
              }
            }
          } catch (error) {
            protocolError = error;
            phaseCompleted = true;
            if (!done.isCompleted) {
              done.completeError(error);
            }
          }
        },
        onDone: () {
          phaseCompleted = true;
          if (!done.isCompleted) {
            done.complete();
          }
        },
        onError: (Object error) {
          protocolError = error;
          phaseCompleted = true;
          if (!done.isCompleted) {
            done.completeError(error);
          }
        },
        cancelOnError: false,
      );

      await done.future;
      if (protocolError != null) {
        throw protocolError!;
      }

      final elapsed = DateTime.now().difference(phaseStart);
      final samples = sampler.finish(
        totalBytes: bytesTransferred,
        elapsed: elapsed,
      );
      final allSamples = [
        if (phase == InternetSpeedTestPhase.testingUpload)
          ...existingDownloadSamples,
        ...samples,
      ];
      final loadedLatencyStats = _LatencyStats.fromSamples(loadedLatency);

      return _TransferStats(
        bytesTransferred: bytesTransferred,
        elapsedMs: elapsed.inMilliseconds.toDouble(),
        transferMeanBps: _sustainedBps(
          bytesTransferred: bytesTransferred,
          elapsed: elapsed,
        ),
        overallProgress: (overallBase + overallWeight).clamp(0.0, 1.0),
        loadedLatency: loadedLatencyStats,
        samplesBps: List<double>.unmodifiable(allSamples),
      );
    } finally {
      progressTimer?.cancel();
      loadedProbeTimer?.cancel();
    }
  }

  Future<_LatencyStats> _measureIdleLatency(
    HttpClient client,
    _ResolvedBackend backend,
  ) async {
    final samples = <double>[];
    var failedAttempts = 0;
    final totalAttempts = _idleLatencySampleCount <= 0
        ? 3
        : _idleLatencySampleCount;

    for (var attempt = 0; attempt < totalAttempts; attempt++) {
      try {
        final latency = await _measureSingleLatencySample(client, backend);
        samples.add(latency);
      } on Object {
        failedAttempts += 1;
      }
    }

    return _LatencyStats.fromSamples(
      samples,
      totalAttempts: totalAttempts,
      failedAttempts: failedAttempts,
    );
  }

  Future<double> _measureSingleLatencySample(
    HttpClient client,
    _ResolvedBackend backend,
  ) async {
    final stopwatch = Stopwatch()..start();
    final request = await client.getUrl(_buildLatencyUri(backend));
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.followRedirects = false;
    final response = await request.close();
    await response.drain<void>();
    stopwatch.stop();

    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw HttpException(
        'Latency probe failed with status ${response.statusCode}.',
      );
    }

    return stopwatch.elapsedMicroseconds / 1000;
  }

  Future<double?> _measureLoadedLatencySample(String host) async {
    final probeClient = HttpClient();
    probeClient.connectionTimeout = const Duration(seconds: 10);

    try {
      final probeUri = Uri.https(host, '/ndt/v7/download');
      final stopwatch = Stopwatch()..start();
      final request = await probeClient.getUrl(probeUri);
      request.followRedirects = false;
      final response = await request.close();
      await response.drain<void>();
      stopwatch.stop();

      return stopwatch.elapsedMicroseconds / 1000;
    } on Object {
      return null;
    } finally {
      probeClient.close(force: true);
    }
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
    final stageSamples = <double>[
      if (phase == InternetSpeedTestPhase.testingUpload)
        ...existingDownloadSamples,
    ];
    final loadedLatencySamples = <double>[];
    var totalBytes = 0;
    var totalElapsedMs = 0.0;

    for (var index = 0; index < stages.length; index++) {
      final stage = stages[index];
      final result = await _runTransferStage(
        client: client,
        phase: phase,
        backend: backend,
        stage: stage,
        completedPhaseBytes: totalBytes,
        totalPhaseBytes: _sumStageBytes(stages),
        completedOverallBytes: phase == InternetSpeedTestPhase.testingDownload
            ? totalBytes
            : totalDownloadPlannedBytes + totalBytes,
        totalOverallBytes: totalDownloadPlannedBytes + totalUploadPlannedBytes,
        loadedLatencySamples: loadedLatencySamples,
        idleLatency: idleLatency,
        existingSamples: stageSamples,
        onProgress: onProgress,
      );

      totalBytes += result.bytesTransferred;
      totalElapsedMs += result.elapsedMs;
      stageSamples
        ..clear()
        ..addAll(result.samplesBps);

      if (index < stages.length - 1) {
        onProgress(
          InternetSpeedTestProgress(
            phase: phase,
            overallProgress: result.overallProgress,
            progress: _phaseProgress(
              completedPhaseBytes: totalBytes,
              totalPhaseBytes: _sumStageBytes(stages),
            ),
            activeStageLabel:
                '${stages[index + 1].label} ${phase == InternetSpeedTestPhase.testingDownload ? 'download' : 'upload'}',
            idleLatencyMs: idleLatency.latencyMs,
            idleJitterMs: idleLatency.jitterMs,
            idlePacketLossPercent: idleLatency.packetLossPercent,
            downloadBps: phase == InternetSpeedTestPhase.testingDownload
                ? result.transferMeanBps
                : _meanBps(existingDownloadSamples),
            uploadBps: phase == InternetSpeedTestPhase.testingUpload
                ? result.transferMeanBps
                : null,
            phaseLatencyMs: result.loadedLatency.latencyMs,
            phaseJitterMs: result.loadedLatency.jitterMs,
            phasePacketLossPercent: result.loadedLatency.packetLossPercent,
            streamCount: _streamCount,
          ),
        );
      }
    }

    return _TransferStats(
      bytesTransferred: totalBytes,
      elapsedMs: totalElapsedMs,
      transferMeanBps: _sustainedBps(
        bytesTransferred: totalBytes,
        elapsedMs: totalElapsedMs,
      ),
      overallProgress: _overallProgress(
        completedOverallBytes: phase == InternetSpeedTestPhase.testingDownload
            ? totalBytes
            : totalDownloadPlannedBytes + totalBytes,
        totalOverallBytes: totalDownloadPlannedBytes + totalUploadPlannedBytes,
      ),
      loadedLatency: _LatencyStats.fromSamples(loadedLatencySamples),
      samplesBps: List<double>.unmodifiable(stageSamples),
    );
  }

  Future<_TransferStats> _runTransferStage({
    required HttpClient client,
    required InternetSpeedTestPhase phase,
    required _ResolvedBackend backend,
    required _StageDefinition stage,
    required int completedPhaseBytes,
    required int totalPhaseBytes,
    required int completedOverallBytes,
    required int totalOverallBytes,
    required List<double> loadedLatencySamples,
    required _LatencyStats idleLatency,
    required List<double> existingSamples,
    required InternetSpeedTestProgressCallback onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final perSecondSampler = _PerSecondSampler();
    final stageLoadedLatency = <double>[];
    final requestUri = phase == InternetSpeedTestPhase.testingDownload
        ? _buildDownloadUri(backend, stage.bytes)
        : _buildUploadUri(backend);
    final payload = phase == InternetSpeedTestPhase.testingUpload
        ? Uint8List(stage.bytes)
        : null;
    var bytesTransferred = 0;
    var uploadSinkClosed = false;

    Future<void> performLoadedProbe() async {
      final latency = await _measureSingleLatencySample(client, backend);
      _appendLimitedSample(
        loadedLatencySamples,
        latency,
        _idleLatencySampleCount,
      );
      stageLoadedLatency.add(latency);
    }

    final loadedProbeTimer = Timer.periodic(
      const Duration(milliseconds: _loadedLatencyProbeIntervalMs),
      (_) => performLoadedProbe().ignore(),
    );

    try {
      final request = await client.openUrl(
        phase == InternetSpeedTestPhase.testingDownload ? 'GET' : 'POST',
        requestUri,
      );
      request.followRedirects = false;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      if (payload != null) {
        request.headers.set(HttpHeaders.contentLengthHeader, payload.length);
        request.add(payload);
      }

      final response = await request.close();
      if (payload != null) {
        uploadSinkClosed = true;
      }

      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException(
          '${phase == InternetSpeedTestPhase.testingDownload ? 'Download' : 'Upload'} stage failed with status ${response.statusCode}.',
          uri: requestUri,
        );
      }

      if (phase == InternetSpeedTestPhase.testingDownload) {
        await for (final chunk in response) {
          bytesTransferred += chunk.length;
          perSecondSampler.capture(
            totalBytes: bytesTransferred,
            elapsed: stopwatch.elapsed,
          );
          final previewSamples = [
            ...existingSamples,
            ...perSecondSampler.previewSamples,
          ];
          onProgress(
            InternetSpeedTestProgress(
              phase: phase,
              overallProgress: _overallProgress(
                completedOverallBytes: completedOverallBytes + bytesTransferred,
                totalOverallBytes: totalOverallBytes,
              ),
              progress: _phaseProgress(
                completedPhaseBytes: completedPhaseBytes + bytesTransferred,
                totalPhaseBytes: totalPhaseBytes,
              ),
              activeStageLabel: '${stage.label} download',
              idleLatencyMs: idleLatency.latencyMs,
              idleJitterMs: idleLatency.jitterMs,
              idlePacketLossPercent: idleLatency.packetLossPercent,
              downloadBps: _meanBps(previewSamples),
              phaseLatencyMs: loadedLatencySamples.isEmpty
                  ? null
                  : loadedLatencySamples.last,
              phaseJitterMs: _LatencyStats.fromSamples(
                stageLoadedLatency,
              ).jitterMs,
              phasePacketLossPercent: _LatencyStats.fromSamples(
                stageLoadedLatency,
              ).packetLossPercent,
              streamCount: _streamCount,
            ),
          );
        }
      } else {
        bytesTransferred = payload?.length ?? 0;
        await response.drain<void>();
        perSecondSampler.capture(
          totalBytes: bytesTransferred,
          elapsed: stopwatch.elapsed,
        );
      }
    } finally {
      loadedProbeTimer.cancel();
      stopwatch.stop();
      if (!uploadSinkClosed && phase == InternetSpeedTestPhase.testingUpload) {
        // No-op. Request sink is already closed by request.close.
      }
    }

    final samples = perSecondSampler.finish(
      totalBytes: bytesTransferred,
      elapsed: stopwatch.elapsed,
    );
    final allSamples = [...existingSamples, ...samples];
    final loadedLatency = _LatencyStats.fromSamples(stageLoadedLatency);

    return _TransferStats(
      bytesTransferred: bytesTransferred,
      elapsedMs: stopwatch.elapsedMilliseconds.toDouble(),
      transferMeanBps: _sustainedBps(
        bytesTransferred: bytesTransferred,
        elapsed: stopwatch.elapsed,
      ),
      overallProgress: _overallProgress(
        completedOverallBytes: completedOverallBytes + bytesTransferred,
        totalOverallBytes: totalOverallBytes,
      ),
      loadedLatency: loadedLatency,
      samplesBps: List<double>.unmodifiable(allSamples),
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

  List<_StageDefinition> _stagesFromBytes(
    List<int> values,
    List<_StageDefinition> defaults,
  ) {
    final selected = values.toSet();
    final stages = defaults
        .where((stage) => selected.contains(stage.bytes))
        .toList(growable: false);
    return stages.isEmpty ? defaults : stages;
  }

  void _appendLimitedSample(List<double> values, double value, int limit) {
    values.add(value);
    if (values.length > limit) {
      values.removeAt(0);
    }
  }

  double? _meanBps(List<double> values) {
    if (values.isEmpty) {
      return null;
    }

    final total = values.fold<double>(0, (sum, value) => sum + value);
    return total / values.length;
  }

  double? _sustainedBps({
    required int bytesTransferred,
    Duration? elapsed,
    double? elapsedMs,
  }) {
    final computedElapsedMs = elapsedMs ?? elapsed?.inMilliseconds.toDouble();
    if (bytesTransferred <= 0 ||
        computedElapsedMs == null ||
        computedElapsedMs <= 0) {
      return null;
    }

    return (bytesTransferred * 8 * 1000) / computedElapsedMs;
  }

  Future<_ResolvedBackend> _resolveBackend(
    HttpClient client,
    BackendConfig backend,
  ) async {
    switch (backend.kind) {
      case BackendKind.cloudflare:
        return _ResolvedBackend(
          backendName: backend.backendName,
          downloadUriBuilder: (bytes) =>
              Uri.parse('${backend.baseUri}__down?bytes=$bytes'),
          uploadUriBuilder: () => Uri.parse('${backend.baseUri}__up'),
          latencyUriBuilder: () =>
              Uri.parse('${backend.baseUri}__down?bytes=1'),
        );
      case BackendKind.librespeed:
        if (backend.usePublicServerList) {
          return _resolvePublicLibrespeedBackend(client, backend);
        }

        return _resolvedCustomLibrespeedBackend(backend);
      case BackendKind.measurementLab:
        throw UnsupportedError(AppMessages.measurementLabUnavailable);
    }
  }

  Future<_ResolvedBackend> _resolvePublicLibrespeedBackend(
    HttpClient client,
    BackendConfig backend,
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
        throw HttpException(
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
    final serverBase = serverValue == null
        ? null
        : normalizedEndpointBaseUri(serverValue);
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

  _ResolvedBackend _resolvedCustomLibrespeedBackend(BackendConfig backend) {
    final base = normalizedEndpointBaseUri(backend.baseUri)!;
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

enum BackendKind { cloudflare, librespeed, measurementLab }

class BackendConfig {
  const BackendConfig.publicLibrespeed()
    : kind = BackendKind.librespeed,
      backendName = 'public_librespeed',
      baseUri = 'https://librespeed.org/',
      usePublicServerList = true;

  const BackendConfig.cloudflare()
    : kind = BackendKind.cloudflare,
      backendName = 'cloudflare',
      baseUri = 'https://speed.cloudflare.com/',
      usePublicServerList = false;

  const BackendConfig.librespeed({
    required this.backendName,
    required this.baseUri,
  }) : kind = BackendKind.librespeed,
       usePublicServerList = false;

  final BackendKind kind;
  final String backendName;
  final String baseUri;
  final bool usePublicServerList;
}

Uri? normalizedEndpointBaseUri(String rawValue) {
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

Uri? normalizedCustomLibrespeedBaseUri(String rawValue) {
  return normalizedEndpointBaseUri(rawValue);
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

class _MeasurementLabSession {
  const _MeasurementLabSession({
    required this.host,
    required this.downloadUrl,
    required this.uploadUrl,
    required this.downloadDuration,
    required this.uploadDuration,
  });

  final String host;
  final Uri downloadUrl;
  final Uri uploadUrl;
  final Duration downloadDuration;
  final Duration uploadDuration;
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
    required this.transferMeanBps,
    required this.overallProgress,
    required this.loadedLatency,
    required this.samplesBps,
  });

  final int bytesTransferred;
  final double elapsedMs;
  final double? transferMeanBps;
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
