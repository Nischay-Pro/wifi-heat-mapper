import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:mobile/src/core/loading_indicator.dart';
import 'package:mobile/src/core/material_spacing.dart';
import 'package:mobile/src/features/measurements/internet_speed_test_service.dart';
import 'package:mobile/src/features/measurements/wifi_metadata_service.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';
import 'package:mobile/src/models/wifi_metadata.dart';

class MeasurementsPage extends ConsumerStatefulWidget {
  const MeasurementsPage({
    super.key,
    required this.selectedSiteSlug,
  });

  final String selectedSiteSlug;

  @override
  ConsumerState<MeasurementsPage> createState() => _MeasurementsPageState();
}

class _MeasurementsPageState extends ConsumerState<MeasurementsPage>
    with WidgetsBindingObserver {
  static const String _seededPointId = 'point-seeded-1';

  WifiMetadata _wifiMetadata = const WifiMetadata();
  InternetMeasurementResult? _internetResult;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isRequestInFlight = false;
  bool _isRecordingMeasurement = false;
  String? _errorMessage;
  String? _internetMeasurementError;
  InternetSpeedTestProgress _internetProgress = const InternetSpeedTestProgress(
    phase: InternetSpeedTestPhase.idle,
    overallProgress: 0,
    progress: 0,
  );
  double _displayedOverallProgress = 0;
  DateTime? _lastRecordedAt;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMetadata(showLoading: true);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _loadMetadata();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadMetadata(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _loadMetadata({bool showLoading = false}) async {
    if (_isRequestInFlight) {
      return;
    }

    _isRequestInFlight = true;

    if (mounted) {
      setState(() {
        if (showLoading) {
          _isLoading = true;
        } else {
          _isRefreshing = true;
        }
        _errorMessage = null;
      });
    }

    try {
      final metadata = await ref.read(wifiMetadataServiceProvider).loadMetadata();
      if (!mounted) {
        return;
      }

      setState(() {
        _wifiMetadata = metadata;
        _isLoading = false;
        _isRefreshing = false;
      });
    } on MissingPluginException {
      if (!mounted) {
        return;
      }

      setState(() {
        _wifiMetadata = const WifiMetadata();
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage =
            'Wi-Fi metadata collection is not available on this device yet.';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _wifiMetadata = const WifiMetadata();
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = error.message ??
            'Could not load Wi-Fi metadata from the device.';
      });
    } finally {
      _isRequestInFlight = false;
    }
  }

  Future<void> _recordMeasurement() async {
    if (_isRecordingMeasurement) {
      return;
    }

    setState(() {
      _isRecordingMeasurement = true;
      _internetMeasurementError = null;
      _internetResult = null;
      _displayedOverallProgress = 0;
      _internetProgress = _internetProgress.mergeWith(const InternetSpeedTestProgress(
        phase: InternetSpeedTestPhase.measuringLatency,
        overallProgress: 0.05,
        progress: 0,
      ));
    });

    try {
      final result = await ref.read(internetSpeedTestServiceProvider).recordInternetMeasurement(
        onProgress: (progress) {
          if (!mounted) {
            return;
          }

          setState(() {
            _internetProgress = _internetProgress.mergeWith(progress);
            _displayedOverallProgress = max(
              _displayedOverallProgress,
              progress.overallProgress,
            );
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _internetResult = result;
        _lastRecordedAt = DateTime.now();
        _displayedOverallProgress = 1;
        _isRecordingMeasurement = false;
      });
    } on SocketException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _internetMeasurementError =
            'Could not reach the public internet test service: ${error.message}.';
        _internetProgress = _internetProgress.mergeWith(const InternetSpeedTestProgress(
          phase: InternetSpeedTestPhase.failed,
          overallProgress: 0,
          progress: 0,
        ));
        _isRecordingMeasurement = false;
      });
    } on HttpException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _internetMeasurementError = error.message;
        _internetProgress = _internetProgress.mergeWith(const InternetSpeedTestProgress(
          phase: InternetSpeedTestPhase.failed,
          overallProgress: 0,
          progress: 0,
        ));
        _isRecordingMeasurement = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _internetMeasurementError = 'Internet measurement failed: $error';
        _internetProgress = _internetProgress.mergeWith(const InternetSpeedTestProgress(
          phase: InternetSpeedTestPhase.failed,
          overallProgress: 0,
          progress: 0,
        ));
        _isRecordingMeasurement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MeasurementsView(
      selectedSiteSlug: widget.selectedSiteSlug,
      seededPointId: _seededPointId,
      wifiMetadata: _wifiMetadata,
      internetResult: _internetResult,
      internetProgress: _internetProgress,
      displayedOverallProgress: _displayedOverallProgress,
      isLoading: _isLoading,
      isRefreshing: _isRefreshing,
      isRecordingMeasurement: _isRecordingMeasurement,
      errorMessage: _errorMessage,
      internetMeasurementError: _internetMeasurementError,
      lastRecordedAt: _lastRecordedAt,
      onRefresh: () => _loadMetadata(showLoading: false),
      onRecordMeasurement: _recordMeasurement,
    );
  }

}

class MeasurementsView extends StatelessWidget {
  const MeasurementsView({
    super.key,
    required this.selectedSiteSlug,
    required this.seededPointId,
    required this.wifiMetadata,
    required this.internetResult,
    required this.internetProgress,
    required this.displayedOverallProgress,
    required this.isLoading,
    required this.isRefreshing,
    required this.isRecordingMeasurement,
    required this.errorMessage,
    required this.internetMeasurementError,
    required this.lastRecordedAt,
    required this.onRefresh,
    required this.onRecordMeasurement,
  });

  final String selectedSiteSlug;
  final String seededPointId;
  final WifiMetadata wifiMetadata;
  final InternetMeasurementResult? internetResult;
  final InternetSpeedTestProgress internetProgress;
  final double displayedOverallProgress;
  final bool isLoading;
  final bool isRefreshing;
  final bool isRecordingMeasurement;
  final String? errorMessage;
  final String? internetMeasurementError;
  final DateTime? lastRecordedAt;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRecordMeasurement;

  @override
  Widget build(BuildContext context) {
    final spacing = MaterialSpacing.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final items = <({String label, String value})>[
      (label: 'SSID', value: wifiMetadata.ssid ?? 'Not available yet'),
      (label: 'BSSID', value: wifiMetadata.bssid ?? 'Not available yet'),
      (label: 'Channel', value: _formatInt(wifiMetadata.channel)),
      (label: 'Channel frequency', value: _formatInt(wifiMetadata.channelFrequency)),
      (label: 'Client IP', value: wifiMetadata.clientIp ?? 'Not available yet'),
      (label: 'Frequency (MHz)', value: _formatInt(wifiMetadata.frequencyMhz)),
      (label: 'Interface name', value: wifiMetadata.interfaceName ?? 'Not available yet'),
      (label: 'Platform', value: wifiMetadata.platform ?? 'Not available yet'),
      (label: 'RSSI', value: _formatInt(wifiMetadata.rssi)),
      (label: 'Signal quality', value: _formatInt(wifiMetadata.signalQuality)),
      (
        label: 'Signal quality percent',
        value: wifiMetadata.signalQualityPercent == null
            ? 'Not available yet'
            : '${wifiMetadata.signalQualityPercent}%',
      ),
      (label: 'Signal strength', value: _formatInt(wifiMetadata.signalStrength)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurements'),
        actions: [
          IconButton(
            onPressed: isLoading || isRefreshing ? null : onRefresh,
            tooltip: 'Refresh Wi-Fi details',
            icon: isLoading || isRefreshing
                ? const LoadingIndicator.small()
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.contentMaxWidth),
            child: ListView(
              padding: EdgeInsets.all(spacing.regular),
              children: [
                Text('Measurement activity', style: textTheme.headlineMedium),
                SizedBox(height: spacing.compact),
                Text(
                  'Temporary page for Wi-Fi metadata collection and debugging.',
                  style: textTheme.bodyMedium,
                ),
                SizedBox(height: spacing.regular),
                if (isLoading)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.regular),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(spacing.regular),
                        child: Row(
                          children: [
                            const LoadingIndicator.medium(),
                            SizedBox(width: spacing.regular),
                            Expanded(
                              child: Text(
                                'Loading current Wi-Fi metadata from this device.',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.regular),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(spacing.regular),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline),
                            SizedBox(width: spacing.compact),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!isLoading && wifiMetadata.isEmpty && errorMessage == null)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.regular),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(spacing.regular),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline),
                            SizedBox(width: spacing.compact),
                            Expanded(
                              child: Text(
                                _statusMessage(wifiMetadata.status),
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(bottom: spacing.regular),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.regular),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Internet measurement', style: textTheme.titleLarge),
                          SizedBox(height: spacing.compact),
                          Text(
                            'Record a public internet speed measurement for the seeded point.',
                            style: textTheme.bodyMedium,
                          ),
                          SizedBox(height: spacing.regular),
                          Text(
                            _primarySpeedLabel(),
                            style: textTheme.displaySmall,
                          ),
                          SizedBox(height: spacing.regular),
                          LinearProgressIndicator(
                            value: displayedOverallProgress,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          SizedBox(height: spacing.regular),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryValue(
                                  label: 'Download',
                                  value: _formatMbps(internetResult?.downloadBps ?? internetProgress.downloadBps),
                                ),
                              ),
                              SizedBox(width: spacing.compact),
                              Expanded(
                                child: _SummaryValue(
                                  label: 'Upload',
                                  value: _formatMbps(internetResult?.uploadBps ?? internetProgress.uploadBps),
                                ),
                              ),
                              SizedBox(width: spacing.compact),
                              Expanded(
                                child: _SummaryValue(
                                  label: 'Idle ping',
                                  value: internetProgress.idleLatencyMs == null
                                      ? 'Pending'
                                      : '${internetProgress.idleLatencyMs!.toStringAsFixed(0)} ms',
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing.compact),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryValue(
                                  label: 'Idle jitter',
                                  value: internetProgress.idleJitterMs == null
                                      ? 'Pending'
                                      : '${internetProgress.idleJitterMs!.toStringAsFixed(1)} ms',
                                ),
                              ),
                              SizedBox(width: spacing.compact),
                              Expanded(
                                child: _SummaryValue(
                                  label: 'Loaded ping',
                                  value: internetProgress.phaseLatencyMs == null
                                      ? 'Pending'
                                      : '${internetProgress.phaseLatencyMs!.toStringAsFixed(0)} ms',
                                ),
                              ),
                              SizedBox(width: spacing.compact),
                              Expanded(
                                child: _SummaryValue(
                                  label: 'Loaded jitter',
                                  value: internetProgress.phaseJitterMs == null
                                      ? 'Pending'
                                      : '${internetProgress.phaseJitterMs!.toStringAsFixed(1)} ms',
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: spacing.compact),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryValue(
                                  label: 'Idle loss',
                                  value: internetProgress.idlePacketLossPercent == null
                                      ? 'Pending'
                                      : '${internetProgress.idlePacketLossPercent!.toStringAsFixed(1)}%',
                                ),
                              ),
                              SizedBox(width: spacing.compact),
                              Expanded(
                                child: _SummaryValue(
                                  label: 'Loaded loss',
                                  value: internetProgress.phasePacketLossPercent == null
                                      ? 'Pending'
                                      : '${internetProgress.phasePacketLossPercent!.toStringAsFixed(1)}%',
                                ),
                              ),
                              SizedBox(width: spacing.compact),
                              Expanded(
                                child: _SummaryValue(
                                  label: 'Streams',
                                  value: internetProgress.streamCount == null
                                      ? 'Pending'
                                      : '${internetProgress.streamCount}',
                                ),
                              ),
                            ],
                          ),
                          if (lastRecordedAt != null) ...[
                            SizedBox(height: spacing.regular),
                            Text(
                              'Latest capture: ${_formatRecordedAt(lastRecordedAt!)}',
                              style: textTheme.bodySmall,
                            ),
                          ],
                          if (internetMeasurementError != null) ...[
                            SizedBox(height: spacing.regular),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.error_outline, color: colorScheme.error),
                                SizedBox(width: spacing.compact),
                                Expanded(
                                  child: Text(
                                    internetMeasurementError!,
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: spacing.regular),
                          FilledButton(
                            onPressed: isLoading || isRefreshing || isRecordingMeasurement
                                ? null
                                : onRecordMeasurement,
                            child: isRecordingMeasurement
                                ? const LoadingIndicator.small()
                                : const Text('Record measurement'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (internetResult != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.regular),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(spacing.regular),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Latest recorded measurement', style: textTheme.titleLarge),
                            SizedBox(height: spacing.regular),
                            _MeasurementRow(label: 'Site', value: selectedSiteSlug),
                            _MeasurementRow(label: 'Point', value: seededPointId),
                            _MeasurementRow(
                              label: 'Backend',
                              value: internetResult?.backend ?? 'Not available',
                            ),
                            _MeasurementRow(
                              label: 'Download',
                              value: _formatMbps(internetResult?.downloadBps),
                            ),
                            _MeasurementRow(
                              label: 'Download samples',
                              value: '${internetResult?.downloadSamplesBps.length ?? 0}',
                            ),
                            _MeasurementRow(
                              label: 'Upload',
                              value: _formatMbps(internetResult?.uploadBps),
                            ),
                            _MeasurementRow(
                              label: 'Upload samples',
                              value: '${internetResult?.uploadSamplesBps.length ?? 0}',
                            ),
                            _MeasurementRow(
                              label: 'Idle latency',
                              value: internetResult?.idleLatencyMs == null
                                  ? 'Not available'
                                  : '${internetResult!.idleLatencyMs!.toStringAsFixed(0)} ms',
                            ),
                            _MeasurementRow(
                              label: 'Idle jitter',
                              value: internetResult?.idleJitterMs == null
                                  ? 'Not available'
                                  : '${internetResult!.idleJitterMs!.toStringAsFixed(1)} ms',
                            ),
                            _MeasurementRow(
                              label: 'Idle packet loss',
                              value: internetResult?.idlePacketLossPercent == null
                                  ? 'Not available'
                                  : '${internetResult!.idlePacketLossPercent!.toStringAsFixed(1)}%',
                            ),
                            _MeasurementRow(
                              label: 'Streams',
                              value: internetResult?.streamCount == null
                                  ? 'Not available'
                                  : '${internetResult!.streamCount}',
                            ),
                            _MeasurementRow(
                              label: 'Download latency',
                              value: internetResult?.downloadLoadedLatencyMs == null
                                  ? 'Not available'
                                  : '${internetResult!.downloadLoadedLatencyMs!.toStringAsFixed(0)} ms',
                            ),
                            _MeasurementRow(
                              label: 'Download jitter',
                              value: internetResult?.downloadLoadedJitterMs == null
                                  ? 'Not available'
                                  : '${internetResult!.downloadLoadedJitterMs!.toStringAsFixed(1)} ms',
                            ),
                            _MeasurementRow(
                              label: 'Download packet loss',
                              value: internetResult?.downloadLoadedPacketLossPercent == null
                                  ? 'Not available'
                                  : '${internetResult!.downloadLoadedPacketLossPercent!.toStringAsFixed(1)}%',
                            ),
                            _MeasurementRow(
                              label: 'Upload latency',
                              value: internetResult?.uploadLoadedLatencyMs == null
                                  ? 'Not available'
                                  : '${internetResult!.uploadLoadedLatencyMs!.toStringAsFixed(0)} ms',
                            ),
                            _MeasurementRow(
                              label: 'Upload jitter',
                              value: internetResult?.uploadLoadedJitterMs == null
                                  ? 'Not available'
                                  : '${internetResult!.uploadLoadedJitterMs!.toStringAsFixed(1)} ms',
                            ),
                            _MeasurementRow(
                              label: 'Upload packet loss',
                              value: internetResult?.uploadLoadedPacketLossPercent == null
                                  ? 'Not available'
                                  : '${internetResult!.uploadLoadedPacketLossPercent!.toStringAsFixed(1)}%',
                            ),
                            _MeasurementRow(
                              label: 'Download size',
                              value: _formatBytes(internetResult?.downloadSize),
                            ),
                            _MeasurementRow(
                              label: 'Upload size',
                              value: _formatBytes(internetResult?.uploadSize),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ...items.map(
                  (item) => Padding(
                    padding: EdgeInsets.only(bottom: spacing.compact),
                    child: Card(
                      child: ListTile(
                        title: Text(item.label),
                        subtitle: Text(item.value),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatInt(int? value) {
    return value == null ? 'Not available yet' : '$value';
  }

  String _formatMbps(double? value) {
    if (value == null) {
      return 'Pending';
    }

    return '${(value / 1000 / 1000).toStringAsFixed(1)} Mbps';
  }

  String _formatBytes(double? bytes) {
    if (bytes == null) {
      return 'Not available';
    }

    final megabytes = bytes / 1000 / 1000;
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  String _primarySpeedLabel() {
    final primaryValue = switch (internetProgress.phase) {
      InternetSpeedTestPhase.testingUpload =>
        internetResult?.uploadBps ?? internetProgress.uploadBps,
      InternetSpeedTestPhase.completed => internetResult?.uploadBps ?? internetResult?.downloadBps,
      _ => internetResult?.downloadBps ?? internetProgress.downloadBps,
    };

    return primaryValue == null ? '--' : _formatMbps(primaryValue);
  }

  String _formatRecordedAt(DateTime value) {
    final localValue = value.toLocal();
    final hour = localValue.hour.toString().padLeft(2, '0');
    final minute = localValue.minute.toString().padLeft(2, '0');
    final second = localValue.second.toString().padLeft(2, '0');
    return '${localValue.year}-${localValue.month.toString().padLeft(2, '0')}-${localValue.day.toString().padLeft(2, '0')} $hour:$minute:$second';
  }

  String _statusMessage(WifiMetadataStatus status) {
    return switch (status) {
      WifiMetadataStatus.available => 'Wi-Fi metadata is available.',
      WifiMetadataStatus.wifiDisabled =>
        'Wi-Fi is turned off. Turn on Wi-Fi to collect Wi-Fi metadata.',
      WifiMetadataStatus.wifiNotConnected =>
        'Wi-Fi is not connected. Join a Wi-Fi network to continue.',
      WifiMetadataStatus.permissionsMissing =>
        'Wi-Fi permissions are missing. Grant the required access to collect Wi-Fi metadata.',
      WifiMetadataStatus.unsupportedPlatform =>
        'Wi-Fi metadata collection is not supported on this platform yet.',
      WifiMetadataStatus.unavailable =>
        'No Wi-Fi metadata is available from the device right now.',
    };
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: textTheme.titleMedium),
      ],
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final spacing = MaterialSpacing.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.compact),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: textTheme.labelMedium),
          ),
          Expanded(
            child: Text(value, style: textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
