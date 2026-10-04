import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/agent_avatar.dart';

class AgentConsoleScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;
  const AgentConsoleScreen({super.key, this.onNavigateTab});

  @override
  State<AgentConsoleScreen> createState() => _AgentConsoleScreenState();
}

class _AgentConsoleScreenState extends State<AgentConsoleScreen> {
  StreamSubscription<List<Map<String, dynamic>>>? _bookingsSub;

  Map<String, dynamic>? _agentProfile;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }


  Future<void> _loadInitialData() async {
    final agentId = SupabaseService.instance.activeAgentId ?? SupabaseService.instance.currentUser?.id;
    if (agentId == null) {
      if (!mounted) return;
      setState(() {
        _agentProfile = null;
        _bookings = [];
        _isLoading = false;
      });
      return;
    }

    // Fetch agent_details with profiles join
    var profile = await SupabaseService.instance.getAgentDetails(agentId);

    // Fallback: if agent_details row doesn't exist yet, fetch directly from profiles
    if (profile == null) {
      try {
        final profileRow = await SupabaseService.instance.client
            ?.from('profiles')
            .select('id, full_name, email, phone, photo_url, role')
            .eq('id', agentId)
            .maybeSingle();
        if (profileRow != null) {
          profile = {'profiles': profileRow};
        }
      } catch (e) {
        debugPrint('Profile fallback fetch error: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _agentProfile = profile;
      _isLoading = false;
    });

    _bookingsSub = SupabaseService.instance.streamAgentBookings(agentId).listen((bList) {
      if (!mounted) return;
      setState(() {
        _bookings = bList;
      });
    });
  }


  @override
  void dispose() {
    _bookingsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agentName = _agentProfile?['profiles']?['full_name'] as String? ?? _agentProfile?['full_name'] as String? ?? '';
    final photoUrl = _agentProfile?['profiles']?['photo_url'] as String? ?? _agentProfile?['photo_url'] as String? ?? '';
    final ratingAvg = (_agentProfile?['rating_avg'] ?? 0.0) as num;
    final reviewCount = (_agentProfile?['review_count'] ?? 0) as int;

    // Aggregates
    final pendingBookings = _bookings.where((b) => b['status'] == 'pending').toList();
    final completedBookings = _bookings.where((b) => b['status'] == 'completed').toList();
    final activeBookings = _bookings.where((b) => b['status'] == 'confirmed' || b['status'] == 'ongoing').toList();

    double monthEarnings = 0.0;
    final now = DateTime.now();
    for (var b in completedBookings) {
      final dateStr = b['created_at'] ?? b['start_date'];
      if (dateStr != null) {
        final d = DateTime.tryParse(dateStr.toString());
        if (d != null && d.month == now.month && d.year == now.year) {
          monthEarnings += (b['total_price'] ?? 0) as num;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: Text(
          'Agent Console',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.kInk),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              color: AppTheme.kAccent,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Profile Header Card
                    _buildProfileCard(agentName, photoUrl, ratingAvg.toDouble(), reviewCount),
                    const SizedBox(height: 20),

                    // 2. Pending Requests Banner
                    if (pendingBookings.isNotEmpty) ...[
                      _buildPendingBanner(pendingBookings.length),
                      const SizedBox(height: 20),
                    ],

                    // 3. Quick Stats Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: "This Month",
                            value: "₹${monthEarnings.toInt()}",
                            icon: Icons.account_balance_wallet_rounded,
                            color: AppTheme.kGreen,
                            onTap: () => widget.onNavigateTab?.call(3),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildStatCard(
                            title: "Total Bookings",
                            value: "${_bookings.length}",
                            icon: Icons.luggage_rounded,
                            color: AppTheme.kInk,
                            onTap: () => widget.onNavigateTab?.call(1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 4. Quick Actions Section
                    Text(
                      'Management Hub',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.kInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionTile(
                                icon: Icons.edit_calendar_rounded,
                                title: 'Manage Availability',
                                subtitle: 'Set open dates & rates',
                                onTap: () => Navigator.pushNamed(context, '/agent_availability'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionTile(
                                icon: Icons.directions_walk_rounded,
                                title: 'Active Tours (${activeBookings.length})',
                                subtitle: 'Guide live itineraries',
                                onTap: () => widget.onNavigateTab?.call(1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionTile(
                                icon: Icons.payments_rounded,
                                title: 'Earnings & Payouts',
                                subtitle: 'Withdraw to Bank / UPI',
                                onTap: () => widget.onNavigateTab?.call(3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionTile(
                                icon: Icons.star_rounded,
                                title: 'Reviews Received',
                                subtitle: '★ $ratingAvg ($reviewCount)',
                                onTap: () => Navigator.pushNamed(context, '/agent_reviews'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileCard(String name, String photoUrl, double rating, int reviews) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.kLine, width: 1.5),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          AgentAvatar(name: name, photoUrl: photoUrl, radius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.kInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, color: AppTheme.kGreen, size: 18),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$rating ($reviews reviews)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.kInk,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.kInk),
            onPressed: () => Navigator.pushNamed(context, '/agent_profile_edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBanner(int count) {
    return GestureDetector(
      onTap: () => widget.onNavigateTab?.call(1),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.kAccentLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.kAccent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppTheme.kAccent, shape: BoxShape.circle),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(color: AppTheme.kWhite, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Booking Requests',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                  ),
                  Text(
                    'Tap to view and respond to travellers',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.kAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.kWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.kLine, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft)),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.kInk),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.kWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.kLine, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.kInk, size: 22),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.kInk),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.kInkSoft),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
