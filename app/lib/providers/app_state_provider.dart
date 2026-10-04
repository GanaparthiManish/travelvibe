import 'package:flutter/material.dart';

class AppStateProvider extends ChangeNotifier {
  // Active user profile cache
  Map<String, dynamic>? _userProfile;
  String _userRole = 'traveller';

  // Cart State
  final List<Map<String, dynamic>> _cartItems = [
    {
      'id': 'p1',
      'title': 'High Peak Waterproof Backpack (45L)',
      'price': 4500.0,
      'qty': 1,
      'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
    },
    {
      'id': 'p2',
      'title': 'Stainless Steel Thermal Flask 1L',
      'price': 1200.0,
      'qty': 2,
      'image': 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=400',
    },
  ];

  // Wishlist Agent IDs Cache
  final Set<String> _wishlistAgentIds = {'agent_1', 'agent_2'};

  // Unread Notifications Count
  int _unreadNotificationCount = 2;

  // Getters
  Map<String, dynamic>? get userProfile => _userProfile;
  String get userRole => _userRole;
  List<Map<String, dynamic>> get cartItems => List.unmodifiable(_cartItems);
  Set<String> get wishlistAgentIds => Set.unmodifiable(_wishlistAgentIds);
  int get unreadNotificationCount => _unreadNotificationCount;

  int get cartCount => _cartItems.fold(0, (sum, item) => sum + (item['qty'] as int));

  double get cartSubtotal =>
      _cartItems.fold(0.0, (sum, item) => sum + ((item['price'] as double) * (item['qty'] as int)));

  // Profile Actions
  void setUserProfile(Map<String, dynamic>? profile) {
    _userProfile = profile;
    if (profile != null && profile['role'] != null) {
      _userRole = profile['role'];
    }
    notifyListeners();
  }

  void setUserRole(String role) {
    _userRole = role;
    notifyListeners();
  }

  // Cart Actions
  void addToCart(Map<String, dynamic> product) {
    final existingIndex = _cartItems.indexWhere((item) => item['id'] == product['id']);
    if (existingIndex >= 0) {
      _cartItems[existingIndex]['qty'] = (_cartItems[existingIndex]['qty'] as int) + 1;
    } else {
      _cartItems.add({
        'id': product['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': product['name'] ?? product['title'] ?? 'Travel Product',
        'price': (product['price'] is num) ? (product['price'] as num).toDouble() : 1000.0,
        'qty': 1,
        'image': product['image_url'] ?? product['image'] ?? '',
      });
    }
    notifyListeners();
  }

  void updateCartQty(String id, int delta) {
    final index = _cartItems.indexWhere((item) => item['id'] == id);
    if (index >= 0) {
      final newQty = (_cartItems[index]['qty'] as int) + delta;
      if (newQty <= 0) {
        _cartItems.removeAt(index);
      } else {
        _cartItems[index]['qty'] = newQty;
      }
      notifyListeners();
    }
  }

  void removeFromCart(String id) {
    _cartItems.removeWhere((item) => item['id'] == id);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  // Wishlist Actions
  bool isWishlisted(String agentId) => _wishlistAgentIds.contains(agentId);

  void toggleWishlist(String agentId) {
    if (_wishlistAgentIds.contains(agentId)) {
      _wishlistAgentIds.remove(agentId);
    } else {
      _wishlistAgentIds.add(agentId);
    }
    notifyListeners();
  }

  // Notification Actions
  void decrementUnreadNotifications() {
    if (_unreadNotificationCount > 0) {
      _unreadNotificationCount--;
      notifyListeners();
    }
  }

  // Theme State
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}
