import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/data_service.dart';
import '../services/location_ping_service.dart';
import 'chat_screen.dart';
import 'review_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const TripDetailScreen({super.key, required this.bookingData});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Map<String, dynamic> _booking;
  Map<String, dynamic>? _lastPing;
  bool _cancelling = false;
  bool _safetyOptOut = false;
  bool _isOfflineLoaded = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.bookingData;
    _safetyOptOut = _booking['safety_opt_out'] as bool? ?? false;
    _initBookingAndPing();
  }

  Future<void> _initBookingAndPing() async {
    final bookingId = _booking['id'] as String? ?? '';
    final agentId = _booking['agent_id'] as String? ?? '';

    // Cache booking data locally for offline use
    if (bookingId.isNotEmpty) {
      await BookingOfflineCache.saveBooking(_booking);
    }

    // Try fetching fresh data from network or fallback to local cache if offline
    try {
      if (bookingId.isNotEmpty) {
        Map<String, dynamic>? freshRes;
        try {
          freshRes = await SupabaseService.client
              .from('bookings')
              .select('*, agent_details(*, profiles(*))')
              .eq('id', bookingId)
              .maybeSingle();
        } catch (_) {
          freshRes = await SupabaseService.client
              .from('bookings')
              .select('*')
              .eq('id', bookingId)
              .maybeSingle();
        }

        if (freshRes != null && mounted) {
          setState(() {
            _booking = {..._booking, ...freshRes!};
            _safetyOptOut = freshRes['safety_opt_out'] as bool? ?? false;
          });
          await BookingOfflineCache.saveBooking(_booking);
        }
      }
    } catch (e) {
      // Device is offline / in Airplane mode -> load from cache!
      if (bookingId.isNotEmpty) {
        final cached = await BookingOfflineCache.getBooking(bookingId);
        if (cached != null && mounted) {
          setState(() {
            _booking = cached;
            _isOfflineLoaded = true;
          });
        }
      }
    }

    // Fetch latest guide ping (supports local cache fallback)
    if (bookingId.isNotEmpty && agentId.isNotEmpty) {
      final ping = await LocationPingService.instance.fetchLatestPing(bookingId, agentId);
      if (mounted) {
        setState(() => _lastPing = ping);
      }
    }
  }

  Future<void> _triggerSOS() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('EMERGENCY SOS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will immediately alert TravelVibe 24/7 Safety Support and dispatch emergency alerts to your contacts. Do you need immediate emergency help?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONFIRM & ALERT SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final user = SupabaseService.client.auth.currentUser;
      final bookingId = _booking['id'] as String?;

      // Insert SOS incident
      await SupabaseService.client.from('sos_incidents').insert({
        'booking_id': bookingId,
        'triggered_by': user?.id,
        'triggered_by_role': 'traveller',
        'status': 'open',
      });

      // Broadcast alert
      try {
        final ch = SupabaseService.client.channel('sos_alert_broadcast');
        await ch.sendBroadcastMessage(
          event: 'sos_triggered',
          payload: {
            'booking_id': bookingId,
            'role': 'traveller',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (_) {}

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🚨 Emergency Dispatched', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TravelVibe Safety Team has been alerted with highest priority.'),
              const SizedBox(height: 14),
              const Text('Immediate Local Emergency Dialers:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makePhoneCall('100'),
                      icon: const Icon(Icons.local_police, color: Colors.white, size: 16),
                      label: const Text('Call 100', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makePhoneCall('112'),
                      icon: const Icon(Icons.phone_in_talk, color: Colors.white, size: 16),
                      label: const Text('Call 112', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error dispatching SOS: $e')),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calling $phoneNumber...')),
      );
    }
  }

  Future<void> _toggleSafetyOptOut(bool value) async {
    setState(() => _safetyOptOut = value);
    _booking['safety_opt_out'] = value;
    final bookingId = _booking['id'] as String?;
    if (bookingId == null) return;

    await BookingOfflineCache.saveBooking(_booking);

    try {
      await SupabaseService.client
          .from('bookings')
          .update({'safety_opt_out': value})
          .eq('id', bookingId);
    } catch (e) {
      debugPrint('Remote safety opt out notice: $e');
    }
  }

  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Trip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Trip', style: TextStyle(color: kAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _cancelling = true);
    try {
      final bookingId = _booking['id'] as String;
      final updateNote = 'REFUND_STATUS:requested | Cancelled by traveller';
      await SupabaseService.client
          .from('bookings')
          .update({'status': 'cancelled', 'admin_note': updateNote})
          .eq('id', bookingId);

      try {
        final ch = SupabaseService.client.channel('booking_live_status_channel');
        await ch.subscribe();
        await ch.sendBroadcastMessage(event: 'refund_status_updated', payload: {
          'booking_id': bookingId,
          'refund_status': 'requested',
        });
      } catch (_) {}

      if (mounted) {
        setState(() {
          _booking['status'] = 'cancelled';
          _booking['admin_note'] = updateNote;
          _cancelling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled. Refund request submitted.')),
        );
      }
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      if (mounted) setState(() => _cancelling = false);
    }
  }


  String _formatPingTime(String? raw) {
    if (raw == null) return 'No ping recorded yet';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentDetails = _booking['agent_details'] as Map<String, dynamic>? ?? {};
    final profile = agentDetails['profiles'] as Map<String, dynamic>? ?? {};
    // Fall back to flat booking fields stored by payment_screen
    final agentName = (profile['full_name'] as String?)?.isNotEmpty == true
        ? profile['full_name'] as String
        : (_booking['agent_name'] as String? ?? 'Your Guide');
    final agentPhone = (profile['phone'] as String?)?.isNotEmpty == true
        ? profile['phone'] as String
        : (_booking['agent_phone'] as String? ?? '');
    final photoUrl = (profile['photo_url'] as String?)?.isNotEmpty == true
        ? profile['photo_url'] as String
        : (_booking['agent_photo'] as String? ?? '');
    final agentId = _booking['agent_id'] as String? ?? '';
    final bookingId = _booking['id'] as String? ?? '';
    final status = _booking['status'] as String? ?? 'pending';
    final totalPrice = _booking['total_price'] ?? 0;
    final startDate = _booking['start_date'] ?? '';
    final endDate = _booking['end_date'] ?? '';
    final tripPlan = _booking['trip_plan'] as String? ?? '';
    final meetingPoint = _booking['meeting_point'] as String? ?? '';

    final isUpcoming = status == 'pending' || status == 'confirmed';
    final isCompleted = status == 'completed';

    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kInk, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text('Trip Details', style: kAppBarTitle),
            if (_isOfflineLoaded) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 12, color: Colors.amber.shade900),
                    const SizedBox(width: 4),
                    Text(
                      'Offline Mode',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _triggerSOS,
                icon: const Icon(Icons.shield_outlined, size: 14, color: Colors.white),
                label: const Text('SOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge & Ref
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Booking #${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: appInkColor(context),
                          ),
                        ),
                        ttBadge(status),
                      ],
                    ),
                    if (status == 'cancelled') ...[
                      const SizedBox(height: 14),
                      Builder(builder: (ctx) {
                        final note = (_booking['admin_note'] as String? ?? '');
                        final refStat = _booking['refund_status'] as String? ?? '';
                        final isRefunded = note.contains('REFUND_STATUS:refunded') || refStat == 'refunded';
                        final isProcessing = note.contains('REFUND_STATUS:processing') || refStat == 'processing';
                        final isDenied = note.contains('REFUND_STATUS:denied') || refStat == 'denied';

                        final title = isRefunded
                            ? 'Refund Completed (₹$totalPrice)'
                            : isProcessing
                                ? 'Refund Processing (₹$totalPrice)'
                                : isDenied
                                    ? 'Refund Denied'
                                    : 'Refund Requested (₹$totalPrice)';
                        final desc = isRefunded
                            ? 'Amount has been credited to your original payment method.'
                            : isProcessing
                                ? 'Bank transfer & payment gateway reversal in progress (1-3 business days).'
                                : isDenied
                                    ? 'This booking was not eligible for an automatic refund.'
                                    : 'Your refund request has been received and is being verified by admin.';
                        final badgeColor = isRefunded
                            ? const Color(0xFF10B981)
                            : (isDenied ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: badgeColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isRefunded
                                    ? Icons.check_circle_rounded
                                    : (isDenied ? Icons.cancel_rounded : Icons.hourglass_top_rounded),
                                color: badgeColor,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w800, fontSize: 13, color: badgeColor)),
                                    const SizedBox(height: 3),
                                    Text(desc,
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5, color: appInkColor(context).withOpacity(0.75))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),


                    // Guide Card & Direct Cell Call Button
                    ttSectionH('Your Assigned Guide'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: appPaperColor(context),
                        border: Border.all(color: appLineColor(context)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  photoUrl.isNotEmpty
                                      ? photoUrl
                                      : 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80',
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: kInkSoft),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      agentName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: appInkColor(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Verified Local Guide · $agentPhone',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: kInkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline_rounded, color: kAccent),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        bookingId: bookingId,
                                        recipientName: agentName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Direct Cellular Call Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _makePhoneCall(agentPhone),
                              icon: const Icon(Icons.call_rounded, size: 18, color: Colors.white),
                              label: Text(
                                'Call Guide ($agentPhone)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E8E5A),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Pre-Shared Trip Plan & Meeting Point (Offline Cached View)
                    ttSectionH('Trip Plan & Meeting Point'),
                    Container(
                      padding: const EdgeInsets.all(16),
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
                              const Icon(Icons.place_rounded, color: kAccent, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Meeting Point',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: kInk,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meetingPoint.isNotEmpty
                                ? meetingPoint
                                : 'To be confirmed by guide prior to departure.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: kInk,
                            ),
                          ),
                          Divider(height: 20, color: appLineColor(context)),
                          Row(
                            children: [
                              const Icon(Icons.alt_route_rounded, color: kAccent, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Pre-Shared Route / Itinerary',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: kInk,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tripPlan.isNotEmpty
                                ? tripPlan
                                : 'Guide will upload full itinerary details here before start date.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: kInkSoft,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Last Known Location Card (Guide's latest ping)
                    ttSectionH('Safety Snapshot (Dead Zone Fallback)'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.my_location_rounded, color: Color(0xFF16A34A), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Guide\'s Last Known Location',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_lastPing != null) ...[
                            Text(
                              'Last seen ${_formatPingTime(_lastPing!['captured_at'])} near:',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF15803D)),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: appPaperColor(context),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${(_lastPing!['latitude'] as num).toStringAsFixed(4)}° N, ${(_lastPing!['longitude'] as num).toStringAsFixed(4)}° E',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF166534)),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Text(
                              'No GPS ping captured yet. Pings auto-sync when guide has signal.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Safety Disclosure & Per-trip Opt-out Toggle
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Colors.blue.shade800, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Safety Fallback Disclosure',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'For your safety, we\'ll periodically save your last known location during this trip when you have signal — this isn\'t live tracking, just a safety fallback in case of emergency.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              color: Colors.blue.shade900,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Opt-out of safety location pings for this trip',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: kInk,
                                ),
                              ),
                              Switch(
                                value: _safetyOptOut,
                                activeColor: kAccent,
                                onChanged: (val) => _toggleSafetyOptOut(val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dates & Pricing Card
                    ttSectionH('Trip Schedule & Price'),
                    ttInfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Start Date', style: kStatLabel),
                              Text(startDate, style: kLcTitle),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('End Date', style: kStatLabel),
                              Text(endDate, style: kLcTitle),
                            ],
                          ),
                          Divider(height: 24, color: appLineColor(context)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Paid', style: kLcTitle),
                              Text(
                                '₹$totalPrice',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: kAccent,
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

            // Action Buttons Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appBgColor(context),
                border: Border(top: BorderSide(color: appLineColor(context), width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    if (isCompleted) ...[
                      ttPrimaryBtn(
                        'Rate Your Trip & Guide',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewScreen(
                                bookingId: bookingId,
                                agentId: agentId,
                                agentName: agentName,
                                destinationName: _booking['destination'] as String? ?? '',
                                destinationId: _booking['destination_id'] as String?,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (isUpcoming) ...[
                      _cancelling
                          ? const Center(
                              child: CircularProgressIndicator(color: kAccent))
                          : ttOutlineBtn(
                              'Cancel Booking',
                              onTap: _cancelBooking,
                              color: const Color(0xFFC0392B),
                            ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
