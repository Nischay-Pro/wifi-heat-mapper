import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_route.dart';
import 'package:mobile/src/core/material_spacing.dart';
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
    final spacing = MaterialSpacing.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WHM Mobile'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.contentMaxWidth),
            child: ListView(
              padding: EdgeInsets.all(spacing.regular),
              children: [
                Text('Connect to server', style: textTheme.headlineMedium),
                SizedBox(height: spacing.compact),
                Text(
                  'Enter the WHM server URL to validate compatibility before loading site data.',
                  style: textTheme.bodyMedium,
                ),
                SizedBox(height: spacing.comfortable),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.url,
                  onChanged: controller.updateServerUrl,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: spacing.regular),
                FilledButton(
                  onPressed: connectionState.isConnecting ? null : _handleConnect,
                  child: connectionState.isConnecting
                      ? const CircularProgressIndicator.adaptive()
                      : const Text('Connect'),
                ),
                SizedBox(height: spacing.regular),
                Text(
                  'Client version $clientVersion • API $clientApiVersion',
                  style: textTheme.bodySmall,
                ),
                if (connectionState.statusMessage != null) ...[
                  SizedBox(height: spacing.comfortable),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.regular),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            connectionState.hasError
                                ? Icons.error_outline
                                : Icons.info_outline,
                          ),
                          SizedBox(width: spacing.compact),
                          Expanded(
                            child: Text(
                              connectionState.statusMessage!,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
