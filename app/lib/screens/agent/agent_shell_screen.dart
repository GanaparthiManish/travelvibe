import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'home/agent_console_screen.dart';
import 'booking/bookings_tab_screen.dart';
import 'chat/agent_chat_tab_screen.dart';
import 'earnings/earnings_screen.dart';
import 'settings/agent_settings_screen.dart';

class AgentShellScreen extends StatefulWidget {
  final int initialTab;
  const AgentShellScreen({super.key, this.initialTab = 0});

  @override
  State<AgentShellScreen> createState() => _AgentShellScreenState();
}

class _AgentShellScreenState extends State<AgentShellScreen> {
  late int _currentIndex;
  StreamSubscription<List<Map<String, dynamic>>>? _bookingsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSub;

  int _pendingBookingsCount = 0;
  int _unreadChatCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _subscribeRealtimeBadges();
  }

  RealtimeChannel? _notifyChannel;
  RealtimeChannel? _suspensionChannel;

  void _checkAndEnforceSuspension() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;
    try {
      final details = await SupabaseService.instance.getAgentDetails(user.id);
      final bool isSuspended = details?['suspended'] == true;
      if (isSuspended && mounted) {
        await SupabaseService.instance.signOut();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Your account has been suspended by administration.'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 8),
          ),
        );
      }
    } catch (_) {}
  }

  void _subscribeRealtimeBadges() {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    _checkAndEnforceSuspension();

    // Stream bookings for pending count
    _bookingsSub = SupabaseService.instance.streamAgentBookings(user.id).listen((bookings) {
      if (!mounted) return;
      final pendingList = bookings.where((b) => b['status'] == 'pending' || b['status'] == 'confirmed').toList();
      setState(() {
        _pendingBookingsCount = pendingList.length;
      });
    });

    // Listen to live broadcast channel for agent notifications & suspension events
    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        _suspensionChannel = client
            .channel('agent_suspension_channel_${user.id}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'agent_details',
              callback: (_) => _checkAndEnforceSuspension(),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'profiles',
              callback: (_) => _checkAndEnforceSuspension(),
            )
            .subscribe();

        _notifyChannel = client.channel('agent_notification_channel');
        _notifyChannel?.onBroadcast(
          event: 'new_booking_notification',
          callback: (payload) {
            if (mounted) {
              final Map<String, dynamic> data = Map<String, dynamic>.from(payload);
              final String title = data['title']?.toString() ?? 'New Booking!';
              final String body = data['body']?.toString() ?? 'You received a new booking.';

              setState(() {
                _pendingBookingsCount += 1;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title: $body'),
                  backgroundColor: AppTheme.kAccent,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          },
        );
        _notifyChannel?.subscribe();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _notificationsSub?.cancel();
    if (_notifyChannel != null && SupabaseService.instance.client != null) {
      SupabaseService.instance.client!.removeChannel(_notifyChannel!);
    }
    if (_suspensionChannel != null && SupabaseService.instance.client != null) {
      SupabaseService.instance.client!.removeChannel(_suspensionChannel!);
    }
    super.dispose();
  }

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      AgentConsoleScreen(onNavigateTab: switchTab),
      const BookingsTabScreen(),
      const AgentChatTabScreen(),
      const EarningsScreen(),
      const AgentSettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.kWhite,
          border: Border(top: BorderSide(color: AppTheme.kLine, width: 1.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.kWhite,
          selectedItemColor: AppTheme.kAccent,
          unselectedItemColor: AppTheme.kInkSoft,
          selectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              activeIcon: Icon(Icons.grid_view_rounded, color: AppTheme.kAccent),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _buildBadgeIcon(
                icon: Icons.calendar_month_rounded,
                count: _pendingBookingsCount,
              ),
              activeIcon: _buildBadgeIcon(
                icon: Icons.calendar_month_rounded,
                count: _pendingBookingsCount,
                isSelected: true,
              ),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: _buildBadgeIcon(
                icon: Icons.chat_bubble_outline_rounded,
                count: _unreadChatCount,
              ),
              activeIcon: _buildBadgeIcon(
                icon: Icons.chat_bubble_rounded,
                count: _unreadChatCount,
                isSelected: true,
              ),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded, color: AppTheme.kAccent),
              label: 'Earnings',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded, color: AppTheme.kAccent),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeIcon({required IconData icon, required int count, bool isSelected = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: isSelected ? AppTheme.kAccent : AppTheme.kInkSoft),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.kAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.kWhite,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
