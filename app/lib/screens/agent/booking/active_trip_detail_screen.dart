import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/supabase_service.dart';
import '../../../services/location_ping_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/agent_avatar.dart';
import '../chat/agent_chat_screen.dart';

class ActiveTripDetailScreen extends StatefulWidget {
  final String bookingId;
  const ActiveTripDetailScreen({super.key, required this.bookingId});

  @override
  State<ActiveTripDetailScreen> createState() => _ActiveTripDetailScreenState();
}

class _ActiveTripDetailScreenState extends State<ActiveTripDetailScreen> {
  final _notesController = TextEditingController();
  final _tripPlanController = TextEditingController();
  final _meetingPointController = TextEditingController();

  Map<String, dynamic>? _bookingData;
  Map<String, dynamic>? _lastPing;
  bool _isLoading = true;
  bool _isSavingNotes = false;
  bool _isSavingSafetyInfo = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
  }

  Future<void> _loadTripDetails() async {
    final data = await SupabaseService.instance.fetchBookingWithTraveller(widget.bookingId);
    if (!mounted) return;

    if (data != null) {
      // Offline cache save
      await BookingOfflineCache.saveBooking(data);

      final travellerId = data['traveller_id'] as String? ?? '';
      if (travellerId.isNotEmpty) {
        final ping = await LocationPingService.instance.fetchLatestPing(widget.bookingId, travellerId);
        _lastPing = ping;
      }
    }

    setState(() {
      _bookingData = data;
      _notesController.text = data?['trip_notes'] ?? '';
      _tripPlanController.text = data?['trip_plan'] ?? '';
      _meetingPointController.text = data?['meeting_point'] ?? '';
      _isLoading = false;
    });
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
        SnackBar(content: Text('Calling $phoneNumber...'), backgroundColor: AppTheme.kGreen),
      );
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _isSavingNotes = true);
    try {
      await SupabaseService.instance.updateTripNotes(widget.bookingId, _notesController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip notes saved.'), backgroundColor: AppTheme.kGreen),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notes: $e'), backgroundColor: AppTheme.kAccent),
      );
    } finally {
      if (mounted) setState(() => _isSavingNotes = false);
    }
  }

  Future<void> _saveSafetyInfo() async {
    setState(() => _isSavingSafetyInfo = true);
    try {
      await SupabaseService.instance.client?.from('bookings').update({
        'trip_plan': _tripPlanController.text.trim(),
        'meeting_point': _meetingPointController.text.trim(),
      }).eq('id', widget.bookingId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pre-shared Trip Plan & Meeting Point saved! Shared with traveller.'),
          backgroundColor: AppTheme.kGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving trip plan: $e'), backgroundColor: AppTheme.kAccent),
      );
    } finally {
      if (mounted) setState(() => _isSavingSafetyInfo = false);
    }
  }

  Future<void> _markCompleted() async {
    final travellerId = _bookingData?['traveller_id'] ?? '';
    setState(() => _isCompleting = true);
    try {
      await SupabaseService.instance.updateBookingStatus(
        widget.bookingId,
        'completed',
        recipientUserId: travellerId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tour marked as Completed! Earnings added to your wallet.'), backgroundColor: AppTheme.kGreen),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating tour: $e'), backgroundColor: AppTheme.kAccent),
      );
    } finally {
      if (mounted) setState(() => _isCompleting = false);
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.kAccent)));
    }

    if (_bookingData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Tour')),
        body: const Center(child: Text('Trip not found.')),
      );
    }

    final destination = _bookingData!['destination'] ?? 'Leh Himalayan Expedition';
    final startDate = _bookingData!['start_date'] ?? '';
    final endDate = _bookingData!['end_date'] ?? '';
    final totalPrice = (_bookingData!['total_price'] ?? 0) as num;

    final travellerName = _bookingData!['profiles']?['full_name'] ?? 'Alex Traveler';
    final travellerPhone = _bookingData!['profiles']?['phone'] ?? '+91 9876543210';
    final travellerPhoto = _bookingData!['profiles']?['photo_url'] ??
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300';

    bool canComplete = true;
    if (endDate.isNotEmpty) {
      final endD = DateTime.tryParse(endDate);
      if (endD != null) {
        canComplete = DateTime.now().isAfter(endD.subtract(const Duration(hours: 12)));
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: const Text('Active Tour Itinerary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Traveller Info & Direct Call Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.kWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.kLine, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AgentAvatar(name: travellerName, photoUrl: travellerPhoto, radius: 26),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(travellerName, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                            const SizedBox(height: 2),
                            Text(travellerPhone, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft)),
                          ],
                        ),
                      ),
                      IconButton(
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
                        icon: const Icon(Icons.chat_bubble_rounded, color: AppTheme.kAccent, size: 20),
                        tooltip: 'Message',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Prominent Cellular Call Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _makePhoneCall(travellerPhone),
                      icon: const Icon(Icons.call_rounded, size: 18, color: Colors.white),
                      label: Text(
                        'Call Traveller ($travellerPhone)',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
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

            // Last Known Location Card (Traveller's ping)
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
                        'Traveller\'s Last Known Location',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF166534)),
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
                        color: Colors.white,
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
                      'No GPS ping captured yet. Pings auto-sync when traveller has signal.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '⚠️ Periodic safety snapshot for dead zones — not live tracking.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.kInkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pre-Shared Trip Plan & Meeting Point Form (Set before departure while signal exists)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.kWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.kLine, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.alt_route_rounded, color: AppTheme.kAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Pre-Shared Trip Plan & Meeting Point',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fill in before departure so the traveller can view itinerary & meeting point offline in dead zones.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.kInkSoft),
                  ),
                  const SizedBox(height: 14),

                  Text('Meeting Point Location', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _meetingPointController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Hotel Grand Dragon Lobby, Leh Main Market @ 8:00 AM',
                      prefixIcon: Icon(Icons.place_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text('Trip Plan / Route Description', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _tripPlanController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Day 1: Leh to Pangong Tso via Chang La (17,590 ft).\nDay 2: Nubra Valley & Hunder Sand Dunes...\nDay 3: Return to Leh.',
                    ),
                  ),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isSavingSafetyInfo ? null : _saveSafetyInfo,
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white),
                      label: _isSavingSafetyInfo
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Safety Plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.kAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tour Overview
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
                  Text(destination, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                  const SizedBox(height: 6),
                  Text('Tour Dates: $startDate → $endDate', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.kInkSoft)),
                  const SizedBox(height: 12),
                  Text('Total Payment: ₹${totalPrice.toInt()}', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.kGreen)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Editable Agent Internal Notes
            Text('Agent Logistics & Pickup Notes', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter internal vehicle numbers, permit details, or extra equipment notes...',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: _isSavingNotes ? null : _saveNotes,
                child: _isSavingNotes
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Logistics Notes'),
              ),
            ),
            const SizedBox(height: 32),

            // Complete Tour Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (canComplete && !_isCompleting) ? _markCompleted : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.kGreen,
                ),
                child: _isCompleting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.kWhite, strokeWidth: 2))
                    : const Text('Mark Tour as Completed'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
