import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_route.dart';
import 'package:mobile/src/core/app_messages.dart';
import 'package:mobile/src/core/loading_indicator.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/app_shell/site_shell_page.dart';
import 'package:mobile/src/features/connect/server_connect_page.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/measurements/measurement_setup_controller.dart';
import 'package:mobile/src/features/measurements/measurement_setup_page.dart';
import 'package:mobile/src/features/permissions/wifi_permission_models.dart';
import 'package:mobile/src/features/permissions/wifi_permission_service.dart';
import 'package:mobile/src/features/sites/sites_page.dart';

class WifiPermissionsPage extends ConsumerStatefulWidget {
  const WifiPermissionsPage({super.key});

  @override
  ConsumerState<WifiPermissionsPage> createState() =>
      _WifiPermissionsPageState();
}

class _WifiPermissionsPageState extends ConsumerState<WifiPermissionsPage>
    with WidgetsBindingObserver {
  List<WifiPermissionRequirement> _requirements = const [];
  bool _isLoading = true;
  bool _isActing = false;
  Timer? _pollTimer;
  bool _isPolling = false;
  bool _isNavigatingToShell = false;
  bool _isNavigatingAway = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshRequirements();
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
      _refreshRequirements();
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
    if (_isPolling || _isNavigatingToShell || _isNavigatingAway) {
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

  Future<void> _refreshRequirements() async {
    if (_isNavigatingToShell) {
      return;
    }

    final service = ref.read(wifiPermissionServiceProvider);
    final requirements = await service.loadRequirements();
    final connectionState = ref.read(serverConnectionControllerProvider);
    final allGranted = requirements.every(
      (requirement) => requirement.isGranted,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _requirements = requirements;
      _isLoading = false;
      _isActing = false;
    });

    if (allGranted && connectionState.selectedSiteSlug != null) {
      final setupStatus = ref.read(measurementSetupStatusProvider);
      _isNavigatingToShell = true;
      _stopPolling();
      await Navigator.of(context).pushReplacement(
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
    }
  }

  Future<void> _completeAction(WifiPermissionRequirement requirement) async {
    final service = ref.read(wifiPermissionServiceProvider);

    setState(() {
      _isActing = true;
    });

    await service.completeAction(requirement);
    await _refreshRequirements();
  }

  @override
  Widget build(BuildContext context) {
    return WifiPermissionsView(
      requirements: _requirements,
      isLoading: _isLoading,
      isRefreshing: _isActing,
      onRefresh: _refreshRequirements,
      onCompleteAction: _completeAction,
    );
  }
}

class WifiPermissionsView extends StatelessWidget {
  const WifiPermissionsView({
    super.key,
    required this.requirements,
    required this.isLoading,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onCompleteAction,
  });

  final List<WifiPermissionRequirement> requirements;
  final bool isLoading;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final Future<void> Function(WifiPermissionRequirement requirement)
  onCompleteAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final grantedCount = requirements
        .where((requirement) => requirement.isGranted)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi permissions'),
        actions: [
          AppBusyIconButton(
            onPressed: () {
              onRefresh();
            },
            tooltip: 'Refresh permission status',
            icon: Icons.refresh,
            isBusy: isRefreshing,
          ),
        ],
      ),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionHeader(
              title: 'Review device access',
              subtitle:
                  'Grant the permissions needed to read Wi-Fi metadata before starting measurements.',
            ),
            SizedBox(height: tokens.sectionGap),
            AppBanner(
              icon: Icons.shield_outlined,
              message: isLoading
                  ? 'Checking the current permission state...'
                  : '$grantedCount of ${requirements.length} Wi-Fi requirements are met.',
            ),
            SizedBox(height: tokens.sectionGap),
            if (isLoading)
              const Center(child: LoadingIndicator.medium())
            else
              ...requirements.map(
                (requirement) => Padding(
                  padding: EdgeInsets.only(bottom: tokens.spacing.compact),
                  child: _PermissionRequirementCard(
                    requirement: requirement,
                    onCompleteAction: onCompleteAction,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRequirementCard extends StatelessWidget {
  const _PermissionRequirementCard({
    required this.requirement,
    required this.onCompleteAction,
  });

  final WifiPermissionRequirement requirement;
  final Future<void> Function(WifiPermissionRequirement requirement)
  onCompleteAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                requirement.isGranted
                    ? Icons.check_circle
                    : Icons.shield_outlined,
                color: requirement.isGranted
                    ? colorScheme.primary
                    : colorScheme.error,
              ),
              SizedBox(width: tokens.spacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(requirement.title, style: textTheme.titleMedium),
                    SizedBox(height: tokens.spacing.compact / 2),
                    Text(requirement.summary, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          if (requirement.actionKind != null &&
              requirement.actionLabel != null) ...[
            SizedBox(height: tokens.spacing.regular),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => onCompleteAction(requirement),
                child: Text(requirement.actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
