import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const serverConnectRouteName = '/server-connect';
const sitesRouteName = '/sites';
const wifiPermissionsRouteName = '/wifi-permissions';
const siteShellRouteName = '/site-shell';

Route<T> platformPageRoute<T>(
  Widget page, {
  RouteSettings? settings,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return CupertinoPageRoute<T>(
        builder: (_) => page,
        settings: settings,
      );
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return MaterialPageRoute<T>(
        builder: (_) => page,
        settings: settings,
      );
  }
}
