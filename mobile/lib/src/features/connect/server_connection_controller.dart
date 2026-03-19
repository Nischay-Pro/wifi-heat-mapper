import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/features/connect/server_connection_state.dart';
import 'package:mobile/src/models/site_summary.dart';
import 'package:mobile/src/services/server_api.dart';
import 'package:mobile/src/storage/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences override is required.');
});

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return AppPreferences(ref.watch(sharedPreferencesProvider));
});

final serverApiProvider = Provider<ServerApi>((ref) {
  return const ServerApi();
});

final serverConnectionControllerProvider =
    NotifierProvider<ServerConnectionController, ServerConnectionState>(
  ServerConnectionController.new,
);

class BackgroundValidationResult {
  const BackgroundValidationResult({
    required this.serverAvailable,
    required this.selectedSiteValid,
  });

  final bool serverAvailable;
  final bool selectedSiteValid;
}

class ServerConnectionController extends Notifier<ServerConnectionState> {
  AppPreferences get _preferences => ref.read(appPreferencesProvider);
  ServerApi get _serverApi => ref.read(serverApiProvider);

  @override
  ServerConnectionState build() {
    return ServerConnectionState.initial(
      draftServerUrl: _preferences.getServerUrl() ?? 'http://localhost:5173',
      selectedSiteSlug: _preferences.getSelectedSiteSlug(),
    );
  }

  void updateServerUrl(String value) {
    state = state.copyWith(
      draftServerUrl: value,
      status: ConnectionStatus.idle,
      clearStatusMessage: true,
      clearConnectedServerUrl: true,
      clearServerInfo: true,
      sites: const [],
    );
  }

  Future<void> connect() async {
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      clearStatusMessage: true,
      clearConnectedServerUrl: true,
      clearServerInfo: true,
      sites: const [],
    );

    try {
      final serverUrl = _serverApi.normalizeServerUrl(state.draftServerUrl);
      final serverInfo = await _serverApi.fetchServerInfo(serverUrl);
      if (!serverInfo.databaseReady) {
        state = state.copyWith(
          status: ConnectionStatus.serverNotReady,
          statusMessage: AppMessages.serverNotReady,
        );
        return;
      }

      final compatibility = _serverApi.checkServerCompatibility(serverInfo);

      if (!compatibility.isCompatible) {
        state = state.copyWith(
          status: ConnectionStatus.incompatibleServer,
          statusMessage: compatibility.message,
        );
        return;
      }

      final sites = await _serverApi.fetchSites(serverUrl);
      final selectedSiteSlug = _resolveSelectedSiteSlug(
        sites: sites,
        preferredSlug: _preferences.getSelectedSiteSlug(),
      );

      await _preferences.setServerUrl(serverUrl);
      if (selectedSiteSlug == null) {
        await _preferences.clearSelectedSiteSlug();
      } else {
        await _preferences.setSelectedSiteSlug(selectedSiteSlug);
      }

      state = state.copyWith(
        status: ConnectionStatus.connected,
        statusMessage:
            'Connected to ${serverInfo.name} ${serverInfo.version} '
            '(server API ${serverInfo.apiVersion}, client API $clientApiVersion).',
        connectedServerUrl: serverUrl,
        serverInfo: serverInfo,
        sites: sites,
        selectedSiteSlug: selectedSiteSlug,
      );
    } on FormatException catch (error) {
      state = state.copyWith(
        status: ConnectionStatus.invalidUrl,
        statusMessage: error.message,
      );
    } on ApiException catch (error) {
      if (error.statusCode == HttpStatus.serviceUnavailable ||
          error.code == 'database_unavailable') {
        state = state.copyWith(
          status: ConnectionStatus.serverNotReady,
          statusMessage: AppMessages.serverNotReady,
        );
        return;
      }

      state = state.copyWith(
        status: ConnectionStatus.serverError,
        statusMessage: error.message,
      );
    } on HttpException {
      state = state.copyWith(
        status: ConnectionStatus.serverError,
        statusMessage:
            'The server responded unexpectedly. Verify the WHM server URL and that the server is running.',
      );
    } on SocketException {
      state = state.copyWith(
        status: ConnectionStatus.networkError,
        statusMessage:
            'Could not connect to the server. Check the server URL, network access, and that the WHM server is reachable.',
      );
    } on TimeoutException {
      state = state.copyWith(
        status: ConnectionStatus.timeout,
        statusMessage:
            'Connection timed out after ${serverConnectionTimeout.inSeconds}s. Check the server URL and network access.',
      );
    } catch (error) {
      state = state.copyWith(
        status: ConnectionStatus.serverError,
        statusMessage: 'Unexpected error: $error',
      );
    }
  }

  Future<void> selectSite(String siteSlug) async {
    await _preferences.setSelectedSiteSlug(siteSlug);
    state = state.copyWith(selectedSiteSlug: siteSlug);
  }

  Future<BackgroundValidationResult> validateActiveConnection() async {
    final serverUrl = state.connectedServerUrl;
    if (serverUrl == null || serverUrl.isEmpty) {
      return const BackgroundValidationResult(
        serverAvailable: false,
        selectedSiteValid: false,
      );
    }

    try {
      final serverInfo = await _serverApi.fetchServerInfo(serverUrl);
      if (!serverInfo.databaseReady) {
        return const BackgroundValidationResult(
          serverAvailable: false,
          selectedSiteValid: false,
        );
      }

      final compatibility = _serverApi.checkServerCompatibility(serverInfo);
      if (!compatibility.isCompatible) {
        return const BackgroundValidationResult(
          serverAvailable: false,
          selectedSiteValid: false,
        );
      }

      final sites = await _serverApi.fetchSites(serverUrl);
      final selectedSiteSlug = state.selectedSiteSlug;
      final selectedSiteValid = selectedSiteSlug != null &&
          sites.any((site) => site.slug == selectedSiteSlug);

      return BackgroundValidationResult(
        serverAvailable: true,
        selectedSiteValid: selectedSiteValid,
      );
    } catch (_) {
      return const BackgroundValidationResult(
        serverAvailable: false,
        selectedSiteValid: false,
      );
    }
  }

  String? _resolveSelectedSiteSlug({
    required List<SiteSummary> sites,
    required String? preferredSlug,
  }) {
    if (preferredSlug == null) {
      return null;
    }

    for (final site in sites) {
      if (site.slug == preferredSlug) {
        return preferredSlug;
      }
    }

    return null;
  }
}
