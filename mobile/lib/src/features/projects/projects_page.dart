import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/core/material_spacing.dart';
import 'package:mobile/src/features/connect/server_connection_controller.dart';
import 'package:mobile/src/models/project_summary.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(serverConnectionControllerProvider);
    final controller = ref.read(serverConnectionControllerProvider.notifier);
    final spacing = MaterialSpacing.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available projects'),
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
                if (connectionState.projects.isEmpty)
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(spacing.regular),
                      child: const Text('No projects are available on this server.'),
                    ),
                  )
                else
                  ...connectionState.projects.map(
                    (project) => Padding(
                      padding: EdgeInsets.only(bottom: spacing.compact),
                      child: _ProjectTile(
                        project: project,
                        isSelected: connectionState.selectedProjectSlug == project.slug,
                        onSelect: () => controller.selectProject(project.slug),
                      ),
                    ),
                  ),
                SizedBox(height: spacing.regular),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Change server'),
                ),
                if (connectionState.selectedProjectSlug != null) ...[
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
                              'Selected project: ${connectionState.selectedProjectSlug}',
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

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.isSelected,
    required this.onSelect,
  });

  final ProjectSummary project;
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
        title: Text(project.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(project.slug, style: textTheme.bodySmall),
            if (project.description != null && project.description!.isNotEmpty) ...[
              SizedBox(height: spacing.compact / 2),
              Text(project.description!),
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
