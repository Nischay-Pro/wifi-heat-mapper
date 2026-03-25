import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_route.dart';
import 'package:mobile/src/app/theme_mode_controller.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/connect/server_connect_page.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/measurements/internet_speed_test_settings_controller.dart';
import 'package:mobile/src/features/measurements/local_measurement_settings_controller.dart';
import 'package:mobile/src/features/measurements/measurements_page.dart';
import 'package:mobile/src/features/permissions/wifi_permissions_page.dart';
import 'package:mobile/src/features/permissions/wifi_permission_service.dart';
import 'package:mobile/src/features/sites/sites_page.dart';
import 'package:mobile/src/models/site_summary.dart';
import 'package:mobile/src/storage/app_preferences.dart';

class SiteShellPage extends ConsumerStatefulWidget {
  const SiteShellPage({super.key, required this.selectedSiteSlug});

  final String selectedSiteSlug;

  @override
  ConsumerState<SiteShellPage> createState() => _SiteShellPageState();
}

class _SiteShellPageState extends ConsumerState<SiteShellPage>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
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
        return;
      }

      final requirementsMet = await ref
          .read(wifiPermissionServiceProvider)
          .areRequirementsMet();
      if (!mounted) {
        return;
      }

      if (!requirementsMet) {
        _isNavigatingAway = true;
        _stopPolling();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppMessages.wifiPermissionsMissing)),
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
        _isNavigatingAway = true;
        _stopPolling();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppMessages.invalidSelectedSite)),
        );
        await Navigator.of(context).pushAndRemoveUntil(
          platformPageRoute<void>(
            const SitesPage(),
            settings: const RouteSettings(name: sitesRouteName),
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
    final currentSelectedSiteSlug =
        connectionState.sites.any(
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
                        onRefreshSites: ref
                            .read(serverConnectionControllerProvider.notifier)
                            .connect,
                        onSelectSite: (siteSlug) async {
                          await ref
                              .read(serverConnectionControllerProvider.notifier)
                              .selectSite(siteSlug);
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
              onRefreshSites: ref
                  .read(serverConnectionControllerProvider.notifier)
                  .connect,
              onSelectSite: (siteSlug) async {
                await ref
                    .read(serverConnectionControllerProvider.notifier)
                    .selectSite(siteSlug);
              },
              onChangeServer: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
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
    final borderColor = isDark
        ? const Color(0xFF232832)
        : const Color(0xFFD4DBE6);
    final indicatorColor = isDark
        ? const Color(0xFF353A42)
        : const Color(0xFFD9DEE7);
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
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const outerPadding = 8.0;
            final segmentWidth =
                (constraints.maxWidth - (outerPadding * 2)) /
                destinations.length;

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
                            overlayColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
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
  const _ShellDestination({required this.icon, required this.selectedIcon});

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
    final internetSettings = ref.watch(
      internetSpeedTestSettingsControllerProvider,
    );
    final intranetSettings = ref.watch(
      localMeasurementSettingsControllerProvider,
    );

    return AppPage(
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        SizedBox(height: tokens.sectionGap),
        const AppSectionLabel(label: 'Appearance'),
        SizedBox(height: tokens.spacing.compact),
        AppSettingsGroup(
          flat: true,
          children: [
            AppSettingsRow(
              title: 'App Theme',
              subtitle: _themePreferenceLabel(themePreference),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _UiSettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
        SizedBox(height: tokens.sectionGap),
        const AppSectionLabel(label: 'Measurement'),
        SizedBox(height: tokens.spacing.compact),
        AppSettingsGroup(
          flat: true,
          children: [
            AppSettingsRow(
              title: 'Internet speed test',
              subtitle: internetSettings.backendLabel,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _InternetSettingsPage(),
                  ),
                );
              },
            ),
            AppSettingsRow(
              title: 'Intranet speed test',
              subtitle: intranetSettings.serverLabel,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _IntranetSettingsPage(),
                  ),
                );
              },
            ),
            AppSettingsRow(
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
        SizedBox(height: tokens.sectionGap),
        const AppSectionLabel(label: 'Connection'),
        SizedBox(height: tokens.spacing.compact),
        AppSettingsGroup(
          flat: true,
          children: [
            AppSettingsRow(
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
          ],
        ),
      ],
    );
  }
}

class _InternetSettingsPage extends ConsumerWidget {
  const _InternetSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final settings = ref.watch(internetSpeedTestSettingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Internet speed test')),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionLabel(label: 'Backend'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message:
                  'Choose which public internet speed test backend this device uses.',
            ),
            SizedBox(height: tokens.sectionGap),
            AppSettingsGroup(
              flat: true,
              children: [
                _BackendSettingsRow(
                  title: 'Public Librespeed (Recommended)',
                  isSelected:
                      settings.backend ==
                      InternetSpeedTestBackendPreference.publicLibrespeed,
                  onSelect: () => ref
                      .read(
                        internetSpeedTestSettingsControllerProvider.notifier,
                      )
                      .setBackend(
                        InternetSpeedTestBackendPreference.publicLibrespeed,
                      ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _HttpBackendSettingsPage(
                          title: 'Public Librespeed',
                          subtitle:
                              'Use the shared Librespeed public backend and adjust how the test runs.',
                          backend: InternetSpeedTestBackendPreference
                              .publicLibrespeed,
                        ),
                      ),
                    );
                  },
                  onOpenAdvanced: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _HttpBackendAdvancedSettingsPage(
                          title: 'Public Librespeed',
                          subtitle:
                              'Adjust stages, stream count, and latency samples for the public Librespeed backend.',
                        ),
                      ),
                    );
                  },
                ),
                _BackendSettingsRow(
                  title: 'Custom Librespeed',
                  isSelected:
                      settings.backend ==
                      InternetSpeedTestBackendPreference.customLibrespeed,
                  onSelect: () => ref
                      .read(
                        internetSpeedTestSettingsControllerProvider.notifier,
                      )
                      .setBackend(
                        InternetSpeedTestBackendPreference.customLibrespeed,
                      ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _CustomLibrespeedSettingsPage(),
                      ),
                    );
                  },
                  onOpenAdvanced: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _HttpBackendAdvancedSettingsPage(
                          title: 'Custom Librespeed',
                          subtitle:
                              'Adjust stages, stream count, and latency samples for your own Librespeed backend.',
                        ),
                      ),
                    );
                  },
                ),
                _BackendSettingsRow(
                  title: 'Cloudflare',
                  isSelected:
                      settings.backend ==
                      InternetSpeedTestBackendPreference.cloudflare,
                  onSelect: () => ref
                      .read(
                        internetSpeedTestSettingsControllerProvider.notifier,
                      )
                      .setBackend(
                        InternetSpeedTestBackendPreference.cloudflare,
                      ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _HttpBackendSettingsPage(
                          title: 'Cloudflare',
                          subtitle:
                              'Use the Cloudflare public speed test backend and adjust how the test runs.',
                          backend:
                              InternetSpeedTestBackendPreference.cloudflare,
                        ),
                      ),
                    );
                  },
                  onOpenAdvanced: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _HttpBackendAdvancedSettingsPage(
                          title: 'Cloudflare',
                          subtitle:
                              'Adjust stages, stream count, and latency samples for the Cloudflare backend.',
                        ),
                      ),
                    );
                  },
                ),
                _BackendSettingsRow(
                  title: 'Measurement Lab',
                  isSelected:
                      settings.backend ==
                      InternetSpeedTestBackendPreference.measurementLab,
                  onSelect: () => ref
                      .read(
                        internetSpeedTestSettingsControllerProvider.notifier,
                      )
                      .setBackend(
                        InternetSpeedTestBackendPreference.measurementLab,
                      ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _MeasurementLabSettingsPage(),
                      ),
                    );
                  },
                  onOpenAdvanced: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const _MeasurementLabAdvancedSettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
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
      appBar: AppBar(title: const Text('App Theme')),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionLabel(label: 'User Interface'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message:
                  'Choose how the app decides between light and dark mode.',
            ),
            SizedBox(height: tokens.sectionGap),
            AppSettingsGroup(
              flat: true,
              children: [
                _SelectableSettingsRow(
                  title: 'System (Default)',
                  subtitle: 'Follow the device theme automatically.',
                  isSelected: themePreference == AppThemePreference.system,
                  onTap: () =>
                      themeController.setPreference(AppThemePreference.system),
                ),
                _SelectableSettingsRow(
                  title: 'Light',
                  subtitle: 'Always use the light theme.',
                  isSelected: themePreference == AppThemePreference.light,
                  onTap: () =>
                      themeController.setPreference(AppThemePreference.light),
                ),
                _SelectableSettingsRow(
                  title: 'Dark',
                  subtitle: 'Always use the dark theme.',
                  isSelected: themePreference == AppThemePreference.dark,
                  onTap: () =>
                      themeController.setPreference(AppThemePreference.dark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IntranetSettingsPage extends ConsumerStatefulWidget {
  const _IntranetSettingsPage();

  @override
  ConsumerState<_IntranetSettingsPage> createState() =>
      _IntranetSettingsPageState();
}

class _IntranetSettingsPageState extends ConsumerState<_IntranetSettingsPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  String? _errorMessage;
  String? _statusMessage;
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(localMeasurementSettingsControllerProvider);
    _hostController = TextEditingController(text: settings.serverHost ?? '');
    _portController = TextEditingController(
      text: settings.serverPort.toString(),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      setState(() {
        _errorMessage = AppMessages.intranetServerRequired;
      });
      return;
    }

    await ref
        .read(localMeasurementSettingsControllerProvider.notifier)
        .saveServer(host: host, port: port);

    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _statusMessage = 'Saved intranet iperf3 server.';
    });
  }

  Future<void> _testConnection() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      setState(() {
        _errorMessage = AppMessages.intranetServerRequired;
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    final connected = await ref
        .read(localMeasurementSettingsControllerProvider.notifier)
        .testServerConnection(host: host, port: port);

    if (!mounted) {
      return;
    }

    setState(() {
      _isTestingConnection = false;
      _statusMessage = connected
          ? 'Connected to intranet iperf3 server.'
          : AppMessages.intranetServerConnectionFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final settings = ref.watch(localMeasurementSettingsControllerProvider);
    final controller = ref.read(
      localMeasurementSettingsControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Intranet speed test')),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionLabel(label: 'iPerf3'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message:
                  'Configure the intranet iperf3 server used for LAN throughput measurements.',
            ),
            SizedBox(height: tokens.sectionGap),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _hostController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Server host or IP',
                      hintText: '192.168.1.100',
                      errorText: _errorMessage,
                    ),
                    onChanged: (_) {
                      if (_errorMessage != null) {
                        setState(() {
                          _errorMessage = null;
                        });
                      }
                    },
                  ),
                  SizedBox(height: tokens.spacing.regular),
                  AppNumericBox(
                    controller: _portController,
                    label: 'Port',
                    hintText: '5201',
                    onChanged: (_) {
                      if (_errorMessage != null || _statusMessage != null) {
                        setState(() {
                          _errorMessage = null;
                          _statusMessage = null;
                        });
                      }
                    },
                  ),
                  if (_statusMessage != null) ...[
                    SizedBox(height: tokens.spacing.regular),
                    Text(
                      _statusMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  SizedBox(height: tokens.spacing.regular),
                  Wrap(
                    spacing: tokens.spacing.compact,
                    runSpacing: tokens.spacing.compact,
                    children: [
                      FilledButton(
                        onPressed: _save,
                        child: const Text('Save intranet server'),
                      ),
                      OutlinedButton(
                        onPressed: _isTestingConnection
                            ? null
                            : _testConnection,
                        child: Text(
                          _isTestingConnection
                              ? 'Testing...'
                              : 'Test connection',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.sectionGap),
            AppPanel(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('TCP download'),
                    value: settings.modes.tcpDownloadEnabled,
                    onChanged: controller.setTcpDownloadEnabled,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('TCP upload'),
                    value: settings.modes.tcpUploadEnabled,
                    onChanged: controller.setTcpUploadEnabled,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('UDP download'),
                    value: settings.modes.udpDownloadEnabled,
                    onChanged: controller.setUdpDownloadEnabled,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('UDP upload'),
                    value: settings.modes.udpUploadEnabled,
                    onChanged: controller.setUdpUploadEnabled,
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.sectionGap),
            AppSettingsGroup(
              flat: true,
              children: [
                AppSettingsRow(
                  title: 'Enabled iperf modes',
                  subtitle: settings.modes.summary,
                ),
              ],
            ),
            SizedBox(height: tokens.sectionGap),
            const AppBanner(
              icon: Icons.info_outline_rounded,
              message:
                  'Intranet measurements map to WHM local_result. The current mobile app still needs a native iperf3 client bridge before these measurements can run.',
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomLibrespeedSettingsPage extends ConsumerStatefulWidget {
  const _CustomLibrespeedSettingsPage();

  @override
  ConsumerState<_CustomLibrespeedSettingsPage> createState() =>
      _CustomLibrespeedSettingsPageState();
}

class _CustomLibrespeedSettingsPageState
    extends ConsumerState<_CustomLibrespeedSettingsPage> {
  late final TextEditingController _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final currentValue = ref
        .read(internetSpeedTestSettingsControllerProvider)
        .customLibrespeedUrl;
    _controller = TextEditingController(text: currentValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    final parsed = Uri.tryParse(value);
    final isValid =
        parsed != null &&
        parsed.hasScheme &&
        parsed.hasAuthority &&
        (parsed.scheme == 'http' || parsed.scheme == 'https');

    if (!isValid) {
      setState(() {
        _errorMessage = AppMessages.customLibrespeedUrlRequired;
      });
      return;
    }

    await ref
        .read(internetSpeedTestSettingsControllerProvider.notifier)
        .saveCustomLibrespeedUrlAndSelect(value);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Custom Librespeed')),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionLabel(label: 'Server URL'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message: 'Enter the base URL for your own Librespeed instance.',
            ),
            SizedBox(height: tokens.sectionGap),
            AppPanel(
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Librespeed URL',
                      hintText: 'https://speed.example.com/',
                      errorText: _errorMessage,
                    ),
                    onChanged: (_) {
                      if (_errorMessage != null) {
                        setState(() {
                          _errorMessage = null;
                        });
                      }
                    },
                  ),
                  SizedBox(height: tokens.spacing.regular),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Use custom Librespeed'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.sectionGap),
            AppSettingsGroup(
              flat: true,
              children: [
                AppSettingsRow(
                  title: 'Advanced options',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _HttpBackendAdvancedSettingsPage(
                          title: 'Custom Librespeed',
                          subtitle:
                              'Adjust stages, stream count, and latency samples for your own Librespeed backend.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HttpBackendSettingsPage extends ConsumerWidget {
  const _HttpBackendSettingsPage({
    required this.title,
    required this.subtitle,
    required this.backend,
  });

  final String title;
  final String subtitle;
  final InternetSpeedTestBackendPreference backend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: AppPage(
          children: [
            AppSectionLabel(label: title),
            SizedBox(height: tokens.spacing.compact),
            AppSectionNote(message: subtitle),
            SizedBox(height: tokens.sectionGap),
            AppSettingsGroup(
              flat: true,
              children: [
                AppSettingsRow(
                  title: 'Advanced options',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _HttpBackendAdvancedSettingsPage(
                          title: title,
                          subtitle:
                              'Adjust stages, stream count, and latency samples for this backend.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementLabSettingsPage extends ConsumerWidget {
  const _MeasurementLabSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Measurement Lab')),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionLabel(label: 'Measurement Lab'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message:
                  'Use speed.measurementlab.net and adjust how the NDT7 test runs.',
            ),
            SizedBox(height: tokens.sectionGap),
            AppSettingsGroup(
              flat: true,
              children: [
                AppSettingsRow(
                  title: 'Advanced options',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const _MeasurementLabAdvancedSettingsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HttpBackendAdvancedSettingsPage extends ConsumerStatefulWidget {
  const _HttpBackendAdvancedSettingsPage({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  ConsumerState<_HttpBackendAdvancedSettingsPage> createState() =>
      _HttpBackendAdvancedSettingsPageState();
}

class _HttpBackendAdvancedSettingsPageState
    extends ConsumerState<_HttpBackendAdvancedSettingsPage> {
  late final TextEditingController _parallelStreamsController;
  late final TextEditingController _latencySampleCountController;
  String? _parallelStreamsError;
  String? _latencySampleCountError;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(internetSpeedTestSettingsControllerProvider);
    _parallelStreamsController = TextEditingController(
      text: settings.http.parallelStreams.toString(),
    );
    _latencySampleCountController = TextEditingController(
      text: settings.http.latencySampleCount.toString(),
    );
  }

  @override
  void dispose() {
    _parallelStreamsController.dispose();
    _latencySampleCountController.dispose();
    super.dispose();
  }

  Future<void> _saveParallelStreams() async {
    final parsed = int.tryParse(_parallelStreamsController.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() {
        _parallelStreamsError = 'Enter a valid positive number of streams.';
      });
      return;
    }

    await ref
        .read(internetSpeedTestSettingsControllerProvider.notifier)
        .setHttpParallelStreams(parsed);
    if (!mounted) {
      return;
    }

    setState(() {
      _parallelStreamsError = null;
      _parallelStreamsController.text = parsed.toString();
    });
  }

  Future<void> _saveLatencySampleCount() async {
    final parsed = int.tryParse(_latencySampleCountController.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() {
        _latencySampleCountError =
            'Enter a valid positive number of latency samples.';
      });
      return;
    }

    await ref
        .read(internetSpeedTestSettingsControllerProvider.notifier)
        .setHttpLatencySampleCount(parsed);
    if (!mounted) {
      return;
    }

    setState(() {
      _latencySampleCountError = null;
      _latencySampleCountController.text = parsed.toString();
    });
  }

  Future<void> _reset() async {
    await ref
        .read(internetSpeedTestSettingsControllerProvider.notifier)
        .resetHttpAdvancedSettings();
    final defaults = HttpInternetSpeedTestAdvancedSettings.defaults;
    if (!mounted) {
      return;
    }

    setState(() {
      _parallelStreamsError = null;
      _latencySampleCountError = null;
      _parallelStreamsController.text = defaults.parallelStreams.toString();
      _latencySampleCountController.text = defaults.latencySampleCount
          .toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final settings = ref.watch(internetSpeedTestSettingsControllerProvider);
    final controller = ref.read(
      internetSpeedTestSettingsControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [TextButton(onPressed: _reset, child: const Text('Reset'))],
      ),
      body: SafeArea(
        child: AppPage(
          children: [
            AppSectionLabel(label: widget.title),
            SizedBox(height: tokens.spacing.compact),
            AppSectionNote(message: widget.subtitle),
            SizedBox(height: tokens.sectionGap),
            const AppSectionLabel(label: 'Download measurements'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message: 'Choose which download stages run during the test.',
            ),
            SizedBox(height: tokens.spacing.regular),
            AppSettingsGroup(
              flat: true,
              children: [
                for (final option in httpDownloadStageOptions)
                  _SelectableSettingsRow(
                    title: option.label,
                    subtitle: 'Run this download measurement stage.',
                    isSelected: settings.http.downloadStageBytes.contains(
                      option.bytes,
                    ),
                    onTap: () => controller.setHttpDownloadStageEnabled(
                      option.bytes,
                      !settings.http.downloadStageBytes.contains(option.bytes),
                    ),
                  ),
              ],
            ),
            SizedBox(height: tokens.sectionGap),
            const AppSectionLabel(label: 'Upload measurements'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message: 'Choose which upload stages run during the test.',
            ),
            SizedBox(height: tokens.spacing.regular),
            AppSettingsGroup(
              flat: true,
              children: [
                for (final option in httpUploadStageOptions)
                  _SelectableSettingsRow(
                    title: option.label,
                    subtitle: 'Run this upload measurement stage.',
                    isSelected: settings.http.uploadStageBytes.contains(
                      option.bytes,
                    ),
                    onTap: () => controller.setHttpUploadStageEnabled(
                      option.bytes,
                      !settings.http.uploadStageBytes.contains(option.bytes),
                    ),
                  ),
              ],
            ),
            SizedBox(height: tokens.sectionGap),
            const AppSectionLabel(label: 'Execution'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message:
                  'Configure how many connections run and how many latency samples are collected.',
            ),
            SizedBox(height: tokens.spacing.regular),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppNumericBox(
                    controller: _parallelStreamsController,
                    label: 'Parallel streams',
                    hintText: '2',
                    errorText: _parallelStreamsError,
                    onChanged: (_) {
                      if (_parallelStreamsError != null) {
                        setState(() {
                          _parallelStreamsError = null;
                        });
                      }
                    },
                    onSubmitted: _saveParallelStreams,
                  ),
                  SizedBox(height: tokens.spacing.regular),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: _saveParallelStreams,
                      child: const Text('Save streams'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.regular),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppNumericBox(
                    controller: _latencySampleCountController,
                    label: 'Latency samples',
                    hintText: '10',
                    errorText: _latencySampleCountError,
                    onChanged: (_) {
                      if (_latencySampleCountError != null) {
                        setState(() {
                          _latencySampleCountError = null;
                        });
                      }
                    },
                    onSubmitted: _saveLatencySampleCount,
                  ),
                  SizedBox(height: tokens.spacing.regular),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: _saveLatencySampleCount,
                      child: const Text('Save samples'),
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

class _MeasurementLabAdvancedSettingsPage extends ConsumerStatefulWidget {
  const _MeasurementLabAdvancedSettingsPage();

  @override
  ConsumerState<_MeasurementLabAdvancedSettingsPage> createState() =>
      _MeasurementLabAdvancedSettingsPageState();
}

class _MeasurementLabAdvancedSettingsPageState
    extends ConsumerState<_MeasurementLabAdvancedSettingsPage> {
  late final TextEditingController _downloadDurationController;
  late final TextEditingController _uploadDurationController;
  late final TextEditingController _latencySampleCountController;
  String? _downloadDurationError;
  String? _uploadDurationError;
  String? _latencySampleCountError;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(internetSpeedTestSettingsControllerProvider);
    _downloadDurationController = TextEditingController(
      text: settings.measurementLab.downloadDurationSeconds.toString(),
    );
    _uploadDurationController = TextEditingController(
      text: settings.measurementLab.uploadDurationSeconds.toString(),
    );
    _latencySampleCountController = TextEditingController(
      text: settings.measurementLab.latencySampleCount.toString(),
    );
  }

  @override
  void dispose() {
    _downloadDurationController.dispose();
    _uploadDurationController.dispose();
    _latencySampleCountController.dispose();
    super.dispose();
  }

  Future<void> _saveDownloadDuration() async {
    final parsed = int.tryParse(_downloadDurationController.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() {
        _downloadDurationError = 'Enter a valid positive number of seconds.';
      });
      return;
    }

    await ref
        .read(internetSpeedTestSettingsControllerProvider.notifier)
        .setMeasurementLabDownloadDurationSeconds(parsed);
    if (!mounted) {
      return;
    }

    setState(() {
      _downloadDurationError = null;
      _downloadDurationController.text = parsed.toString();
    });
  }

  Future<void> _saveUploadDuration() async {
    final parsed = int.tryParse(_uploadDurationController.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() {
        _uploadDurationError = 'Enter a valid positive number of seconds.';
      });
      return;
    }

    await ref
        .read(internetSpeedTestSettingsControllerProvider.notifier)
        .setMeasurementLabUploadDurationSeconds(parsed);
    if (!mounted) {
      return;
    }

    setState(() {
      _uploadDurationError = null;
      _uploadDurationController.text = parsed.toString();
    });
  }

  Future<void> _saveLatencySampleCount() async {
    final parsed = int.tryParse(_latencySampleCountController.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() {
        _latencySampleCountError =
            'Enter a valid positive number of RTT samples.';
      });
      return;
    }

    await ref
        .read(internetSpeedTestSettingsControllerProvider.notifier)
        .setMeasurementLabLatencySampleCount(parsed);
    if (!mounted) {
      return;
    }

    setState(() {
      _latencySampleCountError = null;
      _latencySampleCountController.text = parsed.toString();
    });
  }

  Future<void> _reset() async {
    await ref
        .read(internetSpeedTestSettingsControllerProvider.notifier)
        .resetMeasurementLabAdvancedSettings();
    final defaults = MeasurementLabAdvancedSettings.defaults;
    if (!mounted) {
      return;
    }

    setState(() {
      _downloadDurationError = null;
      _uploadDurationError = null;
      _latencySampleCountError = null;
      _downloadDurationController.text = defaults.downloadDurationSeconds
          .toString();
      _uploadDurationController.text = defaults.uploadDurationSeconds
          .toString();
      _latencySampleCountController.text = defaults.latencySampleCount
          .toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Measurement Lab'),
        actions: [TextButton(onPressed: _reset, child: const Text('Reset'))],
      ),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionLabel(label: 'Advanced options'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message:
                  'Tune the Measurement Lab download/upload durations and telemetry sample window.',
            ),
            SizedBox(height: tokens.sectionGap),
            const AppSectionLabel(label: 'Download duration'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message: 'Choose how long the NDT7 download phase should run.',
            ),
            SizedBox(height: tokens.spacing.regular),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppNumericBox(
                    controller: _downloadDurationController,
                    label: 'Download duration (seconds)',
                    hintText: '15',
                    errorText: _downloadDurationError,
                    onChanged: (_) {
                      if (_downloadDurationError != null) {
                        setState(() {
                          _downloadDurationError = null;
                        });
                      }
                    },
                    onSubmitted: _saveDownloadDuration,
                  ),
                  SizedBox(height: tokens.spacing.regular),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: _saveDownloadDuration,
                      child: const Text('Save download duration'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.sectionGap),
            const AppSectionLabel(label: 'Upload duration'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message: 'Choose how long the NDT7 upload phase should run.',
            ),
            SizedBox(height: tokens.spacing.regular),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppNumericBox(
                    controller: _uploadDurationController,
                    label: 'Upload duration (seconds)',
                    hintText: '10',
                    errorText: _uploadDurationError,
                    onChanged: (_) {
                      if (_uploadDurationError != null) {
                        setState(() {
                          _uploadDurationError = null;
                        });
                      }
                    },
                    onSubmitted: _saveUploadDuration,
                  ),
                  SizedBox(height: tokens.spacing.regular),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: _saveUploadDuration,
                      child: const Text('Save upload duration'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.sectionGap),
            const AppSectionLabel(label: 'Latency telemetry'),
            SizedBox(height: tokens.spacing.compact),
            const AppSectionNote(
              message:
                  'Choose how many recent RTT samples are used when summarizing Measurement Lab latency.',
            ),
            SizedBox(height: tokens.spacing.regular),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppNumericBox(
                    controller: _latencySampleCountController,
                    label: 'RTT samples',
                    hintText: '10',
                    errorText: _latencySampleCountError,
                    onChanged: (_) {
                      if (_latencySampleCountError != null) {
                        setState(() {
                          _latencySampleCountError = null;
                        });
                      }
                    },
                    onSubmitted: _saveLatencySampleCount,
                  ),
                  SizedBox(height: tokens.spacing.regular),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: _saveLatencySampleCount,
                      child: const Text('Save samples'),
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
      appBar: AppBar(title: const Text('Server')),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionHeader(
              title: 'Connection',
              subtitle:
                  'Review the active WHM server and switch to a different one.',
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
              subtitle:
                  'This is the active site for measurement capture and uploads.',
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
                    _SelectableSettingsRow(
                      title: site.name,
                      subtitle: site.description?.isNotEmpty == true
                          ? site.description!
                          : site.slug,
                      isSelected:
                          hasValidSelection && selectedSiteSlug == site.slug,
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

class _SelectableSettingsRow extends StatelessWidget {
  const _SelectableSettingsRow({
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

class _BackendSettingsRow extends StatelessWidget {
  const _BackendSettingsRow({
    required this.title,
    required this.isSelected,
    required this.onSelect,
    required this.onTap,
    this.onOpenAdvanced,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onTap;
  final VoidCallback? onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = AppTokens.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.cardPadding,
        vertical: tokens.spacing.compact,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            child: Padding(
              padding: EdgeInsets.only(
                right: tokens.spacing.regular,
                top: tokens.spacing.compact / 2,
                bottom: tokens.spacing.compact / 2,
              ),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? colorScheme.primary : colorScheme.outline,
                size: tokens.iconMedium + 2,
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: tokens.spacing.compact / 2,
                    horizontal: tokens.spacing.compact / 2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title, style: textTheme.titleMedium),
                      ),
                      SizedBox(width: tokens.spacing.compact),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onOpenAdvanced != null) ...[
            SizedBox(width: tokens.spacing.compact),
            Container(width: 1, height: 24, color: colorScheme.outlineVariant),
            SizedBox(width: tokens.spacing.compact / 2),
            IconButton(
              onPressed: onOpenAdvanced,
              tooltip: 'Advanced options',
              icon: Icon(Icons.settings_outlined, color: colorScheme.outline),
              splashRadius: 18,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
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
  const _MissingSelectedSiteView({required this.onOpenSettings});

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
