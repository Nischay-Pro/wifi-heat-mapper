import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/measurements/measurements_page.dart';

class SiteShellPage extends ConsumerStatefulWidget {
  const SiteShellPage({
    super.key,
    required this.selectedSiteSlug,
  });

  final String selectedSiteSlug;

  @override
  ConsumerState<SiteShellPage> createState() => _SiteShellPageState();
}

class _SiteShellPageState extends ConsumerState<SiteShellPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(serverConnectionControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            MeasurementsPage(
              selectedSiteSlug: widget.selectedSiteSlug,
              showScaffold: false,
            ),
            _SettingsTab(
              selectedSiteSlug: widget.selectedSiteSlug,
              connectedServerUrl: connectionState.connectedServerUrl,
              onChangeServer: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.network_check_outlined),
            selectedIcon: Icon(Icons.network_check),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '',
          ),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.selectedSiteSlug,
    required this.connectedServerUrl,
    required this.onChangeServer,
  });

  final String selectedSiteSlug;
  final String? connectedServerUrl;
  final VoidCallback onChangeServer;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      children: [
        const AppSectionHeader(
          title: 'Settings',
          subtitle: 'Server and site configuration for this device.',
        ),
        SizedBox(height: tokens.sectionGap),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connected server', style: textTheme.titleMedium),
              SizedBox(height: tokens.spacing.compact),
              Text(
                connectedServerUrl ?? 'Not connected',
                style: textTheme.bodyLarge,
              ),
              SizedBox(height: tokens.spacing.regular),
              Text('Selected site', style: textTheme.titleMedium),
              SizedBox(height: tokens.spacing.compact),
              Text(
                selectedSiteSlug,
                style: textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.regular),
        FilledButton.tonalIcon(
          onPressed: onChangeServer,
          icon: const Icon(Icons.sync_alt),
          label: const Text('Change server'),
        ),
      ],
    );
  }
}
