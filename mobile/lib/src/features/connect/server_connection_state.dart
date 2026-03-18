import 'package:mobile/src/models/site_summary.dart';
import 'package:mobile/src/models/server_info.dart';

enum ConnectionStatus {
  idle,
  connecting,
  connected,
  invalidUrl,
  networkError,
  timeout,
  incompatibleServer,
  serverNotReady,
  serverError,
}

class ServerConnectionState {
  const ServerConnectionState({
    required this.status,
    required this.draftServerUrl,
    required this.sites,
    this.statusMessage,
    this.connectedServerUrl,
    this.serverInfo,
    this.selectedSiteSlug,
  });

  factory ServerConnectionState.initial({required String draftServerUrl, String? selectedSiteSlug}) {
    return ServerConnectionState(
      status: ConnectionStatus.idle,
      draftServerUrl: draftServerUrl,
      sites: const [],
      selectedSiteSlug: selectedSiteSlug,
    );
  }

  final ConnectionStatus status;
  final String draftServerUrl;
  final String? statusMessage;
  final String? connectedServerUrl;
  final ServerInfo? serverInfo;
  final List<SiteSummary> sites;
  final String? selectedSiteSlug;

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
    List<SiteSummary>? sites,
    String? selectedSiteSlug,
    bool clearSelectedSiteSlug = false,
  }) {
    return ServerConnectionState(
      status: status ?? this.status,
      draftServerUrl: draftServerUrl ?? this.draftServerUrl,
      statusMessage: clearStatusMessage ? null : statusMessage ?? this.statusMessage,
      connectedServerUrl:
          clearConnectedServerUrl ? null : connectedServerUrl ?? this.connectedServerUrl,
      serverInfo: clearServerInfo ? null : serverInfo ?? this.serverInfo,
      sites: sites ?? this.sites,
      selectedSiteSlug:
          clearSelectedSiteSlug ? null : selectedSiteSlug ?? this.selectedSiteSlug,
    );
  }
}
