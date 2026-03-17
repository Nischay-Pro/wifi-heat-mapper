import 'package:mobile/src/models/project_summary.dart';
import 'package:mobile/src/models/server_info.dart';

enum ConnectionStatus {
  idle,
  connecting,
  connected,
  invalidUrl,
  networkError,
  timeout,
  incompatibleServer,
  serverError,
}

class ServerConnectionState {
  const ServerConnectionState({
    required this.status,
    required this.draftServerUrl,
    required this.projects,
    this.statusMessage,
    this.connectedServerUrl,
    this.serverInfo,
    this.selectedProjectSlug,
  });

  factory ServerConnectionState.initial({required String draftServerUrl, String? selectedProjectSlug}) {
    return ServerConnectionState(
      status: ConnectionStatus.idle,
      draftServerUrl: draftServerUrl,
      projects: const [],
      selectedProjectSlug: selectedProjectSlug,
    );
  }

  final ConnectionStatus status;
  final String draftServerUrl;
  final String? statusMessage;
  final String? connectedServerUrl;
  final ServerInfo? serverInfo;
  final List<ProjectSummary> projects;
  final String? selectedProjectSlug;

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isConnecting => status == ConnectionStatus.connecting;
  bool get hasError => !{
        ConnectionStatus.idle,
        ConnectionStatus.connecting,
        ConnectionStatus.connected,
      }.contains(status);

  ServerConnectionState copyWith({
    ConnectionStatus? status,
    String? draftServerUrl,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? connectedServerUrl,
    bool clearConnectedServerUrl = false,
    ServerInfo? serverInfo,
    bool clearServerInfo = false,
    List<ProjectSummary>? projects,
    String? selectedProjectSlug,
    bool clearSelectedProjectSlug = false,
  }) {
    return ServerConnectionState(
      status: status ?? this.status,
      draftServerUrl: draftServerUrl ?? this.draftServerUrl,
      statusMessage: clearStatusMessage ? null : statusMessage ?? this.statusMessage,
      connectedServerUrl:
          clearConnectedServerUrl ? null : connectedServerUrl ?? this.connectedServerUrl,
      serverInfo: clearServerInfo ? null : serverInfo ?? this.serverInfo,
      projects: projects ?? this.projects,
      selectedProjectSlug:
          clearSelectedProjectSlug ? null : selectedProjectSlug ?? this.selectedProjectSlug,
    );
  }
}
