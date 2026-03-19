import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/theme_mode_controller.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/measurements/measurements_page.dart';
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
    required this.connectedServerUrl,
    required this.onChangeServer,
  });

  final String selectedSiteSlug;
  final String? connectedServerUrl;
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
              subtitle: selectedSiteSlug,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _SiteSettingsPage(
                      selectedSiteSlug: selectedSiteSlug,
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

class _SiteSettingsPage extends StatelessWidget {
  const _SiteSettingsPage({
    required this.selectedSiteSlug,
  });

  final String selectedSiteSlug;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Site'),
      ),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionHeader(
              title: 'Available Sites',
              subtitle: 'This is the active site for measurement capture and uploads.',
            ),
            SizedBox(height: tokens.sectionGap),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
