class ServerInfo {
  const ServerInfo({
    required this.name,
    required this.version,
    required this.apiVersion,
    required this.minClientApiVersion,
  });

  final String name;
  final String version;
  final int apiVersion;
  final int minClientApiVersion;

  factory ServerInfo.fromJson(Map<String, dynamic> json) {
    return ServerInfo(
      name: json['name'] as String,
      version: json['version'] as String,
      apiVersion: json['api_version'] as int,
      minClientApiVersion: json['min_client_api_version'] as int,
    );
  }
}
