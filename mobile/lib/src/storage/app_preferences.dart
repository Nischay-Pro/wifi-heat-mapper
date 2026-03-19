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

class AppPreferences {
  AppPreferences(this._preferences);

  static const serverUrlKey = 'server_url';
  static const selectedSiteSlugKey = 'selected_site_slug';
  static const deviceSlugKey = 'device_slug';
  static const themePreferenceKey = 'theme_preference';

  final SharedPreferences _preferences;

  String? getServerUrl() => _preferences.getString(serverUrlKey);

  String? getSelectedSiteSlug() => _preferences.getString(selectedSiteSlugKey);

  String? getDeviceSlug() => _preferences.getString(deviceSlugKey);

  AppThemePreference getThemePreference() =>
      AppThemePreference.fromStorage(_preferences.getString(themePreferenceKey));

  Future<bool> setServerUrl(String value) => _preferences.setString(serverUrlKey, value);

  Future<bool> setSelectedSiteSlug(String value) =>
      _preferences.setString(selectedSiteSlugKey, value);

  Future<bool> setDeviceSlug(String value) => _preferences.setString(deviceSlugKey, value);

  Future<bool> setThemePreference(AppThemePreference value) =>
      _preferences.setString(themePreferenceKey, value.storageValue);

  Future<bool> clearSelectedSiteSlug() => _preferences.remove(selectedSiteSlugKey);
}
