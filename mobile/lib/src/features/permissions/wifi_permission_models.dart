enum WifiPermissionStatus {
  granted,
  actionRequired,
}

enum WifiPermissionActionKind {
  requestPermission,
  openAppSettings,
  openLocationSettings,
}

class WifiPermissionRequirement {
  const WifiPermissionRequirement({
    required this.id,
    required this.title,
    required this.summary,
    required this.status,
    required this.actionKind,
    required this.actionLabel,
  });

  final String id;
  final String title;
  final String summary;
  final WifiPermissionStatus status;
  final WifiPermissionActionKind? actionKind;
  final String? actionLabel;

  bool get isGranted => status == WifiPermissionStatus.granted;
}
