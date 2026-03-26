import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/features/measurements/backends/core/base.dart';
import 'package:mobile/src/features/measurements/local_measurement_settings_controller.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';

class IperfBackend extends LocalMeasurementTest {
  IperfBackend({required this.settings});

  final LocalMeasurementSettings settings;
  static const MethodChannel _channel = MethodChannel('iperf_native');
  static const EventChannel _progressChannel = EventChannel(
    'iperf_native_progress',
  );

  @override
  Future<InternetMeasurementResult?> recordLocalMeasurement({
    String? bindAddress,
    LocalMeasurementProgressCallback? onProgress,
  }) async {
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

    final progressSubscription = _progressChannel
        .receiveBroadcastStream()
        .listen((event) {
          if (onProgress == null || event is! Map) {
            return;
          }

          final progress = switch (event['progress']) {
            int value => value.toDouble(),
            double value => value,
            _ => 0.0,
          };
          final label = event['label']?.toString() ?? 'Local measurement';
          onProgress(progress.clamp(0.0, 1.0), label);
        });

    try {
      final rawResults = await _channel
          .invokeListMethod<dynamic>('runMeasurement', {
            'host': settings.serverHost,
            'port': settings.serverPort,
            'tcpDownloadEnabled': settings.modes.tcpDownloadEnabled,
            'tcpUploadEnabled': settings.modes.tcpUploadEnabled,
            'udpDownloadEnabled': settings.modes.udpDownloadEnabled,
            'udpUploadEnabled': settings.modes.udpUploadEnabled,
          });

      if (rawResults == null || rawResults.isEmpty) {
        return null;
      }

      final results = rawResults.map(_decodeModeResult).toList(growable: false);
      return _aggregateResults(results);
    } on PlatformException catch (error) {
      final message = error.message?.trim();
      throw StateError(
        message == null || message.isEmpty
            ? AppMessages.intranetUnavailable
            : message,
      );
    } finally {
      await progressSubscription.cancel();
    }
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

_IperfModeResult _decodeModeResult(dynamic value) {
  if (value is! Map) {
    throw const FormatException('iperf3 mode result was malformed.');
  }

  final protocolValue = value['protocol']?.toString();
  final downloadValue = value['download'];
  final jsonText = value['json']?.toString();
  if (protocolValue == null || jsonText == null || downloadValue is! bool) {
    throw const FormatException('iperf3 mode result is missing fields.');
  }

  final decoded = jsonDecode(jsonText);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('iperf3 output was not a JSON object.');
  }

  final mode = switch (protocolValue) {
    'tcp' => _IperfMode.tcp(download: downloadValue),
    'udp' => _IperfMode.udp(download: downloadValue),
    _ => throw const FormatException('iperf3 protocol is unsupported.'),
  };

  final iperfError = _jsonString(decoded['error']);
  if (iperfError != null) {
    throw StateError(iperfError);
  }

  return _IperfModeResult(mode: mode, json: decoded);
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
      final summary = end[key];
      return summary is Map<String, dynamic> ? summary : null;
    }

    final summary = end['sum'];
    return summary is Map<String, dynamic> ? summary : null;
  }
}
