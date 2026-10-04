import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';
import '../services/wishlist_service.dart';
import 'agent_profile_screen.dart';
import 'destination_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Map<String, dynamic>> _allWishlistItems = [];
  bool _loading = true;
  int _selectedFilter = 0; // 0 = All, 1 = Places, 2 = Gear, 3 = Agents

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
    WishlistService.instance.addListener(_fetchWishlist);
  }

  @override
  void dispose() {
    WishlistService.instance.removeListener(_fetchWishlist);
    super.dispose();
  }

  Future<void> _fetchWishlist() async {
    try {
      final wishedDestIds = WishlistService.instance.wishedDestinationIds;
      final wishedAgentIds = WishlistService.instance.wishedAgentIds;
      final wishedProdIds = WishlistService.instance.wishedProductIds;

      final List<Map<String, dynamic>> joined = [];

      // Known destination lookup map
      final Map<String, Map<String, String>> knownDestinations = {
        'dest-munnar': {'name': 'Munnar', 'country': 'Kerala, India', 'image': 'https://images.unsplash.com/photo-1593693397690-362cb9666fc2?auto=format&fit=crop&w=600&q=80'},
        'munnar': {'name': 'Munnar', 'country': 'Kerala, India', 'image': 'https://images.unsplash.com/photo-1593693397690-362cb9666fc2?auto=format&fit=crop&w=600&q=80'},
        'dest-ladakh': {'name': 'Leh Ladakh', 'country': 'Himalayas, India', 'image': 'https://images.unsplash.com/photo-1581793745862-99fde7fa73d2?auto=format&fit=crop&w=600&q=80'},
        'ladakh': {'name': 'Leh Ladakh', 'country': 'Himalayas, India', 'image': 'https://images.unsplash.com/photo-1581793745862-99fde7fa73d2?auto=format&fit=crop&w=600&q=80'},
        'dest-khajjiar': {'name': 'Khajjiar', 'country': 'Himachal Pradesh, India', 'image': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=600&q=80'},
        'khajjiar': {'name': 'Khajjiar', 'country': 'Himachal Pradesh, India', 'image': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=600&q=80'},
        'dest-alleppey': {'name': 'Alleppey', 'country': 'Kerala, India', 'image': 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=600&q=80'},
        'alleppey': {'name': 'Alleppey', 'country': 'Kerala, India', 'image': 'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=600&q=80'},
        'dest-goa': {'name': 'Goa', 'country': 'India', 'image': 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=600&q=80'},
        'goa': {'name': 'Goa', 'country': 'India', 'image': 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=600&q=80'},
        'spiti': {'name': 'Spiti Valley', 'country': 'Himachal, India', 'image': 'https://images.unsplash.com/photo-1581793745862-99fde7fa73d2?auto=format&fit=crop&w=600&q=80'},
        'spiti_valley': {'name': 'Spiti Valley', 'country': 'Himachal, India', 'image': 'https://images.unsplash.com/photo-1581793745862-99fde7fa73d2?auto=format&fit=crop&w=600&q=80'},
        'dzukou': {'name': 'Dzükou Valley', 'country': 'Nagaland & Manipur, India', 'image': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=600&q=80'},
        'dzukou_valley': {'name': 'Dzükou Valley', 'country': 'Nagaland & Manipur, India', 'image': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=600&q=80'},
        'kaas': {'name': 'Kaas Plateau', 'country': 'Maharashtra, India', 'image': 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=600&q=80'},
        'kaas_plateau': {'name': 'Kaas Plateau', 'country': 'Maharashtra, India', 'image': 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=600&q=80'},
        'valley_of_flowers': {'name': 'Valley of Flowers', 'country': 'Uttarakhand, India', 'image': 'https://images.unsplash.com/photo-1593693397690-362cb9666fc2?auto=format&fit=crop&w=600&q=80'},
        'majuli': {'name': 'Majuli Island', 'country': 'Assam, India', 'image': 'https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=600&q=80'},
      };

      // Known product lookup map
      final Map<String, Map<String, String>> knownProducts = {
        'prod-1': {'name': 'Waterproof 45L Trekking Backpack', 'price': '₹2,999', 'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=400&q=80'},
        'prod-2': {'name': 'Insulated Thermal Water Bottle (1L)', 'price': '₹799', 'image': 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=400&q=80'},
        'prod-3': {'name': 'Memory Foam Travel Neck Pillow', 'price': '₹649', 'image': 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=400&q=80'},
        'prod-4': {'name': 'Fast Charge 20,000mAh Power Bank', 'price': '₹1,499', 'image': 'https://images.unsplash.com/photo-1609592807987-a2f004383492?auto=format&fit=crop&w=400&q=80'},
        'prod-5': {'name': 'Universal All-in-One Travel Adapter', 'price': '₹899', 'image': 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?auto=format&fit=crop&w=400&q=80'},
        'prod-6': {'name': 'Compression Travel Packing Cubes (Set of 6)', 'price': '₹999', 'image': 'https://images.unsplash.com/photo-1581553680321-4fffae59fccd?auto=format&fit=crop&w=400&q=80'},
        'prod-7': {'name': 'Quick-Dry Microfiber Camping Towel', 'price': '₹499', 'image': 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=400&q=80'},
        'prod-8': {'name': 'Compact Tactical Travel First Aid Kit', 'price': '₹599', 'image': 'https://images.unsplash.com/photo-1603398938378-e54eab446dde?auto=format&fit=crop&w=400&q=80'},
        'prod-9': {'name': 'Noise-Cancelling Travel Wireless Earbuds', 'price': '₹2,499', 'image': 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=400&q=80'},
        'prod-10': {'name': 'TSA Approved Zinc Alloy Luggage Locks (2 Pack)', 'price': '₹399', 'image': 'https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&w=400&q=80'},
        'prod_cold_weather_sets': {'name': 'Cold Weather Sets', 'price': '₹1', 'image': 'https://images.unsplash.com/photo-1578587018452-892bacefd3f2?auto=format&fit=crop&w=400&q=80'},
        'prod_bag': {'name': 'Backpack Bag', 'price': '₹1', 'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=400&q=80'},
        'prod_backpack': {'name': 'Waterproof 45L Trekking Backpack', 'price': '₹2,999', 'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=400&q=80'},
        'prod_water_bottle': {'name': 'Insulated Thermal Water Bottle (1L)', 'price': '₹799', 'image': 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=400&q=80'},
        'prod_neck_pillow': {'name': 'Memory Foam Travel Neck Pillow', 'price': '₹649', 'image': 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=400&q=80'},
        'prod_power_bank': {'name': 'Fast Charge 20,000mAh Power Bank', 'price': '₹1,499', 'image': 'https://images.unsplash.com/photo-1609592807987-a2f004383492?auto=format&fit=crop&w=400&q=80'},
        'prod_travel_adapter': {'name': 'Universal All-in-One Travel Adapter', 'price': '₹899', 'image': 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?auto=format&fit=crop&w=400&q=80'},
        'comfort_lock_01': {'name': 'TSA Approved Luggage Locks (2 Pack)', 'price': '₹399', 'image': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=400&q=80'},
        'camping_towel_01': {'name': 'Quick-Dry Microfiber Camping Towel', 'price': '₹499', 'image': 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=400&q=80'},
        'camping_firstaid_01': {'name': 'Compact Tactical Travel First Aid Kit', 'price': '₹599', 'image': 'https://images.unsplash.com/photo-1603398938378-e54eab446dde?auto=format&fit=crop&w=400&q=80'},
        'comfort_pillow_01': {'name': 'Memory Foam Travel Neck Pillow', 'price': '₹649', 'image': 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=400&q=80'},
      };

      // Known agent lookup map
      final Map<String, Map<String, String>> knownAgents = {
        'agent-manish': {'name': 'Manish Ganaparthi', 'sub': 'Certified Local Mountain Guide • 4.9 ★', 'image': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400'},
        'agent-rajesh': {'name': 'Rajesh Kumar', 'sub': 'High-Altitude Trek Specialist • 4.8 ★', 'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400'},
        'agent-priya': {'name': 'Priya Sharma', 'sub': 'Heritage & Culture Specialist • 4.9 ★', 'image': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400'},
      };

      // Fetch active destinations from DataService
      final appDests = DataService.instance.data.value.destinations;
      final appAgents = DataService.instance.data.value.agents;

      // 1. Destinations
      for (final destId in wishedDestIds) {
        String name = 'Popular Destination';
        String country = 'India';
        String image = 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=400&q=80';

        final cleanKey = destId.toLowerCase().replaceAll(' ', '_');
        if (knownDestinations.containsKey(destId.toLowerCase())) {
          name = knownDestinations[destId.toLowerCase()]!['name']!;
          country = knownDestinations[destId.toLowerCase()]!['country']!;
          image = knownDestinations[destId.toLowerCase()]!['image']!;
        } else if (knownDestinations.containsKey(cleanKey)) {
          name = knownDestinations[cleanKey]!['name']!;
          country = knownDestinations[cleanKey]!['country']!;
          image = knownDestinations[cleanKey]!['image']!;
        } else {
          final matched = appDests.firstWhere((d) => d.id == destId || d.name.toLowerCase() == destId.toLowerCase(), orElse: () => DestinationData(id: '', name: '', country: '', coverImageUrl: '', isFeatured: false, isTrending: false, agentCount: 0));
          if (matched.name.isNotEmpty) {
            name = matched.name;
            country = matched.country;
            image = matched.coverImageUrl.isNotEmpty ? matched.coverImageUrl : image;
          } else if (destId.isNotEmpty && !destId.startsWith('dest-')) {
            name = destId.replaceAll('_', ' ').split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ');
          }
        }

        joined.add({
          'id': destId,
          'type': 'destination',
          'destination_id': destId,
          'title': name,
          'subtitle': country,
          'image': image,
        });
      }

      // 2. Agents
      for (final agentId in wishedAgentIds) {
        String name = 'Certified Local Guide';
        String sub = 'Verified Travel Expert • 4.9 ★';
        String image = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';

        if (knownAgents.containsKey(agentId)) {
          name = knownAgents[agentId]!['name']!;
          sub = knownAgents[agentId]!['sub']!;
          image = knownAgents[agentId]!['image']!;
        } else {
          final matched = appAgents.firstWhere((a) => a.id == agentId, orElse: () => AgentData(id: '', name: '', bio: '', photoUrl: '', placesCovered: [], ratingAvg: 0, pricePerDay: 0, verified: false));
          if (matched.name.isNotEmpty && matched.name != '—') {
            name = matched.name;
            sub = '${matched.specialty} Specialist • ${matched.ratingAvg > 0 ? matched.ratingAvg : 4.9} ★';
            image = matched.photoUrl.isNotEmpty ? matched.photoUrl : image;
          }
        }

        joined.add({
          'id': agentId,
          'type': 'agent',
          'agent_id': agentId,
          'title': name,
          'subtitle': sub,
          'image': image,
        });
      }

      // 3. Products
      for (final prodId in wishedProdIds) {
        final keyLower = prodId.toLowerCase();
        String name = 'Pro Travel Gear Item';
        String price = '₹499 • Essential Travel Gear';
        String image = 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=400&q=80';

        if (knownProducts.containsKey(keyLower)) {
          name = knownProducts[keyLower]!['name']!;
          price = '${knownProducts[keyLower]!['price']!} • Express Delivery';
          image = knownProducts[keyLower]!['image']!;
        } else {
          // Format dynamic product name from ID
          String clean = prodId.replaceAll('prod_', '').replaceAll('prod-', '').replaceAll('_', ' ');
          if (clean.isNotEmpty) {
            name = clean.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
            price = '₹499 • Express Delivery';
          }
        }

        joined.add({
          'id': prodId,
          'type': 'product',
          'product_id': prodId,
          'title': name,
          'subtitle': price,
          'image': image,
        });
      }

      if (mounted) {
        setState(() {
          _allWishlistItems = joined;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedFilter == 1) {
      return _allWishlistItems.where((i) => i['type'] == 'destination').toList();
    } else if (_selectedFilter == 2) {
      return _allWishlistItems.where((i) => i['type'] == 'product').toList();
    } else if (_selectedFilter == 3) {
      return _allWishlistItems.where((i) => i['type'] == 'agent').toList();
    }
    return _allWishlistItems;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: appInkColor(context), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Saved Wishlist',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: appInkColor(context),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Tabs (All, Places, Gear, Agents)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('All Saved', 0),
                _buildFilterChip('Places', 1),
                _buildFilterChip('Travel Gear', 2),
                _buildFilterChip('Guides & Agents', 3),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7300)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF7300).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_border_rounded,
                                color: Color(0xFFFF7300),
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your Wishlist is Empty',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: appInkColor(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap the heart icon on any place, guide or gear item to save it',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: appInkSoftColor(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final type = item['type'] as String;

                          return GestureDetector(
                            onTap: () {
                              if (type == 'destination') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DestinationDetailScreen(
                                      destinationId: item['id'],
                                      destinationName: item['title'],
                                      country: item['subtitle'],
                                      coverImageUrl: item['image'],
                                    ),
                                  ),
                                );
                              } else if (type == 'agent') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AgentProfileScreen(
                                      agentId: item['id'],
                                      name: item['title'],
                                      photoUrl: item['image'],
                                      bio: 'Certified local mountain & culture guide specializing in regional tours.',
                                      ratingAvg: 4.9,
                                      pricePerDay: 2500,
                                      verified: true,
                                      placesCovered: const ['Regional Treks', 'Heritage Tours'],
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: appPaperColor(context),
                                border: Border.all(color: appLineColor(context), width: 1.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      item['image'],
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: const Color(0xFFFF7300).withOpacity(0.2), child: const Icon(Icons.place_rounded, color: Color(0xFFFF7300))),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF7300).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            type.toUpperCase(),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFFFF7300),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['title'],
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: appInkColor(context),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['subtitle'],
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: appInkSoftColor(context),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.favorite_rounded,
                                      color: Color(0xFFEF4444),
                                      size: 22,
                                    ),
                                    onPressed: () async {
                                      if (type == 'destination') {
                                        await WishlistService.instance.toggleDestination(item['id']);
                                      } else if (type == 'agent') {
                                        await WishlistService.instance.toggleAgent(item['id']);
                                      } else if (type == 'product') {
                                        await WishlistService.instance.toggleProduct(item['id']);
                                      }
                                    },
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
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF7300) : appPaperColor(context),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7300) : appLineColor(context),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : appInkColor(context),
          ),
        ),
      ),
    );
  }
}
