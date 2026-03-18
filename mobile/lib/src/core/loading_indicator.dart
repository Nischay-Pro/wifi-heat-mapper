import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator.small({
    super.key,
  }) : _dimension = 18,
       _strokeWidth = 2;

  const LoadingIndicator.medium({
    super.key,
  }) : _dimension = 24,
       _strokeWidth = 2.5;

  final double _dimension;
  final double _strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _dimension,
      child: CircularProgressIndicator.adaptive(strokeWidth: _strokeWidth),
    );
  }
}
