import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/storage/app_preferences.dart';

class IperfModeSettings {
  const IperfModeSettings({
    required this.tcpDownloadEnabled,
    required this.tcpUploadEnabled,
    required this.udpDownloadEnabled,
    required this.udpUploadEnabled,
  });

  static const defaults = IperfModeSettings(
    tcpDownloadEnabled: true,
    tcpUploadEnabled: true,
    udpDownloadEnabled: true,
    udpUploadEnabled: true,
  );

  factory IperfModeSettings.fromPreferences(AppPreferences preferences) {
    return IperfModeSettings(
      tcpDownloadEnabled:
          preferences.getIperfTcpDownloadEnabled() ??
          defaults.tcpDownloadEnabled,
      tcpUploadEnabled:
          preferences.getIperfTcpUploadEnabled() ?? defaults.tcpUploadEnabled,
      udpDownloadEnabled:
          preferences.getIperfUdpDownloadEnabled() ??
          defaults.udpDownloadEnabled,
      udpUploadEnabled:
          preferences.getIperfUdpUploadEnabled() ?? defaults.udpUploadEnabled,
    );
  }

  final bool tcpDownloadEnabled;
  final bool tcpUploadEnabled;
  final bool udpDownloadEnabled;
  final bool udpUploadEnabled;

  IperfModeSettings copyWith({
    bool? tcpDownloadEnabled,
    bool? tcpUploadEnabled,
    bool? udpDownloadEnabled,
    bool? udpUploadEnabled,
  }) {
    return IperfModeSettings(
      tcpDownloadEnabled: tcpDownloadEnabled ?? this.tcpDownloadEnabled,
      tcpUploadEnabled: tcpUploadEnabled ?? this.tcpUploadEnabled,
      udpDownloadEnabled: udpDownloadEnabled ?? this.udpDownloadEnabled,
      udpUploadEnabled: udpUploadEnabled ?? this.udpUploadEnabled,
    );
  }

  String get summary {
    final parts = <String>[
      if (tcpDownloadEnabled) 'TCP down',
      if (tcpUploadEnabled) 'TCP up',
      if (udpDownloadEnabled) 'UDP down',
      if (udpUploadEnabled) 'UDP up',
    ];
    if (parts.isEmpty) {
      return 'No modes selected';
    }

    return parts.join(', ');
  }

  int get enabledCount => [
    tcpDownloadEnabled,
    tcpUploadEnabled,
    udpDownloadEnabled,
    udpUploadEnabled,
  ].where((value) => value).length;
}

class LocalMeasurementSettings {
  const LocalMeasurementSettings({
    required this.serverHost,
    required this.serverPort,
    required this.modes,
  });

  factory LocalMeasurementSettings.fromPreferences(AppPreferences preferences) {
    return LocalMeasurementSettings(
      serverHost: preferences.getIperfServerHost()?.trim(),
      serverPort: preferences.getIperfServerPort() ?? 5201,
      modes: IperfModeSettings.fromPreferences(preferences),
    );
  }

  final String? serverHost;
  final int serverPort;
  final IperfModeSettings modes;

  bool get hasServerConfigured => serverHost != null && serverHost!.isNotEmpty;

  String get serverLabel =>
      hasServerConfigured ? '$serverHost:$serverPort' : 'Not configured';
}

final localMeasurementSettingsControllerProvider =
    NotifierProvider<
      LocalMeasurementSettingsController,
      LocalMeasurementSettings
    >(LocalMeasurementSettingsController.new);

class LocalMeasurementSettingsController
    extends Notifier<LocalMeasurementSettings> {
  AppPreferences get _preferences => ref.read(appPreferencesProvider);

  @override
  LocalMeasurementSettings build() {
    return LocalMeasurementSettings.fromPreferences(_preferences);
  }

  Future<void> saveServer({required String host, required int port}) async {
    final normalizedHost = host.trim();
    if (normalizedHost.isEmpty) {
      await _preferences.clearIperfServerHost();
      await _preferences.setIperfServerPort(port);
      state = LocalMeasurementSettings(
        serverHost: null,
        serverPort: port,
        modes: state.modes,
      );
      return;
    }

    await _preferences.setIperfServerHost(normalizedHost);
    await _preferences.setIperfServerPort(port);
    state = LocalMeasurementSettings(
      serverHost: normalizedHost,
      serverPort: port,
      modes: state.modes,
    );
  }

  Future<void> setTcpDownloadEnabled(bool value) async {
    await _preferences.setIperfTcpDownloadEnabled(value);
    state = LocalMeasurementSettings(
      serverHost: state.serverHost,
      serverPort: state.serverPort,
      modes: state.modes.copyWith(tcpDownloadEnabled: value),
    );
  }

  Future<void> setTcpUploadEnabled(bool value) async {
    await _preferences.setIperfTcpUploadEnabled(value);
    state = LocalMeasurementSettings(
      serverHost: state.serverHost,
      serverPort: state.serverPort,
      modes: state.modes.copyWith(tcpUploadEnabled: value),
    );
  }

  Future<void> setUdpDownloadEnabled(bool value) async {
    await _preferences.setIperfUdpDownloadEnabled(value);
    state = LocalMeasurementSettings(
      serverHost: state.serverHost,
      serverPort: state.serverPort,
      modes: state.modes.copyWith(udpDownloadEnabled: value),
    );
  }

  Future<void> setUdpUploadEnabled(bool value) async {
    await _preferences.setIperfUdpUploadEnabled(value);
    state = LocalMeasurementSettings(
      serverHost: state.serverHost,
      serverPort: state.serverPort,
      modes: state.modes.copyWith(udpUploadEnabled: value),
    );
  }

  Future<bool> testServerConnection({
    required String host,
    required int port,
  }) async {
    final normalizedHost = host.trim();
    if (normalizedHost.isEmpty || port <= 0 || port > 65535) {
      return false;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        normalizedHost,
        port,
        timeout: const Duration(seconds: 3),
      );
      return true;
    } on SocketException {
      return false;
    } finally {
      await socket?.close();
      socket?.destroy();
    }
  }
}
