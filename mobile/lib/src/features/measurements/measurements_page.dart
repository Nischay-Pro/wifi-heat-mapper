import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:mobile/src/core/loading_indicator.dart';
import 'package:mobile/src/core/material_spacing.dart';
import 'package:mobile/src/features/measurements/wifi_metadata_service.dart';
import 'package:mobile/src/models/wifi_metadata.dart';

class MeasurementsPage extends ConsumerStatefulWidget {
  const MeasurementsPage({
    super.key,
    required this.selectedSiteSlug,
  });

  final String selectedSiteSlug;

  @override
  ConsumerState<MeasurementsPage> createState() => _MeasurementsPageState();
}

class _MeasurementsPageState extends ConsumerState<MeasurementsPage> {
  WifiMetadata _wifiMetadata = const WifiMetadata();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final metadata = await ref.read(wifiMetadataServiceProvider).loadMetadata();
      if (!mounted) {
        return;
      }

      setState(() {
        _wifiMetadata = metadata;
        _isLoading = false;
      });
    } on MissingPluginException {
      if (!mounted) {
        return;
      }

      setState(() {
        _wifiMetadata = const WifiMetadata();
        _isLoading = false;
        _errorMessage =
            'Wi-Fi metadata collection is not available on this device yet.';
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _wifiMetadata = const WifiMetadata();
        _isLoading = false;
        _errorMessage = error.message ??
            'Could not load Wi-Fi metadata from the device.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MeasurementsView(
      selectedSiteSlug: widget.selectedSiteSlug,
      wifiMetadata: _wifiMetadata,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      onRefresh: _loadMetadata,
    );
  }
}

class MeasurementsView extends StatelessWidget {
  const MeasurementsView({
    super.key,
    required this.selectedSiteSlug,
    required this.wifiMetadata,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
  });

  final String selectedSiteSlug;
  final WifiMetadata wifiMetadata;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final spacing = MaterialSpacing.of(context);
    final textTheme = Theme.of(context).textTheme;
    final items = <({String label, String value})>[
      (label: 'SSID', value: wifiMetadata.ssid ?? 'Not available yet'),
      (label: 'BSSID', value: wifiMetadata.bssid ?? 'Not available yet'),
      (label: 'Channel', value: _formatInt(wifiMetadata.channel)),
      (label: 'Channel frequency', value: _formatInt(wifiMetadata.channelFrequency)),
      (label: 'Client IP', value: wifiMetadata.clientIp ?? 'Not available yet'),
      (label: 'Frequency (MHz)', value: _formatInt(wifiMetadata.frequencyMhz)),
      (label: 'Interface name', value: wifiMetadata.interfaceName ?? 'Not available yet'),
      (label: 'Platform', value: wifiMetadata.platform ?? 'Not available yet'),
      (label: 'RSSI', value: _formatInt(wifiMetadata.rssi)),
      (label: 'Signal quality', value: _formatInt(wifiMetadata.signalQuality)),
      (
        label: 'Signal quality percent',
        value: wifiMetadata.signalQualityPercent == null
            ? 'Not available yet'
            : '${wifiMetadata.signalQualityPercent}%',
      ),
      (label: 'Signal strength', value: _formatInt(wifiMetadata.signalStrength)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurements'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : onRefresh,
            tooltip: 'Refresh Wi-Fi details',
            icon: isLoading
                ? const LoadingIndicator.small()
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.contentMaxWidth),
            child: ListView(
              padding: EdgeInsets.all(spacing.regular),
              children: [
                Text('Measurement activity', style: textTheme.headlineMedium),
                SizedBox(height: spacing.compact),
                Text(
                  'Temporary page for Wi-Fi metadata collection and debugging.',
                  style: textTheme.bodyMedium,
                ),
                SizedBox(height: spacing.regular),
                Text(
                  'Selected site: $selectedSiteSlug',
                  style: textTheme.bodySmall,
                ),
                SizedBox(height: spacing.regular),
                if (isLoading)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.regular),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(spacing.regular),
                        child: Row(
                          children: [
                            const LoadingIndicator.medium(),
                            SizedBox(width: spacing.regular),
                            Expanded(
                              child: Text(
                                'Loading current Wi-Fi metadata from this device.',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.regular),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(spacing.regular),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline),
                            SizedBox(width: spacing.compact),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!isLoading && wifiMetadata.isEmpty && errorMessage == null)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.regular),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(spacing.regular),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline),
                            SizedBox(width: spacing.compact),
                            Expanded(
                              child: Text(
                                _statusMessage(wifiMetadata.status),
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ...items.map(
                  (item) => Padding(
                    padding: EdgeInsets.only(bottom: spacing.compact),
                    child: Card(
                      child: ListTile(
                        title: Text(item.label),
                        subtitle: Text(item.value),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatInt(int? value) {
    return value == null ? 'Not available yet' : '$value';
  }

  String _statusMessage(WifiMetadataStatus status) {
    return switch (status) {
      WifiMetadataStatus.available => 'Wi-Fi metadata is available.',
      WifiMetadataStatus.wifiDisabled =>
        'Wi-Fi is turned off. Turn on Wi-Fi to collect Wi-Fi metadata.',
      WifiMetadataStatus.wifiNotConnected =>
        'Wi-Fi is not connected. Join a Wi-Fi network to continue.',
      WifiMetadataStatus.permissionsMissing =>
        'Wi-Fi permissions are missing. Grant the required access to collect Wi-Fi metadata.',
      WifiMetadataStatus.unsupportedPlatform =>
        'Wi-Fi metadata collection is not supported on this platform yet.',
      WifiMetadataStatus.unavailable =>
        'No Wi-Fi metadata is available from the device right now.',
    };
  }
}
