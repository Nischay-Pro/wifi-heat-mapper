class WifiMetadata {
  const WifiMetadata({
    this.bssid,
    this.channel,
    this.channelFrequency,
    this.clientIp,
    this.frequencyMhz,
    this.interfaceName,
    this.platform,
    this.rssi,
    this.signalQuality,
    this.signalQualityPercent,
    this.signalStrength,
    this.ssid,
  });

  final String? bssid;
  final int? channel;
  final int? channelFrequency;
  final String? clientIp;
  final int? frequencyMhz;
  final String? interfaceName;
  final String? platform;
  final int? rssi;
  final int? signalQuality;
  final double? signalQualityPercent;
  final int? signalStrength;
  final String? ssid;
}
