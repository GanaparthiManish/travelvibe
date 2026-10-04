import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../main.dart';
import '../services/data_service.dart';
import 'destination_detail_screen.dart';

import 'agent_profile_screen.dart';
import 'agent_listing_screen.dart';
import 'notifications_screen.dart';
import 'wishlist_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import 'discover_screen.dart';
import 'shop_screen.dart';
import 'category_destinations_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCategory = 0;
  List<DestinationData> _filteredDestinations = [];
  bool _filtering = false;

  // Auto-Location State
  double _userLat = 9.9312; // Default live position (Kochi / Munnar region)
  double _userLng = 76.2673;
  bool _hasLocationPermission = false;
  List<Map<String, dynamic>> _nearbyDestinations = [];

  final List<_Cat> _categories = const [
    _Cat(id: 'all', icon: Icons.explore_rounded, label: 'All'),
    _Cat(id: 'beach', icon: Icons.beach_access_rounded, label: 'Beach'),
    _Cat(id: 'hills', icon: Icons.terrain_rounded, label: 'Hills'),
    _Cat(id: 'honeymoon', icon: Icons.favorite_rounded, label: 'Honeymoon'),
    _Cat(id: 'adventure', icon: Icons.surfing_rounded, label: 'Adventure'),
    _Cat(id: 'culture', icon: Icons.account_balance_rounded, label: 'Culture'),
  ];

  @override
  void initState() {
    super.initState();
    DataService.instance.data.addListener(_onAppDataChanged);
    _onAppDataChanged();
    _initAutoLocation();
  }

  void _initAutoLocation() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Prompt user with explanation dialog
      if (!mounted) return;
      setState(() {
        _hasLocationPermission = true;
        _computeNearbyDestinations();
      });
    });
  }

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  void _computeNearbyDestinations() {
    final allDestinations = DataService.instance.data.value.destinations;
    if (allDestinations.isEmpty) return;

    final list = allDestinations.map((d) {
      final dist = _calculateDistanceKm(_userLat, _userLng, d.latitude, d.longitude);
      return {
        'destination': d,
        'distance_km': dist,
      };
    }).toList();

    list.sort((a, b) => (a['distance_km'] as double).compareTo(b['distance_km'] as double));

    if (mounted) {
      setState(() {
        _nearbyDestinations = list;
      });
    }
  }

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) {
      return 'Good morning 👋';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon ☀️';
    } else if (hour >= 17 && hour < 22) {
      return 'Good evening 🌆';
    } else {
      return 'Good night 🌙';
    }
  }

  @override
  void dispose() {
    DataService.instance.data.removeListener(_onAppDataChanged);
    super.dispose();
  }

  void _onAppDataChanged() {
    _applyCategoryFilter(_selectedCategory);
  }

  Future<void> _applyCategoryFilter(int categoryIndex) async {
    setState(() {
      _selectedCategory = categoryIndex;
      _filtering = true;
    });

    final allFeatured = DataService.instance.data.value.destinations;
    final targetCat = _categories[categoryIndex].id;

    if (targetCat == 'all') {
      if (mounted) {
        setState(() {
          _filteredDestinations = allFeatured;
          _filtering = false;
        });
      }
      return;
    }

    await Future.delayed(const Duration(milliseconds: 200));

    final matches = allFeatured.where((d) {
      final name = d.name.toLowerCase();
      final country = d.country.toLowerCase();
      final text = '$name $country';

      switch (targetCat) {
        case 'beach':
          return text.contains('beach') || text.contains('goa') || text.contains('alleppey') || text.contains('backwater');
        case 'hills':
          return text.contains('hill') || text.contains('munnar') || text.contains('ladakh') || text.contains('tea');
        case 'honeymoon':
          return text.contains('honeymoon') || text.contains('munnar') || text.contains('alleppey');
        case 'adventure':
          return text.contains('rafting') || text.contains('ladakh') || text.contains('rishikesh') || text.contains('trek');
        case 'culture':
          return text.contains('monastery') || text.contains('culture') || text.contains('temple') || text.contains('rishikesh');
        default:
          return true;
      }
    }).toList();

    if (mounted) {
      setState(() {
        _filteredDestinations = matches;
        _filtering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? 'Traveller';

    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, languageNotifier]),
      builder: (context, _) {
        return ValueListenableBuilder<AppData>(
          valueListenable: DataService.instance.data,
          builder: (context, appData, _) {
            final agents = appData.agents;
            final selectedCatObj = _categories[_selectedCategory];

            return Scaffold(
              backgroundColor: appBgColor(context),
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── FIXED TOP SECTION (Greeting + Search + Categories) ──────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        children: [
                          // Top Greeting & Action Badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     const TravelVibeBrandLogo(iconSize: 36, fontSize: 24),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  // Realtime Notification Bell
                                  ListenableBuilder(
                                    listenable: NotificationService.instance,
                                    builder: (context, _) {
                                      final unread = NotificationService.instance.unreadCount;
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                          );
                                        },
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: appPaperColor(context),
                                                border: Border.all(color: appLineColor(context), width: 1.5),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(Icons.notifications_outlined,
                                                  color: appInkColor(context), size: 18),
                                            ),
                                            if (unread > 0)
                                              Positioned(
                                                top: 4,
                                                right: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFFF7300),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Text(
                                                    '$unread',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  // Wishlist heart
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const WishlistScreen()),
                                      );
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: appPaperColor(context),
                                        border: Border.all(color: appLineColor(context), width: 1.5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.favorite_border_rounded,
                                          color: appInkColor(context), size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Search Bar
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const DiscoverScreen()),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 13),
                              decoration: BoxDecoration(
                                color: appPaperColor(context),
                                border: Border.all(color: appLineColor(context), width: 1.5),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.search_rounded,
                                      color: appInkSoftColor(context), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      tr('search_placeholder'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: appInkSoftColor(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 16),

                // Categories Strip (Fixed)
                SizedBox(
                  height: 82,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _categories.length,
                    itemBuilder: (context, i) {
                      final cat = _categories[i];
                      final isActive = _selectedCategory == i;

                      return GestureDetector(
                        onTap: () {
                          if (cat.id == 'all') {
                            _applyCategoryFilter(i);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CategoryDestinationsScreen(
                                  initialCategory: cat.id,
                                  initialLabel: cat.label,
                                ),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive
                                      ? const Color(0xFFFEECEB)
                                      : kPaper,
                                  border: Border.all(
                                    color: isActive ? kAccent : kLine,
                                    width: isActive ? 2.0 : 1.2,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: kAccent.withOpacity(0.18),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Icon(
                                    cat.icon,
                                    size: 24,
                                    color: isActive ? kAccent : kInk,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tr(cat.id),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isActive ? kAccent : kInkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: appLineColor(context)),

                // ── SCROLLABLE REMAINING CONTENT ─────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 16, bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. FEATURED DESTINATIONS (Horizontal Carousel) ──────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedCatObj.id == 'all'
                                    ? 'Featured destinations'
                                    : '${selectedCatObj.label} destinations',
                                style: kSectionH,
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const DiscoverScreen()),
                                  );
                                },
                                child: Text(
                                  'See all',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        _filtering
                            ? const SizedBox(
                                height: 210,
                                child: Center(child: CircularProgressIndicator(color: kAccent)))
                            : _filteredDestinations.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: _buildEmptyCategoryState(selectedCatObj.label),
                                  )
                                : SizedBox(
                                    height: 210,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      itemCount: _filteredDestinations.length,
                                      itemBuilder: (context, i) {
                                        final d = _filteredDestinations[i];
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => DestinationDetailScreen(
                                                  destinationId: d.id,
                                                  destinationName: d.name,
                                                  country: d.country,
                                                  coverImageUrl: d.coverImageUrl,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 180,
                                            margin: const EdgeInsets.only(right: 14),
                                            decoration: BoxDecoration(
                                              color: kWhite,
                                              border: Border.all(color: appLineColor(context), width: 1.5),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.04),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Stack(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                                      child: Image.network(
                                                        d.coverImageUrl.isNotEmpty
                                                            ? d.coverImageUrl
                                                            : 'https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=400&q=80',
                                                        height: 125,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF6B8F71)),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: 6,
                                                      right: 6,
                                                      child: WishlistHeartButton.destination(
                                                        destinationId: d.id,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                       Text(
                                                         d.name,
                                                         style: GoogleFonts.plusJakartaSans(
                                                           fontSize: 14,
                                                           fontWeight: FontWeight.w800,
                                                           color: appInkColor(context),
                                                         ),
                                                         maxLines: 1,
                                                         overflow: TextOverflow.ellipsis,
                                                       ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        d.country.isNotEmpty ? d.country : 'Explore places',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                          color: kInkSoft,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 28),

                        // ── 2. PROMOTIONAL BANNERS ───────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              // Banner 1: Travel Discount Agent Banner
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AgentListingScreen()),
                                  );
                                },
                                child: Container(
                                  height: 145,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    image: const DecorationImage(
                                      image: NetworkImage('https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80'),
                                      fit: BoxFit.cover,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.75),
                                          Colors.black.withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: kAccent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'FLAT 25% OFF',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          tr('flat_discount_banner'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Book verified local experts in Khajjiar & Munnar',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withOpacity(0.9),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              tr('book_guide_now'),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Banner 2: Shopping & Travel Gear Banner
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ShopScreen()),
                                  );
                                },
                                child: Container(
                                  height: 145,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    image: const DecorationImage(
                                      image: NetworkImage('https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=1200&q=80'),
                                      fit: BoxFit.cover,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.75),
                                          Colors.black.withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E8E5A),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'GEAR STORE',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          tr('gear_store_banner'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Backpacks, boots & jackets with free express delivery',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withOpacity(0.9),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              tr('explore_shop'),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── 2.5 VERIFIED LOCAL AGENTS CAROUSEL ──────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Verified Local Agents',
                                style: kSectionH,
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AgentListingScreen()),
                                  );
                                },
                                child: Text(
                                  'See all',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 155,
                          child: ValueListenableBuilder<AppData>(
                            valueListenable: DataService.instance.data,
                            builder: (context, appData, _) {
                              final agents = appData.agents;
                              if (agents.isEmpty) {
                                return ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  children: [
                                    Container(
                                      width: 230,
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: appLineColor(context), width: 1.5),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: agents.length,
                                itemBuilder: (context, index) {
                                  final ag = agents[index];
                                  return _buildHomeAgentCard(
                                    context,
                                    agentId: ag.id,
                                    name: ag.name,
                                    photoUrl: ag.photoUrl,
                                    bio: ag.bio,
                                    ratingAvg: ag.ratingAvg,
                                    pricePerDay: ag.pricePerDay,
                                    verified: ag.verified,
                                    placesCovered: ag.placesCovered,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── 3. THIS SEASON PLACES TO VISIT (2 COLUMNS GRID) ────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    selectedCatObj.id == 'all'
                                        ? tr('this_season_places')
                                        : '${tr(selectedCatObj.id)} Places to Visit',
                                    style: kSectionH,
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Ideal Season',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _filteredDestinations.isEmpty
                              ? _buildEmptyCategoryState(selectedCatObj.label)
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _filteredDestinations.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.18,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemBuilder: (context, i) {
                                    final d = _filteredDestinations[i];
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DestinationDetailScreen(
                                              destinationId: d.id,
                                              destinationName: d.name,
                                              country: d.country,
                                              coverImageUrl: d.coverImageUrl,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: kWhite,
                                          border: Border.all(color: appLineColor(context), width: 1.5),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                                  child: Image.network(
                                                    d.coverImageUrl.isNotEmpty
                                                        ? d.coverImageUrl
                                                        : 'https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=400&q=80',
                                                    height: 105,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF6B8F71)),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 6,
                                                  left: 6,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.70),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'Best Season',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 6,
                                                  right: 6,
                                                  child: WishlistHeartButton.destination(
                                                    destinationId: d.id,
                                                    size: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  // Left Side: Place Name & Subtitle
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          d.name,
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 12.5,
                                                            fontWeight: FontWeight.w800,
                                                            color: kInk,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 1),
                                                        Text(
                                                          d.country.isNotEmpty ? d.country : 'India',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w500,
                                                            color: kInkSoft,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // Right Side: Compact "Book" Button
                                                  SizedBox(
                                                    height: 28,
                                                    child: ElevatedButton(
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => DestinationDetailScreen(
                                                              destinationId: d.id,
                                                              destinationName: d.name,
                                                              country: d.country,
                                                              coverImageUrl: d.coverImageUrl,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: kAccent,
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'Book',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w800,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
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
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  Widget _buildEmptyCategoryState(String categoryLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: appPaperColor(context),
        border: Border.all(color: appLineColor(context)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          'No $categoryLabel destinations yet — check back soon',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kInkSoft,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeAgentCard(
    BuildContext context, {
    required String agentId,
    required String name,
    required String photoUrl,
    required String bio,
    required double ratingAvg,
    required int pricePerDay,
    required bool verified,
    required List<String> placesCovered,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AgentProfileScreen(
              agentId: agentId,
              name: name,
              photoUrl: photoUrl,
              bio: bio,
              ratingAvg: ratingAvg,
              pricePerDay: pricePerDay,
              verified: verified,
              placesCovered: placesCovered,
            ),
          ),
        );
      },
      child: Container(
        width: 230,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: appLineColor(context), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (photoUrl.isNotEmpty && (photoUrl.startsWith('http') || photoUrl.startsWith('data:') || photoUrl.startsWith('file:')))
                  ? Image.network(
                      photoUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: kAccent.withOpacity(0.12),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: kAccent),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: kAccent.withOpacity(0.12),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'A',
                          style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: kAccent),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: kInk),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (verified)
                        const Icon(Icons.verified_rounded, color: kAccent, size: 15),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    placesCovered.isNotEmpty ? placesCovered.join(', ') : 'Local Guide',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kInkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 14),
                          const SizedBox(width: 2),
                          Text(
                            ratingAvg.toStringAsFixed(1),
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: kInk),
                          ),
                        ],
                      ),
                      Text(
                        '₹$pricePerDay/day',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: kAccent),
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
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: appPaperColor(context),
        border: Border.all(color: appLineColor(context)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          msg,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: kInkSoft,
          ),
        ),
      ),
    );
  }
}

class _Cat {
  final String id, label;
  final IconData icon;
  const _Cat({required this.id, required this.icon, required this.label});
}
