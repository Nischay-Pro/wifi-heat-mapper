import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/features/measurements/local_measurement_settings_controller.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';

final localMeasurementTestProvider = Provider<LocalMeasurementTest>((ref) {
  final settings = ref.watch(localMeasurementSettingsControllerProvider);

  if (!settings.hasServerConfigured) {
    return const DisabledLocalMeasurementTest();
  }

  if (settings.modes.enabledCount == 0) {
    return const DisabledLocalMeasurementTest();
  }

  if (!Platform.isAndroid) {
    return UnavailableLocalMeasurementTest(
      message: AppMessages.intranetUnavailable,
    );
  }

  return AndroidIperfLocalMeasurementTest(settings: settings);
});

typedef LocalMeasurementProgressCallback =
    void Function(double progress, String activeStageLabel);

abstract class LocalMeasurementTest {
  const LocalMeasurementTest();

  Future<InternetMeasurementResult?> recordLocalMeasurement({
    String? bindAddress,
    LocalMeasurementProgressCallback? onProgress,
  });
}

class DisabledLocalMeasurementTest extends LocalMeasurementTest {
  const DisabledLocalMeasurementTest();

  @override
  Future<InternetMeasurementResult?> recordLocalMeasurement({
    String? bindAddress,
    LocalMeasurementProgressCallback? onProgress,
  }) async => null;
}

class UnavailableLocalMeasurementTest extends LocalMeasurementTest {
  const UnavailableLocalMeasurementTest({required this.message});

  final String message;

  @override
  Future<InternetMeasurementResult?> recordLocalMeasurement({
    String? bindAddress,
    LocalMeasurementProgressCallback? onProgress,
  }) {
    throw StateError(message);
  }
}

class AndroidIperfLocalMeasurementTest extends LocalMeasurementTest {
  AndroidIperfLocalMeasurementTest({required this.settings});

  final LocalMeasurementSettings settings;
  static const MethodChannel _channel = MethodChannel('iperf_native');
  static const int _modeDurationSeconds = 10;
  static const Duration _modeTimeout = Duration(seconds: 45);

  @override
  Future<InternetMeasurementResult?> recordLocalMeasurement({
    String? bindAddress,
    LocalMeasurementProgressCallback? onProgress,
  }) async {
    final executablePath = await _channel.invokeMethod<String>(
      'prepareExecutable',
    );
    if (executablePath == null || executablePath.isEmpty) {
      throw StateError(AppMessages.intranetUnavailable);
    }
    final configuredModes = <_IperfMode>[
      if (settings.modes.tcpDownloadEnabled)
        const _IperfMode.tcp(download: true),
      if (settings.modes.tcpUploadEnabled)
        const _IperfMode.tcp(download: false),
      if (settings.modes.udpDownloadEnabled)
        const _IperfMode.udp(download: true),
      if (settings.modes.udpUploadEnabled)
        const _IperfMode.udp(download: false),
    ];

    if (configuredModes.isEmpty) {
      return null;
    }

    onProgress?.call(0, 'Preparing intranet test');
    final results = <_IperfModeResult>[];
    for (var index = 0; index < configuredModes.length; index++) {
      final mode = configuredModes[index];
      onProgress?.call(index / configuredModes.length, mode.label);
      results.add(
        await _runMode(
          executablePath: executablePath,
          mode: mode,
          bindAddress: bindAddress,
        ),
      );
      onProgress?.call((index + 1) / configuredModes.length, mode.label);
    }

    return _aggregateResults(results);
  }

  Future<_IperfModeResult> _runMode({
    required String executablePath,
    required _IperfMode mode,
    required String? bindAddress,
  }) async {
    final arguments = <String>[
      '-c',
      settings.serverHost!,
      '-p',
      settings.serverPort.toString(),
      '-t',
      _modeDurationSeconds.toString(),
      '-J',
      '--forceflush',
      if (mode.download) '-R',
      if (mode.protocol == _IperfProtocol.udp) '-u',
    ];

    final process = await Process.start(executablePath, arguments);
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode.timeout(
      _modeTimeout,
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        throw TimeoutException(
          'iperf3 ${mode.label} timed out after ${_modeTimeout.inSeconds} seconds.',
        );
      },
    );
    final stdoutText = await stdoutFuture;
    final stderrText = await stderrFuture;

    Map<String, dynamic>? decodedJson;
    if (stdoutText.trim().isNotEmpty) {
      final decoded = jsonDecode(stdoutText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('iperf3 output was not a JSON object.');
      }
      decodedJson = decoded;
    }

    final iperfError = decodedJson == null
        ? null
        : _jsonString(decodedJson['error']);

    if (exitCode != 0 || iperfError != null) {
      final message =
          iperfError ??
          (stderrText.trim().isNotEmpty
              ? stderrText.trim()
              : stdoutText.trim().isNotEmpty
              ? stdoutText.trim()
              : 'iperf3 exited with code $exitCode.');
      throw StateError(message);
    }

    if (decodedJson == null) {
      throw const FormatException('iperf3 did not return JSON output.');
    }

    return _IperfModeResult(mode: mode, json: decodedJson);
  }

  InternetMeasurementResult _aggregateResults(List<_IperfModeResult> results) {
    double? tcpDownloadBps;
    double? tcpUploadBps;
    double? udpDownloadBps;
    double? udpUploadBps;
    double? downloadElapsedMs;
    double? uploadElapsedMs;
    double? downloadJitterMs;
    double? uploadJitterMs;
    double? downloadPacketLossPercent;
    double? uploadPacketLossPercent;

    for (final result in results) {
      final durationMs = result.durationSeconds == null
          ? null
          : result.durationSeconds! * 1000;
      if (result.mode.protocol == _IperfProtocol.tcp && result.mode.download) {
        tcpDownloadBps = result.bitsPerSecond;
        downloadElapsedMs = durationMs;
      } else if (result.mode.protocol == _IperfProtocol.tcp &&
          !result.mode.download) {
        tcpUploadBps = result.bitsPerSecond;
        uploadElapsedMs = durationMs;
      } else if (result.mode.protocol == _IperfProtocol.udp &&
          result.mode.download) {
        udpDownloadBps = result.bitsPerSecond;
        downloadElapsedMs ??= durationMs;
        downloadJitterMs = result.jitterMs;
        downloadPacketLossPercent = result.packetLossPercent;
      } else if (result.mode.protocol == _IperfProtocol.udp &&
          !result.mode.download) {
        udpUploadBps = result.bitsPerSecond;
        uploadElapsedMs ??= durationMs;
        uploadJitterMs = result.jitterMs;
        uploadPacketLossPercent = result.packetLossPercent;
      }
    }

    return InternetMeasurementResult(
      backend: 'iperf3',
      downloadBps: tcpDownloadBps ?? udpDownloadBps,
      downloadElapsedMs: downloadElapsedMs,
      downloadLoadedJitterMs: downloadJitterMs,
      downloadLoadedPacketLossPercent: downloadPacketLossPercent,
      uploadBps: tcpUploadBps ?? udpUploadBps,
      uploadElapsedMs: uploadElapsedMs,
      uploadLoadedJitterMs: uploadJitterMs,
      uploadLoadedPacketLossPercent: uploadPacketLossPercent,
      streamCount: 1,
    );
  }
}

String? _jsonString(Object? value) {
  return switch (value) {
    String text when text.trim().isNotEmpty => text.trim(),
    _ => null,
  };
}

enum _IperfProtocol { tcp, udp }

class _IperfMode {
  const _IperfMode.tcp({required this.download})
    : protocol = _IperfProtocol.tcp;

  const _IperfMode.udp({required this.download})
    : protocol = _IperfProtocol.udp;

  final _IperfProtocol protocol;
  final bool download;

  String get label {
    final direction = download ? 'download' : 'upload';
    final transport = protocol == _IperfProtocol.tcp ? 'TCP' : 'UDP';
    return '$transport $direction';
  }
}

class _IperfModeResult {
  const _IperfModeResult({required this.mode, required this.json});

  final _IperfMode mode;
  final Map<String, dynamic> json;

  double? get durationSeconds {
    final start = json['start'];
    if (start is! Map<String, dynamic>) {
      return null;
    }

    final testStart = start['test_start'];
    if (testStart is! Map<String, dynamic>) {
      return null;
    }

    final duration = testStart['duration'];
    return switch (duration) {
      int value => value.toDouble(),
      double value => value,
      _ => null,
    };
  }

  double? get bitsPerSecond {
    final summary = _summaryMap;
    final value = summary?['bits_per_second'];
    return switch (value) {
      int parsed => parsed.toDouble(),
      double parsed => parsed,
      _ => null,
    };
  }

  double? get jitterMs {
    final summary = _summaryMap;
    final value = summary?['jitter_ms'];
    return switch (value) {
      int parsed => parsed.toDouble(),
      double parsed => parsed,
      _ => null,
    };
  }

  double? get packetLossPercent {
    final summary = _summaryMap;
    final lostPercent = summary?['lost_percent'];
    return switch (lostPercent) {
      int parsed => parsed.toDouble(),
      double parsed => parsed,
      _ => null,
    };
  }

  Map<String, dynamic>? get _summaryMap {
    final end = json['end'];
    if (end is! Map<String, dynamic>) {
      return null;
    }

    if (mode.protocol == _IperfProtocol.tcp) {
      final key = mode.download ? 'sum_received' : 'sum_sent';
      final value = end[key];
      return value is Map<String, dynamic> ? value : null;
    }

    final value = end['sum'];
    return value is Map<String, dynamic> ? value : null;
  }
}
