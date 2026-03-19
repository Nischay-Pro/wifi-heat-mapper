import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_route.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/app_shell/site_shell_page.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/connect/server_connection_state.dart';
import 'package:mobile/src/features/permissions/wifi_permissions_page.dart';
import 'package:mobile/src/features/permissions/wifi_permission_service.dart';
import 'package:mobile/src/models/site_summary.dart';

class SitesPage extends ConsumerWidget {
  const SitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        final requirementsMet = await wifiPermissionService.areRequirementsMet();
        if (!context.mounted) {
          return;
        }

        if (requirementsMet) {
          await Navigator.of(context).push(
            platformPageRoute<void>(
              SiteShellPage(selectedSiteSlug: connectionState.selectedSiteSlug!),
            ),
          );
          return;
        }

        await Navigator.of(context).push(
          platformPageRoute<void>(const WifiPermissionsPage()),
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
    final selectedSiteSlug = connectionState.sites.any(
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
                message: 'No sites are available on this server.',
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
              SizedBox(height: tokens.spacing.regular),
              const AppBanner(
                icon: Icons.check_circle_outline,
                message: 'A site is selected and ready for measurement.',
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
      padding: EdgeInsets.all(tokens.spacing.compact),
      child: ListTile(
        onTap: onSelect,
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
          color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        selected: isSelected,
      ),
    );
  }
}
