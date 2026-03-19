import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_route.dart';
import 'package:mobile/src/core/loading_indicator.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/app_shell/site_shell_page.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/permissions/wifi_permissions_page.dart';
import 'package:mobile/src/features/permissions/wifi_permission_service.dart';
import 'package:mobile/src/features/sites/sites_page.dart';
import 'package:mobile/src/services/server_api.dart';

class ServerConnectPage extends ConsumerStatefulWidget {
  const ServerConnectPage({super.key});

  @override
  ConsumerState<ServerConnectPage> createState() => _ServerConnectPageState();
}

class _ServerConnectPageState extends ConsumerState<ServerConnectPage> {
  late final TextEditingController _controller;
  bool _didAttemptAutoResume = false;
  late bool _isAttemptingAutoResume;

  @override
  void initState() {
    super.initState();
    final initialState = ref.read(serverConnectionControllerProvider);
    _controller = TextEditingController(text: initialState.draftServerUrl);
    _isAttemptingAutoResume =
        initialState.draftServerUrl.trim().isNotEmpty &&
        initialState.selectedSiteSlug != null &&
        initialState.selectedSiteSlug!.isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptAutoResume();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _attemptAutoResume() async {
    if (_didAttemptAutoResume) {
      return;
    }
    _didAttemptAutoResume = true;

    final initialState = ref.read(serverConnectionControllerProvider);
    final hasSavedServer = initialState.draftServerUrl.trim().isNotEmpty;
    final savedSiteSlug = initialState.selectedSiteSlug;

    if (!hasSavedServer || savedSiteSlug == null || savedSiteSlug.isEmpty) {
      if (mounted) {
        setState(() {
          _isAttemptingAutoResume = false;
        });
      }
      return;
    }

    final controller = ref.read(serverConnectionControllerProvider.notifier);
    await controller.connect();

    if (!mounted) {
      return;
    }

    final connectionState = ref.read(serverConnectionControllerProvider);
    if (!connectionState.isConnected || connectionState.selectedSiteSlug == null) {
      setState(() {
        _isAttemptingAutoResume = false;
      });
      return;
    }

    final requirementsMet = await ref.read(wifiPermissionServiceProvider).areRequirementsMet();
    if (!mounted) {
      return;
    }

    if (!requirementsMet) {
      await Navigator.of(context).pushReplacement(
        platformPageRoute<void>(
          const WifiPermissionsPage(),
          settings: const RouteSettings(name: wifiPermissionsRouteName),
        ),
      );
      return;
    }

    await Navigator.of(context).pushReplacement(
      platformPageRoute<void>(
        SiteShellPage(selectedSiteSlug: connectionState.selectedSiteSlug!),
        settings: const RouteSettings(name: siteShellRouteName),
      ),
    );
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
      platformPageRoute<void>(
        const SitesPage(),
        settings: const RouteSettings(name: sitesRouteName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(serverConnectionControllerProvider);
    final controller = ref.read(serverConnectionControllerProvider.notifier);
    final tokens = AppTokens.of(context);

    if (_isAttemptingAutoResume) {
      return _ServerBootstrapView(
        savedSiteSlug: connectionState.selectedSiteSlug ?? 'Loading site',
      );
    }

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

class _ServerBootstrapView extends StatelessWidget {
  const _ServerBootstrapView({
    required this.savedSiteSlug,
  });

  final String savedSiteSlug;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = isDark ? const Color(0xFF24282E) : const Color(0xFFE1E6EE);
    final placeholderSoft = isDark ? const Color(0xFF1D2025) : const Color(0xFFF0F3F7);

    Widget block({
      required double height,
      double? width,
      BorderRadius? radius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: placeholder,
          borderRadius: radius ?? BorderRadius.circular(20),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('WHM Mobile'),
      ),
      body: SafeArea(
        child: AppPage(
          children: [
            Row(
              children: [
                Expanded(
                  child: AppPanel(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.regular,
                      vertical: tokens.spacing.compact,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.bolt,
                            color: colorScheme.primary,
                          ),
                        ),
                        SizedBox(width: tokens.spacing.compact),
                        Expanded(
                          child: Text(
                            savedSiteSlug,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Icon(
                          Icons.expand_more,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.compact),
                block(height: 52, width: 52, radius: BorderRadius.circular(18)),
              ],
            ),
            SizedBox(height: tokens.sectionGap),
            block(height: 28, width: 280, radius: BorderRadius.circular(16)),
            SizedBox(height: tokens.spacing.regular),
            block(height: 320, radius: BorderRadius.circular(28)),
            SizedBox(height: tokens.sectionGap),
            block(height: 24, width: 180, radius: BorderRadius.circular(14)),
            SizedBox(height: tokens.spacing.regular),
            Row(
              children: [
                Expanded(child: block(height: 76, radius: BorderRadius.circular(24))),
                SizedBox(width: tokens.spacing.compact),
                Expanded(child: block(height: 76, radius: BorderRadius.circular(24))),
                SizedBox(width: tokens.spacing.compact),
                Expanded(child: block(height: 76, radius: BorderRadius.circular(24))),
              ],
            ),
            SizedBox(height: tokens.spacing.regular),
            block(height: 18, width: 120, radius: BorderRadius.circular(10)),
            SizedBox(height: tokens.spacing.compact),
            block(height: 14, radius: BorderRadius.circular(999)),
            SizedBox(height: tokens.sectionGap),
            Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == 3 ? 0 : tokens.spacing.compact,
                    ),
                    child: Container(
                      height: 132,
                      decoration: BoxDecoration(
                        color: placeholderSoft,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: tokens.sectionGap),
            Center(
              child: Column(
                children: [
                  const LoadingIndicator.medium(),
                  SizedBox(height: tokens.spacing.regular),
                  Text(
                    'Loading measurement activity...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
