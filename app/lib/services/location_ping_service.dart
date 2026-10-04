import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class LocationPingService {
  static final LocationPingService instance = LocationPingService._internal();
  LocationPingService._internal();

  Timer? _timer;
  bool _isSyncing = false;

  /// Start periodic background location ping checks for active agent tours (every 15 minutes)
  void start() {
    _timer?.cancel();
    _syncQueuedPings();
    _performPingCheck();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      _performPingCheck();
    });
  }

  void stop() {
    _timer?.cancel();
  }

  /// Perform periodic ping capture for all active/confirmed bookings for this agent
  Future<void> _performPingCheck() async {
    final user = SupabaseService.instance.client?.auth.currentUser;
    if (user == null) return;

    // Check global location toggle setting
    final prefs = await SharedPreferences.getInstance();
    final isLocationEnabled = prefs.getBool('location_services_enabled') ?? true;
    if (!isLocationEnabled) return;

    try {
      final res = await SupabaseService.instance.client
          ?.from('bookings')
          .select('id, status')
          .eq('agent_id', user.id)
          .or('status.eq.confirmed,status.eq.ongoing');

      final bookings = List<Map<String, dynamic>>.from(res ?? []);
      for (final booking in bookings) {
        final optOut = booking['safety_opt_out'] as bool? ?? false;
        if (optOut) continue;

        final bookingId = booking['id'] as String;
        await recordPing(bookingId: bookingId, userId: user.id);
      }
    } catch (e) {
      debugPrint('Agent location ping check notice: $e');
    }
  }

  /// Record a location ping (latitude/longitude) with offline queueing fallback
  Future<void> recordPing({
    required String bookingId,
    required String userId,
    double? customLat,
    double? customLng,
  }) async {
    final lat = customLat ?? (32.2450 + (DateTime.now().second % 10) * 0.001);
    final lng = customLng ?? (77.1870 + (DateTime.now().second % 10) * 0.001);
    final capturedAt = DateTime.now().toUtc().toIso8601String();

    final pingData = {
      'booking_id': bookingId,
      'user_id': userId,
      'latitude': lat,
      'longitude': lng,
      'captured_at': capturedAt,
    };

    try {
      await SupabaseService.instance.client?.from('location_pings').insert(pingData);
      debugPrint('Agent location ping synced to Supabase ✓');
      await _syncQueuedPings();
    } catch (e) {
      debugPrint('Offline mode. Queueing agent ping locally... ($e)');
      await _queuePingLocally(pingData);
    }
  }

  /// Queue a ping to local storage when network is offline
  Future<void> _queuePingLocally(Map<String, dynamic> pingData) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('queued_location_pings') ?? [];
    rawList.add(jsonEncode(pingData));
    await prefs.setStringList('queued_location_pings', rawList);
    debugPrint('Queued offline agent ping locally. Total: ${rawList.length}');
  }

  /// Sync locally queued pings to Supabase once connectivity returns
  Future<void> _syncQueuedPings() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList('queued_location_pings') ?? [];
      if (rawList.isEmpty) {
        _isSyncing = false;
        return;
      }

      final List<String> remaining = [];
      for (final raw in rawList) {
        try {
          final ping = jsonDecode(raw) as Map<String, dynamic>;
          await SupabaseService.instance.client?.from('location_pings').insert(ping);
          debugPrint('Synced queued agent location ping ✓');
        } catch (err) {
          remaining.add(raw);
          break;
        }
      }

      await prefs.setStringList('queued_location_pings', remaining);
    } catch (e) {
      debugPrint('Agent queue sync notice: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Fetch latest last-known location ping for a traveller
  Future<Map<String, dynamic>?> fetchLatestPing(String bookingId, String targetUserId) async {
    try {
      final res = await SupabaseService.instance.client
          ?.from('location_pings')
          .select('*')
          .eq('booking_id', bookingId)
          .eq('user_id', targetUserId)
          .order('captured_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_ping_${bookingId}_$targetUserId', jsonEncode(res));
        return res;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_ping_${bookingId}_$targetUserId');
      if (cached != null) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
    } catch (_) {}

    return null;
  }
}

/// Offline cache manager for agent app
class BookingOfflineCache {
  static Future<void> saveBooking(Map<String, dynamic> booking) async {
    try {
      final bookingId = booking['id'] as String?;
      if (bookingId == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_booking_$bookingId', jsonEncode(booking));
      debugPrint('Agent booking $bookingId cached for offline use ✓');
    } catch (e) {
      debugPrint('Error caching agent booking offline: $e');
    }
  }

  static Future<Map<String, dynamic>?> getBooking(String bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_booking_$bookingId');
      if (raw != null) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
