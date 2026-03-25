import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/storage/app_preferences.dart';

const httpDownloadStageOptions = <InternetStageOption>[
  InternetStageOption(bytes: 100 * 1000, label: '100 KB'),
  InternetStageOption(bytes: 1 * 1000 * 1000, label: '1 MB'),
  InternetStageOption(bytes: 10 * 1000 * 1000, label: '10 MB'),
  InternetStageOption(bytes: 25 * 1000 * 1000, label: '25 MB'),
  InternetStageOption(bytes: 100 * 1000 * 1000, label: '100 MB'),
  InternetStageOption(bytes: 250 * 1000 * 1000, label: '250 MB'),
];

const httpUploadStageOptions = <InternetStageOption>[
  InternetStageOption(bytes: 100 * 1000, label: '100 KB'),
  InternetStageOption(bytes: 1 * 1000 * 1000, label: '1 MB'),
  InternetStageOption(bytes: 10 * 1000 * 1000, label: '10 MB'),
  InternetStageOption(bytes: 25 * 1000 * 1000, label: '25 MB'),
  InternetStageOption(bytes: 50 * 1000 * 1000, label: '50 MB'),
];

const latencySampleCountOptions = <int>[3, 5, 10, 15, 20];

class InternetStageOption {
  const InternetStageOption({required this.bytes, required this.label});

  final int bytes;
  final String label;
}

class HttpInternetSpeedTestAdvancedSettings {
  const HttpInternetSpeedTestAdvancedSettings({
    required this.downloadStageBytes,
    required this.uploadStageBytes,
    required this.parallelStreams,
    required this.latencySampleCount,
  });

  factory HttpInternetSpeedTestAdvancedSettings.fromPreferences(
    AppPreferences preferences,
  ) {
    return HttpInternetSpeedTestAdvancedSettings(
      downloadStageBytes:
          preferences.getHttpDownloadStageBytes() ??
          HttpInternetSpeedTestAdvancedSettings.defaults.downloadStageBytes,
      uploadStageBytes:
          preferences.getHttpUploadStageBytes() ??
          HttpInternetSpeedTestAdvancedSettings.defaults.uploadStageBytes,
      parallelStreams:
          preferences.getHttpParallelStreams() ??
          HttpInternetSpeedTestAdvancedSettings.defaults.parallelStreams,
      latencySampleCount:
          preferences.getHttpLatencySampleCount() ??
          HttpInternetSpeedTestAdvancedSettings.defaults.latencySampleCount,
    );
  }

  final List<int> downloadStageBytes;
  final List<int> uploadStageBytes;
  final int parallelStreams;
  final int latencySampleCount;

  static const defaults = HttpInternetSpeedTestAdvancedSettings(
    downloadStageBytes: [250 * 1000 * 1000],
    uploadStageBytes: [50 * 1000 * 1000],
    parallelStreams: 2,
    latencySampleCount: 10,
  );

  HttpInternetSpeedTestAdvancedSettings copyWith({
    List<int>? downloadStageBytes,
    List<int>? uploadStageBytes,
    int? parallelStreams,
    int? latencySampleCount,
  }) {
    return HttpInternetSpeedTestAdvancedSettings(
      downloadStageBytes: downloadStageBytes ?? this.downloadStageBytes,
      uploadStageBytes: uploadStageBytes ?? this.uploadStageBytes,
      parallelStreams: parallelStreams ?? this.parallelStreams,
      latencySampleCount: latencySampleCount ?? this.latencySampleCount,
    );
  }
}

class MeasurementLabAdvancedSettings {
  const MeasurementLabAdvancedSettings({
    required this.downloadDurationSeconds,
    required this.uploadDurationSeconds,
    required this.latencySampleCount,
  });

  factory MeasurementLabAdvancedSettings.fromPreferences(
    AppPreferences preferences,
  ) {
    return MeasurementLabAdvancedSettings(
      downloadDurationSeconds:
          preferences.getMeasurementLabDownloadDurationSeconds() ??
          MeasurementLabAdvancedSettings.defaults.downloadDurationSeconds,
      uploadDurationSeconds:
          preferences.getMeasurementLabUploadDurationSeconds() ??
          MeasurementLabAdvancedSettings.defaults.uploadDurationSeconds,
      latencySampleCount:
          preferences.getMeasurementLabLatencySampleCount() ??
          MeasurementLabAdvancedSettings.defaults.latencySampleCount,
    );
  }

  final int downloadDurationSeconds;
  final int uploadDurationSeconds;
  final int latencySampleCount;

  static const defaults = MeasurementLabAdvancedSettings(
    downloadDurationSeconds: 15,
    uploadDurationSeconds: 10,
    latencySampleCount: 10,
  );

  MeasurementLabAdvancedSettings copyWith({
    int? downloadDurationSeconds,
    int? uploadDurationSeconds,
    int? latencySampleCount,
  }) {
    return MeasurementLabAdvancedSettings(
      downloadDurationSeconds:
          downloadDurationSeconds ?? this.downloadDurationSeconds,
      uploadDurationSeconds:
          uploadDurationSeconds ?? this.uploadDurationSeconds,
      latencySampleCount: latencySampleCount ?? this.latencySampleCount,
    );
  }
}

class InternetSpeedTestSettings {
  const InternetSpeedTestSettings({
    required this.backend,
    required this.http,
    required this.measurementLab,
    this.customLibrespeedUrl,
  });

  final InternetSpeedTestBackendPreference backend;
  final String? customLibrespeedUrl;
  final HttpInternetSpeedTestAdvancedSettings http;
  final MeasurementLabAdvancedSettings measurementLab;

  String get backendLabel => switch (backend) {
    InternetSpeedTestBackendPreference.publicLibrespeed =>
      'Public Librespeed (Recommended)',
    InternetSpeedTestBackendPreference.customLibrespeed => 'Custom Librespeed',
    InternetSpeedTestBackendPreference.cloudflare => 'Cloudflare',
    InternetSpeedTestBackendPreference.measurementLab => 'Measurement Lab',
  };

  InternetSpeedTestSettings copyWith({
    InternetSpeedTestBackendPreference? backend,
    String? customLibrespeedUrl,
    bool clearCustomLibrespeedUrl = false,
    HttpInternetSpeedTestAdvancedSettings? http,
    MeasurementLabAdvancedSettings? measurementLab,
  }) {
    return InternetSpeedTestSettings(
      backend: backend ?? this.backend,
      customLibrespeedUrl: clearCustomLibrespeedUrl
          ? null
          : customLibrespeedUrl ?? this.customLibrespeedUrl,
      http: http ?? this.http,
      measurementLab: measurementLab ?? this.measurementLab,
    );
  }
}

final internetSpeedTestSettingsControllerProvider =
    NotifierProvider<
      InternetSpeedTestSettingsController,
      InternetSpeedTestSettings
    >(InternetSpeedTestSettingsController.new);

class InternetSpeedTestSettingsController
    extends Notifier<InternetSpeedTestSettings> {
  AppPreferences get _preferences => ref.read(appPreferencesProvider);

  @override
  InternetSpeedTestSettings build() {
    return InternetSpeedTestSettings(
      backend: _preferences.getInternetSpeedTestBackendPreference(),
      customLibrespeedUrl: _preferences.getCustomLibrespeedUrl(),
      http: HttpInternetSpeedTestAdvancedSettings.fromPreferences(_preferences),
      measurementLab: MeasurementLabAdvancedSettings.fromPreferences(
        _preferences,
      ),
    );
  }

  Future<void> setBackend(InternetSpeedTestBackendPreference backend) async {
    if (state.backend == backend) {
      return;
    }

    await _preferences.setInternetSpeedTestBackendPreference(backend);
    state = state.copyWith(backend: backend);
  }

  Future<void> setCustomLibrespeedUrl(String? value) async {
    final normalizedValue = value?.trim();
    if ((normalizedValue == null || normalizedValue.isEmpty) &&
        (state.customLibrespeedUrl == null ||
            state.customLibrespeedUrl!.isEmpty)) {
      return;
    }

    if (normalizedValue == null || normalizedValue.isEmpty) {
      await _preferences.clearCustomLibrespeedUrl();
      state = state.copyWith(clearCustomLibrespeedUrl: true);
      return;
    }

    await _preferences.setCustomLibrespeedUrl(normalizedValue);
    state = state.copyWith(customLibrespeedUrl: normalizedValue);
  }

  Future<void> saveCustomLibrespeedUrlAndSelect(String value) async {
    await setCustomLibrespeedUrl(value);
    await setBackend(InternetSpeedTestBackendPreference.customLibrespeed);
  }

  Future<void> setHttpDownloadStageEnabled(int bytes, bool enabled) async {
    final current = {...state.http.downloadStageBytes};
    if (enabled) {
      current.add(bytes);
    } else {
      current.remove(bytes);
    }

    final ordered = httpDownloadStageOptions
        .where((option) => current.contains(option.bytes))
        .map((option) => option.bytes)
        .toList(growable: false);
    if (ordered.isEmpty) {
      return;
    }

    await _preferences.setHttpDownloadStageBytes(ordered);
    state = state.copyWith(
      http: state.http.copyWith(downloadStageBytes: ordered),
    );
  }

  Future<void> setHttpUploadStageEnabled(int bytes, bool enabled) async {
    final current = {...state.http.uploadStageBytes};
    if (enabled) {
      current.add(bytes);
    } else {
      current.remove(bytes);
    }

    final ordered = httpUploadStageOptions
        .where((option) => current.contains(option.bytes))
        .map((option) => option.bytes)
        .toList(growable: false);
    if (ordered.isEmpty) {
      return;
    }

    await _preferences.setHttpUploadStageBytes(ordered);
    state = state.copyWith(
      http: state.http.copyWith(uploadStageBytes: ordered),
    );
  }

  Future<void> setHttpParallelStreams(int value) async {
    await _preferences.setHttpParallelStreams(value);
    state = state.copyWith(http: state.http.copyWith(parallelStreams: value));
  }

  Future<void> setHttpLatencySampleCount(int value) async {
    await _preferences.setHttpLatencySampleCount(value);
    state = state.copyWith(
      http: state.http.copyWith(latencySampleCount: value),
    );
  }

  Future<void> setMeasurementLabDownloadDurationSeconds(int value) async {
    await _preferences.setMeasurementLabDownloadDurationSeconds(value);
    state = state.copyWith(
      measurementLab: state.measurementLab.copyWith(
        downloadDurationSeconds: value,
      ),
    );
  }

  Future<void> setMeasurementLabUploadDurationSeconds(int value) async {
    await _preferences.setMeasurementLabUploadDurationSeconds(value);
    state = state.copyWith(
      measurementLab: state.measurementLab.copyWith(
        uploadDurationSeconds: value,
      ),
    );
  }

  Future<void> setMeasurementLabLatencySampleCount(int value) async {
    await _preferences.setMeasurementLabLatencySampleCount(value);
    state = state.copyWith(
      measurementLab: state.measurementLab.copyWith(latencySampleCount: value),
    );
  }

  Future<void> resetHttpAdvancedSettings() async {
    final defaults = HttpInternetSpeedTestAdvancedSettings.defaults;
    await _preferences.setHttpDownloadStageBytes(defaults.downloadStageBytes);
    await _preferences.setHttpUploadStageBytes(defaults.uploadStageBytes);
    await _preferences.setHttpParallelStreams(defaults.parallelStreams);
    await _preferences.setHttpLatencySampleCount(defaults.latencySampleCount);
    state = state.copyWith(http: defaults);
  }

  Future<void> resetMeasurementLabAdvancedSettings() async {
    final defaults = MeasurementLabAdvancedSettings.defaults;
    await _preferences.setMeasurementLabDownloadDurationSeconds(
      defaults.downloadDurationSeconds,
    );
    await _preferences.setMeasurementLabUploadDurationSeconds(
      defaults.uploadDurationSeconds,
    );
    await _preferences.setMeasurementLabLatencySampleCount(
      defaults.latencySampleCount,
    );
    state = state.copyWith(measurementLab: defaults);
  }
}
