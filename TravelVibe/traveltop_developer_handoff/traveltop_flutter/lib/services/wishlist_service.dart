import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data_service.dart';

/// Singleton service that tracks wishlist state strictly from Supabase DB in realtime.
class WishlistService extends ChangeNotifier {
  WishlistService._();
  static final WishlistService instance = WishlistService._();

  final Set<String> _wishedAgentIds = {};
  final Set<String> _wishedDestinationIds = {};
  final Set<String> _wishedProductIds = {};
  RealtimeChannel? _channel;
  bool _initialized = false;

  Set<String> get wishedAgentIds => _wishedAgentIds;
  Set<String> get wishedDestinationIds => _wishedDestinationIds;
  Set<String> get wishedProductIds => _wishedProductIds;

  bool isAgentWished(String agentId) => _wishedAgentIds.contains(agentId);
  bool isDestinationWished(String destId) => _wishedDestinationIds.contains(destId);
  bool isProductWished(String productId) => _wishedProductIds.contains(productId);

  void clearWishlist() {
    _wishedAgentIds.clear();
    _wishedDestinationIds.clear();
    _wishedProductIds.clear();
    _initialized = false;
    _channel?.unsubscribe();
    _channel = null;
    notifyListeners();
  }

  Future<void> reloadForUser() async {
    _wishedAgentIds.clear();
    _wishedDestinationIds.clear();
    _wishedProductIds.clear();
    _initialized = false;
    await _fetchAll();
    notifyListeners();
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _fetchAll();
    _subscribeRealtime();
  }

  Future<void> _fetchAll() async {
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId == null) {
      _wishedAgentIds.clear();
      _wishedDestinationIds.clear();
      _wishedProductIds.clear();
      notifyListeners();
      return;
    }

    try {
      final rows = await SupabaseService.client
          .from('wishlists')
          .select('agent_id, destination_id, product_id')
          .eq('traveller_id', userId);

      _wishedAgentIds.clear();
      _wishedDestinationIds.clear();
      _wishedProductIds.clear();

      for (final row in (rows as List)) {
        final agentId = row['agent_id'] as String?;
        final destId = row['destination_id'] as String?;
        final prodId = row['product_id'] as String?;
        if (agentId != null) _wishedAgentIds.add(agentId);
        if (destId != null) _wishedDestinationIds.add(destId);
        if (prodId != null) _wishedProductIds.add(prodId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[WishlistService] fetch error: $e');
    }
  }

  void _subscribeRealtime() async {
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId == null) return;

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
  }

  /// Toggle wishlist for an agent. Requires authenticated user.
  Future<bool> toggleAgent(String agentId) async {
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId == null) {
      debugPrint('[WishlistService] Authentication required to modify wishlist');
      return false;
    }

    final isWished = _wishedAgentIds.contains(agentId);

    try {
      if (isWished) {
        await SupabaseService.client
            .from('wishlists')
            .delete()
            .eq('traveller_id', userId)
            .eq('agent_id', agentId);
        _wishedAgentIds.remove(agentId);
      } else {
        await SupabaseService.client.from('wishlists').insert({
          'traveller_id': userId,
          'agent_id': agentId,
        });
        _wishedAgentIds.add(agentId);
      }
      notifyListeners();
      return !isWished;
    } catch (e) {
      debugPrint('[WishlistService] toggleAgent error: $e');
      rethrow;
    }
  }

  /// Toggle wishlist for a destination. Requires authenticated user.
  Future<bool> toggleDestination(String destinationId) async {
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId == null) {
      debugPrint('[WishlistService] Authentication required to modify wishlist');
      return false;
    }

    final isWished = _wishedDestinationIds.contains(destinationId);

    try {
      if (isWished) {
        await SupabaseService.client
            .from('wishlists')
            .delete()
            .eq('traveller_id', userId)
            .eq('destination_id', destinationId);
        _wishedDestinationIds.remove(destinationId);
      } else {
        await SupabaseService.client.from('wishlists').insert({
          'traveller_id': userId,
          'destination_id': destinationId,
        });
        _wishedDestinationIds.add(destinationId);
      }
      notifyListeners();
      return !isWished;
    } catch (e) {
      debugPrint('[WishlistService] toggleDestination error: $e');
      rethrow;
    }
  }

  /// Toggle wishlist for a product/item. Requires authenticated user.
  Future<bool> toggleProduct(String productId) async {
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId == null) {
      debugPrint('[WishlistService] Authentication required to modify wishlist');
      return false;
    }

    final isWished = _wishedProductIds.contains(productId);

    try {
      if (isWished) {
        await SupabaseService.client
            .from('wishlists')
            .delete()
            .eq('traveller_id', userId)
            .eq('product_id', productId);
        _wishedProductIds.remove(productId);
      } else {
        await SupabaseService.client.from('wishlists').insert({
          'traveller_id': userId,
          'product_id': productId,
        });
        _wishedProductIds.add(productId);
      }
      notifyListeners();
      return !isWished;
    } catch (e) {
      debugPrint('[WishlistService] toggleProduct error: $e');
      rethrow;
    }
  }

  void reset() {
    _wishedAgentIds.clear();
    _wishedDestinationIds.clear();
    _wishedProductIds.clear();
    _channel?.unsubscribe();
    _channel = null;
    _initialized = false;
    notifyListeners();
  }
}
