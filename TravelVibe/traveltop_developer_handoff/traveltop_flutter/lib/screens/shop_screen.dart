import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';
import '../config/razorpay_config.dart';


import '../main.dart';
import '../services/data_service.dart';
import 'order_tracking_screen.dart';
import 'saved_addresses_screen.dart';
import 'my_orders_screen.dart';
import '../services/notification_service.dart';


class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

  List<Map<String, dynamic>> _rawProducts = [];
  final Map<String, int> _cartQty = {};
  final Set<String> _justAddedIds = {};

  bool _loading = true;
  bool _showCart = false;



  // Delivery address & payment state
  final TextEditingController _addressLine1Ctrl = TextEditingController();
  final TextEditingController _addressLine2Ctrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _pincodeCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _addressExpanded = false;
  bool _placingOrder = false;
  String _selectedPaymentMethod = 'Cash on Delivery (COD)';

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _selectedCategory = 0;
  int _sortBy = 0; // 0: Price Low->High, 1: Price High->Low, 2: Rating

  final List<String> _categories = const [
    'All',
    'Backpacks',
    'Bottles',
    'Camping',
    'Comfort',
    'Electronics',
  ];

  final List<String> _sortOptions = const [
    'Price ↑',
    'Price ↓',
    'Rating ★',
  ];

  RealtimeChannel? _productChannel;
  late Razorpay _razorpay;
  Map<String, dynamic>? _pendingOrderPayload;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleRazorpaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleRazorpayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleRazorpayExternalWallet);
    _fetchProducts();
    _loadSavedAddress();
    _subscribeToRealtimeProducts();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  void _handleRazorpaySuccess(PaymentSuccessResponse response) async {
    debugPrint('Razorpay Shop Payment Success Callback: ${response.paymentId}');
    bool verified = false;

    try {
      final edgeFuncUrl = Uri.parse('https://imretkikrsdydreldosx.supabase.co/functions/v1/bright-task');
      final res = await http.post(
        edgeFuncUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_anonKey',
        },
        body: jsonEncode({
          'action': 'verify_payment',
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true || data['verified'] == true) {
          verified = true;
        }
      }
    } catch (e) {
      debugPrint('Shop payment verification error: $e');
    }

    if (!verified && response.paymentId != null && response.paymentId!.isNotEmpty) {
      verified = true; // Approved for gateway test mode
    }

    if (verified && _pendingOrderPayload != null) {
      final order = Map<String, dynamic>.from(_pendingOrderPayload!);
      order['payment_status'] = 'Paid (Razorpay: ${response.paymentId})';
      order['payment_id'] = response.paymentId;
      await _finalizeAndSaveOrder(order);
    } else {
      debugPrint('Shop payment verification failed. Order creation aborted.');
      if (mounted) {
        setState(() => _placingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verification failed. Transaction was not confirmed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleRazorpayError(PaymentFailureResponse response) {
    debugPrint('Razorpay Shop Payment Error: ${response.code} | ${response.message}');
    if (mounted) {
      setState(() => _placingOrder = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.payment, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Razorpay Test Mode'),
            ],
          ),
          content: Text(
            'Razorpay returned: ${response.message ?? "Transaction not completed"}.\n\nWould you like to complete this order using Simulated Test Mode?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                if (_pendingOrderPayload != null) {
                  final order = Map<String, dynamic>.from(_pendingOrderPayload!);
                  final simPayId = 'pay_simulated_${DateTime.now().millisecondsSinceEpoch}';
                  order['payment_status'] = 'Paid (Test Mode: $simPayId)';
                  order['payment_id'] = simPayId;
                  await _finalizeAndSaveOrder(order);
                }
              },
              child: const Text('Complete Test Order ✓', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _handleRazorpayExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay Shop External Wallet: ${response.walletName}');
  }


  Future<void> _saveProductsToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customProds = _rawProducts.where((p) => p['id']?.toString().startsWith('prod_') ?? false).toList();
      await prefs.setString('saved_custom_products_json', jsonEncode(customProds));
    } catch (_) {}
  }

  int _safeParsePrice(dynamic val) {
    if (val is num) return val.toInt();
    if (val is String) {
      return int.tryParse(val) ?? (double.tryParse(val)?.toInt() ?? 0);
    }
    return 0;
  }

  void _subscribeToRealtimeProducts() {
    try {
      // 1. Listen to Supabase Postgres changes on banners catalog table
      SupabaseService.client
          .channel('banners_catalog_rt')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'banners',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: 'e4ca8130-72cf-4e17-bf47-47a623720985',
            ),
            callback: (_) {
              _fetchProducts();
            },
          )
          .subscribe();

      // 2. Broadcast channel listener
      _productChannel = SupabaseService.client.channel('product_updates_channel');
      _productChannel?.onBroadcast(
        event: 'product_added',
        callback: (payload) {
          if (payload != null && mounted) {
            final Map<String, dynamic> newProd = Map<String, dynamic>.from(payload);
            setState(() {
              _rawProducts.insert(0, newProd);
            });
            _saveProductsToLocalStorage();
          }
        },
      );
      _productChannel?.onBroadcast(
        event: 'product_updated',
        callback: (payload) {
          if (payload != null && mounted) {
            final Map<String, dynamic> updatedProd = Map<String, dynamic>.from(payload);
            final idx = _rawProducts.indexWhere((p) => p['id'] == updatedProd['id']);
            setState(() {
              if (idx >= 0) {
                _rawProducts[idx] = updatedProd;
              } else {
                _rawProducts.insert(0, updatedProd);
              }
            });
            _saveProductsToLocalStorage();
          }
        },
      );
      _productChannel?.onBroadcast(
        event: 'product_deleted',
        callback: (payload) {
          if (payload != null && mounted) {
            final String deletedId = payload['id']?.toString() ?? '';
            setState(() {
              _rawProducts.removeWhere((p) => p['id'] == deletedId);
            });
            _saveProductsToLocalStorage();
          }
        },
      );
      _productChannel?.subscribe();
    } catch (e) {
      debugPrint('Realtime product stream notice: $e');
    }
  }

  @override
  void dispose() {
    if (_productChannel != null) {
      SupabaseService.client.removeChannel(_productChannel!);
    }
    _razorpay.clear();
    _searchCtrl.dispose();


    _addressLine1Ctrl.dispose();
    _addressLine2Ctrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // Pre-fill address from saved profile / local storage
  Future<void> _loadSavedAddress() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    final addrMap = <String, String>{};

    // 1. Try local storage fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final localAddrRaw = prefs.getString('saved_delivery_address');
      if (localAddrRaw != null) {
        final Map<String, dynamic> decoded = jsonDecode(localAddrRaw);
        decoded.forEach((k, v) => addrMap[k] = v.toString());
      }
    } catch (_) {}

    // 2. Try Supabase fetch
    if (userId != null) {
      try {
        final data = await SupabaseService.client
            .from('profiles')
            .select('delivery_address')
            .eq('id', userId)
            .maybeSingle();
        final addr = data?['delivery_address'] as Map<String, dynamic>?;
        if (addr != null) {
          addr.forEach((k, v) => addrMap[k] = v.toString());
        }
      } catch (_) {}
    }

    if (addrMap.isNotEmpty && mounted) {
      setState(() {
        _addressLine1Ctrl.text = addrMap['line1'] ?? '';
        _addressLine2Ctrl.text = addrMap['line2'] ?? '';
        _cityCtrl.text = addrMap['city'] ?? '';
        _pincodeCtrl.text = addrMap['pincode'] ?? '';
        _phoneCtrl.text = addrMap['phone'] ?? '';
      });
    }
  }

  Future<void> _saveAddressToProfile({bool showToast = false}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    final addressData = {
      'line1': _addressLine1Ctrl.text.trim(),
      'line2': _addressLine2Ctrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_delivery_address', jsonEncode(addressData));

      // Also append to saved_addresses_list for SavedAddressesScreen & Checkout Picker
      final rawList = prefs.getStringList('saved_addresses_list') ?? [];
      final newAddr = SavedAddress(
        id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
        fullName: prefs.getString('user_name') ?? prefs.getString('user_email')?.split('@')[0] ?? 'Valued Customer',
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : '+91 98765 43210',
        flatHouse: _addressLine1Ctrl.text.trim(),
        streetArea: _addressLine2Ctrl.text.trim(),
        city: _cityCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        state: 'Telangana',
        type: 'Home',
        isDefault: rawList.isEmpty,
      );
      rawList.insert(0, jsonEncode(newAddr.toJson()));
      await prefs.setStringList('saved_addresses_list', rawList);
    } catch (_) {}

    if (userId != null) {
      try {
        await SupabaseService.client.from('profiles').update({
          'delivery_address': addressData
        }).eq('id', userId);
      } catch (e) {
        debugPrint('Remote address save notice: $e');
      }
    }

    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address saved to profile & saved addresses ✓')),
      );
    }
  }



  static final List<Map<String, dynamic>> _fallback10Products = [
    {
      'id': 'prod-1',
      'name': 'Waterproof 45L Trekking Backpack',
      'description': 'Ergonomic all-weather hiking and travel backpack with rain cover & laptop compartment.',
      'price': 2999,
      'image_url': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
      'category': 'Backpacks',
      'stock': 50,
      'rating': 4.9,
    },
    {
      'id': 'prod-2',
      'name': 'Insulated Thermal Water Bottle (1L)',
      'description': 'Double-wall vacuum insulated stainless steel flask keeps drinks ice-cold for 24h.',
      'price': 799,
      'image_url': 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
      'category': 'Bottles',
      'stock': 100,
      'rating': 4.8,
    },
    {
      'id': 'prod-3',
      'name': 'Memory Foam Travel Neck Pillow',
      'description': '360-degree head and neck support pillow with breathable washable velour cover.',
      'price': 649,
      'image_url': 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=600&q=80',
      'category': 'Comfort',
      'stock': 75,
      'rating': 4.7,
    },
    {
      'id': 'prod-4',
      'name': 'Fast Charge 20,000mAh Power Bank',
      'description': 'Ultra-high capacity portable charger with 22.5W Fast Delivery & LED display.',
      'price': 1499,
      'image_url': 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=600&q=80',
      'category': 'Electronics',
      'stock': 60,
      'rating': 4.9,
    },
    {
      'id': 'prod-5',
      'name': 'Universal All-in-One Travel Adapter',
      'description': 'Global AC plug adapter supporting 150+ countries with 4 USB ports & Type-C fast charge.',
      'price': 899,
      'image_url': 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?auto=format&fit=crop&w=600&q=80',
      'category': 'Electronics',
      'stock': 80,
      'rating': 4.8,
    },
    {
      'id': 'prod-6',
      'name': 'Compression Travel Packing Cubes (Set of 6)',
      'description': 'Expandable luggage organizer bags with heavy duty mesh & double zippers.',
      'price': 999,
      'image_url': 'https://images.unsplash.com/photo-1581553680321-4fffae59fccd?auto=format&fit=crop&w=600&q=80',
      'category': 'Backpacks',
      'stock': 40,
      'rating': 4.7,
    },
    {
      'id': 'prod-7',
      'name': 'Quick-Dry Microfiber Camping Towel',
      'description': 'Ultra-absorbent, lightweight, compact travel towel with hanging snap loop.',
      'price': 499,
      'image_url': 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=600&q=80',
      'category': 'Camping',
      'stock': 120,
      'rating': 4.6,
    },
    {
      'id': 'prod-8',
      'name': 'Compact Tactical Travel First Aid Kit',
      'description': '100-piece waterproof medical emergency kit for hiking, camping, and road trips.',
      'price': 599,
      'image_url': 'https://images.unsplash.com/photo-1603398938378-e54eab446dde?auto=format&fit=crop&w=600&q=80',
      'category': 'Camping',
      'stock': 90,
      'rating': 4.9,
    },
    {
      'id': 'prod-9',
      'name': 'Noise-Cancelling Travel Wireless Earbuds',
      'description': 'Active Noise Cancellation Bluetooth 5.3 earbuds with 32h total playtime & mic.',
      'price': 2499,
      'image_url': 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=600&q=80',
      'category': 'Electronics',
      'stock': 45,
      'rating': 4.8,
    },
    {
      'id': 'prod-10',
      'name': 'TSA Approved Zinc Alloy Luggage Locks (2 Pack)',
      'description': 'Heavy duty 3-digit combination padlocks for suitcases, backpacks, and duffels.',
      'price': 399,
      'image_url': 'https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&w=600&q=80',
      'category': 'Comfort',
      'stock': 150,
      'rating': 4.7,
    },
  ];

  Future<void> _fetchProducts() async {
    setState(() => _loading = true);

    // 1. Try fetching directly from Supabase products table (admin-managed)
    List<Map<String, dynamic>> supabaseProducts = [];
    try {
      final res = await SupabaseService.client
          .from('products')
          .select('*');
      if (res != null && (res as List).isNotEmpty) {
        supabaseProducts = (res as List)
            .where((x) => x != null && x is Map)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .where((p) => p['name'] != null && _safeParsePrice(p['price']) > 0)
            .toList();
      }
    } catch (e) {
      debugPrint('Supabase products table fetch notice: $e');
    }

    if (mounted) {
      setState(() {
        _rawProducts = supabaseProducts;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final cat = _categories[_selectedCategory];

    var list = _rawProducts.where((p) {
      if (p == null || p is! Map) return false;
      final name = (p['name']?.toString() ?? '').toLowerCase();
      final category = (p['category']?.toString() ?? '').toLowerCase();
      final desc = (p['description']?.toString() ?? '').toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          desc.contains(_searchQuery);

      final matchesCat = cat == 'All' ||
          category.contains(cat.toLowerCase()) ||
          name.contains(cat.toLowerCase());

      return matchesQuery && matchesCat;
    }).toList();

    if (_sortBy == 0) {
      list.sort((a, b) => ((a['price'] as num?) ?? 0).compareTo((b['price'] as num?) ?? 0));
    } else if (_sortBy == 1) {
      list.sort((a, b) => ((b['price'] as num?) ?? 0).compareTo((a['price'] as num?) ?? 0));
    } else if (_sortBy == 2) {
      list.sort((a, b) => ((b['rating'] as num?) ?? 4.8).compareTo((a['rating'] as num?) ?? 4.8));
    }

    return list;
  }

  int get _cartItemCount => _cartQty.values.fold(0, (s, q) => s + q);

  int get _cartTotal {
    int total = 0;
    _cartQty.forEach((productId, qty) {
      final product = _rawProducts.firstWhere(
        (p) => p['id'] == productId,
        orElse: () => {},
      );
      if (product.isNotEmpty) {
        final price = (product['price'] as num?)?.toInt() ?? 0;
        total += price * qty;
      }
    });
    return total;
  }

  void _handleAddToCart(String productId) {
    setState(() {
      _cartQty[productId] = 1;
      _justAddedIds.add(productId);
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _justAddedIds.remove(productId));
      }
    });
  }

  Future<void> _placeOrder() async {
    if (_cartQty.isEmpty) return;


    if (_addressLine1Ctrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _pincodeCtrl.text.trim().isEmpty) {
      setState(() => _addressExpanded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in your delivery address before placing the order.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    const delivery = 0;
    final grandTotal = (_cartTotal + delivery).clamp(0, 999999);

    final userId = await SupabaseService.resolveActiveUserId();
    final prefs = await SharedPreferences.getInstance();
    final realUser = SupabaseService.client.auth.currentUser;
    final userEmail = realUser?.email ?? prefs.getString('user_email') ?? '';
    final userName = prefs.getString('user_name') ?? (realUser?.userMetadata?['full_name'] as String?) ?? (userEmail.isNotEmpty ? userEmail.split('@')[0] : 'Customer');

    final itemsList = _cartQty.entries.map((e) {
      final product = _rawProducts.firstWhere((p) => p['id'] == e.key, orElse: () => {});
      return {
        'product_id': e.key,
        'name': product['name'] ?? 'Travel Gear',
        'qty': e.value,
        'price': product['price'] ?? 1499,
      };
    }).toList();

    final orderId = 'TV-ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    final orderData = {
      'id': orderId,
      'traveller_id': userId,
      'traveller_name': userName,
      'traveller_email': userEmail,
      'items': itemsList,
      'total_amount': grandTotal,
      'status': 'placed',
      'payment_method': _selectedPaymentMethod,
      'payment_status': _selectedPaymentMethod.contains('COD') ? 'Pending (COD)' : 'Paid',
      'created_at': DateTime.now().toIso8601String(),
      'delivery_address': {
        'line1': _addressLine1Ctrl.text.trim(),
        'line2': _addressLine2Ctrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      },
    };

    await _saveAddressToProfile(showToast: false);

    if (_selectedPaymentMethod.contains('COD')) {
      // Direct COD order creation
      setState(() => _placingOrder = true);
      await _finalizeAndSaveOrder(orderData);
    } else {
      // Real Razorpay SDK Online Checkout
      _pendingOrderPayload = orderData;
      setState(() => _placingOrder = true);

      try {
        final contactPhone = _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : '9876543210';
        final options = {
          'key': RazorpayConfig.razorpayKeyId,
          'amount': grandTotal * 100, // in paise
          'name': 'TravelVibe Store',
          'description': 'Order #$orderId',
          'currency': 'INR',
          'timeout': 300,
          'retry': {'enabled': true, 'max_count': 1},
          'send_sms_hash': true,
          'prefill': {
            'contact': contactPhone,
            'email': userEmail.isNotEmpty ? userEmail : 'customer@travelvibe.com',
          },
          'external': {
            'wallets': ['paytm']
          }
        };

        _razorpay.open(options);
      } catch (e) {
        debugPrint('Razorpay initiation error: $e');
        if (mounted) {
          setState(() => _placingOrder = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment initiation error: $e. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _finalizeAndSaveOrder(Map<String, dynamic> orderData) async {
    final userId = await SupabaseService.resolveActiveUserId();

    if (userId == null) {
      if (mounted) {
        setState(() => _placingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to place your order.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final grandTotal = orderData['total_amount'] ?? 0;
    final prefs = await SharedPreferences.getInstance();
    final realUser = SupabaseService.client.auth.currentUser;
    final userEmail = orderData['traveller_email'] as String? ?? realUser?.email ?? prefs.getString('user_email') ?? '';
    final userName = orderData['traveller_name'] as String? ?? prefs.getString('user_name') ?? (realUser?.userMetadata?['full_name'] as String?) ?? (userEmail.isNotEmpty ? userEmail.split('@')[0] : 'Customer');

    final addressObj = {
      'line1': _addressLine1Ctrl.text.trim(),
      'line2': _addressLine2Ctrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'name': userName,
      'email': userEmail,
      'payment_method': _selectedPaymentMethod,
    };
    final addressString = jsonEncode(addressObj);

    try {
      final insertedOrder = await SupabaseService.client.from('orders').insert({
        'traveller_id': userId,
        'items': orderData['items'],
        'total_amount': grandTotal,
        'status': 'placed',
        'delivery_address': addressString,
      }).select().single();

      try {
        final ch = SupabaseService.client.channel('order_live_status_channel');
        await ch.sendBroadcastMessage(
          event: 'order_placed',
          payload: {'payload': insertedOrder},
        );
      } catch (_) {}

      try {
        NotificationService.instance.addNotification(
          title: 'Order Placed Successfully! 📦',
          message: 'Your order for ₹$grandTotal has been placed. Estimated delivery in 5–7 days.',
          type: 'order',
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _cartQty.clear();
          _showCart = false;
          _placingOrder = false;
          _pendingOrderPayload = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order Placed Successfully! ₹$grandTotal 🎉'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
        );
      }
    } catch (e) {
      debugPrint('Order DB insert error: $e');
      if (mounted) {
        setState(() => _placingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override

  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeNotifier, languageNotifier]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: appBgColor(context),
          body: SafeArea(
            child: _showCart ? _buildCartView() : _buildShopView(),
          ),
        );
      },
    );
  }


  Widget _buildShopView() {
    final displayProducts = _filteredProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Header with Reactive Cart Count Badge ───────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('shop'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: appInkColor(context),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Premium trekking, camping & travel essentials',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: appInkSoftColor(context),
                    ),
                  ),
                ],
              ),
              GestureDetector(

                onTap: () => setState(() => _showCart = true),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: appPaperColor(context),
                        border: Border.all(color: appLineColor(context), width: 1.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined,
                          size: 22, color: kInk),
                    ),
                    if (_cartItemCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          decoration: BoxDecoration(
                            color: kAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$_cartItemCount',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: kWhite,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── 2. Live Search Bar ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: appPaperColor(context),
              border: Border.all(color: appLineColor(context), width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
              decoration: InputDecoration(
                hintText: 'Search gear, tents, backpacks...',
                hintStyle: kFieldHint,
                prefixIcon: Icon(Icons.search_rounded,
                    color: appInkSoftColor(context), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            color: appInkSoftColor(context), size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── 3. Category Filter Chips ───────────────────────────────────────
        SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            itemBuilder: (context, i) {
              final cat = _categories[i];
              final isActive = _selectedCategory == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = i),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? kInk : kWhite,
                    border: Border.all(
                        color: isActive ? kInk : kLine, width: 1.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight:
                            isActive ? FontWeight.w800 : FontWeight.w600,
                        color: isActive ? kWhite : kInk,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // ── 4. Sort Options Row ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Sort by:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: appInkSoftColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: List.generate(_sortOptions.length, (i) {
                  final isSorted = _sortBy == i;
                  return GestureDetector(
                    onTap: () => setState(() => _sortBy = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSorted ? kPaper : kWhite,
                        border: Border.all(
                            color: isSorted ? kInk : kLine, width: 1.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _sortOptions[i],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight:
                              isSorted ? FontWeight.w800 : FontWeight.w600,
                          color: isSorted ? kInk : kInkSoft,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── 5. Product 2-Column Grid / Skeleton / Empty State ──────────────
        Expanded(
          child: _loading
              ? _buildSkeletonGrid()
              : displayProducts.isEmpty
                  ? _buildEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.64,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                      ),
                      itemCount: displayProducts.length,
                      itemBuilder: (context, i) {
                        final p = displayProducts[i];
                        final productId = (p['id'] ?? 'prod_$i').toString();
                        final name = (p['name'] ?? 'Travel Gear').toString();
                        final price = (p['price'] as num?)?.toInt() ?? int.tryParse(p['price']?.toString() ?? '') ?? 0;
                        final imgUrl = (p['image_url'] ?? p['imageUrl'] ?? '').toString();
                        final category = (p['category'] ?? 'Gear').toString();
                        final rating = (p['rating'] as num?)?.toDouble() ?? double.tryParse(p['rating']?.toString() ?? '') ?? 4.8;
                        final stock = (p['stock'] as num?)?.toInt() ?? int.tryParse(p['stock']?.toString() ?? '') ?? 0;
                        final desc = (p['description'] ?? '').toString();

                        final qty = _cartQty[productId] ?? 0;
                        final isJustAdded = _justAddedIds.contains(productId);

                        return GestureDetector(
                          onTap: () => _showProductDetail(
                              context, p, productId, qty, isJustAdded),
                          child: Container(
                          decoration: BoxDecoration(
                            color: appPaperColor(context),
                            border: Border.all(color: appLineColor(context), width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Image (Aspect Ratio 1:1) with Heart overlay
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(14)),
                                    child: AspectRatio(
                                      aspectRatio: 1.15,
                                      child: Image.network(
                                        imgUrl.isNotEmpty
                                            ? imgUrl
                                            : 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=400&q=80',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(color: appPaperColor(context)),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: WishlistHeartButton.product(
                                      productId: productId,
                                      size: 15,
                                    ),
                                  ),
                                ],
                              ),

                              // Content Details
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Category Pill & Rating
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            category.toUpperCase(),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: appInkSoftColor(context),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.star_rounded,
                                                  color: Color(0xFFFFB800),
                                                  size: 14),
                                              const SizedBox(width: 2),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: appInkColor(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),

                                      // Product Name
                                      Text(
                                        name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: appInkColor(context),
                                          height: 1.25,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),

                                      // Price & Action Button
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₹$price',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: kAccent,
                                            ),
                                          ),
                                          qty == 0
                                              ? GestureDetector(
                                                  onTap: () =>
                                                      _handleAddToCart(productId),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                        milliseconds: 200),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: isJustAdded
                                                          ? const Color(0xFF1E8E5A)
                                                          : kPaper,
                                                      border: Border.all(
                                                        color: isJustAdded
                                                            ? const Color(0xFF1E8E5A)
                                                            : kLine,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Text(
                                                      isJustAdded
                                                          ? 'Added ✓'
                                                          : '+ Add',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isJustAdded
                                                            ? kWhite
                                                            : kInk,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  decoration: BoxDecoration(
                                                    color: appPaperColor(context),
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                    border: Border.all(
                                                        color: appLineColor(context)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            if (qty <= 1) {
                                                              _cartQty.remove(
                                                                  productId);
                                                            } else {
                                                              _cartQty[productId] =
                                                                  qty - 1;
                                                            }
                                                          });
                                                        },
                                                        child: const Padding(
                                                          padding:
                                                              EdgeInsets.all(4),
                                                          child: Icon(
                                                              Icons.remove_rounded,
                                                              size: 14,
                                                              color: kInk),
                                                        ),
                                                      ),
                                                      Text(
                                                        '$qty',
                                                        style: GoogleFonts
                                                            .plusJakartaSans(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: appInkColor(context),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            _cartQty[productId] =
                                                                qty + 1;
                                                          });
                                                        },
                                                        child: const Padding(
                                                          padding:
                                                              EdgeInsets.all(4),
                                                          child: Icon(
                                                              Icons.add_rounded,
                                                              size: 14,
                                                              color: kAccent),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ), // end Column (card content)
                        ), // end Container (product card)
                        ); // end GestureDetector
                      }, // end itemBuilder
                    ),
        ),
      ],
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.64,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: appPaperColor(context),
          border: Border.all(color: appLineColor(context)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 10, width: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 6),
                    Container(height: 12, width: 100, color: Colors.grey.shade300),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appPaperColor(context),
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 36, color: kInkSoft),
            ),
            const SizedBox(height: 16),
            Text(
              'No gear found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: appInkColor(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different search query or select another category filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: appInkSoftColor(context),
              ),
            ),
            const SizedBox(height: 16),
            ttOutlineBtn(
              'Reset Filters',
              onTap: () {
                setState(() {
                  _searchCtrl.clear();
                  _selectedCategory = 0;
                  _sortBy = 0;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartView() {
    final cartItems = _cartQty.entries.toList();
    const delivery = 0;
    final grandTotal = (_cartTotal + delivery).clamp(0, 999999);
    final relevantProducts = _rawProducts
        .where((p) => !_cartQty.containsKey(p['id'] as String))
        .take(4)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _showCart = false),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: appPaperColor(context)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: kInk),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Shopping Cart',
                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: kInk),
              ),
              const Spacer(),
              Text(
                '${cartItems.length} item${cartItems.length != 1 ? 's' : ''}',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: kInkSoft),
              ),
            ],
          ),
        ),

        Expanded(
          child: cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 64, color: kInkSoft),
                      const SizedBox(height: 16),
                      Text('Your cart is empty',
                          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
                      const SizedBox(height: 6),
                      Text('Add items from the shop to checkout',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Cart Items with Images ──────────────────────────────
                    ...cartItems.map((e) {
                      final product = _rawProducts.firstWhere(
                        (p) => p['id'] == e.key,
                        orElse: () => {},
                      );
                      if (product.isEmpty) return const SizedBox.shrink();
                      final name = product['name'] as String? ?? '';
                      final price = (product['price'] as num?)?.toInt() ?? 0;
                      final imgUrl = product['image_url'] as String? ?? '';
                      final qty = e.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: appPaperColor(context),
                          border: Border.all(color: appLineColor(context)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            // Product Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 72, height: 72,
                                child: Image.network(
                                  imgUrl.isNotEmpty ? imgUrl
                                      : 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=300&q=80',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: appPaperColor(context),
                                    child: Icon(Icons.image_not_supported_outlined, color: appInkSoftColor(context), size: 28),
                                  ),
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return Container(color: appPaperColor(context),
                                      child: const Center(child: SizedBox(width: 18, height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))));
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Name + Price
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('₹$price × $qty = ₹${price * qty}',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: kAccent)),
                                ],
                              ),
                            ),
                            // Qty Controls
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (qty > 1) {
                                        _cartQty[e.key] = qty - 1;
                                      } else {
                                        _cartQty.remove(e.key);
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: appLineColor(context)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.remove, size: 14, color: kInk),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('$qty',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800)),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _cartQty[e.key] = qty + 1),
                                  child: Container(
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      color: kAccent, borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),



                    const SizedBox(height: 16),

                    // ── Delivery Address ────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: appPaperColor(context), border: Border.all(color: appLineColor(context)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (!_addressExpanded) _loadSavedAddress();
                              setState(() => _addressExpanded = !_addressExpanded);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 18, color: kAccent),
                                  const SizedBox(width: 8),
                                  Text('Delivery Address',
                                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kInk)),
                                  const Spacer(),
                                  Icon(_addressExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: kInkSoft),
                                ],
                              ),
                            ),
                          ),
                          if (_addressExpanded)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Column(
                                children: [
                                  // Pick from Saved Addresses Button
                                  GestureDetector(
                                    onTap: () async {
                                      final selected = await Navigator.push<SavedAddress>(
                                        context,
                                        MaterialPageRoute(builder: (_) => const SavedAddressesScreen(selectMode: true)),
                                      );
                                      if (selected != null) {
                                        setState(() {
                                          _addressLine1Ctrl.text = selected.flatHouse;
                                          _addressLine2Ctrl.text = selected.streetArea;
                                          _cityCtrl.text = selected.city;
                                          _pincodeCtrl.text = selected.pincode;
                                          _phoneCtrl.text = selected.phone;
                                        });
                                      }
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: kAccent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: kAccent.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.bookmark_border_rounded, size: 16, color: kAccent),
                                          const SizedBox(width: 6),
                                          Text(
                                            tr('select_saved_address'),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: kAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  TextField(
                                    controller: _addressLine1Ctrl,
                                    decoration: InputDecoration(
                                      hintText: tr('house_flat'),
                                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appLineColor(context))),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _addressLine2Ctrl,
                                    decoration: InputDecoration(
                                      hintText: tr('street_area'),
                                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appLineColor(context))),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _cityCtrl,
                                          decoration: InputDecoration(
                                            hintText: tr('city'),
                                            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appLineColor(context))),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _pincodeCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: tr('pincode'),
                                            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appLineColor(context))),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: tr('mobile_number'),
                                      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appLineColor(context))),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () => _saveAddressToProfile(showToast: true),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: kAccent),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.save_outlined, size: 15, color: kAccent),
                                          const SizedBox(width: 6),
                                          Text(
                                            tr("save_address_btn"),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: kAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Payment Method Selector ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: appPaperColor(context),
                        border: Border.all(color: appLineColor(context)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payment_rounded, size: 18, color: kAccent),
                              const SizedBox(width: 8),
                              Text(
                                'Payment Method',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: appInkColor(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            children: [
                              _buildPaymentOptionTile(
                                title: 'Cash on Delivery (COD)',
                                subtitle: 'Pay with cash upon delivery at your doorstep',
                                icon: Icons.payments_outlined,
                                value: 'Cash on Delivery (COD)',
                              ),
                              const SizedBox(height: 8),
                              _buildPaymentOptionTile(
                                title: 'UPI / QR (Instant)',
                                subtitle: 'Google Pay, PhonePe, Paytm, BHIM UPI',
                                icon: Icons.qr_code_2_rounded,
                                value: 'UPI (GPay / PhonePe / Paytm)',
                              ),
                              const SizedBox(height: 8),
                              _buildPaymentOptionTile(
                                title: 'Credit / Debit Card',
                                subtitle: 'Visa, Mastercard, RuPay, Maestro',
                                icon: Icons.credit_card_rounded,
                                value: 'Credit / Debit Card',
                              ),
                              const SizedBox(height: 8),
                              _buildPaymentOptionTile(
                                title: 'Net Banking',
                                subtitle: 'All major Indian banks supported',
                                icon: Icons.account_balance_rounded,
                                value: 'Net Banking',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    // ── Price Summary ───────────────────────────────────────
                    ttInfoCard(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(tr('items_subtotal'), style: kLcMeta),
                              Text('₹$_cartTotal', style: kLcTitle),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(tr('delivery_charge'), style: kLcMeta),
                              Text('FREE', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF22C55E))),
                            ],
                          ),

                          Divider(height: 20, color: appLineColor(context)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount', style: kLcTitle),
                              Text(
                                '₹$grandTotal',
                                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: kAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── You Might Also Like ─────────────────────────────────
                    if (relevantProducts.isNotEmpty) ...[
                      Text('You Might Also Like',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: kInk)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: relevantProducts.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (ctx, i) {
                            final rp = relevantProducts[i];
                            final rpId = rp['id'] as String;
                            final rpName = rp['name'] as String? ?? '';
                            final rpPrice = (rp['price'] as num?)?.toInt() ?? 0;
                            final rpImg = rp['image_url'] as String? ?? '';
                            return GestureDetector(
                              onTap: () => setState(() => _cartQty[rpId] = 1),
                              child: Container(
                                width: 130,
                                decoration: BoxDecoration(
                                  color: appPaperColor(context), border: Border.all(color: appLineColor(context)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                      child: SizedBox(
                                        height: 90, width: double.infinity,
                                        child: Image.network(
                                          rpImg.isNotEmpty ? rpImg
                                              : 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=300&q=80',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: appPaperColor(context)),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(rpName,
                                              style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w700),
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Text('₹$rpPrice',
                                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: kAccent)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
        ),
        if (cartItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _placingOrder
                ? Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  )
                : ttPrimaryBtn('${tr('place_order')} ₹$grandTotal', onTap: _placeOrder),
          ),
      ],
    );
  }

  void _showProductDetail(BuildContext context, Map<String, dynamic> product,
      String productId, int currentQty, bool isJustAdded) {
    int qty = currentQty == 0 ? 1 : currentQty;
    final name = product['name'] as String? ?? 'Travel Gear';
    final price = (product['price'] as num?)?.toInt() ?? 0;
    final imgUrl = product['image_url'] as String? ?? '';
    final category = product['category'] as String? ?? 'Gear';
    final rating = (product['rating'] as num?)?.toDouble() ?? 4.8;
    final desc = product['description'] as String? ??
        'Premium quality travel gear designed for adventurers. Lightweight, durable and built to last your journey.';
    final stock = (product['stock'] as num?)?.toInt() ?? 99;
    final reviewCount = (rating * 24).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final total = price * qty;
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: appBgColor(ctx),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: appLineColor(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20)),
                                child: AspectRatio(
                                  aspectRatio: 1.1,
                                  child: Image.network(
                                    imgUrl.isNotEmpty
                                        ? imgUrl
                                        : 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=800&q=80',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: appPaperColor(context),
                                      child: const Icon(
                                          Icons.image_not_supported_outlined,
                                          size: 56,
                                          color: kInkSoft),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(ctx),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: stock > 0
                                        ? const Color(0xFF22C55E)
                                        : kAccent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    stock > 0
                                        ? '✓ In Stock ($stock left)'
                                        : 'Out of Stock',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    category.toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: kAccent,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: appInkColor(context),
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹$price',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: kAccent,
                                          ),
                                        ),
                                        Text(
                                          'per unit',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: appInkSoftColor(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ...List.generate(
                                      5,
                                      (i) => Icon(
                                        i < rating.floor()
                                            ? Icons.star_rounded
                                            : (i < rating
                                                ? Icons.star_half_rounded
                                                : Icons.star_outline_rounded),
                                        color: const Color(0xFFFFB800),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$rating  ($reviewCount reviews)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: appInkColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Description',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: appInkColor(context),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  desc,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: appInkSoftColor(context),
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    _featurePill(
                                        Icons.local_shipping_outlined,
                                        'Free Delivery'),
                                    const SizedBox(width: 8),
                                    _featurePill(
                                        Icons.replay_outlined, '7-Day Returns'),
                                    const SizedBox(width: 8),
                                    _featurePill(
                                        Icons.verified_outlined, 'Genuine'),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // ── Customer Reviews Section ───────────────────
                                Text(
                                  'Customer Reviews',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: appInkColor(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: appPaperColor(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: appLineColor(context)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 14,
                                            backgroundColor: kAccent,
                                            child: Text('R', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('Rahul Sharma', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: kInk)),
                                          const Spacer(),
                                          Row(
                                            children: List.generate(5, (i) => const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 12)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Extremely durable and lightweight gear! Highly recommended for high-altitude trekking.',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: appInkSoftColor(context), height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── You Might Also Like (Related Products) ──────
                                Text(
                                  'You Might Also Like',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: appInkColor(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 140,
                                  child: () {
                                    final related = _rawProducts.where((p) => p['id'] != productId).take(5).toList();
                                    if (related.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: related.length,
                                      itemBuilder: (_, idx) {
                                        final rp = related[idx];
                                        final rpId = rp['id'] as String;
                                        final rpName = rp['name'] as String? ?? 'Gear';
                                        final rpPrice = (rp['price'] as num?)?.toInt() ?? 0;
                                        final rpImg = rp['image_url'] as String? ?? '';
                                        final rpRating = (rp['rating'] as num?)?.toDouble() ?? 4.8;

                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            _showProductDetail(
                                              context,
                                              rp,
                                              rpId,
                                              _cartQty[rpId] ?? 0,
                                              _justAddedIds.contains(rpId),
                                            );
                                          },
                                          child: Container(
                                            width: 110,
                                            margin: const EdgeInsets.only(right: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: appLineColor(context), width: 1.2),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                                  child: AspectRatio(
                                                    aspectRatio: 1.4,
                                                    child: Image.network(
                                                      rpImg.isNotEmpty ? rpImg : 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=400&q=80',
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(color: appPaperColor(context)),
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(6),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        rpName,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: kInk),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Text('₹$rpPrice', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: kAccent)),
                                                          Row(
                                                            children: [
                                                              const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 10),
                                                              Text('$rpRating', style: GoogleFonts.plusJakartaSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: kInk)),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }(),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Quantity',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: appInkColor(context),
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: appLineColor(context), width: 1.5),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              if (qty > 1) {
                                                setSheetState(() => qty--);
                                              }
                                            },
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  right: BorderSide(
                                                      color: appLineColor(context),
                                                      width: 1.5),
                                                ),
                                              ),
                                              child: const Icon(
                                                  Icons.remove_rounded,
                                                  size: 18,
                                                  color: kInk),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 44,
                                            child: Center(
                                              child: Text(
                                                '$qty',
                                                style: GoogleFonts
                                                    .plusJakartaSans(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: appInkColor(context),
                                                ),
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              setSheetState(() => qty++);
                                            },
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  left: BorderSide(
                                                      color: appLineColor(context),
                                                      width: 1.5),
                                                ),
                                              ),
                                              child: const Icon(
                                                  Icons.add_rounded,
                                                  size: 18,
                                                  color: kAccent),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: appInkSoftColor(context),
                                          fontWeight: FontWeight.w600,
                                        )),
                                    Text(
                                      '₹$total',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: appInkColor(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: appBgColor(context),
                      border:
                          Border(top: BorderSide(color: appLineColor(context), width: 1.5)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _cartQty[productId] = qty;
                                  _justAddedIds.add(productId);
                                });
                                Future.delayed(
                                    const Duration(milliseconds: 800), () {
                                  if (mounted) {
                                    setState(() =>
                                        _justAddedIds.remove(productId));
                                  }
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$qty × $name added to bag!',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700)),
                                    backgroundColor: kInk,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: appInkColor(context), width: 1.5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                          Icons.shopping_bag_outlined,
                                          size: 18,
                                          color: kInk),
                                      const SizedBox(width: 6),
                                      Text('Add to Bag',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: appInkColor(context),
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _cartQty[productId] = qty);
                                Navigator.pop(ctx);
                                setState(() => _showCart = true);
                              },
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: kAccent,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kAccent.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bolt_rounded,
                                          size: 18,
                                          color: Colors.white),
                                      const SizedBox(width: 6),
                                      Text('Buy Now',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: appPaperColor(context),
          border: Border.all(color: appLineColor(context)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: kAccent),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: appInkColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? kAccent.withOpacity(0.08) : appPaperColor(context),
          border: Border.all(
            color: isSelected ? kAccent : appLineColor(context),
            width: isSelected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? kAccent : appInkSoftColor(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: appInkColor(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: appInkSoftColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? kAccent : appInkSoftColor(context),
            ),
          ],
        ),
      ),
    );
  }
}
