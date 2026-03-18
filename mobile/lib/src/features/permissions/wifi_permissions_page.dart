import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_route.dart';
import 'package:mobile/src/core/material_spacing.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/features/measurements/measurements_page.dart';
import 'package:mobile/src/features/permissions/wifi_permission_models.dart';
import 'package:mobile/src/features/permissions/wifi_permission_service.dart';

class WifiPermissionsPage extends ConsumerStatefulWidget {
  const WifiPermissionsPage({super.key});

  @override
  ConsumerState<WifiPermissionsPage> createState() => _WifiPermissionsPageState();
}

class _WifiPermissionsPageState extends ConsumerState<WifiPermissionsPage>
    with WidgetsBindingObserver {
  List<WifiPermissionRequirement> _requirements = const [];
  bool _isLoading = true;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshRequirements();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRequirements();
    }
  }

  Future<void> _refreshRequirements() async {
    final service = ref.read(wifiPermissionServiceProvider);
    final requirements = await service.loadRequirements();
    final connectionState = ref.read(serverConnectionControllerProvider);
    final allGranted = requirements.every((requirement) => requirement.isGranted);

    if (!mounted) {
      return;
    }

    setState(() {
      _requirements = requirements;
      _isLoading = false;
      _isActing = false;
    });

    if (allGranted && connectionState.selectedSiteSlug != null) {
      await Navigator.of(context).pushReplacement(
        platformPageRoute<void>(
          MeasurementsPage(selectedSiteSlug: connectionState.selectedSiteSlug!),
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
  final Future<void> Function(WifiPermissionRequirement requirement) onCompleteAction;

  @override
  Widget build(BuildContext context) {
    final spacing = MaterialSpacing.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final grantedCount = requirements.where((requirement) => requirement.isGranted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi permissions'),
        actions: [
          IconButton(
            onPressed: isRefreshing ? null : onRefresh,
            tooltip: 'Refresh permission status',
            icon: isRefreshing
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
                Text('Review device access', style: textTheme.headlineMedium),
                SizedBox(height: spacing.compact),
                Text(
                  'Grant the permissions needed to read Wi-Fi metadata before starting measurements.',
                  style: textTheme.bodyMedium,
                ),
                SizedBox(height: spacing.regular),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.regular),
                    child: Text(
                      isLoading
                          ? 'Checking the current permission state...'
                          : '$grantedCount of ${requirements.length} Wi-Fi requirements are met.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),
                SizedBox(height: spacing.regular),
                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator.adaptive(),
                  )
                else
                  ...requirements.map(
                    (requirement) => Padding(
                      padding: EdgeInsets.only(bottom: spacing.compact),
                      child: _PermissionRequirementCard(
                        requirement: requirement,
                        onCompleteAction: onCompleteAction,
                      ),
                    ),
                  ),
                SizedBox(height: spacing.regular),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(spacing.regular),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.primary,
                        ),
                        SizedBox(width: spacing.compact),
                        Expanded(
                          child: Text(
                            'If the app sends you to system settings, come back here after changing it. This screen refreshes its status when the app resumes.',
                            style: textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
  final Future<void> Function(WifiPermissionRequirement requirement) onCompleteAction;

  @override
  Widget build(BuildContext context) {
    final spacing = MaterialSpacing.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.regular),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  requirement.isGranted ? Icons.check_circle : Icons.shield_outlined,
                  color: requirement.isGranted ? colorScheme.primary : colorScheme.error,
                ),
                SizedBox(width: spacing.compact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(requirement.title, style: textTheme.titleMedium),
                      SizedBox(height: spacing.compact / 2),
                      Text(requirement.summary, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            if (requirement.actionKind != null && requirement.actionLabel != null) ...[
              SizedBox(height: spacing.regular),
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
      ),
    );
  }
}
