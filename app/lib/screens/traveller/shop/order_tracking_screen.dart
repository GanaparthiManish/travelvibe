import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'title': 'Order Placed', 'time': 'Today, 2:30 PM', 'done': true},
      {'title': 'Packed & Dispatched', 'time': 'Today, 4:15 PM', 'done': true},
      {'title': 'Shipped via BlueDart', 'time': 'In Transit', 'done': true},
      {'title': 'Out for Delivery', 'time': 'Expected Tomorrow', 'done': false},
      {'title': 'Delivered', 'time': 'Pending', 'done': false},
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderHeaderCard(),
                        const SizedBox(height: 20),
                        _buildTrackingStepperCard(steps),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.textDark.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.textDark.withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: Icon(LucideIcons.arrowLeft, color: AppTheme.textDark, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Order Tracking',
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Color(0x55000000), blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHeaderCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order #TT-9824', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.charcoalText)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.oceanTeal.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Text('IN TRANSIT', style: TextStyle(color: AppTheme.oceanTeal, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Estimated Delivery: Tomorrow by 5:00 PM', style: TextStyle(color: AppTheme.greyText, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTrackingStepperCard(List<Map<String, dynamic>> steps) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery Timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.charcoalText)),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isDone = step['done'] as bool;
            final isLast = index == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDone ? AppTheme.softGreen : AppTheme.sandBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDone ? AppTheme.softGreen : Colors.grey[400]!, width: 2),
                      ),
                      child: isDone ? const Icon(LucideIcons.check, size: 14, color: AppTheme.textDark) : null,
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 36,
                        color: isDone ? AppTheme.softGreen : Colors.grey[300],
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step['title'], style: TextStyle(fontWeight: isDone ? FontWeight.w800 : FontWeight.w600, color: AppTheme.charcoalText, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(step['time'], style: const TextStyle(color: AppTheme.greyText, fontSize: 12)),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
