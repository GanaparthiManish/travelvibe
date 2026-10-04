import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic>? orderData;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.orderData,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  RealtimeChannel? _subscription;
  RealtimeChannel? _broadcastSub;

  final List<String> _stages = const [
    'placed',
    'packed',
    'shipped',
    'out_for_delivery',
    'delivered'
  ];

  final Map<String, String> _stageLabels = const {
    'placed': 'Order Placed',
    'packed': 'Packed & Ready',
    'shipped': 'In Transit (Shipped)',
    'out_for_delivery': 'Out for Delivery',
    'delivered': 'Delivered',
  };

  @override
  void initState() {
    super.initState();
    if (widget.orderData != null) {
      _order = Map<String, dynamic>.from(widget.orderData!);
      _loading = false;
    }
    _fetchOrder();
    _subscribeRealtime();
  }

  Future<void> _fetchOrder() async {
    try {
      final res = await SupabaseService.client
          .from('orders')
          .select('*')
          .eq('id', widget.orderId)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _order = Map<String, dynamic>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching order: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    SupabaseService.client
        .channel('orders_tracking_rt_${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (_) {
            _fetchOrder();
          },
        )
        .subscribe();

    // 2. Realtime broadcast channel listener for instant status updates from Admin
    try {
      _broadcastSub = SupabaseService.client.channel('order_live_status_channel');
      _broadcastSub?.onBroadcast(
        event: 'order_status_updated',
        callback: (payload) {
          if (payload != null && mounted) {
            final String targetId = payload['order_id']?.toString() ?? '';
            if (targetId == widget.orderId || targetId == _order?['id']) {
              setState(() {
                _order ??= {};
                _order!['status'] = payload['status']?.toString() ?? 'placed';
              });
            }
          }
        },
      );
      _broadcastSub?.subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _broadcastSub?.unsubscribe();
    super.dispose();
  }

  int get _currentStageIndex {
    final status = (_order?['status'] as String? ?? 'placed').toLowerCase();
    final idx = _stages.indexOf(status);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final orderIdShort = widget.orderId.substring(
        0, widget.orderId.length > 12 ? 12 : widget.orderId.length);
    final totalAmount = _order?['total_amount'] ?? 0;
    final statusStr = (_order?['status'] as String? ?? 'placed').toUpperCase().replaceAll('_', ' ');
    final items = List<Map<String, dynamic>>.from(_order?['items'] ?? []);

    final paymentMethod = _order?['payment_method']?.toString() ?? 'Cash on Delivery (COD)';
    final paymentStatus = _order?['payment_status']?.toString() ?? (paymentMethod.contains('COD') ? 'Pending (COD)' : 'Paid');

    final addr = _order?['delivery_address'];
    Map<String, dynamic> deliveryAddr = {};
    if (addr is Map) {
      deliveryAddr = Map<String, dynamic>.from(addr);
    }

    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kInk, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Order #$orderIdShort', style: kAppBarTitle),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kAccent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Status Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            kAccent,
                            kAccent.withOpacity(0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: kAccent.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusStr,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                '₹$totalAmount',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Live Delivery Tracking',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Realtime status updates from merchant & courier',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 5-Stage Stepper Timeline
                    ttSectionH('Live Status Timeline'),
                    ttInfoCard(
                      child: Column(
                        children: List.generate(_stages.length, (i) {
                          final isPassed = i <= _currentStageIndex;
                          final isCurrent = i == _currentStageIndex;
                          final label = _stageLabels[_stages[i]] ?? _stages[i];

                          return Row(
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isPassed ? kAccent : kPaper,
                                      border: Border.all(
                                        color: isPassed ? kAccent : kLine,
                                        width: 2,
                                      ),
                                    ),
                                    child: isPassed
                                        ? const Icon(Icons.check_rounded,
                                            color: kWhite, size: 16)
                                        : null,
                                  ),
                                  if (i < _stages.length - 1)
                                    Container(
                                      width: 2.5,
                                      height: 32,
                                      color: i < _currentStageIndex
                                          ? kAccent
                                          : kLine,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13.5,
                                    fontWeight: isCurrent
                                        ? FontWeight.w800
                                        : (isPassed
                                            ? FontWeight.w700
                                            : FontWeight.w500),
                                    color: isPassed ? kInk : kInkSoft,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 📦 Purchased Products Details
                    ttSectionH('Purchased Items (${items.length})'),
                    ttInfoCard(
                      child: Column(
                        children: [
                          ...items.map((item) {
                            final name = item['name'] ?? 'Travel Gear';
                            final qty = item['qty'] ?? 1;
                            final price = item['price'] ?? 0;
                            final imgUrl = item['image_url']?.toString() ?? '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  if (imgUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 24, color: kAccent)),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: kAccent.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.shopping_bag_outlined, size: 22, color: kAccent),
                                    ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: appInkColor(context),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Qty: $qty • ₹$price each',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            color: appInkSoftColor(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${price * qty}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: kAccent,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          Divider(height: 20, color: appLineColor(context)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount Paid', style: kLcTitle),
                              Text(
                                '₹$totalAmount',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: kAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 💳 Payment Details
                    ttSectionH('Payment Details'),
                    ttInfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Payment Mode:', style: kLcMeta),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  paymentMethod,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Payment Status:', style: kLcMeta),
                              Text(
                                paymentStatus,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: paymentStatus.contains('Paid') ? const Color(0xFF22C55E) : const Color(0xFFFF7300),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 📍 Delivery Address
                    ttSectionH('Delivery Address'),
                    ttInfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 18, color: kAccent),
                              const SizedBox(width: 6),
                              Text(
                                'Shipping Address',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: appInkColor(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (deliveryAddr.isNotEmpty) ...[
                            Text(
                              '${deliveryAddr['line1'] ?? ''} ${deliveryAddr['line2'] ?? ''}'.trim(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: appInkColor(context),
                              ),
                            ),
                            Text(
                              '${deliveryAddr['city'] ?? ''} - ${deliveryAddr['pincode'] ?? ''}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: appInkSoftColor(context),
                              ),
                            ),
                            if (deliveryAddr['phone'] != null && deliveryAddr['phone'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Phone: ${deliveryAddr['phone']}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kAccent,
                                  ),
                                ),
                              ),
                          ] else
                            Text(
                              'Standard Express Delivery to User Saved Address',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: appInkSoftColor(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
