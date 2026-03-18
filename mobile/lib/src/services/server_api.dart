import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mobile/src/models/site_summary.dart';
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

class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.statusCode,
    this.code,
  });

  final String message;
  final int statusCode;
  final String? code;
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
      final readinessJson = decoded['readiness'];

      if (serverJson is! Map<String, dynamic>) {
        throw const FormatException('Server info payload is missing the server object.');
      }

      final databaseReady =
          readinessJson is Map<String, dynamic> ? readinessJson['database'] == true : true;

      return ServerInfo.fromJson(
        serverJson,
        databaseReady: databaseReady,
      );
    } finally {
      httpClient.close();
    }
  }

  Future<List<SiteSummary>> fetchSites(String serverUrl) async {
    final baseUri = Uri.parse(normalizeServerUrl(serverUrl));
    final sitesUri = baseUri.replace(
      path: '${baseUri.path}/api/sites'.replaceAll('//', '/'),
    );

    final httpClient = HttpClient()..connectionTimeout = serverConnectionTimeout;

    try {
      final request = await httpClient.getUrl(sitesUri).timeout(serverConnectionTimeout);
      final response = await request.close().timeout(serverConnectionTimeout);
      final responseBody = await utf8.decodeStream(response);

      if (response.statusCode != HttpStatus.ok) {
        throw _parseApiException(
          responseBody: responseBody,
          statusCode: response.statusCode,
          fallbackMessage: 'Server returned ${response.statusCode} for ${sitesUri.path}',
        );
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final sitesJson = decoded['sites'];

      if (sitesJson is! List) {
        throw const FormatException('Sites payload is missing the sites list.');
      }

      return sitesJson
          .map((site) => SiteSummary.fromJson(site as Map<String, dynamic>))
          .toList(growable: false);
    } finally {
      httpClient.close();
    }
  }

  ApiException _parseApiException({
    required String responseBody,
    required int statusCode,
    required String fallbackMessage,
  }) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final errorJson = decoded['error'];

      if (errorJson is Map<String, dynamic>) {
        return ApiException(
          message: errorJson['message'] as String? ?? fallbackMessage,
          statusCode: statusCode,
          code: (errorJson['details'] as Map<String, dynamic>?)?['code'] as String?,
        );
      }
    } catch (_) {}

    return ApiException(
      message: fallbackMessage,
      statusCode: statusCode,
    );
  }
}
