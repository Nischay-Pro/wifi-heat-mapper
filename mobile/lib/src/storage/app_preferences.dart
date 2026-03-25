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
  static const httpDownloadStageBytesKey = 'http_download_stage_bytes';
  static const httpUploadStageBytesKey = 'http_upload_stage_bytes';
  static const httpParallelStreamsKey = 'http_parallel_streams';
  static const httpLatencySampleCountKey = 'http_latency_sample_count';
  static const measurementLabDownloadDurationSecondsKey =
      'measurement_lab_download_duration_seconds';
  static const measurementLabUploadDurationSecondsKey =
      'measurement_lab_upload_duration_seconds';
  static const measurementLabLatencySampleCountKey =
      'measurement_lab_latency_sample_count';

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

  List<int>? getHttpDownloadStageBytes() =>
      _getIntList(httpDownloadStageBytesKey);

  List<int>? getHttpUploadStageBytes() => _getIntList(httpUploadStageBytesKey);

  int? getHttpParallelStreams() => _preferences.getInt(httpParallelStreamsKey);

  int? getHttpLatencySampleCount() =>
      _preferences.getInt(httpLatencySampleCountKey);

  int? getMeasurementLabDownloadDurationSeconds() =>
      _preferences.getInt(measurementLabDownloadDurationSecondsKey);

  int? getMeasurementLabUploadDurationSeconds() =>
      _preferences.getInt(measurementLabUploadDurationSecondsKey);

  int? getMeasurementLabLatencySampleCount() =>
      _preferences.getInt(measurementLabLatencySampleCountKey);

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

  Future<bool> setHttpDownloadStageBytes(List<int> values) =>
      _setIntList(httpDownloadStageBytesKey, values);

  Future<bool> setHttpUploadStageBytes(List<int> values) =>
      _setIntList(httpUploadStageBytesKey, values);

  Future<bool> setHttpParallelStreams(int value) =>
      _preferences.setInt(httpParallelStreamsKey, value);

  Future<bool> setHttpLatencySampleCount(int value) =>
      _preferences.setInt(httpLatencySampleCountKey, value);

  Future<bool> setMeasurementLabDownloadDurationSeconds(int value) =>
      _preferences.setInt(measurementLabDownloadDurationSecondsKey, value);

  Future<bool> setMeasurementLabUploadDurationSeconds(int value) =>
      _preferences.setInt(measurementLabUploadDurationSecondsKey, value);

  Future<bool> setMeasurementLabLatencySampleCount(int value) =>
      _preferences.setInt(measurementLabLatencySampleCountKey, value);

  Future<bool> clearSelectedSiteSlug() =>
      _preferences.remove(selectedSiteSlugKey);

  Future<bool> clearCustomLibrespeedUrl() =>
      _preferences.remove(customLibrespeedUrlKey);

  List<int>? _getIntList(String key) {
    final values = _preferences.getStringList(key);
    if (values == null) {
      return null;
    }

    final parsed = values
        .map(int.tryParse)
        .whereType<int>()
        .where((value) => value > 0)
        .toList(growable: false);
    if (parsed.isEmpty) {
      return null;
    }

    return parsed;
  }

  Future<bool> _setIntList(String key, List<int> values) {
    return _preferences.setStringList(
      key,
      values.map((value) => value.toString()).toList(growable: false),
    );
  }
}
