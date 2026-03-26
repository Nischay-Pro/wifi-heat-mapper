import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_route.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/app_shell/site_shell_page.dart';
import 'package:mobile/src/features/connect/server_connect_page.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/connect/server_connection_state.dart';
import 'package:mobile/src/features/measurements/measurement_setup_controller.dart';
import 'package:mobile/src/features/measurements/measurement_setup_page.dart';
import 'package:mobile/src/features/permissions/wifi_permissions_page.dart';
import 'package:mobile/src/features/permissions/wifi_permission_service.dart';
import 'package:mobile/src/models/site_summary.dart';

class SitesPage extends ConsumerStatefulWidget {
  const SitesPage({super.key});

  @override
  ConsumerState<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends ConsumerState<SitesPage>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  bool _isPolling = false;
  bool _isNavigatingAway = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _pollServerState();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollServerState(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollServerState() async {
    if (_isPolling || _isNavigatingAway) {
      return;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }

    _isPolling = true;

    try {
      final validation = await ref
          .read(serverConnectionControllerProvider.notifier)
          .validateActiveConnection();
      if (!mounted) {
        return;
      }

      if (!validation.serverAvailable) {
        _isNavigatingAway = true;
        _stopPolling();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppMessages.serverUnavailable)),
        );
        await Navigator.of(context).pushAndRemoveUntil(
          platformPageRoute<void>(
            const ServerConnectPage(),
            settings: const RouteSettings(name: serverConnectRouteName),
          ),
          (_) => false,
        );
      }
    } finally {
      _isPolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(serverConnectionControllerProvider);
    final controller = ref.read(serverConnectionControllerProvider.notifier);
    final wifiPermissionService = ref.read(wifiPermissionServiceProvider);

    return SitesView(
      connectionState: connectionState,
      onSelectSite: controller.selectSite,
      onRefreshSites: controller.connect,
      onContinue: () async {
        if (connectionState.selectedSiteSlug == null) {
          return;
        }

        final requirementsMet = await wifiPermissionService
            .areRequirementsMet();
        if (!context.mounted) {
          return;
        }

        if (requirementsMet) {
          final setupStatus = ref.read(measurementSetupStatusProvider);
          await Navigator.of(context).push(
            platformPageRoute<void>(
              setupStatus.isComplete
                  ? SiteShellPage(
                      selectedSiteSlug: connectionState.selectedSiteSlug!,
                    )
                  : MeasurementSetupPage(
                      selectedSiteSlug: connectionState.selectedSiteSlug!,
                    ),
              settings: RouteSettings(
                name: setupStatus.isComplete
                    ? siteShellRouteName
                    : 'measurement-setup',
              ),
            ),
          );
          return;
        }

        await Navigator.of(context).push(
          platformPageRoute<void>(
            const WifiPermissionsPage(),
            settings: const RouteSettings(name: wifiPermissionsRouteName),
          ),
        );
      },
      onChangeServer: () => Navigator.of(context).pop(),
    );
  }
}

class SitesView extends StatelessWidget {
  const SitesView({
    super.key,
    required this.connectionState,
    required this.onSelectSite,
    required this.onRefreshSites,
    required this.onContinue,
    required this.onChangeServer,
  });

  final ServerConnectionState connectionState;
  final ValueChanged<String> onSelectSite;
  final Future<void> Function() onRefreshSites;
  final Future<void> Function() onContinue;
  final VoidCallback onChangeServer;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final selectedSiteSlug =
        connectionState.sites.any(
          (site) => site.slug == connectionState.selectedSiteSlug,
        )
        ? connectionState.selectedSiteSlug
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available sites'),
        actions: [
          AppBusyIconButton(
            onPressed: () {
              onRefreshSites();
            },
            tooltip: 'Refresh sites',
            icon: Icons.refresh,
            isBusy: connectionState.isConnecting,
          ),
        ],
      ),
      body: SafeArea(
        child: AppPage(
          children: [
            AppSectionHeader(
              title: 'Available sites',
              subtitle: connectionState.connectedServerUrl == null
                  ? 'Pick the site you want to measure.'
                  : 'Connected to ${connectionState.connectedServerUrl}',
            ),
            SizedBox(height: tokens.sectionGap),
            if (connectionState.sites.isEmpty)
              const AppBanner(
                icon: Icons.info_outline,
                message: AppMessages.noSitesAvailable,
              )
            else
              ...connectionState.sites.map(
                (site) => Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacing.compact),
                  child: _SiteTile(
                    site: site,
                    isSelected: selectedSiteSlug == site.slug,
                    onSelect: () => onSelectSite(site.slug),
                  ),
                ),
              ),
            SizedBox(height: tokens.sectionGap),
            OutlinedButton(
              onPressed: onChangeServer,
              child: const Text('Change server'),
            ),
            if (selectedSiteSlug != null) ...[
              SizedBox(height: tokens.spacing.regular),
              FilledButton(
                onPressed: onContinue,
                child: const Text('Continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SiteTile extends StatelessWidget {
  const _SiteTile({
    required this.site,
    required this.isSelected,
    required this.onSelect,
  });

  final SiteSummary site;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AppPanel(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onSelect,
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.regular,
          vertical: tokens.spacing.compact,
        ),
        title: Text(site.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(site.slug, style: textTheme.bodySmall),
            if (site.description != null && site.description!.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.compact / 2),
              Text(site.description!),
            ],
          ],
        ),
        leading: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        selected: isSelected,
      ),
    );
  }
}
