import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/app/platform_route.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';
import 'package:mobile/src/core/ui/app_widgets.dart';
import 'package:mobile/src/features/app_shell/site_shell_page.dart';
import 'package:mobile/src/features/measurements/internet_speed_test_settings_controller.dart';
import 'package:mobile/src/features/measurements/local_measurement_settings_controller.dart';
import 'package:mobile/src/features/measurements/measurement_scope_controller.dart';
import 'package:mobile/src/features/measurements/measurement_setup_controller.dart';
import 'package:mobile/src/storage/app_preferences.dart';

class MeasurementSetupPage extends ConsumerWidget {
  const MeasurementSetupPage({super.key, required this.selectedSiteSlug});

  final String selectedSiteSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final scope = ref.watch(measurementScopeControllerProvider);
    final setupStatus = ref.watch(measurementSetupStatusProvider);
    final internetSettings = ref.watch(
      internetSpeedTestSettingsControllerProvider,
    );
    final localSettings = ref.watch(localMeasurementSettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Measurement setup')),
      body: SafeArea(
        child: AppPage(
          children: [
            const AppSectionHeader(
              title: 'Finish measurement setup',
              subtitle:
                  'Choose which measurements this device runs, then configure the required backends before continuing.',
            ),
            SizedBox(height: tokens.sectionGap),
            AppBanner(
              icon: Icons.checklist_rtl_rounded,
              message:
                  'Complete the items below before starting measurements for this device.',
            ),
            SizedBox(height: tokens.sectionGap),
            _SetupCard(
              title: 'Measurement mode',
              subtitle: _scopeLabel(scope),
              isComplete: true,
              actionLabel: 'Choose',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MeasurementModeSettingsPage(),
                  ),
                );
              },
            ),
            if (setupStatus.requiresInternet) ...[
              SizedBox(height: tokens.spacing.compact),
              _SetupCard(
                title: 'Internet measurements',
                subtitle: setupStatus.internetConfigured
                    ? internetSettings.backendLabel
                    : 'Choose an internet backend.',
                isComplete: setupStatus.internetConfigured,
                actionLabel: 'Configure',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const InternetSettingsPage(),
                    ),
                  );
                },
              ),
            ],
            if (setupStatus.requiresLocal) ...[
              SizedBox(height: tokens.spacing.compact),
              _SetupCard(
                title: 'Local measurements',
                subtitle: _localSetupSummary(localSettings),
                isComplete: setupStatus.localConfigured,
                actionLabel: 'Configure',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LocalMeasurementsSettingsPage(),
                    ),
                  );
                },
              ),
            ],
            SizedBox(height: tokens.sectionGap),
            FilledButton(
              onPressed: setupStatus.isComplete
                  ? () {
                      Navigator.of(context).pushReplacement(
                        platformPageRoute<void>(
                          SiteShellPage(selectedSiteSlug: selectedSiteSlug),
                          settings: const RouteSettings(
                            name: siteShellRouteName,
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

String _scopeLabel(MeasurementScopePreference scope) {
  return switch (scope) {
    MeasurementScopePreference.internetOnly => 'Internet only',
    MeasurementScopePreference.localOnly => 'Local only',
    MeasurementScopePreference.internetAndLocal => 'Internet and local',
  };
}

String _localSetupSummary(LocalMeasurementSettings settings) {
  if (!settings.hasServerConfigured) {
    return 'Configure iPerf3.';
  }

  if (settings.modes.enabledCount == 0) {
    return 'Configure iPerf3.';
  }

  return 'iPerf3';
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.title,
    required this.subtitle,
    required this.isComplete,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isComplete;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isComplete
                    ? Icons.check_circle_outline_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isComplete
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: tokens.spacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: tokens.spacing.compact),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.regular),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(onPressed: onTap, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}
