import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/core/material_spacing.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/connect/server_connection_state.dart';
import 'package:mobile/src/models/site_summary.dart';

class SitesPage extends ConsumerWidget {
  const SitesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(serverConnectionControllerProvider);
    final controller = ref.read(serverConnectionControllerProvider.notifier);

    return SitesView(
      connectionState: connectionState,
      onSelectSite: controller.selectSite,
      onRefreshSites: controller.connect,
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
    required this.onChangeServer,
  });

  final ServerConnectionState connectionState;
  final ValueChanged<String> onSelectSite;
  final Future<void> Function() onRefreshSites;
  final VoidCallback onChangeServer;

  @override
  Widget build(BuildContext context) {
    final spacing = MaterialSpacing.of(context);
    final textTheme = Theme.of(context).textTheme;
    final selectedSiteSlug = connectionState.sites.any(
      (site) => site.slug == connectionState.selectedSiteSlug,
    )
        ? connectionState.selectedSiteSlug
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available sites'),
        actions: [
          IconButton(
            onPressed: connectionState.isConnecting ? null : onRefreshSites,
            tooltip: 'Refresh sites',
            icon: connectionState.isConnecting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.contentMaxWidth),
            child: ListView(
              padding: EdgeInsets.all(spacing.regular),
              children: [
                if (connectionState.connectedServerUrl != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.regular),
                    child: Text(
                      'Connected to ${connectionState.connectedServerUrl}',
                      style: textTheme.bodySmall,
                    ),
                  ),
                if (connectionState.sites.isEmpty)
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.regular),
                      child: const Text('No sites are available on this server.'),
                    ),
                  )
                else
                  ...connectionState.sites.map(
                    (site) => Padding(
                      padding: EdgeInsets.only(bottom: spacing.compact),
                      child: _SiteTile(
                        site: site,
                        isSelected: selectedSiteSlug == site.slug,
                        onSelect: () => onSelectSite(site.slug),
                      ),
                    ),
                  ),
                SizedBox(height: spacing.regular),
                OutlinedButton(
                  onPressed: onChangeServer,
                  child: const Text('Change server'),
                ),
                if (selectedSiteSlug != null) ...[
                  SizedBox(height: spacing.regular),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.regular),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline),
                          SizedBox(width: spacing.compact),
                          Expanded(
                            child: Text(
                              'Selected site: $selectedSiteSlug',
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
    final spacing = MaterialSpacing.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        onTap: onSelect,
        title: Text(site.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(site.slug, style: textTheme.bodySmall),
            if (site.description != null && site.description!.isNotEmpty) ...[
              SizedBox(height: spacing.compact / 2),
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
