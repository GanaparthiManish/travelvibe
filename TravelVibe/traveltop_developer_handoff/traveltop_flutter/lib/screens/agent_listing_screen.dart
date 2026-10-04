import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';
import 'agent_profile_screen.dart';

class AgentListingScreen extends StatefulWidget {
  final String? destinationName;

  const AgentListingScreen({super.key, this.destinationName});

  @override
  State<AgentListingScreen> createState() => _AgentListingScreenState();
}

class _AgentListingScreenState extends State<AgentListingScreen> {
  List<Map<String, dynamic>> _agents = [];
  Set<String> _wishlistIds = {};
  bool _loading = true;
  int _sortBy = 0; // 0: Rating, 1: Price Low->High, 2: Safety

  final List<String> _sortOptions = const ['Rating', 'Price ↑', 'Safety Score'];

  @override
  void initState() {
    super.initState();
    _fetchAgentsAndWishlist();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    try {
      SupabaseService.client
          .channel('agent_listing_rt')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'agent_details',
            callback: (_) => _fetchAgentsAndWishlist(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'agent_gallery',
            callback: (_) => _fetchAgentsAndWishlist(),
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _fetchAgentsAndWishlist() async {
    setState(() => _loading = true);
    try {
      final client = SupabaseService.client;
      final userId = client.auth.currentUser?.id;

      // Fetch only approved, verified, non-suspended agents
      dynamic req = client
          .from('agent_details')
          .select('*')
          .eq('verification_status', 'approved')
          .eq('verified', true)
          .eq('suspended', false);


      if (_sortBy == 0) {
        req = req.order('rating_avg', ascending: false);
      } else if (_sortBy == 1) {
        req = req.order('price_per_day', ascending: true);
      } else if (_sortBy == 2) {
        req = req.order('safety_score', ascending: false);
      }

      final agentRes = await req;
      List<Map<String, dynamic>> rawList = List<Map<String, dynamic>>.from(agentRes ?? []);

      // Fetch profiles for names & photos
      final agentIds = rawList.map((a) => a['id'] as String?).whereType<String>().toList();
      Map<String, dynamic> profilesMap = {};
      if (agentIds.isNotEmpty) {
        try {
          final pRes = await client.from('profiles').select('id, full_name, photo_url').inFilter('id', agentIds);
          if (pRes != null) {
            for (final p in pRes) {
              profilesMap[p['id']] = p;
            }
          }
        } catch (_) {}
      }

      List<Map<String, dynamic>> loadedAgents = rawList.map((a) {
        final p = profilesMap[a['id']];
        return {
          ...a,
          'profiles': p ?? {'full_name': 'Local Travel Guide', 'photo_url': a['photo_url']},
        };
      }).toList();

      // Filter by location if destinationName is passed
      if (widget.destinationName != null && widget.destinationName!.trim().isNotEmpty) {
        final targetLoc = widget.destinationName!.trim().toLowerCase();
        loadedAgents = loadedAgents.where((agent) {
          final places = List<String>.from(agent['places_covered'] ?? []);
          return places.any((p) => p.toLowerCase().contains(targetLoc) || targetLoc.contains(p.toLowerCase()));
        }).toList();
      }

      // Fetch user wishlists
      Set<String> wished = {};
      if (userId != null) {
        try {
          final wishRes = await client
              .from('wishlists')
              .select('agent_id')
              .eq('traveller_id', userId);
          wished = (wishRes as List).map((e) => e['agent_id'] as String).toSet();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _agents = loadedAgents;
          _wishlistIds = wished;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching agent list: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleWishlist(String agentId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;

    final isWished = _wishlistIds.contains(agentId);

    // Optimistic UI update
    setState(() {
      if (isWished) {
        _wishlistIds.remove(agentId);
      } else {
        _wishlistIds.add(agentId);
      }
    });

    try {
      final client = SupabaseService.client;
      if (isWished) {
        await client
            .from('wishlists')
            .delete()
            .eq('traveller_id', userId)
            .eq('agent_id', agentId);
      } else {
        await client.from('wishlists').insert({
          'traveller_id': userId,
          'agent_id': agentId,
        });
      }
    } catch (e) {
      debugPrint('Wishlist toggle error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = (widget.destinationName != null && widget.destinationName!.isNotEmpty)
        ? 'Guides for ${widget.destinationName}'
        : 'Top Rated Local Guides';

    return Scaffold(
      backgroundColor: appBgColor(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ttAppBar(context, headerTitle, showBack: true),

            // Sort Option Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Sort by: ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kInkSoft,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(_sortOptions.length, (i) {
                      return ttChip(
                        _sortOptions[i],
                        context: context,
                        active: _sortBy == i,
                        onTap: () {
                          setState(() => _sortBy = i);
                          _fetchAgentsAndWishlist();
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Agent List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: kAccent))
                  : _agents.isEmpty
                      ? Center(
                          child: Text(
                            'No guides found.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: kInkSoft,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _agents.length,
                          itemBuilder: (_, i) {
                            final agent = _agents[i];
                            final profile = agent['profiles'] as Map<String, dynamic>? ?? {};
                            final agentId = agent['id'] as String;
                            final name = profile['full_name'] as String? ?? 'Local Guide';
                            var photoUrl = profile['photo_url'] as String? ?? agent['selfie_url'] as String? ?? '';
                            if (photoUrl.isNotEmpty && !photoUrl.startsWith('http://') && !photoUrl.startsWith('https://') && !photoUrl.startsWith('data:')) {
                              photoUrl = 'https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/$photoUrl';
                            }
                            final placesCovered = List<String>.from(agent['places_covered'] ?? []);
                            final ratingAvg = (agent['rating_avg'] as num?)?.toDouble() ?? 0.0;
                            final pricePerDay = (agent['price_per_day'] as num?)?.toInt() ?? 0;
                            final isWished = _wishlistIds.contains(agentId);

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AgentProfileScreen(
                                      agentId: agentId,
                                      name: name,
                                      photoUrl: photoUrl,
                                      bio: agent['bio'] ?? '',
                                      ratingAvg: ratingAvg,
                                      pricePerDay: pricePerDay,
                                      verified: agent['verified'] ?? false,
                                      placesCovered: placesCovered,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: appPaperColor(context),
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
                                child: Row(
                                  children: [
                                     ClipRRect(
                                       borderRadius: BorderRadius.circular(12),
                                       child: SizedBox(
                                         width: 60,
                                         height: 60,
                                         child: () {
                                           final initials = (name.isNotEmpty ? name[0] : 'A').toUpperCase();
                                           if (photoUrl.startsWith('data:')) {
                                             try {
                                               return Image.memory(
                                                 Uri.parse(photoUrl).data!.contentAsBytes(),
                                                 fit: BoxFit.cover,
                                                 errorBuilder: (_, __, ___) => Container(color: kAccent, child: Center(child: Text(initials, style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 20)))),
                                               );
                                             } catch (_) {}
                                           } else if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
                                             return Image.network(
                                               photoUrl,
                                               fit: BoxFit.cover,
                                               errorBuilder: (_, __, ___) => Container(color: kAccent, child: Center(child: Text(initials, style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 20)))),
                                             );
                                           }
                                           return Container(color: kAccent, child: Center(child: Text(initials, style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 20))));
                                         }(),
                                       ),
                                     ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                name,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: kInk,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.verified_rounded,
                                                  color: Color(0xFF1E8E5A), size: 16),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            placesCovered.isNotEmpty
                                                ? placesCovered.join(', ')
                                                : 'Local Specialist',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: kInkSoft,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.star_rounded,
                                                  color: Color(0xFFFFB800), size: 16),
                                              const SizedBox(width: 2),
                                              Text(
                                                ratingAvg.toStringAsFixed(1),
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: kInk,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                '₹$pricePerDay/day',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: kAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Wishlist heart button
                                    WishlistHeartButton.agent(
                                      agentId: agentId,
                                      size: 20,
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
  }
}
