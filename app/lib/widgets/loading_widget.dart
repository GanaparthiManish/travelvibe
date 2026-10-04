import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import 'travel_top_logo.dart';

class LoadingWidget extends StatelessWidget {
  final String message;

  const LoadingWidget({
    super.key,
    this.message = 'Loading TravelTop...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Ripple pulse background
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.skyBlue,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.8, 1.8),
                    duration: 1500.ms,
                  )
                  .fade(begin: 0.4, end: 0, duration: 1500.ms),

              // Central Logo
              const TravelTopLogo(size: 80),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.charcoalText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .fade(begin: 0.6, end: 1.0, duration: 1000.ms),
        ],
      ),
    );
  }
}
