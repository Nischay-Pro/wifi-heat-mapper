import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/src/core/loading_indicator.dart';
import 'package:mobile/src/core/ui/app_tokens.dart';

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.children, this.maxWidth});

  final List<Widget> children;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? tokens.spacing.contentMaxWidth,
        ),
        child: ListView(
          padding: EdgeInsets.all(tokens.pagePadding),
          children: children,
        ),
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineMedium),
              SizedBox(height: tokens.spacing.compact),
              Text(
                subtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: tokens.spacing.compact),
          trailing!,
        ],
      ],
    );
  }
}

class AppPanel extends StatelessWidget {
  const AppPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? EdgeInsets.all(tokens.cardPadding),
        child: child,
      ),
    );
  }
}

class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.icon,
    required this.message,
    this.iconColor,
  });

  final IconData icon;
  final String message;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return AppPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          SizedBox(width: tokens.spacing.compact),
          Expanded(child: Text(message, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class AppMetricTile extends StatelessWidget {
  const AppMetricTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.metricMinHeight),
      child: AppPanel(
        padding: EdgeInsets.all(tokens.spacing.compact),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: textTheme.labelMedium),
            SizedBox(height: tokens.spacing.compact / 2),
            Text(value, style: textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class AppInfoRow extends StatelessWidget {
  const AppInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.compact),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(label, style: textTheme.labelMedium),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class AppBusyIconButton extends StatelessWidget {
  const AppBusyIconButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    required this.isBusy,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: isBusy ? null : onPressed,
      tooltip: tooltip,
      icon: isBusy ? const LoadingIndicator.small() : Icon(icon),
    );
  }
}

class AppSettingsGroup extends StatelessWidget {
  const AppSettingsGroup({
    super.key,
    required this.children,
    this.flat = false,
  });

  final List<Widget> children;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    final group = Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1)
            Divider(
              height: 1,
              indent: tokens.cardPadding,
              endIndent: tokens.cardPadding,
            ),
        ],
      ],
    );

    if (flat) {
      return group;
    }

    return AppPanel(
      padding: EdgeInsets.zero,
      child: group,
    );
  }
}

class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Text(
      label,
      style: textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class AppSectionNote extends StatelessWidget {
  const AppSectionNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Text(
      message,
      style: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class AppSettingsRow extends StatelessWidget {
  const AppSettingsRow({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.onTap,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = AppTokens.of(context);

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: icon == null ? 0 : null,
      leading: icon == null
          ? null
          : Icon(
              icon,
              color: colorScheme.primary,
              size: tokens.iconMedium + 2,
            ),
      title: Text(title, style: textTheme.titleMedium),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class AppNumericBox extends StatelessWidget {
  const AppNumericBox({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(24);

    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted?.call(),
      onEditingComplete: onSubmitted,
    );
  }
}
