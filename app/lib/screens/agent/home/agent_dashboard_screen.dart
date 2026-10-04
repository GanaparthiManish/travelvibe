import '../../../widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120, left: 20, right: 20, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildMetricsRow(context),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Incoming Tour Requests',
                        style: TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/agent_availability'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.coralGold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Manage Dates',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRequestList(context),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFloatingBottomNav(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agent Console',
              style: TextStyle(
                color: AppTheme.textDark.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Wayan Sudarsa',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/agent_profile_edit'),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.coralGold, width: 2),
            ),
            child: const CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/agent_earnings'),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.softGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.dollarSign, color: AppTheme.softGreen, size: 20),
                  ),
                  const SizedBox(height: 12),
                  const Text('Earnings (Oct)', style: TextStyle(color: AppTheme.greyText, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text(
                    '₹42,500',
                    style: TextStyle(color: AppTheme.charcoalText, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/agent_reviews'),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.oceanTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.star_rounded, color: AppTheme.coralGold, size: 20),
                  ),
                  const SizedBox(height: 12),
                  const Text('Rating & Reviews', style: TextStyle(color: AppTheme.greyText, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text(
                    '4.9 (124)',
                    style: TextStyle(color: AppTheme.charcoalText, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestList(BuildContext context) {
    final requests = [
      {'name': 'Alex Traveler', 'dates': 'Oct 15 - Oct 17', 'status': 'Pending', 'amount': '₹7,500', 'route': '/agent_booking_detail'},
      {'name': 'Emma Watson', 'dates': 'Oct 20 - Oct 22', 'status': 'Ongoing', 'amount': '₹7,500', 'route': '/agent_active_trip'},
      {'name': 'David Miller', 'dates': 'Oct 25 - Oct 28', 'status': 'Confirmed', 'amount': '₹10,000', 'route': '/agent_booking_detail'},
    ];

    return Column(
      children: requests.map((req) {
        final isPending = req['status'] == 'Pending';
        final isOngoing = req['status'] == 'Ongoing';

        Color badgeColor = AppTheme.softGreen;
        if (isPending) badgeColor = AppTheme.coralGold;
        if (isOngoing) badgeColor = AppTheme.oceanTeal;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, req['route']!),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        req['name']!,
                        style: const TextStyle(
                          color: AppTheme.charcoalText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          req['status']!,
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.calendar, color: AppTheme.greyText, size: 14),
                          const SizedBox(width: 6),
                          Text(req['dates']!, style: const TextStyle(color: AppTheme.greyText, fontSize: 13)),
                        ],
                      ),
                      Text(
                        req['amount']!,
                        style: const TextStyle(
                          color: AppTheme.oceanTeal,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFloatingBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: AppTheme.textDark.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(36),
        boxShadow: AppTheme.tealGlowShadow,
        border: Border.all(color: AppTheme.textDark.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, LucideIcons.layoutDashboard, 'Console'),
            _buildNavItem(context, 1, LucideIcons.wallet, 'Earnings', route: '/agent_earnings'),
            _buildNavItem(context, 2, LucideIcons.star, 'Reviews', route: '/agent_reviews'),
            _buildNavItem(context, 3, LucideIcons.settings, 'Settings', route: '/agent_settings'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label, {String? route}) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        if (route != null) Navigator.pushNamed(context, route);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.oceanTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.charcoalText.withValues(alpha: 0.6),
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
