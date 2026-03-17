import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mobile/src/models/project_summary.dart';
import 'package:mobile/src/models/server_info.dart';

const clientName = 'whm-mobile';
const clientVersion = '0.1.0';
const clientApiVersion = 1;
const serverConnectionTimeout = Duration(seconds: 3);

class CompatibilityResult {
  const CompatibilityResult({
    required this.isCompatible,
    this.message,
  });

  final bool isCompatible;
  final String? message;
}

class ServerApi {
  const ServerApi();

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
            'This server is older than the app. '
            'Update the WHM server to a version that supports client API $clientApiVersion '
            '(current server API: ${serverInfo.apiVersion}, server version: ${serverInfo.version}).',
      );
    }

    if (clientApiVersion < serverInfo.minClientApiVersion) {
      return CompatibilityResult(
        isCompatible: false,
        message:
            'This app is too old for the server. '
            'Update the mobile app to a version that supports server ${serverInfo.version} '
            '(required client API: ${serverInfo.minClientApiVersion}+).',
      );
    }

    return const CompatibilityResult(isCompatible: true);
  }

  Future<ServerInfo> fetchServerInfo(String serverUrl) async {
    final baseUri = Uri.parse(normalizeServerUrl(serverUrl));
    final infoUri = baseUri.replace(
      path: '${baseUri.path}/api/server-info'.replaceAll('//', '/'),
    );

    final httpClient = HttpClient()..connectionTimeout = serverConnectionTimeout;

    try {
      final request = await httpClient.getUrl(infoUri).timeout(serverConnectionTimeout);
      final response = await request.close().timeout(serverConnectionTimeout);
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

  Future<List<ProjectSummary>> fetchProjects(String serverUrl) async {
    final baseUri = Uri.parse(normalizeServerUrl(serverUrl));
    final projectsUri = baseUri.replace(
      path: '${baseUri.path}/api/projects'.replaceAll('//', '/'),
    );

    final httpClient = HttpClient()..connectionTimeout = serverConnectionTimeout;

    try {
      final request = await httpClient.getUrl(projectsUri).timeout(serverConnectionTimeout);
      final response = await request.close().timeout(serverConnectionTimeout);
      final responseBody = await utf8.decodeStream(response);

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Server returned ${response.statusCode} for ${projectsUri.path}',
          uri: projectsUri,
        );
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final projectsJson = decoded['projects'];

      if (projectsJson is! List) {
        throw const FormatException('Projects payload is missing the projects list.');
      }

      return projectsJson
          .map((project) => ProjectSummary.fromJson(project as Map<String, dynamic>))
          .toList(growable: false);
    } finally {
      httpClient.close();
    }
  }
}
