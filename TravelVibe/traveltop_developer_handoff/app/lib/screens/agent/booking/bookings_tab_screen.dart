import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';
import 'booking_request_detail_screen.dart';
import 'active_trip_detail_screen.dart';

class BookingsTabScreen extends StatefulWidget {
  const BookingsTabScreen({super.key});

  @override
  State<BookingsTabScreen> createState() => _BookingsTabScreenState();
}

class _BookingsTabScreenState extends State<BookingsTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Map<String, dynamic>> _allBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _subscribeBookings();
  }

  void _subscribeBookings() {
    final agentId = SupabaseService.instance.activeAgentId ?? SupabaseService.instance.currentUser?.id;
    if (agentId == null) {
      if (!mounted) return;
      setState(() {
        _allBookings = [];
        _isLoading = false;
      });
      return;
    }

    _subscription = SupabaseService.instance.streamAgentBookings(agentId).listen((bList) {
      if (!mounted) return;
      setState(() {
        _allBookings = bList;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _allBookings.where((b) => b['status'] == 'pending').toList();
    final active = _allBookings.where((b) => b['status'] == 'confirmed' || b['status'] == 'ongoing').toList();
    final completed = _allBookings.where((b) => b['status'] == 'completed').toList();
    final cancelled = _allBookings.where((b) => b['status'] == 'cancelled').toList();

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: Text('Tour Bookings', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.kAccent,
          unselectedLabelColor: AppTheme.kInkSoft,
          indicatorColor: AppTheme.kAccent,
          labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Active (${active.length})'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList(pending, isPending: true),
                _buildBookingList(active, isActive: true),
                _buildBookingList(completed, isReadOnly: true),
                _buildBookingList(cancelled, isReadOnly: true),
              ],
            ),
    );
  }

  Widget _buildBookingList(List<Map<String, dynamic>> list,
      {bool isPending = false, bool isActive = false, bool isReadOnly = false}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 48, color: AppTheme.kInkMuted),
            const SizedBox(height: 12),
            Text(
              'No tours in this tab',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.kInk),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final b = list[index];
        final destination = b['destination'] ?? 'Kerala Tour';
        final startDate = b['start_date'] ?? '';
        final endDate = b['end_date'] ?? '';
        final price = (b['total_price'] ?? 0) as num;
        final status = b['status'] ?? 'pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (isPending) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BookingRequestDetailScreen(bookingId: b['id'])),
                );
              } else if (isActive) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ActiveTripDetailScreen(bookingId: b['id'])),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BookingRequestDetailScreen(bookingId: b['id'], readOnly: true)),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        destination,
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.kInkSoft),
                      const SizedBox(width: 6),
                      Text('$startDate → $endDate', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.kInkSoft)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Price',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft),
                      ),
                      Text(
                        '₹${price.toInt()}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.kAccent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = AppTheme.kPaper;
    Color fg = AppTheme.kInk;

    if (status == 'pending') {
      bg = AppTheme.kAccentLight;
      fg = AppTheme.kAccent;
    } else if (status == 'confirmed' || status == 'ongoing') {
      bg = AppTheme.kGreenLight;
      fg = AppTheme.kGreen;
    } else if (status == 'completed') {
      bg = AppTheme.kLine;
      fg = AppTheme.kInk;
    } else if (status == 'cancelled') {
      bg = Colors.red.shade50;
      fg = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
