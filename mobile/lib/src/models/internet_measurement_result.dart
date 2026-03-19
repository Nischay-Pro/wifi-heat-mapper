class InternetMeasurementResult {
  const InternetMeasurementResult({
    this.backend,
    this.downloadBps,
    this.downloadElapsedMs,
    this.downloadLoadedJitterMs,
    this.downloadLoadedLatencyMs,
    this.downloadLoadedPacketLossPercent,
    this.downloadSamplesBps = const [],
    this.downloadSize,
    this.idleJitterMs,
    this.idleLatencyMs,
    this.idlePacketLossPercent,
    this.streamCount,
    this.uploadBps,
    this.uploadElapsedMs,
    this.uploadLoadedJitterMs,
    this.uploadLoadedLatencyMs,
    this.uploadLoadedPacketLossPercent,
    this.uploadSamplesBps = const [],
    this.uploadSize,
  });

  final String? backend;
  final double? downloadBps;
  final double? downloadElapsedMs;
  final double? downloadLoadedJitterMs;
  final double? downloadLoadedLatencyMs;
  final double? downloadLoadedPacketLossPercent;
  final List<double> downloadSamplesBps;
  final double? downloadSize;
  final double? idleJitterMs;
  final double? idleLatencyMs;
  final double? idlePacketLossPercent;
  final int? streamCount;
  final double? uploadBps;
  final double? uploadElapsedMs;
  final double? uploadLoadedJitterMs;
  final double? uploadLoadedLatencyMs;
  final double? uploadLoadedPacketLossPercent;
  final List<double> uploadSamplesBps;
  final double? uploadSize;

  double? get downloadMbps => _bpsToMbps(downloadBps);
  double? get uploadMbps => _bpsToMbps(uploadBps);

  static double? _bpsToMbps(double? bps) {
    if (bps == null) {
      return null;
    }

    return bps / 1000 / 1000;
  }

  Map<String, Object?> toJson() {
    return {
      'backend': backend,
      'download_bps': downloadBps,
      'download_elapsed_ms': downloadElapsedMs,
      'download_jitter_ms': downloadLoadedJitterMs,
      'download_latency_ms': downloadLoadedLatencyMs,
      'download_packet_loss_percent': downloadLoadedPacketLossPercent,
      'download_samples_bps': downloadSamplesBps,
      'download_size': downloadSize,
      'idle_jitter_ms': idleJitterMs,
      'idle_latency_ms': idleLatencyMs,
      'idle_packet_loss_percent': idlePacketLossPercent,
      'stream_count': streamCount,
      'upload_bps': uploadBps,
      'upload_elapsed_ms': uploadElapsedMs,
      'upload_jitter_ms': uploadLoadedJitterMs,
      'upload_latency_ms': uploadLoadedLatencyMs,
      'upload_packet_loss_percent': uploadLoadedPacketLossPercent,
      'upload_samples_bps': uploadSamplesBps,
      'upload_size': uploadSize,
    }..removeWhere((_, value) => value == null);
  }
}
