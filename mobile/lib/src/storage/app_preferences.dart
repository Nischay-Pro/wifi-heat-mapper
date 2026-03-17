import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences(this._preferences);

  static const serverUrlKey = 'server_url';
  static const selectedProjectSlugKey = 'selected_project_slug';

  final SharedPreferences _preferences;

  String? getServerUrl() => _preferences.getString(serverUrlKey);

  String? getSelectedProjectSlug() => _preferences.getString(selectedProjectSlugKey);

  Future<bool> setServerUrl(String value) => _preferences.setString(serverUrlKey, value);

  Future<bool> setSelectedProjectSlug(String value) =>
      _preferences.setString(selectedProjectSlugKey, value);

  Future<bool> clearSelectedProjectSlug() => _preferences.remove(selectedProjectSlugKey);
}
