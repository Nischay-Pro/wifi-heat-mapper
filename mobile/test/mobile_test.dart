import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/mobile.dart';
import 'package:mobile/src/features/connect/server_connection_state.dart';
import 'package:mobile/src/features/sites/sites_page.dart';

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
          databaseReady: true,
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
          databaseReady: true,
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
          databaseReady: true,
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
          databaseReady: true,
        ),
      );

      expect(result.isCompatible, isFalse);
    });
  });

  group('SiteSummary', () {
    test('parses site json', () {
      final site = SiteSummary.fromJson(const {
        'id': 'site-1',
        'slug': 'default',
        'name': 'Default',
        'description': 'Default site',
      });

      expect(site.id, 'site-1');
      expect(site.slug, 'default');
      expect(site.name, 'Default');
      expect(site.description, 'Default site');
    });
  });

  group('SitesView', () {
    testWidgets('shows an empty state when no sites are available', (tester) async {
      final state = ServerConnectionState(
        status: ConnectionStatus.connected,
        draftServerUrl: 'http://localhost:5173',
        connectedServerUrl: 'http://localhost:5173',
        sites: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: SitesView(
            connectionState: state,
            onSelectSite: (_) {},
            onRefreshSites: () async {},
            onContinue: () async {},
            onChangeServer: () {},
          ),
        ),
      );

      expect(find.text('Available sites'), findsOneWidget);
      expect(find.text('Connected to http://localhost:5173'), findsOneWidget);
      expect(find.text('No sites are available on this server.'), findsOneWidget);
    });

    testWidgets('does not show a stale selected site when the site list is empty', (tester) async {
      final state = ServerConnectionState(
        status: ConnectionStatus.connected,
        draftServerUrl: 'http://localhost:5173',
        connectedServerUrl: 'http://localhost:5173',
        sites: const [],
        selectedSiteSlug: 'default',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: SitesView(
            connectionState: state,
            onSelectSite: (_) {},
            onRefreshSites: () async {},
            onContinue: () async {},
            onChangeServer: () {},
          ),
        ),
      );

      expect(find.text('No sites are available on this server.'), findsOneWidget);
      expect(find.text('Selected site: default'), findsNothing);
    });
  });
}
