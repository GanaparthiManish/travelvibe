import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_network_image.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchBookings();
    _setupRealtime();
  }

  void _setupRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _channel = _supabase.channel('public:bookings:traveller_$userId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'bookings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'traveller_id',
        value: userId,
      ),
      callback: (payload) {
        _fetchBookings();
      }
    ).subscribe();
  }

  Future<void> _fetchBookings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final res = await _supabase.from('bookings').select('''
        *,
        agent:agent_id (
          full_name,
          photo_url
        )
      ''').eq('traveller_id', userId).order('start_date', ascending: false);

      if (mounted) {
        setState(() {
          _bookings = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(context),
                _buildTabBar(),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingsList('Upcoming'),
                      _buildBookingsList('Ongoing'),
                      _buildBookingsList('Completed'),
                      _buildBookingsList('Cancelled'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: const Text(
        'My Bookings & Trips',
        style: TextStyle(
          color: AppTheme.textDark,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Color(0x55000000), blurRadius: 8)],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.textDark.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.textDark.withValues(alpha: 0.3), width: 1.2),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppTheme.textDark.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Ongoing'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList(String filterStatus) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _bookings.where((b) {
      final status = b['status'] as String? ?? 'pending';
      if (filterStatus == 'Upcoming') {
        return status == 'pending' || status == 'confirmed';
      } else if (filterStatus == 'Ongoing') {
        return status == 'ongoing';
      } else if (filterStatus == 'Completed') {
        return status == 'completed';
      } else if (filterStatus == 'Cancelled') {
        return status == 'cancelled';
      }
      return false;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.calendarX, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 14),
            Text(
              'No $filterStatus trips yet',
              style: const TextStyle(color: AppTheme.textDark, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => Navigator.pushNamed(context, '/agent_listing'),
              child: const Text('Explore Destinations'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final agent = item['agent'] ?? {};
        final agentName = agent['full_name'] ?? 'Agent';
        final agentPhoto = agent['photo_url'] ?? 'https://ui-avatars.com/api/?name=$agentName';
        final title = item['destination'] ?? 'Destination';
        final status = (item['status'] as String? ?? 'pending').toUpperCase();
        final price = '₹${item['total_price'] ?? 0}';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/trip_detail', arguments: item['id']),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AppNetworkImage(
                      imageUrl: agentPhoto,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.coralGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(color: AppTheme.coralGold, fontWeight: FontWeight.w700, fontSize: 11),
                              ),
                            ),
                            Text(price, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.oceanTeal, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(color: AppTheme.charcoalText, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(LucideIcons.user, size: 12, color: AppTheme.greyText),
                            const SizedBox(width: 4),
                            Text('Guide: $agentName', style: const TextStyle(color: AppTheme.greyText, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
