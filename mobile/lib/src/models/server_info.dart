class ServerInfo {
  const ServerInfo({
    required this.name,
    required this.version,
    required this.apiVersion,
    required this.minClientApiVersion,
    required this.databaseReady,
  });

  final String name;
  final String version;
  final int apiVersion;
  final int minClientApiVersion;
  final bool databaseReady;

  factory ServerInfo.fromJson(
    Map<String, dynamic> json, {
    required bool databaseReady,
  }) {
    return ServerInfo(
      name: json['name'] as String,
      version: json['version'] as String,
      apiVersion: json['api_version'] as int,
      minClientApiVersion: json['min_client_api_version'] as int,
      databaseReady: databaseReady,
    );
  }
}
