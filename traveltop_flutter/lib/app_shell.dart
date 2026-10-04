import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'main.dart';
import 'screens/home_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/profile_screen.dart';
import 'services/data_service.dart';
import 'services/notification_service.dart';
import 'services/wishlist_service.dart';
import 'utils/user_utils.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  RealtimeChannel? _notifChannel;
  final ValueNotifier<int> _unreadCount = ValueNotifier<int>(0);

  final List<Widget> _screens = const [
    HomeScreen(),
    DiscoverScreen(),
    ShopScreen(),
    BookingScreen(),
    ProfileScreen(),
  ];

  final List<_NavTarget> _navItems = const [
    _NavTarget(icon: Icons.home_rounded, key: 'home'),
    _NavTarget(icon: Icons.explore_rounded, key: 'search'),
    _NavTarget(icon: Icons.shopping_bag_rounded, key: 'shop'),
    _NavTarget(icon: Icons.calendar_today_rounded, key: 'trips'),
    _NavTarget(icon: Icons.person_rounded, key: 'profile'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUnreadCount();
    _subscribeNotifications();
    _broadcastCurrentUserProfile();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermission();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App resumed from background — immediately sync announcements, alerts, and wishlist
      NotificationService.instance.reloadForUser();
      WishlistService.instance.reloadForUser();
      _fetchUnreadCount();
    }
  }

  Future<void> _broadcastCurrentUserProfile() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();

      final email = user.email ?? prefs.getString('user_email') ?? '';
      final name = resolveDisplayName(prefName: prefs.getString('user_name'), user: user, email: email);
      final photo = prefs.getString('user_photo') ?? user.userMetadata?['avatar_url'] ?? '';
      final phone = prefs.getString('user_phone') ?? user.userMetadata?['phone'];

      final updates = <String, dynamic>{
        'email': email,
        'full_name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (photo.isNotEmpty) 'photo_url': photo,
      };

      try {
        await SupabaseService.client.from('profiles').update(updates).eq('id', user.id);
      } catch (dbErr) {
        debugPrint('DB profile sync notice: $dbErr');
      }

      // Broadcast to admin via HTTP (fire-and-forget, no race condition)
      unawaited(_httpBroadcastUserEvent('user_logged_in', {
        'id': user.id,
        'email': email,
        'full_name': name,
        'phone': phone,
        'photo_url': photo,
      }));
    } catch (e) {
      debugPrint('Shell live profile sync notice: $e');
    }
  }

  /// Sends a Supabase Realtime broadcast via HTTP REST (no WebSocket race condition).
  Future<void> _httpBroadcastUserEvent(String event, Map<String, dynamic> payload) async {
    const supabaseUrl = 'https://imretkikrsdydreldosx.supabase.co';
    const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';
    try {
      await http.post(
        Uri.parse('$supabaseUrl/realtime/v1/api/broadcast'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
        },
        body: jsonEncode({
          'messages': [
            {
              'topic': 'realtime:user_live_stream_channel',
              'event': event,
              'payload': payload,
            }
          ],
        }),
      );
    } catch (e) {
      debugPrint('HTTP broadcast error (non-critical): $e');
    }
  }


  Future<void> _fetchUnreadCount() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final res = await SupabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      _unreadCount.value = (res as List? ?? []).length;
    } catch (_) {}
  }

  void _subscribeNotifications() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    _notifChannel = SupabaseService.client
        .channel('shell:notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final title = row['title'] as String? ?? 'Notification';
            final body = row['body'] as String? ?? '';

            _unreadCount.value = _unreadCount.value + 1;

            if (mounted) {
              _showNotificationBanner(title, body);
            }

            _fetchUnreadCount();
          },
        )
        .subscribe();
  }

  void _showNotificationBanner(String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: kAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifChannel?.unsubscribe();
    _unreadCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeNotifier, languageNotifier]),
      builder: (context, _) {

        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth > 600;

        Widget shellContent = Scaffold(
          backgroundColor: appBgColor(context),
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: appPaperColor(context),
                border: Border(top: BorderSide(color: appLineColor(context), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_navItems.length, (index) {
                  final isSelected = _currentIndex == index;
                  final item = _navItems[index];
                  final isProfile = index == 4;

                  return InkWell(
                    onTap: () {
                      if (isProfile) {
                        // Mark notifications read when visiting profile
                        _unreadCount.value = 0;
                      }
                      setState(() => _currentIndex = index);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                item.icon,
                                color: isSelected ? kAccent : appInkSoftColor(context),
                                size: 22,
                              ),
                              // Notification badge on profile icon
                              if (isProfile)
                                ValueListenableBuilder<int>(
                                  valueListenable: _unreadCount,
                                  builder: (_, count, __) {
                                    if (count == 0) return const SizedBox.shrink();
                                    return Positioned(
                                      top: -4,
                                      right: -6,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          color: kAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            count > 9 ? '9+' : '$count',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(item.key),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? kAccent : appInkSoftColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );

        if (isDesktop) {
          return Scaffold(
            backgroundColor: isDarkMode(context) ? const Color(0xFF000000) : const Color(0xFFF2F4F7),
            body: Center(
              child: Container(
                width: 480,
                decoration: BoxDecoration(
                  color: appBgColor(context),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRect(child: shellContent),
              ),
            ),
          );
        }

        return shellContent;
      },
    );
  }
}

class _NavTarget {
  final IconData icon;
  final String key;
  const _NavTarget({required this.icon, required this.key});
}
