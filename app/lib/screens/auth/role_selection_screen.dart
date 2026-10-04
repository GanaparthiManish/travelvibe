import '../../widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/travel_top_logo.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const TravelTopLogo(size: 80),
                  const SizedBox(height: 16),
                  Text(
                    'Choose Your Role',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppTheme.textDark,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select how you would like to use TravelTop',
                    style: TextStyle(
                      color: AppTheme.textDark.withValues(alpha: 0.9),
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),

                  // Traveller Role Card
                  _buildRoleCard(
                    roleId: 'traveller',
                    title: 'I am a Traveller',
                    subtitle: 'Discover destination packages, hire expert guides, and book seamless trips.',
                    icon: LucideIcons.compass,
                  ).animate().slideX(begin: -0.5, end: 0, duration: 500.ms),

                  const SizedBox(height: 20),

                  // Agent Role Card
                  _buildRoleCard(
                    roleId: 'agent',
                    title: 'I am a Travel Agent',
                    subtitle: 'Manage client itineraries, set your daily availability, and accept tour bookings.',
                    icon: LucideIcons.briefcase,
                  ).animate().slideX(begin: 0.5, end: 0, duration: 500.ms),

                  const Spacer(),

                  // Continue Button
                  GradientButton(
                    text: 'CONTINUE',
                    style: GradientButtonStyle.primaryCoral,
                    onPressed: _selectedRole == null
                        ? () {}
                        : () {
                            if (_selectedRole == 'traveller') {
                              Navigator.pushReplacementNamed(context, '/traveller_home');
                            } else {
                              Navigator.pushReplacementNamed(context, '/agent_dashboard');
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String roleId,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == roleId;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = roleId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: GlassCard(
          opacity: isSelected ? 0.95 : 0.85,
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.coralGold : AppTheme.oceanTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected ? Colors.white : AppTheme.oceanTeal,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.charcoalText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.greyText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 12),
                const Icon(
                  LucideIcons.checkCircle2,
                  color: AppTheme.coralGold,
                  size: 28,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
