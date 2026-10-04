import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double opacity;
  final double blur;
  final Color? tintColor;
  final bool darkMode;
  final Border? border;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.opacity = 1.0,
    this.blur = 0.0,
    this.tintColor,
    this.darkMode = false,
    this.border,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(16);
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tintColor ?? Colors.white,
        borderRadius: effectiveRadius,
        border: border ?? Border.all(color: AppTheme.borderLight, width: 1),
        boxShadow: AppTheme.softShadow,
      ),
      child: child,
    );
  }
}
