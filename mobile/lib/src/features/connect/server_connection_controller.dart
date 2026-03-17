import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/features/connect/server_connection_state.dart';
import 'package:mobile/src/models/project_summary.dart';
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

class ServerConnectionController extends Notifier<ServerConnectionState> {
  AppPreferences get _preferences => ref.read(appPreferencesProvider);
  ServerApi get _serverApi => ref.read(serverApiProvider);

  @override
  ServerConnectionState build() {
    return ServerConnectionState.initial(
      draftServerUrl: _preferences.getServerUrl() ?? 'http://localhost:5173',
      selectedProjectSlug: _preferences.getSelectedProjectSlug(),
    );
  }

  void updateServerUrl(String value) {
    state = state.copyWith(
      draftServerUrl: value,
      status: ConnectionStatus.idle,
      clearStatusMessage: true,
      clearConnectedServerUrl: true,
      clearServerInfo: true,
      projects: const [],
    );
  }

  Future<void> connect() async {
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      clearStatusMessage: true,
      clearConnectedServerUrl: true,
      clearServerInfo: true,
      projects: const [],
    );

    try {
      final serverUrl = _serverApi.normalizeServerUrl(state.draftServerUrl);
      final serverInfo = await _serverApi.fetchServerInfo(serverUrl);
      final compatibility = _serverApi.checkServerCompatibility(serverInfo);

      if (!compatibility.isCompatible) {
        state = state.copyWith(
          status: ConnectionStatus.incompatibleServer,
          statusMessage: compatibility.message,
        );
        return;
      }

      final projects = await _serverApi.fetchProjects(serverUrl);
      final selectedProjectSlug = _resolveSelectedProjectSlug(
        projects: projects,
        preferredSlug: _preferences.getSelectedProjectSlug(),
      );

      await _preferences.setServerUrl(serverUrl);
      if (selectedProjectSlug == null) {
        await _preferences.clearSelectedProjectSlug();
      } else {
        await _preferences.setSelectedProjectSlug(selectedProjectSlug);
      }

      state = state.copyWith(
        status: ConnectionStatus.connected,
        statusMessage:
            'Connected to ${serverInfo.name} ${serverInfo.version} '
            '(server API ${serverInfo.apiVersion}, client API $clientApiVersion).',
        connectedServerUrl: serverUrl,
        serverInfo: serverInfo,
        projects: projects,
        selectedProjectSlug: selectedProjectSlug,
      );
    } on FormatException catch (error) {
      state = state.copyWith(
        status: ConnectionStatus.invalidUrl,
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

  Future<void> selectProject(String projectSlug) async {
    await _preferences.setSelectedProjectSlug(projectSlug);
    state = state.copyWith(selectedProjectSlug: projectSlug);
  }

  String? _resolveSelectedProjectSlug({
    required List<ProjectSummary> projects,
    required String? preferredSlug,
  }) {
    if (preferredSlug == null) {
      return null;
    }

    for (final project in projects) {
      if (project.slug == preferredSlug) {
        return preferredSlug;
      }
    }

    return null;
  }
}
