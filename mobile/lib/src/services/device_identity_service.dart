import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/models/device_identity.dart';
import 'package:mobile/src/storage/app_preferences.dart';

final deviceIdentityServiceProvider = Provider<DeviceIdentityService>((ref) {
  return DeviceIdentityService(
    deviceInfoPlugin: DeviceInfoPlugin(),
  );
});

class DeviceIdentityService {
  DeviceIdentityService({
    required DeviceInfoPlugin deviceInfoPlugin,
  }) : _deviceInfoPlugin = deviceInfoPlugin;

  final DeviceInfoPlugin _deviceInfoPlugin;

  Future<DeviceIdentity> loadIdentity(AppPreferences preferences) async {
    var deviceSlug = preferences.getDeviceSlug();
    if (deviceSlug == null || deviceSlug.isEmpty) {
      deviceSlug = _generateDeviceSlug();
      await preferences.setDeviceSlug(deviceSlug);
    }

    final platform = _readPlatform();

    if (Platform.isAndroid) {
      final info = await _deviceInfoPlugin.androidInfo;
      final brand = info.brand.trim();
      final model = info.model.trim();
      final name = [brand, model].where((value) => value.isNotEmpty).join(' ').trim();
      return DeviceIdentity(
        slug: deviceSlug,
        name: name.isEmpty ? 'Android device' : name,
        platform: platform,
        model: model.isEmpty ? null : model,
      );
    }

    if (Platform.isIOS) {
      final info = await _deviceInfoPlugin.iosInfo;
      final model = info.utsname.machine.trim();
      final name = info.name.trim();
      return DeviceIdentity(
        slug: deviceSlug,
        name: name.isEmpty ? 'iOS device' : name,
        platform: platform,
        model: model.isEmpty ? null : model,
      );
    }

    return DeviceIdentity(
      slug: deviceSlug,
      name: 'Unknown device',
      platform: platform,
    );
  }

  String _generateDeviceSlug() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // UUID v4: 16 random bytes with the version and variant bits fixed.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}'
        '${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-'
        '${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 12).join()}-'
        '${hex.sublist(12, 16).join()}';
  }

  String _readPlatform() {
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isLinux) {
      return 'linux';
    }

    return 'unknown';
  }
}
