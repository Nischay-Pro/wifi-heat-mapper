import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences(this._preferences);

  static const serverUrlKey = 'server_url';
  static const selectedSiteSlugKey = 'selected_site_slug';
  static const deviceSlugKey = 'device_slug';

  final SharedPreferences _preferences;

  String? getServerUrl() => _preferences.getString(serverUrlKey);

  String? getSelectedSiteSlug() => _preferences.getString(selectedSiteSlugKey);

  String? getDeviceSlug() => _preferences.getString(deviceSlugKey);

  Future<bool> setServerUrl(String value) => _preferences.setString(serverUrlKey, value);

  Future<bool> setSelectedSiteSlug(String value) =>
      _preferences.setString(selectedSiteSlugKey, value);

  Future<bool> setDeviceSlug(String value) => _preferences.setString(deviceSlugKey, value);

  Future<bool> clearSelectedSiteSlug() => _preferences.remove(selectedSiteSlugKey);
}
