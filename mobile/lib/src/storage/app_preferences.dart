import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemePreference(this.storageValue);

  final String storageValue;

  static AppThemePreference fromStorage(String? value) {
    for (final preference in values) {
      if (preference.storageValue == value) {
        return preference;
      }
    }

    return AppThemePreference.system;
  }
}

enum InternetSpeedTestBackendPreference {
  publicLibrespeed('public_librespeed'),
  customLibrespeed('custom_librespeed'),
  cloudflare('cloudflare'),
  measurementLab('measurement_lab');

  const InternetSpeedTestBackendPreference(this.storageValue);

  final String storageValue;

  static InternetSpeedTestBackendPreference fromStorage(String? value) {
    for (final preference in values) {
      if (preference.storageValue == value) {
        return preference;
      }
    }

    return InternetSpeedTestBackendPreference.publicLibrespeed;
  }
}

class AppPreferences {
  AppPreferences(this._preferences);

  static const serverUrlKey = 'server_url';
  static const selectedSiteSlugKey = 'selected_site_slug';
  static const deviceSlugKey = 'device_slug';
  static const themePreferenceKey = 'theme_preference';
  static const internetSpeedTestBackendKey = 'internet_speed_test_backend';
  static const customLibrespeedUrlKey = 'custom_librespeed_url';

  final SharedPreferences _preferences;

  String? getServerUrl() => _preferences.getString(serverUrlKey);

  String? getSelectedSiteSlug() => _preferences.getString(selectedSiteSlugKey);

  String? getDeviceSlug() => _preferences.getString(deviceSlugKey);

  AppThemePreference getThemePreference() => AppThemePreference.fromStorage(
    _preferences.getString(themePreferenceKey),
  );

  InternetSpeedTestBackendPreference getInternetSpeedTestBackendPreference() =>
      InternetSpeedTestBackendPreference.fromStorage(
        _preferences.getString(internetSpeedTestBackendKey),
      );

  String? getCustomLibrespeedUrl() =>
      _preferences.getString(customLibrespeedUrlKey);

  Future<bool> setServerUrl(String value) =>
      _preferences.setString(serverUrlKey, value);

  Future<bool> setSelectedSiteSlug(String value) =>
      _preferences.setString(selectedSiteSlugKey, value);

  Future<bool> setDeviceSlug(String value) =>
      _preferences.setString(deviceSlugKey, value);

  Future<bool> setThemePreference(AppThemePreference value) =>
      _preferences.setString(themePreferenceKey, value.storageValue);

  Future<bool> setInternetSpeedTestBackendPreference(
    InternetSpeedTestBackendPreference value,
  ) => _preferences.setString(internetSpeedTestBackendKey, value.storageValue);

  Future<bool> setCustomLibrespeedUrl(String value) =>
      _preferences.setString(customLibrespeedUrlKey, value);

  Future<bool> clearSelectedSiteSlug() =>
      _preferences.remove(selectedSiteSlugKey);

  Future<bool> clearCustomLibrespeedUrl() =>
      _preferences.remove(customLibrespeedUrlKey);
}
