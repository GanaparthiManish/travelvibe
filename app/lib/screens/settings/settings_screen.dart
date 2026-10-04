import '../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_network_image.dart';
import '../../providers/app_state_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _error;

  bool _notifications = true;
  bool _darkMode = false;
  bool _locationAccess = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // 1. Fetch user profile
        final profileRes = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        // 2. Fetch user preferences
        final prefRes = await _supabase
            .from('user_preferences')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (prefRes != null) {
          _notifications = prefRes['push_notifications'] ?? true;
          _darkMode = prefRes['dark_theme'] ?? false;
          _locationAccess = prefRes['location_services'] ?? true;
        } else {
          // Initialize default preference record if missing
          try {
            await _supabase.from('user_preferences').upsert({
              'id': user.id,
              'push_notifications': true,
              'dark_theme': false,
              'location_services': true,
            });
          } catch (_) {
            // Ignore insert errors if table isn't created yet locally
          }
        }

        _profileData = profileRes;

        if (mounted) {
          context.read<AppStateProvider>().setThemeMode(
                _darkMode ? ThemeMode.dark : ThemeMode.light,
              );
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _error = 'Failed to load user preferences. Tap to retry.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePreference(String key, bool newValue) async {
    final prevNotifications = _notifications;
    final prevDarkMode = _darkMode;
    final prevLocation = _locationAccess;

    setState(() {
      if (key == 'push_notifications') _notifications = newValue;
      if (key == 'dark_theme') _darkMode = newValue;
      if (key == 'location_services') _locationAccess = newValue;
    });

    // Handle immediate side-effects
    if (key == 'dark_theme') {
      context.read<AppStateProvider>().setThemeMode(
            newValue ? ThemeMode.dark : ThemeMode.light,
          );
    } else if (key == 'location_services' && newValue) {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        setState(() => _locationAccess = false);
        newValue = false;
      }
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('user_preferences').upsert({
          'id': user.id,
          'push_notifications': _notifications,
          'dark_theme': _darkMode,
          'location_services': _locationAccess,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error saving preference: $e');
      if (mounted) {
        // Revert switch state on error
        setState(() {
          _notifications = prevNotifications;
          _darkMode = prevDarkMode;
          _locationAccess = prevLocation;
        });
        if (key == 'dark_theme') {
          context.read<AppStateProvider>().setThemeMode(
                prevDarkMode ? ThemeMode.dark : ThemeMode.light,
              );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save — check connection"),
            backgroundColor: AppTheme.coral,
          ),
        );
      }
    }
  }

  Future<void> _navigateToEditProfile() async {
    final updated = await Navigator.pushNamed(context, '/edit_traveller_profile');
    if (updated == true) {
      _loadInitialData();
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of TravelTop?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.greyText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mutedRed,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _supabase.auth.signOut();
              if (context.mounted) {
                context.read<AppStateProvider>().clearCart();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out', style: TextStyle(color: AppTheme.textDark)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                if (_error != null) _buildErrorBanner(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileSection(),
                        const SizedBox(height: 24),
                        _buildSectionHeader('App Preferences'),
                        const SizedBox(height: 10),
                        _buildSwitchTile(
                          icon: Icons.notifications_none_outlined,
                          title: 'Push Notifications',
                          value: _notifications,
                          onChanged: (val) => _togglePreference('push_notifications', val),
                        ),
                        _buildSwitchTile(
                          icon: Icons.dark_mode_outlined,
                          title: 'Dark Theme (Beta)',
                          value: _darkMode,
                          onChanged: (val) => _togglePreference('dark_theme', val),
                        ),
                        _buildSwitchTile(
                          icon: Icons.location_on_outlined,
                          title: 'Location Services',
                          value: _locationAccess,
                          onChanged: (val) => _togglePreference('location_services', val),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Account & Security'),
                        const SizedBox(height: 10),
                        _buildActionTile(
                          icon: Icons.person_outline,
                          title: 'Edit Profile',
                          onTap: _navigateToEditProfile,
                        ),
                        _buildActionTile(
                          icon: Icons.shield_outlined,
                          title: 'Privacy Policy',
                          onTap: () => Navigator.pushNamed(context, '/privacy_policy'),
                        ),
                        _buildActionTile(
                          icon: Icons.help_outline,
                          title: 'Help & Support',
                          onTap: () => Navigator.pushNamed(context, '/help_support'),
                        ),
                        const SizedBox(height: 24),
                        _buildLogoutTile(context),
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
                  child: const Icon(Icons.arrow_back, color: AppTheme.textDark, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Settings & Account',
            style: TextStyle(
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

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.coral.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.textDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppTheme.textDark, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _loadInitialData,
            child: const Text('Retry', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    if (_isLoading) {
      return _buildProfileSkeleton();
    }

    final user = _supabase.auth.currentUser;
    final String? profileName = _profileData?['full_name'];
    final String? metaName = user?.userMetadata?['full_name'];
    final String fullName = (profileName != null && profileName.trim().isNotEmpty)
        ? profileName.trim()
        : ((metaName != null && metaName.trim().isNotEmpty)
            ? metaName.trim()
            : (user?.email != null && user!.email!.contains('@')
                ? user.email!.split('@').first
                : 'Alex Traveler'));

    final String email = (user?.email != null && user!.email!.isNotEmpty)
        ? user.email!
        : (_profileData?['email'] ?? 'alex.traveler@example.com');
    final photoUrl = _profileData?['photo_url'];

    final initials = fullName.isNotEmpty
        ? fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
        : 'AT';

    return GestureDetector(
      onTap: _navigateToEditProfile,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? AppNetworkImage(
                      imageUrl: photoUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: AppTheme.oceanTeal,
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: AppTheme.textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Color(0x44000000), blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.75), fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.oceanTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit_outlined, color: AppTheme.oceanTeal, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSkeleton() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 180,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        color: isDark ? AppTheme.warmPaper : AppTheme.inkNavy,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.oceanTeal, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.charcoalText,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: AppTheme.coralGold,
              onChanged: _isLoading ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.oceanTeal, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.charcoalText,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.greyText, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleLogout(context),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: AppTheme.mutedRed, size: 20),
            SizedBox(width: 10),
            Text(
              'Log Out of TravelTop',
              style: TextStyle(
                color: AppTheme.mutedRed,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
