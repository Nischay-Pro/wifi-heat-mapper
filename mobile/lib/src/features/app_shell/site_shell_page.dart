import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_route.dart';
import 'package:mobile/src/app/theme_mode_controller.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/measurements/measurements_page.dart';
import 'package:mobile/src/features/permissions/wifi_permissions_page.dart';
import 'package:mobile/src/features/permissions/wifi_permission_service.dart';
import 'package:mobile/src/models/site_summary.dart';
import 'package:mobile/src/storage/app_preferences.dart';

class SiteShellPage extends ConsumerStatefulWidget {
  const SiteShellPage({
    super.key,
    required this.selectedSiteSlug,
  });

  final String selectedSiteSlug;

  @override
  ConsumerState<SiteShellPage> createState() => _SiteShellPageState();
}

class _SiteShellPageState extends ConsumerState<SiteShellPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Timer? _pollTimer;
  bool _isPolling = false;

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
    if (_isPolling) {
      return;
    }

    _isPolling = true;

    try {
      final validation =
          await ref.read(serverConnectionControllerProvider.notifier).validateActiveConnection();
      if (!mounted) {
        return;
      }

      if (!validation.serverAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppMessages.serverUnavailable),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      final requirementsMet = await ref.read(wifiPermissionServiceProvider).areRequirementsMet();
      if (!mounted) {
        return;
      }

      if (!requirementsMet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppMessages.wifiPermissionsMissing),
          ),
        );
        await Navigator.of(context).pushReplacement(
          platformPageRoute<void>(
            const WifiPermissionsPage(),
            settings: const RouteSettings(name: wifiPermissionsRouteName),
          ),
        );
        return;
      }

      if (!validation.selectedSiteValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppMessages.invalidSelectedSite),
          ),
        );
        Navigator.of(context).popUntil(
          (route) => route.settings.name == sitesRouteName || route.isFirst,
        );
      }
    } finally {
      _isPolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(serverConnectionControllerProvider);
    final currentSelectedSiteSlug = connectionState.sites.any(
      (site) => site.slug == connectionState.selectedSiteSlug,
    )
        ? connectionState.selectedSiteSlug
        : null;

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            if (currentSelectedSiteSlug == null)
              _MissingSelectedSiteView(
                onOpenSettings: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
              )
            else
              MeasurementsPage(
                selectedSiteSlug: currentSelectedSiteSlug,
                showScaffold: false,
                onOpenSiteSettings: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SiteSettingsPage(
                        selectedSiteSlug: currentSelectedSiteSlug,
                        sites: connectionState.sites,
                        isRefreshingSites: connectionState.isConnecting,
                        onRefreshSites: ref.read(serverConnectionControllerProvider.notifier).connect,
                        onSelectSite: (siteSlug) async {
                          await ref.read(serverConnectionControllerProvider.notifier).selectSite(siteSlug);
                        },
                      ),
                    ),
                  );
                },
              ),
            _SettingsTab(
              selectedSiteSlug: currentSelectedSiteSlug,
              sites: connectionState.sites,
              connectedServerUrl: connectionState.connectedServerUrl,
              isRefreshingSites: connectionState.isConnecting,
              onRefreshSites: ref.read(serverConnectionControllerProvider.notifier).connect,
              onSelectSite: (siteSlug) async {
                await ref.read(serverConnectionControllerProvider.notifier).selectSite(siteSlug);
              },
              onChangeServer: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ShellBottomBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class _ShellBottomBar extends StatelessWidget {
  const _ShellBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final barColor = isDark ? const Color(0xFF171A1F) : const Color(0xFFEDEFF3);
    final borderColor = isDark ? const Color(0xFF232832) : const Color(0xFFD4DBE6);
    final indicatorColor = isDark ? const Color(0xFF353A42) : const Color(0xFFD9DEE7);
    const destinations = <_ShellDestination>[
      _ShellDestination(
        icon: Icons.network_check_outlined,
        selectedIcon: Icons.network_check,
      ),
      _ShellDestination(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: barColor,
          border: Border(
            top: BorderSide(color: borderColor),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const outerPadding = 8.0;
            final segmentWidth = (constraints.maxWidth - (outerPadding * 2)) / destinations.length;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: outerPadding + (segmentWidth * selectedIndex),
                  top: outerPadding,
                  width: segmentWidth,
                  height: 72,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onSelected(index),
                            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                            splashFactory: NoSplash.splashFactory,
                            borderRadius: BorderRadius.circular(24),
                            child: SizedBox.expand(
                              child: Center(
                                child: Icon(
                                  index == selectedIndex
                                      ? destinations[index].selectedIcon
                                      : destinations[index].icon,
                                  color: index == selectedIndex
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.icon,
    required this.selectedIcon,
  });

  final IconData icon;
  final IconData selectedIcon;
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({
    required this.selectedSiteSlug,
    required this.sites,
    required this.connectedServerUrl,
    required this.isRefreshingSites,
    required this.onRefreshSites,
    required this.onSelectSite,
    required this.onChangeServer,
  });

  final String? selectedSiteSlug;
  final List<SiteSummary> sites;
  final String? connectedServerUrl;
  final bool isRefreshingSites;
  final Future<void> Function() onRefreshSites;
  final ValueChanged<String> onSelectSite;
  final VoidCallback onChangeServer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final themePreference = ref.watch(themeModeControllerProvider);

    return AppPage(
      children: [
        const AppSectionHeader(
          title: 'Settings',
          subtitle: 'App and site configuration for this device.',
        ),
        SizedBox(height: tokens.sectionGap),
        AppSettingsGroup(
          children: [
            AppSettingsRow(
              icon: Icons.palette_outlined,
              title: 'UI',
              subtitle: _themePreferenceLabel(themePreference),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _UiSettingsPage(),
                  ),
                );
              },
            ),
            AppSettingsRow(
              icon: Icons.storage_outlined,
              title: 'Server',
              subtitle: connectedServerUrl ?? 'Not connected',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _ServerSettingsPage(
                      connectedServerUrl: connectedServerUrl,
                      onChangeServer: onChangeServer,
                    ),
                  ),
                );
              },
            ),
            AppSettingsRow(
              icon: Icons.location_on_outlined,
              title: 'Site',
              subtitle: selectedSiteSlug ?? AppMessages.invalidSelectedSite,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SiteSettingsPage(
                      selectedSiteSlug: selectedSiteSlug,
                      sites: sites,
                      isRefreshingSites: isRefreshingSites,
                      onRefreshSites: onRefreshSites,
                      onSelectSite: onSelectSite,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _UiSettingsPage extends ConsumerWidget {
  const _UiSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final themePreference = ref.watch(themeModeControllerProvider);
    final themeController = ref.read(themeModeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UI'),
      ),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionHeader(
              title: 'Options',
              subtitle: 'Choose how the app decides between light and dark mode.',
            ),
            SizedBox(height: tokens.sectionGap),
            AppSettingsGroup(
              children: [
                _ThemeOptionRow(
                  title: 'System (Default)',
                  subtitle: 'Follow the device theme automatically.',
                  isSelected: themePreference == AppThemePreference.system,
                  onTap: () => themeController.setPreference(AppThemePreference.system),
                ),
                _ThemeOptionRow(
                  title: 'Light',
                  subtitle: 'Always use the light theme.',
                  isSelected: themePreference == AppThemePreference.light,
                  onTap: () => themeController.setPreference(AppThemePreference.light),
                ),
                _ThemeOptionRow(
                  title: 'Dark',
                  subtitle: 'Always use the dark theme.',
                  isSelected: themePreference == AppThemePreference.dark,
                  onTap: () => themeController.setPreference(AppThemePreference.dark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerSettingsPage extends StatelessWidget {
  const _ServerSettingsPage({
    required this.connectedServerUrl,
    required this.onChangeServer,
  });

  final String? connectedServerUrl;
  final VoidCallback onChangeServer;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server'),
      ),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionHeader(
              title: 'Connection',
              subtitle: 'Review the active WHM server and switch to a different one.',
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
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.regular),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).pop();
                onChangeServer();
              },
              icon: const Icon(Icons.sync_alt),
              label: const Text('Change server'),
            ),
          ],
        ),
      ),
    );
  }
}

class SiteSettingsPage extends StatelessWidget {
  const SiteSettingsPage({
    super.key,
    required this.selectedSiteSlug,
    required this.sites,
    required this.isRefreshingSites,
    required this.onRefreshSites,
    required this.onSelectSite,
  });

  final String? selectedSiteSlug;
  final List<SiteSummary> sites;
  final bool isRefreshingSites;
  final Future<void> Function() onRefreshSites;
  final ValueChanged<String> onSelectSite;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final hasValidSelection = selectedSiteSlug != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Site'),
        actions: [
          AppBusyIconButton(
            onPressed: () {
              onRefreshSites();
            },
            tooltip: 'Refresh sites',
            icon: Icons.refresh,
            isBusy: isRefreshingSites,
          ),
        ],
      ),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionHeader(
              title: 'Available Sites',
              subtitle: 'This is the active site for measurement capture and uploads.',
            ),
            SizedBox(height: tokens.sectionGap),
            if (!hasValidSelection)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.regular),
                child: const AppBanner(
                  icon: Icons.warning_amber_rounded,
                  message: AppMessages.invalidSelectedSite,
                ),
              ),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selected site', style: textTheme.titleMedium),
                  SizedBox(height: tokens.spacing.compact),
                  Text(
                    selectedSiteSlug ?? 'No valid site selected',
                    style: textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.regular),
            if (sites.isEmpty)
              const AppBanner(
                icon: Icons.info_outline,
                message: AppMessages.noSitesAvailable,
              )
            else
              AppSettingsGroup(
                children: [
                  for (final site in sites)
                    _ThemeOptionRow(
                      title: site.name,
                      subtitle: site.description?.isNotEmpty == true ? site.description! : site.slug,
                      isSelected: hasValidSelection && selectedSiteSlug == site.slug,
                      onTap: () {
                        onSelectSite(site.slug);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            SizedBox(height: tokens.spacing.regular),
            AppPanel(
              child: Text(
                'Access site management at your WHM Admin Dashboard',
                style: textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionRow extends StatelessWidget {
  const _ThemeOptionRow({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      title: Text(title, style: textTheme.titleMedium),
      subtitle: Text(subtitle),
      trailing: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? colorScheme.primary : colorScheme.outline,
      ),
    );
  }
}

String _themePreferenceLabel(AppThemePreference preference) {
  return switch (preference) {
    AppThemePreference.system => 'System (Default)',
    AppThemePreference.light => 'Light',
    AppThemePreference.dark => 'Dark',
  };
}

class _MissingSelectedSiteView extends StatelessWidget {
  const _MissingSelectedSiteView({
    required this.onOpenSettings,
  });

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return AppPage(
      children: [
        const AppSectionHeader(
          title: 'Measurement',
          subtitle: 'Choose a valid site before recording a measurement.',
        ),
        SizedBox(height: tokens.sectionGap),
        const AppBanner(
          icon: Icons.warning_amber_rounded,
          message: AppMessages.invalidSelectedSite,
        ),
        SizedBox(height: tokens.spacing.regular),
        FilledButton.tonalIcon(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Open settings'),
        ),
      ],
    );
  }
}
