class AppMessages {
  const AppMessages._();

  static const serverUnavailable = 'WHM server is no longer reachable.';
  static const serverNotReady =
      'The WHM server is reachable, but it is not ready yet. Check that the database is running and migrations have been applied.';
  static const invalidSelectedSite =
      'Selected site no longer exists on the server.';
  static const noSitesAvailable = 'No sites are available on this server.';
  static const noFloorplanAvailable =
      'This site does not have any floorplans yet. Upload them from the WHM Admin Dashboard.';
  static const noPointsAvailable =
      'This floor does not have any measurement points yet. Add points from the WHM Admin Dashboard.';
  static const floorplanLoadFailed =
      'The site floorplan could not be loaded right now.';
  static const pointNoLongerExists =
      'The selected point is no longer available. Choose another point on the floorplan.';

  static const wifiDisabled =
      'Wi-Fi is turned off. Turn on Wi-Fi to collect Wi-Fi metadata.';
  static const wifiNotConnected =
      'Wi-Fi is not connected. Join a Wi-Fi network to continue.';
  static const wifiPermissionsMissing =
      'Wi-Fi permissions are missing. Grant the required access to collect Wi-Fi metadata.';
  static const wifiUnsupportedPlatform =
      'Wi-Fi metadata collection is not supported on this platform yet.';
  static const wifiUnavailable =
      'No Wi-Fi metadata is available from the device right now.';
  static const wifiAvailable = 'Wi-Fi metadata is available.';

  static const measurementUploaded = 'Measurement uploaded to the WHM server.';
  static const measurementCapturedNoServer =
      'Measurement captured locally, but no connected server URL is available for upload.';
  static const noMeasurementRecorded =
      'No measurement could be recorded for the selected measurement mode.';
  static const customLibrespeedUrlRequired =
      'Enter a valid http:// or https:// URL for your custom Librespeed server.';
  static const intranetServerRequired =
      'Enter a valid local iperf3 server host or IP address.';
  static const intranetServerConnectionFailed =
      'The configured local iperf3 server could not be reached.';
  static const intranetUnavailable =
      'The local iperf3 setting is configured, but this mobile app build does not include a native iperf3 client yet.';
  static const intranetNoModesSelected = 'No local iperf3 modes are enabled.';
  static const measurementLabUnavailable =
      'Measurement Lab could not provide a test server right now. Try again later.';
}
