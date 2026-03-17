import 'package:flutter/material.dart';
import 'package:mobile/src/app/platform_theme.dart';
import 'package:mobile/src/features/connect/server_connect_page.dart';
import 'package:mobile/src/services/server_api.dart';

class WhmMobileApp extends StatelessWidget {
  const WhmMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: clientName,
      theme: buildPlatformTheme(),
      home: const ServerConnectPage(),
    );
  }
}
