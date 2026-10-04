import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NatureBackground extends StatelessWidget {
  final Widget? child;

  const NatureBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: child,
    );
  }
}
