import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/agent_avatar.dart';
import '../chat/agent_chat_screen.dart';

class BookingRequestDetailScreen extends StatefulWidget {
  final String bookingId;
  final bool readOnly;
  const BookingRequestDetailScreen({super.key, required this.bookingId, this.readOnly = false});

  @override
  State<BookingRequestDetailScreen> createState() => _BookingRequestDetailScreenState();
}

class _BookingRequestDetailScreenState extends State<BookingRequestDetailScreen> {
  Map<String, dynamic>? _bookingData;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    final data = await SupabaseService.instance.fetchBookingWithTraveller(widget.bookingId);
    if (!mounted) return;
    setState(() {
      _bookingData = data;
      _isLoading = false;
    });
  }

  Future<void> _handleAccept() async {
    final travellerId = _bookingData?['traveller_id'] ?? '';
    setState(() => _isProcessing = true);
    try {
      await SupabaseService.instance.updateBookingStatus(
        widget.bookingId,
        'confirmed',
        recipientUserId: travellerId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking Confirmed!'), backgroundColor: AppTheme.kGreen),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error confirming: $e'), backgroundColor: AppTheme.kAccent),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDecline() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Booking Request?'),
        content: const Text('Are you sure you want to decline this request? The traveller will be notified immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Decline Request', style: GoogleFonts.plusJakartaSans(color: AppTheme.kAccent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final travellerId = _bookingData?['traveller_id'] ?? '';
    setState(() => _isProcessing = true);
    try {
      await SupabaseService.instance.updateBookingStatus(
        widget.bookingId,
        'cancelled',
        recipientUserId: travellerId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking declined.'), backgroundColor: AppTheme.kInk),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining: $e'), backgroundColor: AppTheme.kAccent),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.kAccent)),
      );
    }

    if (_bookingData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: Text('Booking not found.')),
      );
    }

    final destination = _bookingData!['destination'] ?? 'Kerala Tour';
    final startDate = _bookingData!['start_date'] ?? '';
    final endDate = _bookingData!['end_date'] ?? '';
    final totalPrice = (_bookingData!['total_price'] ?? 0) as num;
    final status = _bookingData!['status'] ?? 'pending';

    final travellerName = _bookingData!['profiles']?['full_name'] ?? 'Alex Traveler';
    final travellerPhone = _bookingData!['profiles']?['phone'] ?? '+91 9876543210';
    final travellerPhoto = _bookingData!['profiles']?['photo_url'] ??
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300';

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: const Text('Booking Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Traveller Profile Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.kWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.kLine, width: 1.5),
              ),
              child: Row(
                children: [
                  AgentAvatar(name: travellerName, photoUrl: travellerPhoto, radius: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(travellerName, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                        Text(travellerPhone, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AgentChatScreen(
                            bookingId: widget.bookingId,
                            travellerName: travellerName,
                            travellerPhoto: travellerPhoto,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text('Message'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tour & Itemized Details Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.kWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.kLine, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tour Destination', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft)),
                  const SizedBox(height: 2),
                  Text(destination, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                  const Divider(height: 24, color: AppTheme.kLine),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoCol('Start Date', startDate),
                      _buildInfoCol('End Date', endDate),
                    ],
                  ),
                  const Divider(height: 24, color: AppTheme.kLine),

                  // Itemized Breakdown
                  Text('Itemized Request Breakdown', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                  const SizedBox(height: 10),

                  // Base Price Line
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🧭 Base Guide Service', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.kInkSoft)),
                      Text(
                        '₹${((_bookingData!['base_price'] as num?)?.toInt() ?? totalPrice.toInt())}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.kInk),
                      ),
                    ],
                  ),

                  // Selected Add-ons Lines
                  if (_bookingData!['selected_addons'] != null && (_bookingData!['selected_addons'] as List).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...(_bookingData!['selected_addons'] as List).map((addon) {
                      String icon = '🎒';
                      final cat = (addon['category'] ?? '').toString();
                      if (cat.contains('accommodat')) icon = '🏨';
                      if (cat.contains('food')) icon = '🍽️';
                      if (cat.contains('transport')) icon = '🚗';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$icon ${addon['name']}', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.kInkSoft)),
                            Text('+ ₹${addon['price_per_day']}/day', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.kAccent)),
                          ],
                        ),
                      );
                    }),
                  ],

                  if (_bookingData!['negotiated_price'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('🤝 Negotiated Chat Price', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF15803D))),
                          Text('₹${(_bookingData!['negotiated_price'] as num).toInt()}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF15803D))),
                        ],
                      ),
                    ),
                  ],

                  const Divider(height: 24, color: AppTheme.kLine),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Package Price', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800)),
                      Text('₹${totalPrice.toInt()}', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.kAccent)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Actions for Pending state
            if (status == 'pending' && !widget.readOnly) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handleAccept,
                  child: _isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.kWhite, strokeWidth: 2))
                      : const Text('Accept Booking Request'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _handleDecline,
                  child: const Text('Decline Request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCol(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
      ],
    );
  }
}
