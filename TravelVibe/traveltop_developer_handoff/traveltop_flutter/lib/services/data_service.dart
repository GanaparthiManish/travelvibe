import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Helper to safely parse Postgres text[] array columns (whether returned as List or raw String)
List<String> parseStringList(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw.map((e) => e.toString()).toList();
  }
  if (raw is String) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    } else if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    if (cleaned.isEmpty) return [];

    return cleaned
        .split(',')
        .map((s) => s.trim().replaceAll('"', '').replaceAll('\\', ''))
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return [];
}

// ─── Supabase project credentials ──────────────────────────────────────────
const String _supabaseUrl = 'https://imretkikrsdydreldosx.supabase.co';
const String _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

// ─── Data models ────────────────────────────────────────────────────────────

class AppData {
  final List<DestinationData> destinations;
  final List<AgentData> agents;

  AppData({required this.destinations, required this.agents});

  factory AppData.empty() =>
      AppData(destinations: [], agents: []);
}

class DestinationData {
  final String id, name, country, coverImageUrl;
  final bool isFeatured, isTrending;
  final int agentCount;
  final double latitude;
  final double longitude;

  DestinationData({
    required this.id,
    required this.name,
    required this.country,
    required this.coverImageUrl,
    required this.isFeatured,
    required this.isTrending,
    required this.agentCount,
    this.latitude = 10.0889,
    this.longitude = 77.0595,
  });

  factory DestinationData.fromJson(Map<String, dynamic> j) {
    final nameStr = (j['name'] ?? '').toString().toLowerCase();
    double lat = (j['latitude'] as num?)?.toDouble() ?? 10.0889;
    double lng = (j['longitude'] as num?)?.toDouble() ?? 77.0595;

    if (nameStr.contains('ladakh') || nameStr.contains('leh')) {
      lat = 34.1526; lng = 77.5771;
    } else if (nameStr.contains('khajjiar')) {
      lat = 32.5558; lng = 76.0656;
    } else if (nameStr.contains('alleppey') || nameStr.contains('alappuzha')) {
      lat = 9.4981; lng = 76.3388;
    } else if (nameStr.contains('goa')) {
      lat = 15.2993; lng = 74.1240;
    } else if (nameStr.contains('munnar')) {
      lat = 10.0889; lng = 77.0595;
    }

    return DestinationData(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      country: j['country'] ?? '',
      coverImageUrl: j['cover_image_url'] ?? '',
      isFeatured: j['is_featured'] ?? false,
      isTrending: j['is_trending'] ?? false,
      agentCount: (j['agent_count'] as num?)?.toInt() ?? 0,
      latitude: lat,
      longitude: lng,
    );
  }

  // Backward-compat helpers used by HomeScreen
  String get location => country;
  String get imageUrl => coverImageUrl;
  String get color => '#4A7FA5';
}

class AgentData {
  final String id, name, bio, photoUrl;
  final List<String> placesCovered;
  final double ratingAvg;
  final int pricePerDay;
  final bool verified;

  AgentData({
    required this.id,
    required this.name,
    required this.bio,
    required this.photoUrl,
    required this.placesCovered,
    required this.ratingAvg,
    required this.pricePerDay,
    required this.verified,
  });

  factory AgentData.fromJson(Map<String, dynamic> j) {
    final profile = (j['profiles'] as Map<String, dynamic>?) ?? {};
    var photo = (profile['photo_url'] as String?) ?? (j['selfie_url'] as String?) ?? '';
    if (photo.isNotEmpty && !photo.startsWith('http://') && !photo.startsWith('https://') && !photo.startsWith('data:')) {
      photo = 'https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/$photo';
    }
    return AgentData(
      id: j['id'] ?? '',
      name: (profile['full_name'] != null && (profile['full_name'] as String).isNotEmpty) ? profile['full_name'] : 'Local Guide',
      bio: j['bio'] ?? '',
      photoUrl: photo,
      placesCovered: parseStringList(j['places_covered']),
      ratingAvg: (j['rating_avg'] as num?)?.toDouble() ?? 0.0,
      pricePerDay: (j['price_per_day'] as num?)?.toInt() ?? 0,
      verified: j['verified'] ?? false,
    );
  }

  // Backward-compat helpers used by HomeScreen
  String get specialty =>
      placesCovered.isNotEmpty ? placesCovered.first : 'Travel';
  String get location =>
      placesCovered.isNotEmpty ? placesCovered.first : '—';
  double get rating => ratingAvg;
  String get color => '#6B8F71';
}

// ─── Supabase singleton ─────────────────────────────────────────────────────

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
    if (client.auth.currentUser == null) {
      try {
        await client.auth.signInAnonymously();
      } catch (e) {
        debugPrint('Anonymous auth init notice: $e');
      }
    }
  }

  static Future<String?> resolveActiveUserId() async {
    final realUser = client.auth.currentUser;
    if (realUser != null && realUser.id.isNotEmpty) {
      return realUser.id;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getAgentAddons(String agentId) async {
    try {
      final res = await client
          .from('agent_addons')
          .select('*')
          .eq('agent_id', agentId)
          .eq('is_active', true);
      if (res != null && (res as List).isNotEmpty) {
        return List<Map<String, dynamic>>.from(res);
      }
    } catch (e) {
      debugPrint('agent_addons table fetch notice: $e');
    }
    return [];
  }
}

// ─── Data Service Singleton ──────────────────────────────────────────────────

class DataService {
  static final DataService instance = DataService._internal();
  DataService._internal();

  final ValueNotifier<AppData> data = ValueNotifier<AppData>(AppData.empty());
  RealtimeChannel? _channel;

  void start() {
    loadData();
    _subscribeRealtime();
  }

  Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
      debugPrint('Supabase initialized in DataService.');
    } catch (e) {
      if (!e.toString().contains('already initialized')) {
        debugPrint('Supabase init notice in DataService: $e');
      }
    }
  }

  Future<void> loadData() async {
    List<DestinationData> fetchedDestinations = [];
    List<AgentData> fetchedAgents = [];

    final client = SupabaseService.client;

    // 1. Fetch All Destinations
    try {
      final res = await client.from('destinations').select('*').limit(50);
      if (res != null && (res as List).isNotEmpty) {
        fetchedDestinations = (res as List)
            .map((e) => DestinationData.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching destinations: $e');
    }

    // 2. Fetch All Registered Agents from Supabase PostgreSQL DB
    try {
      final res = await client
          .from('agent_details')
          .select('*')
          .eq('verification_status', 'approved')
          .eq('verified', true)
          .eq('suspended', false)
          .order('updated_at', ascending: false)
          .limit(50);

      if (res != null && (res as List).isNotEmpty) {
        List<Map<String, dynamic>> rawList = List<Map<String, dynamic>>.from(res);
        final agentIds = rawList.map((a) => a['id'] as String?).whereType<String>().toList();
        Map<String, dynamic> profilesMap = {};
        if (agentIds.isNotEmpty) {
          try {
            final pRes = await client.from('profiles').select('id, full_name, photo_url').inFilter('id', agentIds);
            if (pRes != null) {
              for (final p in pRes) {
                profilesMap[p['id']] = p;
              }
            }
          } catch (e) {
            debugPrint('Profiles fetch notice in DataService: $e');
          }
        }

        fetchedAgents = rawList.map((e) {
          final p = profilesMap[e['id']];
          return AgentData.fromJson({
            ...e,
            'profiles': p ?? {},
          });
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching agents: $e');
    }

    data.value = AppData(destinations: fetchedDestinations, agents: fetchedAgents);
  }

  void _subscribeRealtime() {
    try {
      _channel = SupabaseService.client
          .channel('app_data_rt')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'destinations',
            callback: (_) => loadData(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'agent_details',
            callback: (_) => loadData(),
          )
          .subscribe();
    } catch (_) {}
  }
}

class SplashData {
  final String imageUrl, tagline;
  SplashData({required this.imageUrl, required this.tagline});
}

class CategoryData {
  final String id, emoji, label;
  CategoryData({required this.id, required this.emoji, required this.label});
}
