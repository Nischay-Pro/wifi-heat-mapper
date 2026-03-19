import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/mobile.dart';
import 'package:mobile/src/features/connect/server_connection_state.dart';
import 'package:mobile/src/features/sites/sites_page.dart';
import 'package:mobile/src/storage/app_preferences.dart';

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

  group('WifiMetadata', () {
    test('parses wifi metadata json', () {
      final wifiMetadata = WifiMetadata.fromJson(const {
        'status': 'available',
        'ssid': 'ExampleWiFi',
        'bssid': 'aa:bb:cc:dd:ee:ff',
        'channel': 36,
        'channel_frequency': 5180,
        'client_ip': '192.168.7.50',
        'frequency_mhz': 5180,
        'interface_name': 'wlan0',
        'platform': 'android',
        'rssi': -58,
        'signal_quality': 74,
        'signal_quality_percent': 74.0,
        'signal_strength': -58,
      });

      expect(wifiMetadata.status, WifiMetadataStatus.available);
      expect(wifiMetadata.ssid, 'ExampleWiFi');
      expect(wifiMetadata.bssid, 'aa:bb:cc:dd:ee:ff');
      expect(wifiMetadata.channel, 36);
      expect(wifiMetadata.channelFrequency, 5180);
      expect(wifiMetadata.clientIp, '192.168.7.50');
      expect(wifiMetadata.frequencyMhz, 5180);
      expect(wifiMetadata.interfaceName, 'wlan0');
      expect(wifiMetadata.platform, 'android');
      expect(wifiMetadata.rssi, -58);
      expect(wifiMetadata.signalQuality, 74);
      expect(wifiMetadata.signalQualityPercent, 74.0);
      expect(wifiMetadata.signalStrength, -58);
    });
  });

  group('AppThemePreference', () {
    test('falls back to system for unknown values', () {
      expect(
        AppThemePreference.fromStorage('unexpected'),
        AppThemePreference.system,
      );
    });

    test('parses stored values', () {
      expect(
        AppThemePreference.fromStorage('light'),
        AppThemePreference.light,
      );
      expect(
        AppThemePreference.fromStorage('dark'),
        AppThemePreference.dark,
      );
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

      expect(find.text('Available sites'), findsAtLeastNWidgets(1));
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
