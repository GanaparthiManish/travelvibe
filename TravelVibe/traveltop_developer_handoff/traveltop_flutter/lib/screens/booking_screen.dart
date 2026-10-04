import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../main.dart';
import '../services/data_service.dart';
import 'trip_detail_screen.dart';


class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _selectedTab = 0;
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  RealtimeChannel? _subscription;

  final List<String> _tabs = const ['Upcoming', 'Ongoing', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
    _subscribeRealtime();
  }

  Future<void> _fetchBookings() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _bookings = [];
          _loading = false;
        });
      }
      return;
    }

    try {
      final res = await SupabaseService.client
          .from('bookings')
          .select('*, agent_details(profiles(full_name))')
          .eq('traveller_id', user.id)
          .order('created_at', ascending: false);

      final remote = List<Map<String, dynamic>>.from(res ?? []);
      if (mounted) {
        setState(() {
          _bookings = remote;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch bookings notice: $e');
      if (mounted) {
        setState(() {
          _bookings = [];
          _loading = false;
        });
      }
    }
  }

  void _subscribeRealtime() {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;

    try {
      _subscription = SupabaseService.client
          .channel('public_bookings_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bookings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'traveller_id',
              value: user.id,
            ),
            callback: (_) => _fetchBookings(),
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredBookings {
    if (_selectedTab == 0) {
      // Upcoming: any booking that is confirmed or pending
      return _bookings.where((b) {
        final st = (b['status'] as String? ?? '').toLowerCase();
        return st != 'completed' && st != 'cancelled';
      }).toList();
    } else if (_selectedTab == 1) {
      return _bookings.where((b) => (b['status'] as String? ?? '').toLowerCase() == 'ongoing').toList();
    } else if (_selectedTab == 2) {
      return _bookings.where((b) => (b['status'] as String? ?? '').toLowerCase() == 'completed').toList();
    } else {
      return _bookings.where((b) => (b['status'] as String? ?? '').toLowerCase() == 'cancelled').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeNotifier, languageNotifier]),
      builder: (context, _) {
        final filtered = _filteredBookings;

        return Scaffold(
          backgroundColor: appBgColor(context),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Text(
                    tr('trips'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: appInkColor(context),
                    ),
                  ),
                ),

                // Tab chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Wrap(
                    spacing: 8,
                    children: List.generate(_tabs.length, (i) {
                      return ttChip(
                        _tabs[i],
                        context: context,
                        active: _selectedTab == i,
                        onTap: () => setState(() => _selectedTab = i),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: kAccent))
                      : filtered.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final b = filtered[i];
                                final agentDetails =
                                    b['agent_details'] as Map<String, dynamic>? ?? {};
                                final profile =
                                    agentDetails['profiles'] as Map<String, dynamic>? ?? {};
                                // Use flat fields first (from SharedPreferences), then nested
                                final agentName = (b['agent_name'] as String?)?.isNotEmpty == true
                                    ? b['agent_name'] as String
                                    : (profile['full_name'] as String? ?? 'Your Guide');
                                final photoUrl = (b['agent_photo'] as String?)?.isNotEmpty == true
                                    ? b['agent_photo'] as String
                                    : (profile['photo_url'] as String? ?? '');
                                final placesCovered =
                                    List<String>.from(agentDetails['places_covered'] ?? []);
                                final status = b['status'] as String? ?? 'pending';

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TripDetailScreen(
                                          bookingData: b,
                                        ),
                                      ),
                                    ).then((_) => _fetchBookings());
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: appPaperColor(context),
                                      border: Border.all(color: appLineColor(context)),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            photoUrl.isNotEmpty
                                                ? photoUrl
                                                : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(color: appLineColor(context), width: 56, height: 56),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(agentName,
                                                      style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w800,
                                                          color: appInkColor(context))),
                                                  ttBadge(status, context: context),
                                                ],
                                              ),

                                              const SizedBox(height: 4),
                                              Text(
                                                placesCovered.isNotEmpty
                                                    ? placesCovered.join(' • ')
                                                    : 'Custom Tour Package',
                                                style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: appInkSoftColor(context)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    b['travel_date'] ?? 'Upcoming',
                                                    style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: appInkSoftColor(context)),
                                                  ),
                                                  Text(
                                                    '₹${b['total_price'] ?? 0}',
                                                    style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w800,
                                                        color: kAccent),
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
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.card_travel_rounded, size: 54, color: appInkSoftColor(context)),
          const SizedBox(height: 12),
          Text(
            'No trips found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: appInkColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Explore top destinations and book a local guide!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: appInkSoftColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
