import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme.dart';
import '../main.dart';
import '../services/data_service.dart';
import '../services/wishlist_service.dart';
import '../services/notification_service.dart';
import '../utils/user_utils.dart';
import 'edit_profile_screen.dart';




import 'settings_screen.dart';
import 'wishlist_screen.dart';
import 'my_orders_screen.dart';
import 'saved_addresses_screen.dart';
import 'notifications_screen.dart';
import 'help_support_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  int _totalTrips = 0;
  int _reviewsGiven = 0;
  bool _loading = true;
  String? _cachedName;
  String? _cachedEmail;
  String? _cachedPhoto;
  RealtimeChannel? _rtChannel;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _fetchProfileAndStats();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _rtChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _subscribeRealtime() async {
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId == null) return;
    try {
      _rtChannel = SupabaseService.client
          .channel('profile_user_rt_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bookings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'traveller_id',
              value: userId,
            ),
            callback: (_) { if (mounted) _fetchProfileAndStats(); },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _cachedName = prefs.getString('user_name');
          _cachedEmail = prefs.getString('user_email');
          _cachedPhoto = prefs.getString('user_photo');
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchProfileAndStats() async {
    final userId = await SupabaseService.resolveActiveUserId();
    final user = SupabaseService.client.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final cachedEmail = prefs.getString('user_email');
    final emailToSearch = user?.email ?? cachedEmail ?? _cachedEmail;

    if ((userId == null || userId.isEmpty) && (emailToSearch == null || emailToSearch.isEmpty)) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final client = SupabaseService.client;
      Map<String, dynamic>? profRes;

      if (userId != null && userId.isNotEmpty) {
        profRes = await client
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .maybeSingle();
      }

      if (profRes == null && emailToSearch != null && emailToSearch.isNotEmpty) {
        profRes = await client
            .from('profiles')
            .select('*')
            .eq('email', emailToSearch)
            .maybeSingle();
      }

      int tripCount = 0;
      int reviewsCount = 0;

      final targetId = userId ?? profRes?['id'] ?? user?.id;
      if (targetId != null) {
        try {
          final bookingsRes = await client
              .from('bookings')
              .select('id')
              .eq('traveller_id', targetId);
          tripCount = (bookingsRes as List? ?? []).length;
        } catch (_) {}

        try {
          final reviewsRes = await client
              .from('reviews')
              .select('id')
              .eq('traveller_id', targetId);
          reviewsCount = (reviewsRes as List? ?? []).length;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _profile = profRes;
          _totalTrips = tripCount;
          _reviewsGiven = reviewsCount;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[PROFILE_SCREEN] Error fetching profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of TravelVibe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: kAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    WishlistService.instance.clearWishlist();
    NotificationService.instance.clearNotifications();
    final prefs = await SharedPreferences.getInstance();

    // IMPORTANT: Only clear session flags — NOT the user's identity data.
    // Keeping user_email, user_name, user_photo in prefs means the profile
    // screen renders instantly on re-login (before Supabase re-fetches).
    await prefs.remove('is_logged_in');
    await prefs.remove('user_id');
    // Keep: user_email, user_name, user_photo, cached_wished_*, cached_app_notifications

    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await SupabaseService.client.auth.signOut();

    if (mounted) {
      setState(() {
        _profile = null;
        // Do NOT clear _cachedName/_cachedEmail/_cachedPhoto here — they are
        // re-loaded from prefs on next initState and make the profile feel instant.
      });
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.client.auth.currentUser;
    final activeEmail = user?.email ?? _profile?['email'] as String? ?? _cachedEmail;
    final isAuthenticated = (user != null || (activeEmail != null && activeEmail.isNotEmpty));

    final fullName = resolveDisplayName(
      profileName: _profile?['full_name'] as String?,
      prefName: _cachedName,
      user: user,
      email: activeEmail,
    );

    final email = activeEmail ?? '—';

    final photoUrl = _profile?['photo_url'] as String? ??
        _cachedPhoto ??
        '';

    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, languageNotifier]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: appBgColor(context),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  tr('profile_account'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: appInkColor(context),
                  ),
                ),
                const SizedBox(height: 20),

                // Profile Card Header
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: appPaperColor(context),
                    border: Border.all(color: appLineColor(context), width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: isAuthenticated
                      ? Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.network(
                                photoUrl.isNotEmpty
                                    ? photoUrl
                                    : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 60,
                                  height: 60,
                                  color: kAccent,
                                  child: Center(
                                    child: Text(
                                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T',
                                      style: const TextStyle(
                                          color: kWhite,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: appInkColor(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: appInkSoftColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: appInkColor(context)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => EditProfileScreen(profile: _profile)),
                                ).then((_) => _fetchProfileAndStats());
                              },
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign in to TravelVibe',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: appInkColor(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sign in to manage your trip bookings, profile settings, and wishlist.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                color: appInkSoftColor(context),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Sign In / Register', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),

                // 2 Stat Cards Row
                Row(
                  children: [
                    ttStatCard(tr('total_trips'), '$_totalTrips'),
                    const SizedBox(width: 8),
                    ttStatCard(tr('reviews'), '$_reviewsGiven'),
                  ],
                ),
                const SizedBox(height: 24),

                // Settings & Quick Links
                ttSectionH(tr('account_settings')),
                _menuTile(
                  context,
                  Icons.settings_outlined,
                  tr('app_settings'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                _menuTile(
                  context,
                  Icons.favorite_border_rounded,
                  tr('my_wishlist'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WishlistScreen()),
                    );
                  },
                ),
                _menuTile(
                  context,
                  Icons.shopping_bag_outlined,
                  tr('my_orders'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
                    );
                  },
                ),
                _menuTile(
                  context,
                  Icons.location_on_outlined,
                  tr('saved_addresses'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
                    );
                  },
                ),
                _menuTile(
                  context,
                  Icons.notifications_outlined,
                  tr('notifications'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    );
                  },
                ),
                _menuTile(
                  context,
                  Icons.help_outline_rounded,
                  tr('help_support'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => HelpSupportScreen()),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Action Button (Sign Out or Sign In)
                if (isAuthenticated)
                  ttOutlineBtn(tr('sign_out'), onTap: _handleLogout, color: const Color(0xFFC0392B))
                else
                  ttOutlineBtn('Sign In', onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }, color: kAccent),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuTile(BuildContext context, IconData icon, String title, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: appPaperColor(context),
          border: Border.all(color: appLineColor(context)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: appInkColor(context), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: appInkColor(context),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: appInkSoftColor(context), size: 20),
          ],
        ),
      ),
    );
  }
}
