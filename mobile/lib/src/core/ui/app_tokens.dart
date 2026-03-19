import 'package:flutter/material.dart';
import 'package:mobile/src/core/material_spacing.dart';

class AppTokens {
  const AppTokens._({
    required this.spacing,
    required this.pagePadding,
    required this.sectionGap,
    required this.cardPadding,
    required this.radiusLarge,
    required this.radiusMedium,
    required this.radiusSmall,
    required this.iconSmall,
    required this.iconMedium,
    required this.metricMinHeight,
  });

  final MaterialSpacing spacing;
  final double pagePadding;
  final double sectionGap;
  final double cardPadding;
  final double radiusLarge;
  final double radiusMedium;
  final double radiusSmall;
  final double iconSmall;
  final double iconMedium;
  final double metricMinHeight;

  static AppTokens of(BuildContext context) {
    final spacing = MaterialSpacing.of(context);
    return AppTokens._(
      spacing: spacing,
      pagePadding: spacing.regular,
      sectionGap: spacing.regular,
      cardPadding: spacing.regular,
      radiusLarge: 24,
      radiusMedium: 18,
      radiusSmall: 14,
      iconSmall: 18,
      iconMedium: 22,
      metricMinHeight: 76,
    );
  }
}
