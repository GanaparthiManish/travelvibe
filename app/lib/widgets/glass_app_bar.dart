import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;

  const GlassBackButton({
    super.key,
    this.onTap,
    this.icon = Icons.arrow_back,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.maybePop(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.borderLight, width: 1),
          boxShadow: AppTheme.softShadow,
        ),
        child: Icon(
          icon,
          size: 20,
          color: AppTheme.textDark,
        ),
      ),
    );
  }
}
