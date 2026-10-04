import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/app_network_image.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _supabase = Supabase.instance.client;
  String? _bookingId;
  Map<String, dynamic>? _booking;
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingId == null) {
      final args = ModalRoute.of(context)?.settings.arguments as String?;
      if (args != null) {
        _bookingId = args;
        _fetchBooking();
        _setupRealtime();
      } else {
        setState(() => _loading = false);
      }
    }
  }

  void _setupRealtime() {
    if (_bookingId == null) return;
    _channel = _supabase.channel('public:bookings:$_bookingId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'bookings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: _bookingId!,
      ),
      callback: (payload) {
        _fetchBooking();
      }
    ).subscribe();
  }

  Future<void> _fetchBooking() async {
    try {
      final res = await _supabase.from('bookings').select('''
        *,
        agent:agent_id (
          full_name,
          photo_url
        ),
        agent_details:agent_id (
          rating_avg
        )
      ''').eq('id', _bookingId!).maybeSingle();
      
      if (mounted) {
        setState(() {
          _booking = res;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching booking detail: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _cancelBooking() async {
    try {
      await _supabase.from('bookings').update({'status': 'cancelled'}).eq('id', _bookingId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled. Refund initiated.'), backgroundColor: AppTheme.mutedRed),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.mutedRed),
        );
      }
    }
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Text('Full refund of ₹${_booking?['total_price'] ?? 0} will be credited back to your payment method within 3 business days.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep Booking')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mutedRed),
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking();
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Details')),
        body: const Center(child: Text('Booking not found.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroImageCard(context),
                        const SizedBox(height: 20),
                        _buildAgentCard(context),
                        const SizedBox(height: 20),
                        _buildItineraryCard(),
                        const SizedBox(height: 20),
                        _buildPriceBreakdownCard(),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),
                _buildBottomCTA(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.textDark.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.textDark.withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: const Icon(LucideIcons.arrowLeft, color: AppTheme.textDark, size: 20),
                ),
              ),
            ),
          ),
          const Text(
            'Trip Details',
            style: TextStyle(
              color: AppTheme.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Color(0x55000000), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildHeroImageCard(BuildContext context) {
    final statusStr = (_booking?['status'] as String? ?? 'pending').toUpperCase();
    final title = _booking?['destination'] ?? 'Destination';
    final agentPhoto = _booking?['agent']?['photo_url'] ?? 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=800';
    
    String dateRange = '';
    if (_booking?['start_date'] != null && _booking?['end_date'] != null) {
      final s = DateTime.parse(_booking!['start_date']);
      final e = DateTime.parse(_booking!['end_date']);
      final diff = e.difference(s).inDays + 1;
      dateRange = '${DateFormat('MMM dd').format(s)} - ${DateFormat('MMM dd, yyyy').format(e)} ($diff Days)';
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Stack(
              children: [
                AppNetworkImage(
                  imageUrl: agentPhoto,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.coralGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusStr,
                      style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.charcoalText),
                ),
                const SizedBox(height: 4),
                Text('Ref ID: #${_booking?['id']?.toString().substring(0, 8).toUpperCase()}', style: const TextStyle(color: AppTheme.greyText, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, color: AppTheme.oceanTeal, size: 16),
                    const SizedBox(width: 6),
                    Text(dateRange, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.charcoalText, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(BuildContext context) {
    final agentName = _booking?['agent']?['full_name'] ?? 'Agent';
    final agentPhoto = _booking?['agent']?['photo_url'] ?? 'https://ui-avatars.com/api/?name=$agentName';
    final rating = _booking?['agent_details']?['rating_avg'] ?? 5.0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AppNetworkImage(
              imageUrl: agentPhoto,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agentName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.charcoalText, fontSize: 16)),
                const SizedBox(height: 2),
                Text('Verified Local Guide • $rating ★', style: const TextStyle(color: AppTheme.greyText, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.messageCircle, color: AppTheme.oceanTeal),
            onPressed: () => Navigator.pushNamed(context, '/traveller_chat', arguments: _booking?['id']),
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryCard() {
    final notes = _booking?['admin_note'] ?? 'No specific itinerary provided.';
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tour Itinerary & Notes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.charcoalText)),
          const SizedBox(height: 10),
          Text(
            notes,
            style: const TextStyle(color: AppTheme.charcoalText, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard() {
    final total = _booking?['total_price'] ?? 0;
    
    int days = 1;
    if (_booking?['start_date'] != null && _booking?['end_date'] != null) {
      final s = DateTime.parse(_booking!['start_date']);
      final e = DateTime.parse(_booking!['end_date']);
      days = e.difference(s).inDays + 1;
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.charcoalText)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Guide Fee ($days Days)', style: const TextStyle(color: AppTheme.greyText)),
              Text('₹$total', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Paid', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('₹$total', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.oceanTeal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA(BuildContext context) {
    final statusStr = (_booking?['status'] as String? ?? 'pending');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        boxShadow: AppTheme.softShadow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          if (statusStr == 'pending' || statusStr == 'confirmed')
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.mutedRed, width: 1.5),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _showCancelDialog(context),
              child: const Text('CANCEL BOOKING', style: TextStyle(color: AppTheme.mutedRed, fontWeight: FontWeight.w800)),
            )
          else if (statusStr == 'completed')
            GradientButton(
              text: 'RATE YOUR TRIP & GUIDE',
              style: GradientButtonStyle.primaryCoral,
              onPressed: () => Navigator.pushNamed(context, '/write_review'),
            )
          else
            GradientButton(
              text: 'MESSAGE GUIDE NOW',
              style: GradientButtonStyle.primaryCoral,
              onPressed: () => Navigator.pushNamed(context, '/traveller_chat', arguments: _booking?['id']),
            ),
        ],
      ),
    );
  }
}
