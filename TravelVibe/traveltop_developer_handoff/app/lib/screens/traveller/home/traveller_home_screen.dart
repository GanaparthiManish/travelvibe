import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_network_image.dart';

class TravellerHomeScreen extends StatefulWidget {
  const TravellerHomeScreen({super.key});

  @override
  State<TravellerHomeScreen> createState() => _TravellerHomeScreenState();
}

class _TravellerHomeScreenState extends State<TravellerHomeScreen> {
  final _supabase = Supabase.instance.client;
  int _currentIndex = 0;
  int _selectedCategoryIndex = 0;

  List<Map<String, dynamic>> _destinations = [];
  List<Map<String, dynamic>> _topAgents = [];
  bool _loadingDestinations = true;
  bool _loadingAgents = true;
  String _userName = 'Traveller';
  String? _userPhotoUrl;

  final List<Map<String, dynamic>> _categories = [
    {'label': 'All', 'emoji': '🏔️'},
    {'label': 'Beach', 'emoji': '🏖️'},
    {'label': 'Hills', 'emoji': '⛰️'},
    {'label': 'Honeym', 'emoji': '💕'},
    {'label': 'Culture', 'emoji': '🏛️'},
    {'label': 'Adventure', 'emoji': '🧗'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchUserProfile(), _fetchDestinations(), _fetchAgents()]);
  }

  Future<void> _fetchUserProfile() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid != null) {
        final profile = await _supabase
            .from('profiles')
            .select('full_name, photo_url')
            .eq('id', uid)
            .maybeSingle();
        if (mounted && profile != null) {
          setState(() {
            _userName = profile['full_name'] ?? 'Traveller';
            _userPhotoUrl = profile['photo_url'];
          });
        }
      }
    } catch (_) {}
  }

  // Fallback popular destinations to fill empty slots
  static const List<Map<String, dynamic>> _fallbackDestinations = [
    {'name': 'Ladakh', 'state': 'J&K', 'agent_count': 8, 'cover_image_url': '', '_gradient': 'blue'},
    {'name': 'Goa', 'state': 'Goa', 'agent_count': 15, 'cover_image_url': '', '_gradient': 'teal'},
    {'name': 'Shimla', 'state': 'Himachal', 'agent_count': 6, 'cover_image_url': '', '_gradient': 'green'},
    {'name': 'Jaipur', 'state': 'Rajasthan', 'agent_count': 10, 'cover_image_url': '', '_gradient': 'orange'},
    {'name': 'Manali', 'state': 'Himachal', 'agent_count': 9, 'cover_image_url': '', '_gradient': 'purple'},
  ];

  Future<void> _fetchDestinations() async {
    try {
      final res = await _supabase.from('destinations').select().limit(6);
      final realDests = List<Map<String, dynamic>>.from(res);
      // Pad with fallbacks if fewer than 2 real destinations
      final combined = [...realDests];
      for (final fb in _fallbackDestinations) {
        if (combined.length >= 6) break;
        final alreadyExists = realDests.any(
          (d) => (d['name'] ?? '').toString().toLowerCase() == fb['name'].toString().toLowerCase(),
        );
        if (!alreadyExists) combined.add(fb);
      }
      if (mounted) {
        setState(() {
          _destinations = combined;
          _loadingDestinations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _destinations = List<Map<String, dynamic>>.from(_fallbackDestinations);
          _loadingDestinations = false;
        });
      }
    }
  }

  Future<void> _fetchAgents() async {
    try {
      final res = await _supabase
          .from('agent_details')
          .select('*, profiles(full_name, photo_url)')
          .eq('verified', true)
          .eq('suspended', false)
          .order('rating_avg', ascending: false)
          .limit(5);
      if (mounted) {
        setState(() {
          _topAgents = List<Map<String, dynamic>>.from(res);
          _loadingAgents = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingAgents = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 20),
              _buildCategories(),
              const SizedBox(height: 24),
              _buildSectionHeader('Featured destinations', onSeeAll: () {
                Navigator.pushNamed(context, '/search_results');
              }),
              const SizedBox(height: 14),
              _buildFeaturedDestinations(),
              const SizedBox(height: 24),
              _buildSectionHeader('Top rated agents', onSeeAll: () {
                Navigator.pushNamed(context, '/agent_listing');
              }),
              const SizedBox(height: 14),
              _buildTopAgents(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _userName.split(' ').first,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          // Avatar circle
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/traveller_profile'),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2C5F8A),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2C5F8A).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _userPhotoUrl != null
                  ? ClipOval(
                      child: AppNetworkImage(imageUrl: _userPhotoUrl!, width: 46, height: 46, fit: BoxFit.cover),
                    )
                  : Center(
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'T',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/search_results'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: const [
            SizedBox(width: 16),
            Text('🔍', style: TextStyle(fontSize: 16)),
            SizedBox(width: 10),
            Text(
              'Where to next?',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Categories ──────────────────────────────────────────────────────────────
  Widget _buildCategories() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategoryIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryIndex = i),
            child: Container(
              width: 68,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE8F1FB) : const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: const Color(0xFF2563EB), width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(cat['emoji']!, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat['label']!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Section Header ──────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              'See all',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Featured Destinations ───────────────────────────────────────────────────
  Widget _buildFeaturedDestinations() {
    if (_loadingDestinations) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_destinations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('No destinations available', style: TextStyle(color: Color(0xFF6B7280))),
      );
    }

    // Calculate card width so 2 cards are visible at once
    final screenW = MediaQuery.of(context).size.width;
    final cardWidth = (screenW - 52) / 2; // 20 left pad + 12 gap + 20 right

    return SizedBox(
      height: 185,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 8),
        itemCount: _destinations.length,
        itemBuilder: (context, i) {
          final dest = _destinations[i];
          final name = dest['name'] ?? 'Destination';
          final state = dest['state'] ?? dest['country'] ?? '';
          final imageUrl = dest['cover_image_url'] ?? '';
          final agentCount = dest['agent_count'] ?? 0;
          final gradientTag = dest['_gradient'] ?? '';

          // Pick gradient based on tag or index
          final gradient = _getDestinationGradient(gradientTag, i);

          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/destination_detail', arguments: dest),
            child: Container(
              width: cardWidth,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: cardWidth,
                      height: 130,
                      child: imageUrl.isNotEmpty
                          ? AppNetworkImage(imageUrl: imageUrl, width: cardWidth, height: 130, fit: BoxFit.cover)
                          : Container(decoration: BoxDecoration(gradient: gradient)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '$state · $agentCount agents',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Top Agents ──────────────────────────────────────────────────────────────
  Widget _buildTopAgents() {
    if (_loadingAgents) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_topAgents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('No agents available', style: TextStyle(color: Color(0xFF6B7280))),
      );
    }

    return Column(
      children: _topAgents.map((agent) {
        final profile = agent['profiles'] as Map<String, dynamic>? ?? {};
        final name = profile['full_name'] ?? 'Agent';
        final photo = profile['photo_url'] ?? '';
        final rating = (agent['rating_avg'] ?? 0.0).toDouble();
        final pricePerDay = agent['price_per_day'] ?? 0;
        final specialties = agent['specialties'] as List<dynamic>? ?? [];
        final specialty = specialties.isNotEmpty ? specialties.first.toString() : 'Travel Expert';
        final destination = agent['primary_destination'] ?? 'India';

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/agent_profile', arguments: agent),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Agent photo
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: const Color(0xFFE5E7EB),
                    child: photo.isNotEmpty
                        ? AppNetworkImage(imageUrl: photo, width: 52, height: 52, fit: BoxFit.cover)
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF4A6741).withValues(alpha: 0.8),
                                  const Color(0xFF2C5F8A).withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),

                // Agent info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$destination · $specialty',
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Rating & price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Text('★', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13)),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_formatPrice(pricePerDay)}/day',
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }


  String _formatPrice(dynamic price) {
    final p = int.tryParse(price.toString()) ?? 0;
    if (p >= 1000) return '${(p / 1000).toStringAsFixed(1)}k';
    return p.toString();
  }

  LinearGradient _getDestinationGradient(String tag, int index) {
    final gradients = {
      'blue': const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF2C5F8A), Color(0xFF5BA4C7)],
      ),
      'teal': const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF0D7377), Color(0xFF14BDCA)],
      ),
      'green': const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF4A6741), Color(0xFF7DAF6A)],
      ),
      'orange': const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFD4622A), Color(0xFFF0A06B)],
      ),
      'purple': const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF5C3A8A), Color(0xFF9B6FBF)],
      ),
    };

    // Default gradient for real destinations (warm brown like Munnar)
    const defaultGradients = [
      LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFA07850), Color(0xFFC4A882)], // warm brown
      ),
      LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF2C5F8A), Color(0xFF5BA4C7)], // blue
      ),
    ];

    if (tag.isNotEmpty && gradients.containsKey(tag)) return gradients[tag]!;
    return defaultGradients[index % defaultGradients.length];
  }


  // ── Bottom Navigation ───────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    const icons = [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.calendar_today_rounded,
      Icons.person_rounded,
    ];
    const routes = [
      null,
      '/search_results',
      '/my_bookings',
      '/traveller_profile',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(4, (i) {
              // Home (i==0) is always highlighted; others navigate away
              final isActive = i == 0;
              return GestureDetector(
                onTap: () {
                  if (routes[i] != null) {
                    Navigator.pushNamed(context, routes[i]!);
                  }
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFE03E2D)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icons[i],
                    color: isActive ? Colors.white : const Color(0xFFBDBDBD),
                    size: 24,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
