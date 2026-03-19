import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_route.dart';
import 'package:mobile/src/core/loading_indicator.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/sites/sites_page.dart';
import 'package:mobile/src/services/server_api.dart';

class ServerConnectPage extends ConsumerStatefulWidget {
  const ServerConnectPage({super.key});

  @override
  ConsumerState<ServerConnectPage> createState() => _ServerConnectPageState();
}

class _ServerConnectPageState extends ConsumerState<ServerConnectPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(serverConnectionControllerProvider).draftServerUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final controller = ref.read(serverConnectionControllerProvider.notifier);
    await controller.connect();

    if (!mounted) {
      return;
    }

    final connectionState = ref.read(serverConnectionControllerProvider);
    if (!connectionState.isConnected) {
      return;
    }

    await Navigator.of(context).push(
      platformPageRoute<void>(const SitesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(serverConnectionControllerProvider);
    final controller = ref.read(serverConnectionControllerProvider.notifier);
    final tokens = AppTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WHM Mobile'),
      ),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionHeader(
              title: 'Connect to server',
              subtitle:
                  'Enter the WHM server URL to validate compatibility before loading site data.',
            ),
            SizedBox(height: tokens.sectionGap),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.url,
                    onChanged: controller.updateServerUrl,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.regular),
                  FilledButton(
                    onPressed: connectionState.isConnecting ? null : _handleConnect,
                    child: connectionState.isConnecting
                        ? const LoadingIndicator.small()
                        : const Text('Connect'),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.regular),
            Text(
              'Client version $clientVersion • API $clientApiVersion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (connectionState.statusMessage != null) ...[
              SizedBox(height: tokens.sectionGap),
              AppBanner(
                icon: connectionState.hasError ? Icons.error_outline : Icons.info_outline,
                message: connectionState.statusMessage!,
                iconColor: connectionState.hasError
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
