import 'package:flutter/material.dart';

class MaterialSpacing {
  const MaterialSpacing._({
    required this.compact,
    required this.regular,
    required this.comfortable,
    required this.contentMaxWidth,
  });

  final double compact;
  final double regular;
  final double comfortable;
  final double contentMaxWidth;

  static MaterialSpacing of(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final baseDimension = kMinInteractiveDimension * textScale;

    return MaterialSpacing._(
      compact: baseDimension / 4,
      regular: baseDimension / 2,
      comfortable: (baseDimension * 3) / 4,
      contentMaxWidth: baseDimension * 10,
    );
  }
}
