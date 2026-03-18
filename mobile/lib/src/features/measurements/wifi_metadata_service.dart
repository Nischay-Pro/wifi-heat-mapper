import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/models/wifi_metadata.dart';

final wifiMetadataServiceProvider = Provider<WifiMetadataService>((ref) {
  return const WifiMetadataService();
});

class WifiMetadataService {
  const WifiMetadataService();

  static const String _channelName = 'wifi_metadata';
  static const MethodChannel _channel = MethodChannel(_channelName);

  Future<WifiMetadata> loadMetadata() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return const WifiMetadata(
        status: WifiMetadataStatus.unsupportedPlatform,
        platform: kIsWeb ? 'web' : null,
      );
    }

    final payload = await _channel.invokeMapMethod<Object?, Object?>('load');
    if (payload == null) {
      return const WifiMetadata();
    }

    return WifiMetadata.fromJson(payload);
  }
}
