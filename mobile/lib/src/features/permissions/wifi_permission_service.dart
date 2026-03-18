import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/features/permissions/wifi_permission_models.dart';
import 'package:permission_handler/permission_handler.dart';

final wifiPermissionServiceProvider = Provider<WifiPermissionService>((ref) {
  return WifiPermissionService(
    deviceInfoPlugin: DeviceInfoPlugin(),
  );
});

class WifiPermissionService {
  WifiPermissionService({
    required DeviceInfoPlugin deviceInfoPlugin,
  }) : _deviceInfoPlugin = deviceInfoPlugin;

  final DeviceInfoPlugin _deviceInfoPlugin;

  Future<List<WifiPermissionRequirement>> loadRequirements() async {
    if (Platform.isAndroid) {
      return _loadAndroidRequirements();
    }

    if (Platform.isIOS) {
      return _loadIosRequirements();
    }

    return const [];
  }

  Future<bool> areRequirementsMet() async {
    final requirements = await loadRequirements();
    return requirements.every((requirement) => requirement.isGranted);
  }

  Future<void> completeAction(WifiPermissionRequirement requirement) async {
    switch (requirement.actionKind) {
      case WifiPermissionActionKind.requestPermission:
        await _requestPermission(requirement.id);
      case WifiPermissionActionKind.openAppSettings:
        await openAppSettings();
      case WifiPermissionActionKind.openLocationSettings:
        await AppSettings.openAppSettings(type: AppSettingsType.location);
      case null:
        return;
    }
  }

  Future<List<WifiPermissionRequirement>> _loadAndroidRequirements() async {
    final androidInfo = await _deviceInfoPlugin.androidInfo;
    final requirements = <WifiPermissionRequirement>[
      await _buildLocationPermissionRequirement(
        summary:
            'Needed to read SSID, BSSID, RSSI, and Wi-Fi data that Android treats as location-sensitive.',
      ),
      await _buildLocationServicesRequirement(
        summary:
            'Android requires system Location services to be on before Wi-Fi APIs return SSID, BSSID, and scan-derived results.',
      ),
    ];

    if (androidInfo.version.sdkInt >= 33) {
      requirements.insert(
        0,
        await _buildNearbyWifiDevicesRequirement(
          summary:
              'Needed on Android 13+ to query nearby Wi-Fi device details used for Wi-Fi metadata collection.',
        ),
      );
    }

    return requirements;
  }

  Future<List<WifiPermissionRequirement>> _loadIosRequirements() async {
    return [
      await _buildLocationPermissionRequirement(
        summary:
            'Needed when iOS gates Wi-Fi context behind location-aware APIs and user-approved access.',
      ),
      await _buildLocationServicesRequirement(
        summary:
            'Turn on Location Services in Settings so iOS can satisfy location-backed Wi-Fi access checks.',
      ),
    ];
  }

  Future<WifiPermissionRequirement> _buildNearbyWifiDevicesRequirement({
    required String summary,
  }) async {
    final status = await Permission.nearbyWifiDevices.status;
    return _buildRuntimeRequirement(
      id: 'nearby_wifi_devices',
      title: 'Nearby Wi-Fi devices',
      summary: summary,
      status: status,
    );
  }

  Future<WifiPermissionRequirement> _buildLocationPermissionRequirement({
    required String summary,
  }) async {
    final status = await Permission.locationWhenInUse.status;
    return _buildRuntimeRequirement(
      id: 'location_permission',
      title: 'Location access',
      summary: summary,
      status: status,
    );
  }

  Future<WifiPermissionRequirement> _buildLocationServicesRequirement({
    required String summary,
  }) async {
    final status = await Permission.locationWhenInUse.serviceStatus;
    if (status.isEnabled) {
      return WifiPermissionRequirement(
        id: 'location_services',
        title: 'Location Services',
        summary: summary,
        status: WifiPermissionStatus.granted,
        actionKind: null,
        actionLabel: null,
      );
    }

    return WifiPermissionRequirement(
      id: 'location_services',
      title: 'Location Services',
      summary: summary,
      status: WifiPermissionStatus.actionRequired,
      actionKind: WifiPermissionActionKind.openLocationSettings,
      actionLabel: 'Open settings',
    );
  }

  WifiPermissionRequirement _buildRuntimeRequirement({
    required String id,
    required String title,
    required String summary,
    required PermissionStatus status,
  }) {
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return WifiPermissionRequirement(
        id: id,
        title: title,
        summary: summary,
        status: WifiPermissionStatus.granted,
        actionKind: null,
        actionLabel: null,
      );
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return WifiPermissionRequirement(
        id: id,
        title: title,
        summary: summary,
        status: WifiPermissionStatus.actionRequired,
        actionKind: WifiPermissionActionKind.openAppSettings,
        actionLabel: 'Open app settings',
      );
    }

    return WifiPermissionRequirement(
      id: id,
      title: title,
      summary: summary,
      status: WifiPermissionStatus.actionRequired,
      actionKind: WifiPermissionActionKind.requestPermission,
      actionLabel: 'Grant access',
    );
  }

  Future<void> _requestPermission(String id) async {
    switch (id) {
      case 'nearby_wifi_devices':
        await Permission.nearbyWifiDevices.request();
      case 'location_permission':
        await Permission.locationWhenInUse.request();
      default:
        return;
    }
  }
}
