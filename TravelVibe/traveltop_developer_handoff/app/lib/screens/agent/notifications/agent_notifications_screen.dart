import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

class AgentNotificationsScreen extends StatefulWidget {
  const AgentNotificationsScreen({super.key});

  @override
  State<AgentNotificationsScreen> createState() => _AgentNotificationsScreenState();
}

class _AgentNotificationsScreenState extends State<AgentNotificationsScreen> {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subscribeNotifications();
  }

  void _subscribeNotifications() {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    _subscription = SupabaseService.instance.streamNotifications(user.id).listen((nList) {
      if (!mounted) return;
      setState(() {
        _notifications = nList;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 48, color: AppTheme.kInkMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications yet',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.kInk),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    final title = n['title'] ?? 'Notification';
                    final body = n['body'] ?? '';
                    final isRead = (n['is_read'] ?? false) as bool;
                    final dateStr = (n['created_at'] ?? '').toString().split('T')[0];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRead ? AppTheme.kWhite : AppTheme.kAccentLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isRead ? AppTheme.kLine : AppTheme.kAccent, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            color: isRead ? AppTheme.kInkMuted : AppTheme.kAccent,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.kInk,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  body,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateStr,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.kInkMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
