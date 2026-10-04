import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data_service.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'trip', 'order', 'promo'
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'is_read': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] ?? 'TravelVibe Alert',
        message: json['message'] ?? '',
        type: json['type'] ?? 'promo',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
            : DateTime.now(),
        isRead: json['is_read'] ?? false,
      );
}

class NotificationService extends ChangeNotifier {
  NotificationService._() {
    _initLocalNotifications();
    _loadFromPrefs();
  }
  static final NotificationService instance = NotificationService._();

  final List<AppNotification> _notifications = [];
  RealtimeChannel? _channel;
  bool _initialized = false;
  final FlutterLocalNotificationsPlugin _localNotifPlugin =
      FlutterLocalNotificationsPlugin();

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _initLocalNotifications() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotifPlugin.initialize(initSettings);

      // Request notification permissions for Android 13+
      final androidPlatform =
          _localNotifPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlatform?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('[NotificationService] Local notif plugin error: $e');
    }
  }

  Future<void> _showSystemNotification(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'travelvibe_alerts',
        'TravelVibe System Alerts',
        channelDescription: 'Realtime updates for bookings, orders & deals',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'TravelVibe Notification',
        playSound: true,
        enableVibration: true,
      );

      const details = NotificationDetails(android: androidDetails);
      await _localNotifPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('[NotificationService] System notification error: $e');
    }
  }

  Future<String> _getUserId() async {
    final authUser = SupabaseService.client.auth.currentUser;
    return authUser?.id ?? '';
  }

  void clearNotifications() {
    _notifications.clear();
    _initialized = false;
    _channel?.unsubscribe();
    _channel = null;
    notifyListeners();
  }

  Future<void> reloadForUser() async {
    clearNotifications();
    await _loadFromPrefs();
    await init();
  }

  Future<void> _loadFromPrefs() async {
    await _fetchRemote();
  }

  Future<void> _saveToPrefs() async {
    // Single source of truth: persisted strictly in Supabase DB notifications table
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _fetchRemote();
    _subscribeRealtime();
  }

  Future<void> _fetchRemote() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final rows = await SupabaseService.client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<AppNotification> remoteList = [];
      for (final r in (rows as List)) {
        final notif = AppNotification(
          id: r['id'] as String? ?? UniqueKey().toString(),
          title: r['title'] as String? ?? 'Notification',
          message: r['message'] as String? ?? r['body'] as String? ?? '',
          type: r['type'] as String? ?? 'promo',
          timestamp: DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now(),
          isRead: r['is_read'] as bool? ?? false,
        );
        remoteList.add(notif);
      }
      _notifications.clear();
      _notifications.addAll(remoteList);
      _saveToPrefs();
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationService] fetch error: $e');
    }
  }

  void _subscribeRealtime() {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    // 1. Postgres changes on notifications table for this user
    _channel = SupabaseService.client
        .channel('notif_svc_$userId')
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
            final r = payload.newRecord;
            final title = r['title'] as String? ?? 'New Alert';
            final body = r['message'] as String? ?? r['body'] as String? ?? '';
            final notif = AppNotification(
              id: r['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
              message: body,
              type: r['type'] as String? ?? 'promo',
              timestamp: DateTime.now(),
            );
            _notifications.insert(0, notif);
            _saveToPrefs();
            _showSystemNotification(title, body);
            notifyListeners();
          },
        )
        .subscribe();

    // 2. Broadcast channel for announcements
    SupabaseService.client
        .channel('announcements_rt')
        .onBroadcast(
          event: 'new_announcement',
          callback: (payload) {
            final title = payload['title'] as String? ?? 'Announcement';
            final body = payload['body'] as String? ?? '';
            final notif = AppNotification(
              id: 'ann_${DateTime.now().millisecondsSinceEpoch}',
              title: '📢 $title',
              message: body,
              type: 'promo',
              timestamp: DateTime.now(),
            );
            _notifications.insert(0, notif);
            _saveToPrefs();
            _showSystemNotification('📢 $title', body);
            notifyListeners();
          },
        )
        .subscribe();
  }

  void addNotification({
    required String title,
    required String message,
    required String type,
  }) {
    final notif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );
    _notifications.insert(0, notif);
    _saveToPrefs();
    notifyListeners();

    // Trigger Android System Phone Notification Banner!
    _showSystemNotification(title, message);

    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        SupabaseService.client.from('notifications').insert({
          'user_id': userId,
          'title': title,
          'message': message,
          'type': type,
        });
      } catch (_) {}
    }
  }

  void markAllAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    _saveToPrefs();
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    _saveToPrefs();
    notifyListeners();
  }
}
