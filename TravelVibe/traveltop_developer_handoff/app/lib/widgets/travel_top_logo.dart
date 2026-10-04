import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

class TravelTopLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const TravelTopLogo({
    super.key,
    this.size = 80.0,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.coralGold,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: AppTheme.textDark, width: size * 0.05),
        boxShadow: showShadow ? AppTheme.stickerShadow : null,
      ),
      child: Center(
        child: Icon(
          LucideIcons.compass,
          color: AppTheme.textDark,
          size: size * 0.55,
        ),
      ),
    );
  }
}
