enum WifiMetadataStatus {
  available,
  wifiDisabled,
  wifiNotConnected,
  permissionsMissing,
  unavailable,
  unsupportedPlatform,
}

class WifiMetadata {
  const WifiMetadata({
    this.status = WifiMetadataStatus.unavailable,
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

  factory WifiMetadata.fromJson(Map<Object?, Object?> json) {
    return WifiMetadata(
      status: _readStatus(json, 'status'),
      bssid: _readString(json, 'bssid'),
      channel: _readInt(json, 'channel'),
      channelFrequency: _readInt(json, 'channel_frequency'),
      clientIp: _readString(json, 'client_ip'),
      frequencyMhz: _readInt(json, 'frequency_mhz'),
      interfaceName: _readString(json, 'interface_name'),
      platform: _readString(json, 'platform'),
      rssi: _readInt(json, 'rssi'),
      signalQuality: _readInt(json, 'signal_quality'),
      signalQualityPercent: _readDouble(json, 'signal_quality_percent'),
      signalStrength: _readInt(json, 'signal_strength'),
      ssid: _readString(json, 'ssid'),
    );
  }

  final WifiMetadataStatus status;
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

  bool get isEmpty {
    return bssid == null &&
        channel == null &&
        channelFrequency == null &&
        clientIp == null &&
        frequencyMhz == null &&
        interfaceName == null &&
        platform == null &&
        rssi == null &&
        signalQuality == null &&
        signalQualityPercent == null &&
        signalStrength == null &&
        ssid == null;
  }

  bool get isAvailable => status == WifiMetadataStatus.available;

  Map<String, Object?> toJson() {
    return {
      'bssid': bssid,
      'channel': channel,
      'channel_frequency': channelFrequency,
      'client_ip': clientIp,
      'frequency_mhz': frequencyMhz,
      'interface_name': interfaceName,
      'platform': platform,
      'rssi': rssi,
      'signal_quality': signalQuality,
      'signal_quality_percent': signalQualityPercent,
      'signal_strength': signalStrength,
      'ssid': ssid,
    }..removeWhere((_, value) => value == null);
  }

  static String? _readString(Map<Object?, Object?> json, String key) {
    final value = json[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  static int? _readInt(Map<Object?, Object?> json, String key) {
    final value = json[key];
    return switch (value) {
      int intValue => intValue,
      double doubleValue => doubleValue.round(),
      _ => null,
    };
  }

  static double? _readDouble(Map<Object?, Object?> json, String key) {
    final value = json[key];
    return switch (value) {
      int intValue => intValue.toDouble(),
      double doubleValue => doubleValue,
      _ => null,
    };
  }

  static WifiMetadataStatus _readStatus(Map<Object?, Object?> json, String key) {
    final value = json[key];
    return switch (value) {
      'available' => WifiMetadataStatus.available,
      'wifi_disabled' => WifiMetadataStatus.wifiDisabled,
      'wifi_not_connected' => WifiMetadataStatus.wifiNotConnected,
      'permissions_missing' => WifiMetadataStatus.permissionsMissing,
      'unsupported_platform' => WifiMetadataStatus.unsupportedPlatform,
      _ => WifiMetadataStatus.unavailable,
    };
  }
}
