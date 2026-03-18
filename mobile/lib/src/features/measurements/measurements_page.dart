import 'package:flutter/material.dart';
import 'package:mobile/src/core/material_spacing.dart';
import 'package:mobile/src/models/wifi_metadata.dart';

class MeasurementsPage extends StatelessWidget {
  const MeasurementsPage({
    super.key,
    required this.selectedSiteSlug,
  });

  final String selectedSiteSlug;

  @override
  Widget build(BuildContext context) {
    const wifiMetadata = WifiMetadata();

    return MeasurementsView(
      selectedSiteSlug: selectedSiteSlug,
      wifiMetadata: wifiMetadata,
    );
  }
}

class MeasurementsView extends StatelessWidget {
  const MeasurementsView({
    super.key,
    required this.selectedSiteSlug,
    required this.wifiMetadata,
  });

  final String selectedSiteSlug;
  final WifiMetadata wifiMetadata;

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
}
