import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';
import 'order_tracking_screen.dart';
import 'trip_detail_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _shopOrders = [];
  List<Map<String, dynamic>> _agentBookings = [];
  bool _loading = true;
  RealtimeChannel? _bannersSub;
  RealtimeChannel? _broadcastSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserOrdersAndBookings();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bannersSub?.unsubscribe();
    _broadcastSub?.unsubscribe();
    _bookingsSub?.unsubscribe();
    _ordersSub?.unsubscribe();
    super.dispose();
  }

  RealtimeChannel? _bookingsSub;
  RealtimeChannel? _ordersSub;

  void _subscribeRealtime() async {
    final userId = await SupabaseService.resolveActiveUserId();
    if (userId == null) return;

    try {
      // 1. Listen to Realtime changes on bookings table specifically for this user
      _bookingsSub = SupabaseService.client
          .channel('user_bookings_rt_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bookings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'traveller_id',
              value: userId,
            ),
            callback: (_) {
              if (mounted) _loadUserOrdersAndBookings();
            },
          )
          .subscribe();

      // 2. Listen to Realtime changes on orders table specifically for this user
      _ordersSub = SupabaseService.client
          .channel('user_orders_rt_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'traveller_id',
              value: userId,
            ),
            callback: (_) {
              if (mounted) _loadUserOrdersAndBookings();
            },
          )
          .subscribe();

      // 3. Listen to Realtime broadcast status updates from Admin Console
      _broadcastSub = SupabaseService.client.channel('order_live_status_channel');
      _broadcastSub?.onBroadcast(
        event: 'order_status_updated',
        callback: (payload) {
          if (payload != null && mounted) {
            _loadUserOrdersAndBookings();
          }
        },
      );
      _broadcastSub?.subscribe();
    } catch (_) {}
  }

  Future<void> _loadUserOrdersAndBookings() async {
    final userId = await SupabaseService.resolveActiveUserId();

    if (userId == null) {
      if (mounted) {
        setState(() {
          _shopOrders = [];
          _agentBookings = [];
          _loading = false;
        });
      }
      return;
    }

    try {
      List<Map<String, dynamic>> orders = [];
      List<Map<String, dynamic>> bookings = [];

      try {
        final ordRes = await SupabaseService.client
            .from('orders')
            .select('*')
            .eq('traveller_id', userId)
            .order('created_at', ascending: false);
        if (ordRes != null) {
          orders = List<Map<String, dynamic>>.from(ordRes);
        }
      } catch (e) {
        debugPrint('Fetch orders error: $e');
      }

      try {
        final bkRes = await SupabaseService.client
            .from('bookings')
            .select('*, agent_details(profiles(full_name))')
            .eq('traveller_id', userId)
            .order('created_at', ascending: false);
        if (bkRes != null) {
          bookings = List<Map<String, dynamic>>.from(bkRes);
        }
      } catch (e) {
        debugPrint('Fetch bookings error: $e');
      }

      if (mounted) {
        setState(() {
          _shopOrders = orders;
          _agentBookings = bookings;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load orders/bookings error: $e');
      if (mounted) {
        setState(() {
          _shopOrders = [];
          _agentBookings = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: appInkColor(context), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Orders & Bookings',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: appInkColor(context),
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF7300),
          unselectedLabelColor: appInkSoftColor(context),
          indicatorColor: const Color(0xFFFF7300),
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Gear Orders'),
            Tab(text: 'Guide Bookings'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7300)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(_shopOrders, isGear: true),
                _buildOrdersList(_agentBookings, isGear: false),
              ],
            ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> items, {required bool isGear}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7300).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGear ? Icons.shopping_bag_outlined : Icons.calendar_today_rounded,
                color: const Color(0xFFFF7300),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isGear ? 'No Shop Orders Yet' : 'No Guide Bookings Yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: appInkColor(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isGear
                  ? 'Your purchased travel gear will appear here'
                  : 'Your booked local guide itineraries will appear here',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: appInkSoftColor(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = items[index];
        final orderId = item['id'] as String? ?? 'ORD-${index + 100}';
        final status = item['status'] as String? ?? 'confirmed';
        final total = item['total_amount'] ?? item['total_price'] ?? 0;
        final date = item['created_at'] != null
            ? DateTime.tryParse(item['created_at']) ?? DateTime.now()
            : DateTime.now();

        final title = isGear
            ? 'Travel Gear Order (#$orderId)'
            : 'Guide Booking: ${item['agent_name'] ?? 'Local Guide'}';

        final subtitle = isGear
            ? 'Total Items: ${(item['items'] as List?)?.length ?? 1} • Placed on ${date.day}/${date.month}/${date.year}'
            : 'Dates: ${item['start_date'] ?? 'Upcoming'} to ${item['end_date'] ?? ''}';

        final payMethod = item['payment_method']?.toString() ?? 'COD';

        return GestureDetector(
          onTap: () {
            if (isGear) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderTrackingScreen(
                    orderId: orderId,
                    orderData: item,
                  ),
                ),
              ).then((_) => _loadUserOrdersAndBookings());
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TripDetailScreen(
                    bookingData: item,
                  ),
                ),
              ).then((_) => _loadUserOrdersAndBookings());
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appPaperColor(context),
              border: Border.all(color: appLineColor(context), width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status.contains('cod') || status.contains('confirmed') || status == 'placed'
                                ? const Color(0xFF22C55E).withOpacity(0.12)
                                : const Color(0xFFFF7300).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase().replaceAll('_', ' '),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: status.contains('cod') || status.contains('confirmed') || status == 'placed'
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFFF7300),
                            ),
                          ),
                        ),
                        if (isGear) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              payMethod.contains('UPI') ? 'UPI' : (payMethod.contains('Card') ? 'CARD' : 'COD'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '₹$total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFF7300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: appInkColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: appInkSoftColor(context),
                  ),
                ),
                if (isGear) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Tap to View Order Details & Track Delivery →',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF7300),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
