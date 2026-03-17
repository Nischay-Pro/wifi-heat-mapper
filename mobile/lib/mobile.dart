import 'dart:convert';
import 'dart:io';

const clientName = 'whm-mobile';
const clientVersion = '0.1.0';
const clientApiVersion = 1;

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

class CompatibilityResult {
  const CompatibilityResult({
    required this.isCompatible,
    this.message,
  });

  final bool isCompatible;
  final String? message;
}

String normalizeServerUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Server URL cannot be empty.');
  }

  final parsed = Uri.parse(trimmed);
  if (!parsed.hasScheme || parsed.host.isEmpty) {
    throw FormatException('Invalid server URL: $rawUrl');
  }

  final normalizedPath = parsed.path == '/'
      ? ''
      : parsed.path.endsWith('/') && parsed.path.length > 1
          ? parsed.path.substring(0, parsed.path.length - 1)
          : parsed.path;

  return parsed.replace(path: normalizedPath).toString();
}

CompatibilityResult checkServerCompatibility(ServerInfo serverInfo) {
  if (clientApiVersion > serverInfo.apiVersion) {
    return CompatibilityResult(
      isCompatible: false,
      message:
          'Server ${serverInfo.version} is older than this client. '
          'Server API ${serverInfo.apiVersion} does not support client API $clientApiVersion.',
    );
  }

  if (clientApiVersion < serverInfo.minClientApiVersion) {
    return CompatibilityResult(
      isCompatible: false,
      message:
          'This client is too old for server ${serverInfo.version}. '
          'Server requires client API ${serverInfo.minClientApiVersion}+.',
    );
  }

  return const CompatibilityResult(isCompatible: true);
}

Future<ServerInfo> fetchServerInfo(String serverUrl) async {
  final baseUri = Uri.parse(normalizeServerUrl(serverUrl));
  final infoUri = baseUri.replace(path: '${baseUri.path}/api/server-info'.replaceAll('//', '/'));

  final httpClient = HttpClient();

  try {
    final request = await httpClient.getUrl(infoUri);
    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Server returned ${response.statusCode} for ${infoUri.path}',
        uri: infoUri,
      );
    }

    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final serverJson = decoded['server'];

    if (serverJson is! Map<String, dynamic>) {
      throw const FormatException('Server info payload is missing the server object.');
    }

    return ServerInfo.fromJson(serverJson);
  } finally {
    httpClient.close();
  }
}
