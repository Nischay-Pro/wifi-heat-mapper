import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/core/loading_indicator.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/measurements/internet_speed_test_service.dart';
import 'package:mobile/src/features/measurements/wifi_metadata_service.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';
import 'package:mobile/src/models/wifi_metadata.dart';
import 'package:mobile/src/services/device_identity_service.dart';
import 'package:mobile/src/services/server_api.dart';

class MeasurementsPage extends ConsumerStatefulWidget {
  const MeasurementsPage({
    super.key,
    required this.selectedSiteSlug,
    this.showScaffold = true,
    this.onOpenSiteSettings,
  });

  final String selectedSiteSlug;
  final bool showScaffold;
  final VoidCallback? onOpenSiteSettings;

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
  String? _measurementSubmissionMessage;
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
      _measurementSubmissionMessage = null;
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

      final serverUrl = ref.read(serverConnectionControllerProvider).connectedServerUrl;
      if (serverUrl == null || serverUrl.isEmpty) {
        setState(() {
          _internetResult = result;
          _lastRecordedAt = DateTime.now();
          _displayedOverallProgress = 1;
          _isRecordingMeasurement = false;
          _measurementSubmissionMessage =
              AppMessages.measurementCapturedNoServer;
        });
        return;
      }

      try {
        final deviceIdentity = await ref
            .read(deviceIdentityServiceProvider)
            .loadIdentity(ref.read(appPreferencesProvider));
        final measuredAt = DateTime.now();
        await ref.read(serverApiProvider).submitMeasurement(
          serverUrl: serverUrl,
          siteSlug: widget.selectedSiteSlug,
          device: deviceIdentity,
          wifiMetadata: _wifiMetadata,
          internetResult: result,
          measuredAt: measuredAt,
          pointLabel: _seededPointId,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _internetResult = result;
          _lastRecordedAt = measuredAt;
          _displayedOverallProgress = 1;
          _isRecordingMeasurement = false;
          _measurementSubmissionMessage = AppMessages.measurementUploaded;
        });
        return;
      } on ApiException catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _internetResult = result;
          _lastRecordedAt = DateTime.now();
          _displayedOverallProgress = 1;
          _isRecordingMeasurement = false;
          _measurementSubmissionMessage = 'Measurement captured, but upload failed: ${error.message}';
        });
        return;
      } on SocketException catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _internetResult = result;
          _lastRecordedAt = DateTime.now();
          _displayedOverallProgress = 1;
          _isRecordingMeasurement = false;
          _measurementSubmissionMessage =
              'Measurement captured, but the server upload could not be completed: ${error.message}.';
        });
        return;
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _internetResult = result;
          _lastRecordedAt = DateTime.now();
          _displayedOverallProgress = 1;
          _isRecordingMeasurement = false;
          _measurementSubmissionMessage =
              'Measurement captured, but upload failed: $error';
        });
        return;
      }

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
      showScaffold: widget.showScaffold,
      onOpenSiteSettings: widget.onOpenSiteSettings,
      wifiMetadata: _wifiMetadata,
      internetResult: _internetResult,
      internetProgress: _internetProgress,
      displayedOverallProgress: _displayedOverallProgress,
      isLoading: _isLoading,
      isRefreshing: _isRefreshing,
      isRecordingMeasurement: _isRecordingMeasurement,
      errorMessage: _errorMessage,
      internetMeasurementError: _internetMeasurementError,
      measurementSubmissionMessage: _measurementSubmissionMessage,
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
    required this.showScaffold,
    required this.onOpenSiteSettings,
    required this.wifiMetadata,
    required this.internetResult,
    required this.internetProgress,
    required this.displayedOverallProgress,
    required this.isLoading,
    required this.isRefreshing,
    required this.isRecordingMeasurement,
    required this.errorMessage,
    required this.internetMeasurementError,
    required this.measurementSubmissionMessage,
    required this.lastRecordedAt,
    required this.onRefresh,
    required this.onRecordMeasurement,
  });

  final String selectedSiteSlug;
  final String seededPointId;
  final bool showScaffold;
  final VoidCallback? onOpenSiteSettings;
  final WifiMetadata wifiMetadata;
  final InternetMeasurementResult? internetResult;
  final InternetSpeedTestProgress internetProgress;
  final double displayedOverallProgress;
  final bool isLoading;
  final bool isRefreshing;
  final bool isRecordingMeasurement;
  final String? errorMessage;
  final String? internetMeasurementError;
  final String? measurementSubmissionMessage;
  final DateTime? lastRecordedAt;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRecordMeasurement;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final wifiItems = <({String label, String value})>[
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

    final content = AppPage(
      children: [
        _MeasurementHeader(
          selectedSiteSlug: selectedSiteSlug,
          onOpenSiteSettings: onOpenSiteSettings,
          wifiMetadata: wifiMetadata,
          isRefreshing: isLoading || isRefreshing,
          onRefresh: onRefresh,
        ),
        SizedBox(height: tokens.sectionGap),
        if (isLoading)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.sectionGap),
            child: AppPanel(
              child: Row(
                children: [
                  const LoadingIndicator.medium(),
                  SizedBox(width: tokens.spacing.regular),
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
        if (errorMessage != null)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.sectionGap),
            child: AppBanner(
              icon: Icons.info_outline,
              message: errorMessage!,
            ),
          ),
        if (!isLoading && wifiMetadata.isEmpty && errorMessage == null)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.sectionGap),
            child: AppBanner(
              icon: Icons.info_outline,
              message: _statusMessage(wifiMetadata.status),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: tokens.sectionGap),
          child: AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Internet measurement', style: textTheme.titleLarge),
                SizedBox(height: tokens.spacing.compact),
                Text(
                  'Record a public internet speed measurement for the seeded point.',
                  style: textTheme.bodyMedium,
                ),
                SizedBox(height: tokens.spacing.regular),
                Text(
                  _primarySpeedLabel(),
                  style: textTheme.displaySmall,
                ),
                SizedBox(height: tokens.spacing.regular),
                LinearProgressIndicator(
                  value: displayedOverallProgress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                ),
                SizedBox(height: tokens.spacing.regular),
                Row(
                  children: [
                    Expanded(
                      child: AppMetricTile(
                        label: 'Download',
                        value: _formatMbps(
                          internetResult?.downloadBps ?? internetProgress.downloadBps,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.compact),
                    Expanded(
                      child: AppMetricTile(
                        label: 'Upload',
                        value: _formatMbps(
                          internetResult?.uploadBps ?? internetProgress.uploadBps,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.compact),
                    Expanded(
                      child: AppMetricTile(
                        label: 'Idle ping',
                        value: internetProgress.idleLatencyMs == null
                            ? 'Pending'
                            : '${internetProgress.idleLatencyMs!.toStringAsFixed(0)} ms',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.compact),
                Row(
                  children: [
                    Expanded(
                      child: AppMetricTile(
                        label: 'Idle jitter',
                        value: internetProgress.idleJitterMs == null
                            ? 'Pending'
                            : '${internetProgress.idleJitterMs!.toStringAsFixed(1)} ms',
                      ),
                    ),
                    SizedBox(width: tokens.spacing.compact),
                    Expanded(
                      child: AppMetricTile(
                        label: 'Loaded ping',
                        value: internetProgress.phaseLatencyMs == null
                            ? 'Pending'
                            : '${internetProgress.phaseLatencyMs!.toStringAsFixed(0)} ms',
                      ),
                    ),
                    SizedBox(width: tokens.spacing.compact),
                    Expanded(
                      child: AppMetricTile(
                        label: 'Loaded jitter',
                        value: internetProgress.phaseJitterMs == null
                            ? 'Pending'
                            : '${internetProgress.phaseJitterMs!.toStringAsFixed(1)} ms',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.compact),
                Row(
                  children: [
                    Expanded(
                      child: AppMetricTile(
                        label: 'Idle loss',
                        value: internetProgress.idlePacketLossPercent == null
                            ? 'Pending'
                            : '${internetProgress.idlePacketLossPercent!.toStringAsFixed(1)}%',
                      ),
                    ),
                    SizedBox(width: tokens.spacing.compact),
                    Expanded(
                      child: AppMetricTile(
                        label: 'Loaded loss',
                        value: internetProgress.phasePacketLossPercent == null
                            ? 'Pending'
                            : '${internetProgress.phasePacketLossPercent!.toStringAsFixed(1)}%',
                      ),
                    ),
                    SizedBox(width: tokens.spacing.compact),
                    Expanded(
                      child: AppMetricTile(
                        label: 'Streams',
                        value: internetProgress.streamCount == null
                            ? 'Pending'
                            : '${internetProgress.streamCount}',
                      ),
                    ),
                  ],
                ),
                if (lastRecordedAt != null) ...[
                  SizedBox(height: tokens.spacing.regular),
                  Text(
                    'Latest capture: ${_formatRecordedAt(lastRecordedAt!)}',
                    style: textTheme.bodySmall,
                  ),
                ],
                if (internetMeasurementError != null) ...[
                  SizedBox(height: tokens.spacing.regular),
                  AppBanner(
                    icon: Icons.error_outline,
                    iconColor: colorScheme.error,
                    message: internetMeasurementError!,
                  ),
                ],
                if (measurementSubmissionMessage != null) ...[
                  SizedBox(height: tokens.spacing.regular),
                  AppBanner(
                    icon: Icons.cloud_done_outlined,
                    message: measurementSubmissionMessage!,
                  ),
                ],
                SizedBox(height: tokens.spacing.regular),
                FilledButton(
                  onPressed:
                      isLoading || isRefreshing || isRecordingMeasurement ? null : onRecordMeasurement,
                  child: isRecordingMeasurement
                      ? const LoadingIndicator.small()
                      : const Text('Record measurement'),
                ),
              ],
            ),
          ),
        ),
        if (internetResult != null)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.sectionGap),
            child: AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Latest recorded measurement', style: textTheme.titleLarge),
                  SizedBox(height: tokens.spacing.regular),
                  AppInfoRow(label: 'Site', value: selectedSiteSlug),
                  AppInfoRow(label: 'Point', value: seededPointId),
                  AppInfoRow(
                    label: 'Backend',
                    value: internetResult?.backend ?? 'Not available',
                  ),
                  AppInfoRow(
                    label: 'Download',
                    value: _formatMbps(internetResult?.downloadBps),
                  ),
                  AppInfoRow(
                    label: 'Download samples',
                    value: '${internetResult?.downloadSamplesBps.length ?? 0}',
                  ),
                  AppInfoRow(
                    label: 'Upload',
                    value: _formatMbps(internetResult?.uploadBps),
                  ),
                  AppInfoRow(
                    label: 'Upload samples',
                    value: '${internetResult?.uploadSamplesBps.length ?? 0}',
                  ),
                  AppInfoRow(
                    label: 'Idle latency',
                    value: internetResult?.idleLatencyMs == null
                        ? 'Not available'
                        : '${internetResult!.idleLatencyMs!.toStringAsFixed(0)} ms',
                  ),
                  AppInfoRow(
                    label: 'Idle jitter',
                    value: internetResult?.idleJitterMs == null
                        ? 'Not available'
                        : '${internetResult!.idleJitterMs!.toStringAsFixed(1)} ms',
                  ),
                  AppInfoRow(
                    label: 'Idle packet loss',
                    value: internetResult?.idlePacketLossPercent == null
                        ? 'Not available'
                        : '${internetResult!.idlePacketLossPercent!.toStringAsFixed(1)}%',
                  ),
                  AppInfoRow(
                    label: 'Streams',
                    value: internetResult?.streamCount == null
                        ? 'Not available'
                        : '${internetResult!.streamCount}',
                  ),
                  AppInfoRow(
                    label: 'Download latency',
                    value: internetResult?.downloadLoadedLatencyMs == null
                        ? 'Not available'
                        : '${internetResult!.downloadLoadedLatencyMs!.toStringAsFixed(0)} ms',
                  ),
                  AppInfoRow(
                    label: 'Download jitter',
                    value: internetResult?.downloadLoadedJitterMs == null
                        ? 'Not available'
                        : '${internetResult!.downloadLoadedJitterMs!.toStringAsFixed(1)} ms',
                  ),
                  AppInfoRow(
                    label: 'Download packet loss',
                    value: internetResult?.downloadLoadedPacketLossPercent == null
                        ? 'Not available'
                        : '${internetResult!.downloadLoadedPacketLossPercent!.toStringAsFixed(1)}%',
                  ),
                  AppInfoRow(
                    label: 'Upload latency',
                    value: internetResult?.uploadLoadedLatencyMs == null
                        ? 'Not available'
                        : '${internetResult!.uploadLoadedLatencyMs!.toStringAsFixed(0)} ms',
                  ),
                  AppInfoRow(
                    label: 'Upload jitter',
                    value: internetResult?.uploadLoadedJitterMs == null
                        ? 'Not available'
                        : '${internetResult!.uploadLoadedJitterMs!.toStringAsFixed(1)} ms',
                  ),
                  AppInfoRow(
                    label: 'Upload packet loss',
                    value: internetResult?.uploadLoadedPacketLossPercent == null
                        ? 'Not available'
                        : '${internetResult!.uploadLoadedPacketLossPercent!.toStringAsFixed(1)}%',
                  ),
                  AppInfoRow(
                    label: 'Download size',
                    value: _formatBytes(internetResult?.downloadSize),
                  ),
                  AppInfoRow(
                    label: 'Upload size',
                    value: _formatBytes(internetResult?.uploadSize),
                  ),
                ],
              ),
            ),
          ),
        ...wifiItems.map(
          (item) => Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.compact),
            child: AppPanel(
              padding: EdgeInsets.all(tokens.spacing.compact),
              child: ListTile(
                title: Text(item.label),
                subtitle: Text(item.value),
              ),
            ),
          ),
        ),
      ],
    );

    if (!showScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurements'),
        actions: [
          AppBusyIconButton(
            onPressed: () {
              onRefresh();
            },
            tooltip: 'Refresh Wi-Fi details',
            icon: Icons.refresh,
            isBusy: isLoading || isRefreshing,
          ),
        ],
      ),
      body: SafeArea(child: content),
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
      WifiMetadataStatus.available => AppMessages.wifiAvailable,
      WifiMetadataStatus.wifiDisabled => AppMessages.wifiDisabled,
      WifiMetadataStatus.wifiNotConnected => AppMessages.wifiNotConnected,
      WifiMetadataStatus.permissionsMissing => AppMessages.wifiPermissionsMissing,
      WifiMetadataStatus.unsupportedPlatform => AppMessages.wifiUnsupportedPlatform,
      WifiMetadataStatus.unavailable => AppMessages.wifiUnavailable,
    };
  }
}

class _MeasurementHeader extends StatelessWidget {
  const _MeasurementHeader({
    required this.selectedSiteSlug,
    required this.onOpenSiteSettings,
    required this.wifiMetadata,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final String selectedSiteSlug;
  final VoidCallback? onOpenSiteSettings;
  final WifiMetadata wifiMetadata;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onOpenSiteSettings,
                child: AppPanel(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.regular,
                    vertical: tokens.spacing.compact,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bolt,
                          color: colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: tokens.spacing.compact),
                      Expanded(
                        child: Text(
                          selectedSiteSlug,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.compact),
            IconButton.outlined(
              onPressed: isRefreshing
                  ? null
                  : () {
                      onRefresh();
                    },
              icon: isRefreshing
                  ? const LoadingIndicator.small()
                  : const Icon(Icons.refresh),
              tooltip: 'Refresh Wi-Fi details',
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.regular),
        Text('Measurement', style: textTheme.headlineMedium),
        SizedBox(height: tokens.spacing.compact),
        Text(
          wifiMetadata.ssid == null
              ? 'Collect Wi-Fi metadata and internet speed measurements for this site.'
              : 'Connected to ${wifiMetadata.ssid}. Capture a measurement and upload it to the server.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
