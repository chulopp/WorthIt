import 'package:flutter/material.dart';

/// A reusable pull-to-refresh widget with WorthIt brand colors.
class WorthItRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const WorthItRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF304423),
      backgroundColor: Colors.white,
      child: child,
    );
  }
}
