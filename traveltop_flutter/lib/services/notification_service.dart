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

      await _localNotifPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[NotificationService] Notification tapped: ${response.payload}');
        },
      );

      final androidPlatform =
          _localNotifPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        const androidChannel = AndroidNotificationChannel(
          'travelvibe_alerts_v2',
          'TravelVibe Notifications',
          description: 'Realtime announcements, bookings & alerts',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        await androidPlatform.createNotificationChannel(androidChannel);
      }
    } catch (e) {
      debugPrint('[NotificationService] Local notif plugin error: $e');
    }
  }

  /// Request runtime notification permissions on Android 13+ (API 33+)
  Future<bool> requestPermission() async {
    try {
      final androidPlatform = _localNotifPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        final granted = await androidPlatform.requestNotificationsPermission();
        debugPrint('[NotificationService] POST_NOTIFICATIONS permission granted: $granted');
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Request permission error: $e');
    }
    return false;
  }

  Future<void> _showSystemNotification(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'travelvibe_alerts_v2',
        'TravelVibe Notifications',
        channelDescription: 'Realtime announcements, bookings & alerts',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'TravelVibe Alert',
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(''),
      );

      const details = NotificationDetails(android: androidDetails);
      final int notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _localNotifPlugin.show(
        notifId,
        title,
        body,
        details,
      );
      debugPrint('[NotificationService] System notification posted: $title | $body');
    } catch (e) {
      debugPrint('[NotificationService] System notification error: $e');
    }
  }

  Future<String> _getUserId() async {
    final authUser = SupabaseService.client.auth.currentUser;
    return authUser?.id ?? '';
  }

  /// Called on LOGOUT — clears in-memory state and disconnects realtime.
  /// Does NOT wipe SharedPreferences cache so notifications are still
  /// visible immediately when the user logs back in (before Supabase sync).
  void clearNotifications() {
    _notifications.clear();
    _initialized = false;
    _channel?.unsubscribe();
    _channel = null;
    _announcementsChannel?.unsubscribe();
    _announcementsChannel = null;
    // NOTE: deliberately NOT calling _saveToPrefs() here — we keep the
    // local cache intact so the UI stays populated until the next sync.
    notifyListeners();
  }

  Future<void> reloadForUser() async {
    _initialized = false;
    _notifications.clear(); // Fresh start before re-fetch — avoids cross-session duplicates
    await _loadFromPrefs();
    await _fetchRemote();
    _subscribeRealtime();
    _subscribeAnnouncements();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_app_notifications');
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        _notifications.clear();
        for (final item in list) {
          _notifications.add(AppNotification.fromJson(Map<String, dynamic>.from(item)));
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[NotificationService] Load prefs notice: $e');
    }
    await _fetchRemote();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString('cached_app_notifications', jsonEncode(list));
    } catch (e) {
      debugPrint('[NotificationService] Save prefs notice: $e');
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromPrefs();
    _subscribeAnnouncements();
    _subscribeRealtime();
  }

  Future<void> _fetchRemote() async {
    // 1. Fetch user notifications if logged in
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId != null) {
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
        for (final n in remoteList) {
          if (!_notifications.any((existing) => existing.id == n.id)) {
            _notifications.add(n);
          }
        }
      } catch (e) {
        debugPrint('[NotificationService] user notif fetch notice: $e');
      }
    }

    // 2. Fetch public announcements from announcements table
    try {
      final annRows = await SupabaseService.client
          .from('announcements')
          .select('*')
          .order('sent_at', ascending: false)
          .limit(20);

      if (annRows is List && annRows.isNotEmpty) {
        for (final r in annRows) {
          final id = r['id'] as String? ?? '';
          final title = r['title'] as String? ?? 'Announcement';
          final body = r['body'] as String? ?? '';
          final sentAt = DateTime.tryParse(r['sent_at'] ?? '') ?? DateTime.now();

          if (!_notifications.any((n) => n.id == id || (n.title == '📢 $title' && n.message == body))) {
            _notifications.add(AppNotification(
              id: id.isNotEmpty ? id : 'ann_${sentAt.millisecondsSinceEpoch}',
              title: '📢 $title',
              message: body,
              type: 'promo',
              timestamp: sentAt,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] announcements fetch notice: $e');
    }

    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _saveToPrefs();
    notifyListeners();
  }

  RealtimeChannel? _announcementsChannel;
  RealtimeChannel? _streamChannel;

  void _handleAnnouncementPayload(dynamic payload) {
    debugPrint('[NotificationService] Broadcast announcement received: $payload');
    try {
      final p = (payload is Map && payload.containsKey('payload'))
          ? payload['payload']
          : (payload is Map && payload.containsKey('data'))
              ? payload['data']
              : payload;
      if (p is! Map) return;

      final title = p['title'] as String? ?? 'Announcement';
      final body = p['body'] as String? ?? '';
      final id = p['id'] as String? ?? 'ann_${DateTime.now().millisecondsSinceEpoch}';

      if (_notifications.any((n) => n.id == id || (n.title == '📢 $title' && n.message == body))) {
        return;
      }

      final notif = AppNotification(
        id: id,
        title: '📢 $title',
        message: body,
        type: 'promo',
        timestamp: DateTime.now(),
      );
      _notifications.insert(0, notif);
      _saveToPrefs();
      _showSystemNotification('📢 $title', body);
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationService] Handle announcement payload notice: $e');
    }
  }

  void _subscribeAnnouncements() {
    try {
      _announcementsChannel?.unsubscribe();
      _announcementsChannel = SupabaseService.client
          .channel('announcements_rt')
          .onBroadcast(
            event: 'new_announcement',
            callback: _handleAnnouncementPayload,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'announcements',
            callback: (payload) {
              final r = payload.newRecord;
              _handleAnnouncementPayload(r);
            },
          )
          .subscribe();

      _streamChannel?.unsubscribe();
      _streamChannel = SupabaseService.client
          .channel('user_live_stream_channel')
          .onBroadcast(
            event: 'new_announcement',
            callback: _handleAnnouncementPayload,
          )
          .subscribe();
    } catch (e) {
      debugPrint('[NotificationService] Subscribe announcements error: $e');
    }
  }

  void _subscribeRealtime() async {
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId == null) return;

    _channel?.unsubscribe();

    // Postgres changes on notifications table for this user
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
            _showSystemNotification(title, body);
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
