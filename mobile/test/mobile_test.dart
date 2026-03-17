import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/mobile.dart';

void main() {
  const serverApi = ServerApi();

  group('normalizeServerUrl', () {
    test('keeps a valid base URL', () {
      expect(serverApi.normalizeServerUrl('http://localhost:5173'), 'http://localhost:5173');
    });

    test('removes a trailing slash', () {
      expect(serverApi.normalizeServerUrl('http://localhost:5173/'), 'http://localhost:5173');
    });
  });

  group('checkServerCompatibility', () {
    test('accepts same API version', () {
      final result = serverApi.checkServerCompatibility(
        const ServerInfo(
          name: 'whm-server',
          version: '0.1.0',
          apiVersion: 1,
          minClientApiVersion: 1,
        ),
      );

      expect(result.isCompatible, isTrue);
    });

    test('accepts newer server that still supports this client', () {
      final result = serverApi.checkServerCompatibility(
        const ServerInfo(
          name: 'whm-server',
          version: '0.2.0',
          apiVersion: 2,
          minClientApiVersion: 1,
        ),
      );

      expect(result.isCompatible, isTrue);
    });

    test('rejects older server', () {
      final result = serverApi.checkServerCompatibility(
        const ServerInfo(
          name: 'whm-server',
          version: '0.0.5',
          apiVersion: 0,
          minClientApiVersion: 0,
        ),
      );

      expect(result.isCompatible, isFalse);
    });

    test('rejects server that requires a newer client', () {
      final result = serverApi.checkServerCompatibility(
        const ServerInfo(
          name: 'whm-server',
          version: '0.2.0',
          apiVersion: 2,
          minClientApiVersion: 2,
        ),
      );

      expect(result.isCompatible, isFalse);
    });
  });

  group('ProjectSummary', () {
    test('parses project json', () {
      final project = ProjectSummary.fromJson(const {
        'id': 'project-1',
        'slug': 'default',
        'name': 'Default',
        'description': 'Default project',
      });

      expect(project.id, 'project-1');
      expect(project.slug, 'default');
      expect(project.name, 'Default');
      expect(project.description, 'Default project');
    });
  });
}
