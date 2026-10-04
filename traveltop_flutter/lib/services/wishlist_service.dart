import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data_service.dart';

/// Singleton service that tracks wishlist state strictly from Supabase DB in realtime.
class WishlistService extends ChangeNotifier {
  WishlistService._() {
    _loadFromCache();
  }
  static final WishlistService instance = WishlistService._();

  final Set<String> _wishedAgentIds = {};
  final Set<String> _wishedDestinationIds = {};
  final Set<String> _wishedProductIds = {};
  RealtimeChannel? _channel;
  bool _initialized = false;

  Set<String> get wishedAgentIds => Set.unmodifiable(_wishedAgentIds);
  Set<String> get wishedDestinationIds => Set.unmodifiable(_wishedDestinationIds);
  Set<String> get wishedProductIds => Set.unmodifiable(_wishedProductIds);

  bool isAgentWished(String agentId) => _wishedAgentIds.contains(agentId);
  bool isDestinationWished(String destId) => _wishedDestinationIds.contains(destId);
  bool isProductWished(String productId) => _wishedProductIds.contains(productId);

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      List<String>? a = userId.isNotEmpty ? prefs.getStringList('cached_wished_agents_$userId') : null;
      List<String>? d = userId.isNotEmpty ? prefs.getStringList('cached_wished_destinations_$userId') : null;
      List<String>? p = userId.isNotEmpty ? prefs.getStringList('cached_wished_products_$userId') : null;

      a ??= prefs.getStringList('cached_wished_agents');
      d ??= prefs.getStringList('cached_wished_destinations');
      p ??= prefs.getStringList('cached_wished_products');

      if (a != null && a.isNotEmpty) _wishedAgentIds.addAll(a);
      if (d != null && d.isNotEmpty) _wishedDestinationIds.addAll(d);
      if (p != null && p.isNotEmpty) _wishedProductIds.addAll(p);
      notifyListeners();
    } catch (e) {
      debugPrint('[WishlistService] Cache load notice: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      await prefs.setStringList('cached_wished_agents', _wishedAgentIds.toList());
      await prefs.setStringList('cached_wished_destinations', _wishedDestinationIds.toList());
      await prefs.setStringList('cached_wished_products', _wishedProductIds.toList());
      if (userId.isNotEmpty) {
        await prefs.setStringList('cached_wished_agents_$userId', _wishedAgentIds.toList());
        await prefs.setStringList('cached_wished_destinations_$userId', _wishedDestinationIds.toList());
        await prefs.setStringList('cached_wished_products_$userId', _wishedProductIds.toList());
      }
    } catch (e) {
      debugPrint('[WishlistService] Cache save notice: $e');
    }
  }

  /// Called on LOGOUT — disconnects realtime channel.
  /// Preserves cache so data is intact when re-logging in.
  void clearWishlist() {
    _initialized = false;
    _channel?.unsubscribe();
    _channel = null;
    notifyListeners();
  }

  Future<void> reloadForUser() async {
    _initialized = false;
    await _loadFromCache();
    await _fetchAll();
    _subscribeRealtime();
    notifyListeners();
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromCache();
    await _fetchAll();
    _subscribeRealtime();
  }

  Future<void> _fetchAll() async {
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId == null) {
      return;
    }

    try {
      final rows = await SupabaseService.client
          .from('wishlists')
          .select('agent_id, destination_id, product_id')
          .eq('traveller_id', userId);

      final List list = rows as List;
      if (list.isNotEmpty) {
        _wishedAgentIds.clear();
        _wishedDestinationIds.clear();
        _wishedProductIds.clear();

        for (final row in list) {
          final agentId = row['agent_id'] as String?;
          final destId = row['destination_id'] as String?;
          final prodId = row['product_id'] as String?;
          if (agentId != null && agentId.isNotEmpty) _wishedAgentIds.add(agentId);
          if (destId != null && destId.isNotEmpty) _wishedDestinationIds.add(destId);
          if (prodId != null && prodId.isNotEmpty) _wishedProductIds.add(prodId);
        }
        await _saveToCache();
        notifyListeners();
      } else {
        // If Supabase returned 0 rows but local cache has items, push local cache to Supabase
        if (_wishedAgentIds.isNotEmpty || _wishedDestinationIds.isNotEmpty || _wishedProductIds.isNotEmpty) {
          debugPrint('[WishlistService] Supabase empty — pushing local wishlist items to cloud');
          for (final a in _wishedAgentIds.toList()) {
            _syncAgentRemote(a, true);
          }
          for (final d in _wishedDestinationIds.toList()) {
            _syncDestinationRemote(d, true);
          }
          for (final p in _wishedProductIds.toList()) {
            _syncProductRemote(p, true);
          }
        }
      }
    } catch (e) {
      debugPrint('[WishlistService] remote fetch notice: $e');
    }
  }

  void _subscribeRealtime() async {
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId == null) return;

    try {
      _channel?.unsubscribe();
      _channel = SupabaseService.client
          .channel('wishlist_svc_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'wishlists',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'traveller_id',
              value: userId,
            ),
            callback: (_) => _fetchAll(),
          )
          .subscribe();
    } catch (_) {}
  }

  /// Toggle wishlist for an agent. Optimistic update with instant UI feedback & local persistence.
  Future<bool> toggleAgent(String agentId) async {
    final bool willBeWished = !_wishedAgentIds.contains(agentId);
    if (willBeWished) {
      _wishedAgentIds.add(agentId);
    } else {
      _wishedAgentIds.remove(agentId);
    }
    notifyListeners();
    await _saveToCache();

    _syncAgentRemote(agentId, willBeWished);
    return willBeWished;
  }

  void _syncAgentRemote(String agentId, bool add) async {
    try {
      final userId = await SupabaseService.resolveActiveUserId();
      if (userId == null) return;

      if (add) {
        final existing = await SupabaseService.client
            .from('wishlists')
            .select('id')
            .eq('traveller_id', userId)
            .eq('agent_id', agentId)
            .maybeSingle();
        if (existing == null) {
          await SupabaseService.client.from('wishlists').insert({
            'traveller_id': userId,
            'agent_id': agentId,
          });
        }
      } else {
        await SupabaseService.client
            .from('wishlists')
            .delete()
            .eq('traveller_id', userId)
            .eq('agent_id', agentId);
      }
    } catch (e) {
      debugPrint('[WishlistService] Agent remote sync notice: $e');
    }
  }

  /// Toggle wishlist for a destination. Optimistic update with instant UI feedback & local persistence.
  Future<bool> toggleDestination(String destinationId) async {
    final bool willBeWished = !_wishedDestinationIds.contains(destinationId);
    if (willBeWished) {
      _wishedDestinationIds.add(destinationId);
    } else {
      _wishedDestinationIds.remove(destinationId);
    }
    notifyListeners();
    await _saveToCache();

    _syncDestinationRemote(destinationId, willBeWished);
    return willBeWished;
  }

  void _syncDestinationRemote(String destinationId, bool add) async {
    try {
      final userId = await SupabaseService.resolveActiveUserId();
      if (userId == null) return;

      if (add) {
        final existing = await SupabaseService.client
            .from('wishlists')
            .select('id')
            .eq('traveller_id', userId)
            .eq('destination_id', destinationId)
            .maybeSingle();
        if (existing == null) {
          await SupabaseService.client.from('wishlists').insert({
            'traveller_id': userId,
            'destination_id': destinationId,
          });
        }
      } else {
        await SupabaseService.client
            .from('wishlists')
            .delete()
            .eq('traveller_id', userId)
            .eq('destination_id', destinationId);
      }
    } catch (e) {
      debugPrint('[WishlistService] Destination remote sync notice: $e');
    }
  }

  /// Toggle wishlist for a product/item. Optimistic update with instant UI feedback & local persistence.
  Future<bool> toggleProduct(String productId) async {
    final bool willBeWished = !_wishedProductIds.contains(productId);
    if (willBeWished) {
      _wishedProductIds.add(productId);
    } else {
      _wishedProductIds.remove(productId);
    }
    notifyListeners();
    await _saveToCache();

    _syncProductRemote(productId, willBeWished);
    return willBeWished;
  }

  void _syncProductRemote(String productId, bool add) async {
    try {
      final userId = await SupabaseService.resolveActiveUserId();
      if (userId == null) return;

      if (add) {
        final existing = await SupabaseService.client
            .from('wishlists')
            .select('id')
            .eq('traveller_id', userId)
            .eq('product_id', productId)
            .maybeSingle();
        if (existing == null) {
          await SupabaseService.client.from('wishlists').insert({
            'traveller_id': userId,
            'product_id': productId,
          });
        }
      } else {
        await SupabaseService.client
            .from('wishlists')
            .delete()
            .eq('traveller_id', userId)
            .eq('product_id', productId);
      }
    } catch (e) {
      debugPrint('[WishlistService] Product remote sync notice: $e');
    }
  }

  void reset() {
    _wishedAgentIds.clear();
    _wishedDestinationIds.clear();
    _wishedProductIds.clear();
    _channel?.unsubscribe();
    _channel = null;
    _initialized = false;
    _saveToCache();
    notifyListeners();
  }
}
