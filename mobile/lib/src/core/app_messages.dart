class AppMessages {
  const AppMessages._();

  static const serverUnavailable = 'WHM server is no longer reachable.';
  static const serverNotReady =
      'The WHM server is reachable, but it is not ready yet. Check that the database is running and migrations have been applied.';
  static const invalidSelectedSite =
      'Selected site no longer exists on the server.';
  static const noSitesAvailable = 'No sites are available on this server.';

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
  static const customLibrespeedUrlRequired =
      'Enter a valid http:// or https:// URL for your custom Librespeed server.';
  static const measurementLabNotImplemented =
      'Measurement Lab is available as a selectable backend, but this client does not support running it yet.';
}
