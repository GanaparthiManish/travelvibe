import '../../../widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_network_image.dart';

class TravellerProfileScreen extends StatelessWidget {
  const TravellerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Account Shortcuts'),
                  const SizedBox(height: 12),
                  _buildShortcutCard(context, LucideIcons.calendar, 'My Bookings & Trips', '/my_bookings'),
                  _buildShortcutCard(context, LucideIcons.heart, 'Wishlist & Saved Destinations', '/wishlist'),
                  _buildShortcutCard(context, LucideIcons.bell, 'Notifications & Alerts', '/notifications'),
                  _buildShortcutCard(context, LucideIcons.helpCircle, 'Help & Support', '/help_support'),
                  _buildShortcutCard(context, LucideIcons.settings, 'Settings & Preferences', '/settings'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: const AppNetworkImage(
                  imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Alex Traveler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.charcoalText)),
                    const SizedBox(height: 2),
                    const Text('alex.traveler@example.com', style: TextStyle(color: AppTheme.greyText, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Member since Jan 2024', style: TextStyle(color: AppTheme.oceanTeal.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralGold,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pushNamed(context, '/edit_traveller_profile'),
            child: const Text('Edit Profile Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatItem('Total Trips', '14')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem('Countries', '6')),
        const SizedBox(width: 12),
        Expanded(child: _buildStatItem('Reviews', '8')),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.oceanTeal)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.greyText, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.w800));
  }

  Widget _buildShortcutCard(BuildContext context, IconData icon, String title, String route) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.oceanTeal, size: 20),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.charcoalText, fontSize: 15))),
              const Icon(LucideIcons.chevronRight, color: AppTheme.greyText, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
