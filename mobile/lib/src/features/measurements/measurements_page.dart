import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/core/loading_indicator.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/measurements/internet_speed_test_service.dart';
import 'package:mobile/src/features/measurements/local_measurement_service.dart';
import 'package:mobile/src/features/measurements/wifi_metadata_service.dart';
import 'package:mobile/src/models/floor_map.dart';
import 'package:mobile/src/models/internet_measurement_result.dart';
import 'package:mobile/src/models/site_detail.dart';
import 'package:mobile/src/models/site_point.dart';
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
  static const double _localMeasurementWeight = 0.3;
  static const double _internetMeasurementWeight = 0.6;
  static const double _uploadWeight = 0.1;

  WifiMetadata _wifiMetadata = const WifiMetadata();
  SiteDetail? _siteDetail;
  FloorMap? _selectedFloorMap;
  SitePoint? _selectedPoint;
  Set<String> _completedPointIds = <String>{};
  String? _deviceSlug;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isRequestInFlight = false;
  bool _isSiteDetailRequestInFlight = false;
  bool _isCompletedPointsRequestInFlight = false;
  bool _isLoadingSiteDetail = true;
  bool _isRecordingMeasurement = false;
  String? _errorMessage;
  String? _siteDetailError;
  String? _internetMeasurementError;
  String? _measurementSubmissionMessage;
  InternetSpeedTestProgress _internetProgress = const InternetSpeedTestProgress(
    phase: InternetSpeedTestPhase.idle,
    overallProgress: 0,
    progress: 0,
  );
  double _displayedOverallProgress = 0;
  Timer? _metadataPollTimer;
  Timer? _siteDetailPollTimer;
  String? _lastSnackbarMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDeviceIdentity();
    _loadMetadata(showLoading: true);
    _loadSiteDetail(showLoading: true);
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant MeasurementsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSiteSlug != widget.selectedSiteSlug) {
      _siteDetail = null;
      _selectedFloorMap = null;
      _selectedPoint = null;
      _completedPointIds = <String>{};
      _siteDetailError = null;
      _internetMeasurementError = null;
      _measurementSubmissionMessage = null;
      _displayedOverallProgress = 0;
      _loadSiteDetail(showLoading: true);
    }
  }

  Future<void> _loadDeviceIdentity() async {
    final deviceIdentity = await ref
        .read(deviceIdentityServiceProvider)
        .loadIdentity(ref.read(appPreferencesProvider));
    if (!mounted) {
      return;
    }

    setState(() {
      _deviceSlug = deviceIdentity.slug;
    });
    await _loadCompletedPointIds();
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
      _loadSiteDetail(autoSelectFirstPoint: false);
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  Future<void> _loadSiteDetail({
    bool showLoading = false,
    bool autoSelectFirstPoint = true,
  }) async {
    if (_isSiteDetailRequestInFlight) {
      return;
    }

    final serverUrl = ref
        .read(serverConnectionControllerProvider)
        .connectedServerUrl;
    if (serverUrl == null || serverUrl.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _siteDetail = null;
        _selectedFloorMap = null;
        _selectedPoint = null;
        _siteDetailError = AppMessages.serverUnavailable;
        _isLoadingSiteDetail = false;
      });
      return;
    }

    _isSiteDetailRequestInFlight = true;

    if (mounted && showLoading) {
      setState(() {
        _isLoadingSiteDetail = true;
        _siteDetailError = null;
      });
    }

    try {
      final siteDetail = await ref
          .read(serverApiProvider)
          .fetchSiteDetail(
            serverUrl: serverUrl,
            siteSlug: widget.selectedSiteSlug,
          );
      if (!mounted) {
        return;
      }

      final previousFloorId = _selectedFloorMap?.id;
      final previousPointId = _selectedPoint?.id;
      final selectedFloorMap =
          siteDetail.floorMaps.any(
            (floorMap) => floorMap.id == _selectedFloorMap?.id,
          )
          ? siteDetail.floorMaps.firstWhere(
              (floorMap) => floorMap.id == _selectedFloorMap!.id,
            )
          : (siteDetail.floorMaps.isNotEmpty
                ? siteDetail.floorMaps.first
                : null);
      final availablePoints = selectedFloorMap == null
          ? const <SitePoint>[]
          : siteDetail.points
                .where((point) => point.floorMapId == selectedFloorMap.id)
                .toList(growable: false);
      final floorSelectionChanged =
          previousFloorId != null && selectedFloorMap?.id != previousFloorId;
      final selectedPoint =
          !floorSelectionChanged &&
              availablePoints.any((point) => point.id == _selectedPoint?.id)
          ? availablePoints.firstWhere(
              (point) => point.id == _selectedPoint!.id,
            )
          : (autoSelectFirstPoint && availablePoints.isNotEmpty
                ? availablePoints.first
                : null);
      final pointSelectionChanged =
          previousPointId != null && selectedPoint?.id != previousPointId;
      final pointNoLongerExists =
          previousPointId != null &&
          !availablePoints.any((point) => point.id == previousPointId);

      setState(() {
        _siteDetail = siteDetail;
        _selectedFloorMap = selectedFloorMap;
        _selectedPoint = selectedPoint;
        _siteDetailError = null;
        _isLoadingSiteDetail = false;
        if (pointNoLongerExists) {
          _measurementSubmissionMessage = AppMessages.pointNoLongerExists;
          _showSnackbar(AppMessages.pointNoLongerExists);
        } else if (!_isRecordingMeasurement &&
            (floorSelectionChanged || pointSelectionChanged)) {
          _measurementSubmissionMessage = null;
        }
      });
      await _loadCompletedPointIds();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _siteDetail = null;
        _selectedFloorMap = null;
        _selectedPoint = null;
        _siteDetailError = error.message;
        _isLoadingSiteDetail = false;
      });
    } on SocketException {
      if (!mounted) {
        return;
      }

      setState(() {
        _siteDetail = null;
        _selectedFloorMap = null;
        _selectedPoint = null;
        _siteDetailError = AppMessages.serverUnavailable;
        _isLoadingSiteDetail = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _siteDetail = null;
        _selectedFloorMap = null;
        _selectedPoint = null;
        _siteDetailError = AppMessages.floorplanLoadFailed;
        _isLoadingSiteDetail = false;
      });
    } finally {
      _isSiteDetailRequestInFlight = false;
    }
  }

  Future<void> _loadCompletedPointIds() async {
    if (_isCompletedPointsRequestInFlight) {
      return;
    }

    final serverUrl = ref
        .read(serverConnectionControllerProvider)
        .connectedServerUrl;
    final deviceSlug = _deviceSlug;
    if (serverUrl == null ||
        serverUrl.isEmpty ||
        deviceSlug == null ||
        deviceSlug.isEmpty) {
      return;
    }

    _isCompletedPointsRequestInFlight = true;
    try {
      final completedPointIds = await ref
          .read(serverApiProvider)
          .fetchMeasuredPointIds(
            serverUrl: serverUrl,
            siteSlug: widget.selectedSiteSlug,
            deviceSlug: deviceSlug,
          );
      if (!mounted) {
        return;
      }

      setState(() {
        _completedPointIds = completedPointIds;
      });
    } catch (_) {
      // Background refresh should stay silent on successful screen state.
    } finally {
      _isCompletedPointsRequestInFlight = false;
    }
  }

  void _startPolling() {
    _metadataPollTimer?.cancel();
    _metadataPollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadMetadata(),
    );
    _siteDetailPollTimer?.cancel();
    _siteDetailPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadSiteDetail(autoSelectFirstPoint: false),
    );
  }

  void _stopPolling() {
    _metadataPollTimer?.cancel();
    _metadataPollTimer = null;
    _siteDetailPollTimer?.cancel();
    _siteDetailPollTimer = null;
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
      final metadata = await ref
          .read(wifiMetadataServiceProvider)
          .loadMetadata();
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
        _errorMessage =
            error.message ?? 'Could not load Wi-Fi metadata from the device.';
      });
    } finally {
      _isRequestInFlight = false;
    }
  }

  void _showSnackbar(String message) {
    if (!mounted || _lastSnackbarMessage == message) {
      return;
    }

    _lastSnackbarMessage = message;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _recordMeasurement() async {
    if (_isRecordingMeasurement) {
      return;
    }

    if (_siteDetail == null) {
      setState(() {
        _measurementSubmissionMessage =
            _siteDetailError ?? AppMessages.floorplanLoadFailed;
      });
      return;
    }

    if (_siteDetail!.floorMaps.isEmpty) {
      setState(() {
        _measurementSubmissionMessage = AppMessages.noFloorplanAvailable;
      });
      return;
    }

    if (_siteDetail!.points.isEmpty || _selectedPoint == null) {
      setState(() {
        _measurementSubmissionMessage = AppMessages.noPointsAvailable;
      });
      return;
    }

    final measurementPoint = _selectedPoint!;

    setState(() {
      _isRecordingMeasurement = true;
      _internetMeasurementError = null;
      _measurementSubmissionMessage = null;
      _displayedOverallProgress = 0;
      _internetProgress = _internetProgress.mergeWith(
        const InternetSpeedTestProgress(
          phase: InternetSpeedTestPhase.measuringLatency,
          overallProgress: 0,
          progress: 0,
        ),
      );
    });

    try {
      InternetMeasurementResult? localResult;
      String? localMeasurementNotice;
      try {
        localResult = await ref
            .read(localMeasurementTestProvider)
            .recordLocalMeasurement(
              bindAddress: _wifiMetadata.clientIp,
              onProgress: (progress, activeStageLabel) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _displayedOverallProgress = max(
                    _displayedOverallProgress,
                    progress.clamp(0.0, 1.0) * _localMeasurementWeight,
                  );
                  _internetProgress = _internetProgress.mergeWith(
                    InternetSpeedTestProgress(
                      phase: InternetSpeedTestPhase.measuringLatency,
                      overallProgress: _displayedOverallProgress,
                      progress: progress.clamp(0.0, 1.0),
                      activeStageLabel: activeStageLabel,
                    ),
                  );
                });
              },
            );
      } on StateError catch (error) {
        localMeasurementNotice = _formatLocalMeasurementNotice(error.message);
      } on SocketException catch (error) {
        localMeasurementNotice = _formatLocalMeasurementNotice(error.message);
      } catch (error) {
        localMeasurementNotice = _formatLocalMeasurementNotice('$error');
      }

      if (mounted) {
        setState(() {
          _displayedOverallProgress = max(
            _displayedOverallProgress,
            _localMeasurementWeight,
          );
        });
      }

      final result = await ref
          .read(internetSpeedTestServiceProvider)
          .recordInternetMeasurement(
            onProgress: (progress) {
              if (!mounted) {
                return;
              }

              setState(() {
                _internetProgress = _internetProgress.mergeWith(progress);
                _displayedOverallProgress = max(
                  _displayedOverallProgress,
                  _localMeasurementWeight +
                      (progress.overallProgress * _internetMeasurementWeight),
                );
              });
            },
          );

      if (!mounted) {
        return;
      }

      final serverUrl = ref
          .read(serverConnectionControllerProvider)
          .connectedServerUrl;
      if (serverUrl == null || serverUrl.isEmpty) {
        setState(() {
          _completedPointIds = {..._completedPointIds, measurementPoint.id};
          _displayedOverallProgress = 1;
          _isRecordingMeasurement = false;
          _measurementSubmissionMessage = localMeasurementNotice == null
              ? AppMessages.measurementCapturedNoServer
              : '${AppMessages.measurementCapturedNoServer} $localMeasurementNotice';
        });
        return;
      }

      try {
        if (mounted) {
          setState(() {
            _displayedOverallProgress = max(
              _displayedOverallProgress,
              1 - _uploadWeight,
            );
          });
        }

        final deviceIdentity = await ref
            .read(deviceIdentityServiceProvider)
            .loadIdentity(ref.read(appPreferencesProvider));
        final measuredAt = DateTime.now();
        await ref
            .read(serverApiProvider)
            .submitMeasurement(
              serverUrl: serverUrl,
              siteSlug: widget.selectedSiteSlug,
              device: deviceIdentity,
              wifiMetadata: _wifiMetadata,
              localResult: localResult,
              internetResult: result,
              measuredAt: measuredAt,
              point: measurementPoint,
            );

        if (!mounted) {
          return;
        }

        setState(() {
          _completedPointIds = {..._completedPointIds, measurementPoint.id};
          _displayedOverallProgress = 1;
          _isRecordingMeasurement = false;
          _measurementSubmissionMessage = localMeasurementNotice == null
              ? AppMessages.measurementUploaded
              : '${AppMessages.measurementUploaded} $localMeasurementNotice';
        });
        return;
      } on ApiException catch (error) {
        if (!mounted) {
          return;
        }

        if (error.code == 'invalid_point') {
          _selectedPoint = null;
          await _loadSiteDetail(autoSelectFirstPoint: false);
        }

        setState(() {
          _displayedOverallProgress = 1;
          _isRecordingMeasurement = false;
          _measurementSubmissionMessage = error.code == 'invalid_point'
              ? AppMessages.pointNoLongerExists
              : 'Measurement captured, but upload failed: ${error.message}';
        });
        return;
      } on SocketException catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _completedPointIds = {..._completedPointIds, measurementPoint.id};
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
          _completedPointIds = {..._completedPointIds, measurementPoint.id};
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
        _internetProgress = _internetProgress.mergeWith(
          const InternetSpeedTestProgress(
            phase: InternetSpeedTestPhase.failed,
            overallProgress: 0,
            progress: 0,
          ),
        );
        _isRecordingMeasurement = false;
      });
    } on HttpException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _internetMeasurementError = error.message;
        _internetProgress = _internetProgress.mergeWith(
          const InternetSpeedTestProgress(
            phase: InternetSpeedTestPhase.failed,
            overallProgress: 0,
            progress: 0,
          ),
        );
        _isRecordingMeasurement = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _internetMeasurementError = 'Internet measurement failed: $error';
        _internetProgress = _internetProgress.mergeWith(
          const InternetSpeedTestProgress(
            phase: InternetSpeedTestPhase.failed,
            overallProgress: 0,
            progress: 0,
          ),
        );
        _isRecordingMeasurement = false;
      });
    }
  }

  String _formatLocalMeasurementNotice(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'Intranet measurement skipped.';
    }

    if (trimmed.startsWith('Intranet measurement')) {
      return trimmed;
    }

    final normalized = trimmed.endsWith('.') ? trimmed : '$trimmed.';
    return 'Intranet measurement skipped: $normalized';
  }

  @override
  Widget build(BuildContext context) {
    return MeasurementsView(
      selectedSiteSlug: widget.selectedSiteSlug,
      connectedServerUrl: ref
          .read(serverConnectionControllerProvider)
          .connectedServerUrl,
      showScaffold: widget.showScaffold,
      onOpenSiteSettings: widget.onOpenSiteSettings,
      wifiMetadata: _wifiMetadata,
      siteDetail: _siteDetail,
      selectedFloorMap: _selectedFloorMap,
      selectedPoint: _selectedPoint,
      completedPointIds: _completedPointIds,
      internetProgress: _internetProgress,
      displayedOverallProgress: _displayedOverallProgress,
      isLoading: _isLoading,
      isRefreshing: _isRefreshing,
      isLoadingSiteDetail: _isLoadingSiteDetail,
      isRecordingMeasurement: _isRecordingMeasurement,
      errorMessage: _errorMessage,
      siteDetailError: _siteDetailError,
      internetMeasurementError: _internetMeasurementError,
      measurementSubmissionMessage: _measurementSubmissionMessage,
      onRecordMeasurement: _recordMeasurement,
      onSelectPoint: (point) {
        setState(() {
          _selectedPoint = point;
          _measurementSubmissionMessage = null;
          _internetMeasurementError = null;
          _lastSnackbarMessage = null;
        });
      },
      onSelectFloorMap: (floorMap) {
        final pointsForFloor = (_siteDetail?.points ?? const <SitePoint>[])
            .where((point) => point.floorMapId == floorMap.id)
            .toList(growable: false);

        setState(() {
          _selectedFloorMap = floorMap;
          _selectedPoint = pointsForFloor.isNotEmpty
              ? pointsForFloor.first
              : null;
          _measurementSubmissionMessage = null;
          _internetMeasurementError = null;
          _lastSnackbarMessage = null;
        });
      },
    );
  }
}

class MeasurementsView extends StatelessWidget {
  const MeasurementsView({
    super.key,
    required this.selectedSiteSlug,
    required this.connectedServerUrl,
    required this.showScaffold,
    required this.onOpenSiteSettings,
    required this.wifiMetadata,
    required this.siteDetail,
    required this.selectedFloorMap,
    required this.selectedPoint,
    required this.completedPointIds,
    required this.internetProgress,
    required this.displayedOverallProgress,
    required this.isLoading,
    required this.isRefreshing,
    required this.isLoadingSiteDetail,
    required this.isRecordingMeasurement,
    required this.errorMessage,
    required this.siteDetailError,
    required this.internetMeasurementError,
    required this.measurementSubmissionMessage,
    required this.onRecordMeasurement,
    required this.onSelectPoint,
    required this.onSelectFloorMap,
  });

  final String selectedSiteSlug;
  final String? connectedServerUrl;
  final bool showScaffold;
  final VoidCallback? onOpenSiteSettings;
  final WifiMetadata wifiMetadata;
  final SiteDetail? siteDetail;
  final FloorMap? selectedFloorMap;
  final SitePoint? selectedPoint;
  final Set<String> completedPointIds;
  final InternetSpeedTestProgress internetProgress;
  final double displayedOverallProgress;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingSiteDetail;
  final bool isRecordingMeasurement;
  final String? errorMessage;
  final String? siteDetailError;
  final String? internetMeasurementError;
  final String? measurementSubmissionMessage;
  final Future<void> Function() onRecordMeasurement;
  final ValueChanged<SitePoint> onSelectPoint;
  final ValueChanged<FloorMap> onSelectFloorMap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final activeFloorMap = selectedFloorMap;
    final pointsForSelectedFloor = activeFloorMap == null
        ? const <SitePoint>[]
        : (siteDetail?.points ?? const <SitePoint>[])
              .where((point) => point.floorMapId == activeFloorMap.id)
              .toList(growable: false);
    final hasUsableFloorplan =
        activeFloorMap != null &&
        activeFloorMap.imagePath != null &&
        activeFloorMap.imagePath!.isNotEmpty;
    final hasPoints = pointsForSelectedFloor.isNotEmpty;
    final floorplanStatusMessage =
        siteDetailError ??
        (siteDetail == null
            ? null
            : !hasUsableFloorplan
            ? AppMessages.noFloorplanAvailable
            : !hasPoints
            ? AppMessages.noPointsAvailable
            : null);
    final canRecordMeasurement =
        !isLoadingSiteDetail &&
        siteDetail != null &&
        hasUsableFloorplan &&
        hasPoints &&
        selectedPoint != null &&
        !isLoading &&
        !isRefreshing &&
        !isRecordingMeasurement;
    final content = AppPage(
      children: [
        _MeasurementHeader(
          selectedSiteSlug: selectedSiteSlug,
          onOpenSiteSettings: onOpenSiteSettings,
        ),
        SizedBox(height: tokens.sectionGap),
        Padding(
          padding: EdgeInsets.only(bottom: tokens.sectionGap),
          child: AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Floorplan and points', style: textTheme.titleLarge),
                SizedBox(height: tokens.spacing.compact),
                Text(
                  'Choose a floor, then select a point on that floorplan before recording a measurement.',
                  style: textTheme.bodyMedium,
                ),
                SizedBox(height: tokens.spacing.regular),
                if (isLoadingSiteDetail)
                  const SizedBox(
                    height: 240,
                    child: Center(child: LoadingIndicator.medium()),
                  )
                else if (floorplanStatusMessage != null)
                  AppBanner(
                    icon: Icons.map_outlined,
                    message: floorplanStatusMessage,
                  )
                else if (siteDetail != null && activeFloorMap != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FloorMapSelector(
                        floorMaps: siteDetail!.floorMaps,
                        selectedFloorMap: activeFloorMap,
                        onSelectFloorMap: onSelectFloorMap,
                      ),
                      SizedBox(height: tokens.spacing.regular),
                      _FloorplanPreview(
                        serverUrl: connectedServerUrl,
                        floorMap: activeFloorMap,
                        points: pointsForSelectedFloor,
                        selectedPoint: selectedPoint,
                        completedPointIds: completedPointIds,
                        onSelectPoint: onSelectPoint,
                      ),
                      SizedBox(height: tokens.spacing.regular),
                      AppInfoRow(
                        label: 'Selected floor',
                        value: activeFloorMap.name,
                      ),
                      AppInfoRow(
                        label: 'Selected point',
                        value:
                            selectedPoint?.label ??
                            'Choose a point on the floorplan',
                      ),
                      AppInfoRow(
                        label: 'Completed points',
                        value: '${completedPointIds.length}',
                      ),
                      AppInfoRow(
                        label: 'Point position',
                        value: selectedPoint == null
                            ? 'Not selected'
                            : '${selectedPoint!.x}, ${selectedPoint!.y}',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: tokens.sectionGap),
          child: AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Measurement', style: textTheme.titleLarge),
                SizedBox(height: tokens.spacing.compact),
                Text(
                  selectedPoint == null
                      ? 'Choose a point on the floorplan, then record a measurement.'
                      : 'Record a measurement for ${selectedPoint!.label ?? 'the selected point'}.',
                  style: textTheme.bodyMedium,
                ),
                if (measurementSubmissionMessage != null) ...[
                  SizedBox(height: tokens.spacing.regular),
                  AppBanner(
                    icon: Icons.cloud_done_outlined,
                    message: measurementSubmissionMessage!,
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
                if (isRecordingMeasurement) ...[
                  SizedBox(height: tokens.spacing.regular),
                  LinearProgressIndicator(
                    value: displayedOverallProgress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
                SizedBox(height: tokens.spacing.regular),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canRecordMeasurement
                        ? onRecordMeasurement
                        : null,
                    child: isRecordingMeasurement
                        ? const LoadingIndicator.small()
                        : const Text('Record measurement'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (!showScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Measurements')),
      body: SafeArea(child: content),
    );
  }
}

class _MeasurementHeader extends StatelessWidget {
  const _MeasurementHeader({
    required this.selectedSiteSlug,
    required this.onOpenSiteSettings,
  });

  final String selectedSiteSlug;
  final VoidCallback? onOpenSiteSettings;

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
                        child: Icon(Icons.bolt, color: colorScheme.primary),
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
          ],
        ),
        SizedBox(height: tokens.spacing.regular),
        Text('Measurement', style: textTheme.headlineMedium),
        SizedBox(height: tokens.spacing.compact),
        Text(
          'Select a floor, choose a point, and record measurements for this site.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FloorplanPreview extends StatelessWidget {
  const _FloorplanPreview({
    required this.serverUrl,
    required this.floorMap,
    required this.points,
    required this.selectedPoint,
    required this.completedPointIds,
    required this.onSelectPoint,
  });

  final String? serverUrl;
  final FloorMap floorMap;
  final List<SitePoint> points;
  final SitePoint? selectedPoint;
  final Set<String> completedPointIds;
  final ValueChanged<SitePoint> onSelectPoint;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = _resolveFloorplanUrl(serverUrl, floorMap.imagePath);
    final width = max(1, floorMap.imageWidth ?? 640);
    final height = max(1, floorMap.imageHeight ?? 463);
    final aspectRatio = width / height;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusLarge),
      child: Container(
        decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: imageUrl == null
              ? const SizedBox.shrink()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final scaleX = constraints.maxWidth / width;
                    final scaleY = constraints.maxHeight / height;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child:
                              floorMap.imagePath?.toLowerCase().endsWith(
                                    '.svg',
                                  ) ==
                                  true
                              ? SvgPicture.network(
                                  imageUrl,
                                  fit: BoxFit.fill,
                                  placeholderBuilder: (context) => const Center(
                                    child: LoadingIndicator.medium(),
                                  ),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.fill,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) {
                                      return child;
                                    }

                                    return const Center(
                                      child: LoadingIndicator.medium(),
                                    );
                                  },
                                ),
                        ),
                        for (final point in points)
                          Positioned(
                            left: (point.x * scaleX) - 9,
                            top: (point.y * scaleY) - 9,
                            child: _FloorplanPointDot(
                              point: point,
                              isSelected: point.id == selectedPoint?.id,
                              isCompleted: completedPointIds.contains(point.id),
                              onTap: () => onSelectPoint(point),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  String? _resolveFloorplanUrl(String? serverUrl, String? imagePath) {
    if (serverUrl == null ||
        serverUrl.isEmpty ||
        imagePath == null ||
        imagePath.isEmpty) {
      return null;
    }

    final baseUri = Uri.parse(serverUrl);
    return baseUri.resolve(imagePath).toString();
  }
}

class _FloorMapSelector extends StatelessWidget {
  const _FloorMapSelector({
    required this.floorMaps,
    required this.selectedFloorMap,
    required this.onSelectFloorMap,
  });

  final List<FloorMap> floorMaps;
  final FloorMap selectedFloorMap;
  final ValueChanged<FloorMap> onSelectFloorMap;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: () async {
          final selected = await showModalBottomSheet<FloorMap>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (context) => _FloorMapPickerSheet(
              floorMaps: floorMaps,
              selectedFloorMap: selectedFloorMap,
            ),
          );

          if (selected != null && selected.id != selectedFloorMap.id) {
            onSelectFloorMap(selected);
          }
        },
        leading: const Icon(Icons.layers_outlined),
        title: const Text('Floor'),
        subtitle: Text(selectedFloorMap.name),
        trailing: const Icon(Icons.expand_more),
      ),
    );
  }
}

class _FloorMapPickerSheet extends StatefulWidget {
  const _FloorMapPickerSheet({
    required this.floorMaps,
    required this.selectedFloorMap,
  });

  final List<FloorMap> floorMaps;
  final FloorMap selectedFloorMap;

  @override
  State<_FloorMapPickerSheet> createState() => _FloorMapPickerSheetState();
}

class _FloorMapPickerSheetState extends State<_FloorMapPickerSheet> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final showSearch = widget.floorMaps.length > 5;
    final normalizedQuery = _query.trim().toLowerCase();
    final filteredFloorMaps = normalizedQuery.isEmpty
        ? widget.floorMaps
        : widget.floorMaps
              .where((floorMap) {
                return floorMap.name.toLowerCase().contains(normalizedQuery) ||
                    floorMap.slug.toLowerCase().contains(normalizedQuery);
              })
              .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: tokens.pagePadding,
          right: tokens.pagePadding,
          bottom: tokens.pagePadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSearch) ...[
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Search floors',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: tokens.spacing.regular),
            ],
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredFloorMaps.length,
                itemBuilder: (context, index) {
                  final floorMap = filteredFloorMaps[index];
                  return ListTile(
                    title: Text(floorMap.name),
                    trailing: floorMap.id == widget.selectedFloorMap.id
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: () => Navigator.of(context).pop(floorMap),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloorplanPointDot extends StatelessWidget {
  const _FloorplanPointDot({
    required this.point,
    required this.isSelected,
    required this.isCompleted,
    required this.onTap,
  });

  final SitePoint point;
  final bool isSelected;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fillColor = point.isBaseStation
        ? colorScheme.tertiary
        : isCompleted
        ? const Color(0xFF2E7D32)
        : (isSelected ? colorScheme.primary : colorScheme.surface);
    final borderColor = point.isBaseStation
        ? colorScheme.onTertiary
        : isCompleted
        ? const Color(0xFFA5D6A7)
        : (isSelected ? colorScheme.onPrimary : colorScheme.primary);

    return Tooltip(
      message: point.label ?? 'Unnamed point',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fillColor,
              border: Border.all(color: borderColor, width: 2),
              boxShadow: isSelected || isCompleted
                  ? [
                      BoxShadow(
                        color:
                            (isCompleted
                                    ? const Color(0xFF2E7D32)
                                    : colorScheme.primary)
                                .withValues(alpha: 0.32),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
