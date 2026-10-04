import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../main.dart';
import '../services/data_service.dart';
import 'story_viewer_screen.dart';
import 'agent_listing_screen.dart';

List<String> parseStringList(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw.map((e) => e.toString()).toList();
  }
  if (raw is String) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    } else if (cleaned.startsWith('[') && cleaned.endsWith(']')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    if (cleaned.isEmpty) return [];

    return cleaned
        .split(',')
        .map((s) => s.trim().replaceAll('"', '').replaceAll('\\', ''))
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return [];
}

class DestinationDetailScreen extends StatefulWidget {
  final String destinationId;
  final String destinationName;
  final String country;
  final String coverImageUrl;

  const DestinationDetailScreen({
    super.key,
    required this.destinationId,
    required this.destinationName,
    required this.country,
    required this.coverImageUrl,
  });

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  Map<String, dynamic>? _destinationData;
  List<Map<String, dynamic>> _places = [];
  bool _loading = true;

  // Multi-image cover gallery state
  List<String> _galleryImages = [];
  int _currentPhotoIndex = 0;
  late final PageController _pageController;

  // Destination reviews state
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = true;
  RealtimeChannel? _reviewsChannel;
  RealtimeChannel? _imagesChannel;

  final List<String> _allMonths = const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (_reviewsChannel != null) {
      SupabaseService.client.removeChannel(_reviewsChannel!);
    }
    if (_imagesChannel != null) {
      SupabaseService.client.removeChannel(_imagesChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() => _loading = true);
    try {
      final client = SupabaseService.client;
      final id = widget.destinationId;

      final isUuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(id);

      if (isUuid) {
        // 1. Fetch full destination row
        final destRes = await client
            .from('destinations')
            .select('*')
            .eq('id', id)
            .maybeSingle();

        // 2. Fetch places for this destination
        final placesRes = await client
            .from('places')
            .select('*, place_images(*)')
            .eq('destination_id', id);

        // 3. Fetch gallery images
        await _fetchGalleryImages(id);

        // 4. Fetch destination reviews
        await _fetchDestinationReviews(id);

        // 5. Setup realtime subscriptions
        _setupRealtime(id);

        if (mounted) {
          setState(() {
            _destinationData = destRes;
            _places = List<Map<String, dynamic>>.from(placesRes ?? []);
            _loading = false;
          });
        }
      } else {
        // Offline / fallback destination
        _galleryImages = [
          if (widget.coverImageUrl.isNotEmpty) widget.coverImageUrl
        ];
        if (mounted) {
          setState(() {
            _loading = false;
            _reviewsLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching destination details: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _reviewsLoading = false;
        });
      }
    }
  }

  Future<void> _fetchGalleryImages([String? destId]) async {
    final id = destId ?? widget.destinationId;
    try {
      final client = SupabaseService.client;
      final imagesRes = await client
          .from('destination_images')
          .select('image_url, display_order')
          .eq('destination_id', id)
          .order('display_order', ascending: true);

      if (imagesRes != null && (imagesRes as List).isNotEmpty) {
        final list = (imagesRes as List)
            .map((i) => i['image_url']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (mounted) {
          setState(() {
            _galleryImages = list;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error fetching destination_images: $e');
    }

    if (mounted) {
      setState(() {
        _galleryImages = [
          if (widget.coverImageUrl.isNotEmpty) widget.coverImageUrl
        ];
      });
    }
  }

  Future<void> _fetchDestinationReviews([String? destId]) async {
    final id = destId ?? widget.destinationId;
    try {
      final client = SupabaseService.client;
      final data = await client
          .from('destination_reviews')
          .select('*, traveller:profiles!traveller_id(full_name, avatar_url), booking:bookings!booking_id(agent_id), destination_review_images(*)')
          .eq('destination_id', id)
          .order('created_at', ascending: false);

      if (data != null && mounted) {
        // Enrich reviews with agent name if booking has agent_id
        final revList = List<Map<String, dynamic>>.from(data);
        final agentIds = revList
            .map((r) => r['booking']?['agent_id'] as String?)
            .whereType<String>()
            .toSet()
            .toList();

        if (agentIds.isNotEmpty) {
          try {
            final profiles = await client
                .from('profiles')
                .select('id, full_name')
                .inFilter('id', agentIds);
            if (profiles != null) {
              final Map<String, String> nameMap = {
                for (var p in profiles) p['id'] as String: p['full_name'] as String? ?? 'Guide'
              };
              for (var r in revList) {
                final aId = r['booking']?['agent_id'] as String?;
                if (aId != null && nameMap.containsKey(aId)) {
                  r['agent_name'] = nameMap[aId];
                }
              }
            }
          } catch (_) {}
        }

        setState(() {
          _reviews = revList;
          _reviewsLoading = false;
        });
        return;
      }
    } catch (e) {
      // Fallback query without complex join
      try {
        final client = SupabaseService.client;
        final data = await client
            .from('destination_reviews')
            .select('*')
            .eq('destination_id', id)
            .order('created_at', ascending: false);

        if (data != null && mounted) {
          final revList = List<Map<String, dynamic>>.from(data);
          final revIds = revList.map((r) => r['id']).toList();
          final travellerIds = revList
              .map((r) => r['traveller_id'] as String?)
              .whereType<String>()
              .toSet()
              .toList();

          Map<String, List<dynamic>> imgMap = {};
          if (revIds.isNotEmpty) {
            try {
              final imgs = await client
                  .from('destination_review_images')
                  .select('*')
                  .inFilter('review_id', revIds)
                  .order('display_order', ascending: true);
              if (imgs != null) {
                for (var im in imgs) {
                  imgMap.putIfAbsent(im['review_id'] as String, () => []).add(im);
                }
              }
            } catch (_) {}
          }

          Map<String, String> userNames = {};
          if (travellerIds.isNotEmpty) {
            try {
              final users = await client.from('profiles').select('id, full_name').inFilter('id', travellerIds);
              if (users != null) {
                for (var u in users) {
                  userNames[u['id'] as String] = u['full_name'] as String? ?? 'Verified Traveller';
                }
              }
            } catch (_) {}
          }

          for (var r in revList) {
            r['destination_review_images'] = imgMap[r['id']] ?? [];
            r['traveller'] = {'full_name': userNames[r['traveller_id']] ?? 'Verified Traveller'};
          }

          setState(() {
            _reviews = revList;
            _reviewsLoading = false;
          });
          return;
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _reviewsLoading = false);
  }

  void _setupRealtime(String id) {
    if (_reviewsChannel != null) return;

    try {
      final client = SupabaseService.client;
      _reviewsChannel = client
          .channel('dest_reviews_live_$id')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'destination_reviews',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'destination_id',
              value: id,
            ),
            callback: (_) {
              _fetchDestinationReviews(id);
              _refreshDestinationMetrics(id);
            },
          )
          .subscribe();

      _imagesChannel = client
          .channel('dest_images_live_$id')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'destination_images',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'destination_id',
              value: id,
            ),
            callback: (_) => _fetchGalleryImages(id),
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up destination realtime: $e');
    }
  }

  Future<void> _refreshDestinationMetrics(String id) async {
    try {
      final client = SupabaseService.client;
      final res = await client
          .from('destinations')
          .select('rating_avg, review_count')
          .eq('id', id)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          if (_destinationData != null) {
            _destinationData!['rating_avg'] = res['rating_avg'];
            _destinationData!['review_count'] = res['review_count'];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _openGoogleMapsDirections() async {
    final nameStr = widget.destinationName.toLowerCase();
    double destLat = (_destinationData?['latitude'] as num?)?.toDouble() ?? 10.0889;
    double destLng = (_destinationData?['longitude'] as num?)?.toDouble() ?? 77.0595;

    if (nameStr.contains('ladakh') || nameStr.contains('leh')) {
      destLat = 34.1526; destLng = 77.5771;
    } else if (nameStr.contains('khajjiar')) {
      destLat = 32.5558; destLng = 76.0656;
    } else if (nameStr.contains('alleppey')) {
      destLat = 9.4981; destLng = 76.3388;
    } else if (nameStr.contains('goa')) {
      destLat = 15.2993; destLng = 74.1240;
    } else if (nameStr.contains('chikmagalur')) {
      destLat = 13.3153; destLng = 75.7754;
    }

    const double userLat = 9.9312;
    const double userLng = 76.2673;

    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$userLat,$userLng&destination=$destLat,$destLng&travelmode=driving');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (e) {
        debugPrint('Error launching Google Maps: $e');
      }
    }
  }

  void _showPhotoDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 250,
                    color: Colors.black54,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.white, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xB3000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
          color: const Color(0xFFFFB800),
          size: size,
        );
      }),
    );
  }

  // ── Header Image Carousel ──────────────────────────────────────────
  Widget _buildImageGallery() {
    final images = _galleryImages.isNotEmpty
        ? _galleryImages
        : [
            widget.coverImageUrl.isNotEmpty
                ? widget.coverImageUrl
                : 'https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=1200&q=80'
          ];
    final hasMultiple = images.length > 1;

    return Stack(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (idx) {
              setState(() => _currentPhotoIndex = idx);
            },
            itemBuilder: (context, idx) {
              final imgUrl = images[idx];
              return Image.network(
                imgUrl,
                width: double.infinity,
                height: 280,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 280,
                  color: kInkSoft,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_rounded, color: Colors.white54, size: 36),
                  ),
                ),
              );
            },
          ),
        ),

        // Gradient overlay
        Container(
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0xCC000000),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Back button
        Positioned(
          top: 44,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.9),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: kInk),
            ),
          ),
        ),

        // Wishlist button
        Positioned(
          top: 44,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.9),
            ),
            child: WishlistHeartButton.destination(
              destinationId: widget.destinationId,
              size: 20,
            ),
          ),
        ),

        // Pagination Counter Pill (Only if > 1 image)
        if (hasMultiple)
          Positioned(
            top: 48,
            right: 68,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentPhotoIndex + 1}/${images.length}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bottom Destination title & Pagination dots
        Positioned(
          bottom: 16,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.country.isNotEmpty
                    ? '${widget.destinationName}, ${widget.country}'
                    : widget.destinationName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              if (hasMultiple) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (dotIdx) {
                    final isCur = dotIdx == _currentPhotoIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isCur ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isCur ? Colors.white : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Traveller Reviews Summary Card ─────────────────────────────────
  Widget _buildReviewsSummaryCard() {
    double ratingAvg = (_destinationData?['rating_avg'] as num?)?.toDouble() ?? 0.0;
    int reviewCount = (_destinationData?['review_count'] as int?) ?? 0;

    // Local calculation if server columns not yet populated
    if (ratingAvg == 0.0 && _reviews.isNotEmpty) {
      reviewCount = _reviews.length;
      final sum = _reviews.fold<double>(0.0, (acc, r) => acc + ((r['rating'] as num?)?.toDouble() ?? 5.0));
      ratingAvg = (sum / reviewCount * 10).round() / 10.0;
    }

    return ttInfoCard(
      context: context,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 22),
                    const SizedBox(width: 4),
                    Text(
                      ratingAvg > 0 ? ratingAvg.toStringAsFixed(1) : '—',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                  ],
                ),
                Text(
                  'out of 5',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: kInkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Traveller Ratings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 4),
                _buildStars(ratingAvg, size: 16),
                const SizedBox(height: 4),
                Text(
                  reviewCount > 0
                      ? '$reviewCount verified trip review${reviewCount == 1 ? '' : 's'}'
                      : 'No reviews yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: kInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────
  Widget _buildEmptyReviewsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: appPaperColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appLineColor(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 32, color: kInkSoft.withOpacity(0.5)),
          const SizedBox(height: 10),
          Text(
            'No reviews yet — be the first to share your experience',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kInkSoft,
            ),
          ),
        ],
      ),
    );
  }

  // ── Reviews List ──────────────────────────────────────────────────
  Widget _buildReviewsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final r = _reviews[idx];
        final travellerName = (r['traveller']?['full_name'] as String?)?.trim() ?? 'Verified Traveller';
        final rating = (r['rating'] as num?)?.toDouble() ?? 5.0;
        final reviewText = r['review_text'] as String? ?? '';
        final agentName = r['agent_name'] as String?;
        final images = (r['destination_review_images'] as List? ?? [])
            .map((img) => img['image_url'] as String? ?? '')
            .where((url) => url.isNotEmpty)
            .toList();

        String dateStr = '';
        if (r['created_at'] != null) {
          try {
            final dt = DateTime.parse(r['created_at'].toString()).toLocal();
            dateStr = '${dt.day} ${_monthNames[dt.month - 1]} ${dt.year}';
          } catch (_) {}
        }

        return ttInfoCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Traveller Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: kAccent.withOpacity(0.15),
                    child: Text(
                      travellerName.isNotEmpty ? travellerName[0].toUpperCase() : 'T',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: kAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          travellerName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                        if (dateStr.isNotEmpty)
                          Text(
                            dateStr,
                            style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: kInkSoft),
                          ),
                      ],
                    ),
                  ),
                  _buildStars(rating, size: 14),
                ],
              ),

              // Trip with Agent Badge
              if (agentName != null && agentName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 0.6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        'Trip with $agentName',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Review Text
              if (reviewText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  reviewText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: kInkSoft,
                    height: 1.45,
                  ),
                ),
              ],

              // Attached Photos Thumbnail Row
              if (images.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, imgIdx) {
                      final imgUrl = images[imgIdx];
                      return GestureDetector(
                        onTap: () => _showPhotoDialog(context, imgUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imgUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: kInkSoft,
                              child: const Icon(Icons.image, color: Colors.white54, size: 20),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bestSeason = _destinationData?['best_season'] as String? ??
        'September to March for ideal weather & sightseeing.';
    final bestMonths = parseStringList(_destinationData?['best_months']);
    final riskyMonths = parseStringList(_destinationData?['risky_months']);
    final travelTips = parseStringList(_destinationData?['travel_tips']);

    return AnimatedBuilder(
      animation: Listenable.merge([themeNotifier, languageNotifier]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: appBgColor(context),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Swipeable Image Carousel Header
                    _buildImageGallery(),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Destination Description Section
                          if ((_destinationData?['description'] as String?)?.trim().isNotEmpty == true) ...[
                            ttSectionH('About ${widget.destinationName}'),
                            Text(
                              _destinationData!['description'].toString().trim(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: kInkSoft,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Route & Directions Card (Google Maps Integration)
                          ttInfoCard(
                            context: context,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_car_rounded, color: kAccent, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Driving Route & Directions',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: kInk,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Live Navigation',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Get turn-by-turn driving route and real-time traffic updates from your location to ${widget.destinationName}.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: kInkSoft,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _openGoogleMapsDirections,
                                    icon: const Icon(Icons.map_rounded, color: Colors.white, size: 18),
                                    label: Text(
                                      'Get Directions in Google Maps',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kAccent,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Best Season Info Card
                          ttInfoCard(
                            context: context,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.wb_sunny_outlined,
                                        color: kAccent, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Best Season',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: kInk,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  bestSeason,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: kInkSoft,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 12-Month Color Strip
                          ttSectionH('Best Months to Visit'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _allMonths.map((m) {
                              final isBest = bestMonths.contains(m);
                              final isRisky = riskyMonths.contains(m);

                              Color bg = appPaperColor(context);
                              Color fg = appInkSoftColor(context);
                              Color border = appLineColor(context);

                              if (isBest) {
                                bg = const Color(0xFFE7F7EF);
                                fg = kGreen;
                                border = kGreen.withOpacity(0.5);
                              } else if (isRisky) {
                                bg = const Color(0xFFFDE8E8);
                                fg = const Color(0xFFC0392B);
                                border = const Color(0xFFC0392B).withOpacity(0.5);
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: bg,
                                  border: Border.all(color: border),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  m,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: fg,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),

                          // Places to Visit (Story Rings)
                          ttSectionH('Places to Visit (Tap to view stories)'),
                          _places.isEmpty
                              ? Text(
                                  'Places list coming soon.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: kInkSoft,
                                  ),
                                )
                              : SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _places.length,
                                    itemBuilder: (context, i) {
                                      final place = _places[i];
                                      final images = (place['place_images'] as List? ?? [])
                                          .map((e) => e['image_url'] as String)
                                          .toList();

                                      final thumbUrl = images.isNotEmpty
                                          ? images.first
                                          : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=400&q=80';

                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => StoryViewerScreen(
                                                placeName: place['name'] ?? '',
                                                category: place['category'] ?? 'Sightseeing',
                                                description: place['description'] ?? '',
                                                idealDuration: place['ideal_duration'] ?? '',
                                                bestTimeOfDay: place['best_time_of_day'] ?? '',
                                                imageUrls: images,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 16),
                                          child: Column(
                                            children: [
                                              Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: kAccent, width: 2.5),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(2),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(30),
                                                    child: Image.network(
                                                      thumbUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) =>
                                                          Container(color: kInkSoft),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                width: 70,
                                                child: Text(
                                                  place['name'] ?? '',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: appInkColor(context),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                          // ── TRAVELLER REVIEWS SECTION (Below Places to Visit) ────
                          const SizedBox(height: 24),
                          ttSectionH('Traveller Reviews'),
                          _buildReviewsSummaryCard(),
                          const SizedBox(height: 12),
                          if (_reviewsLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(color: kAccent),
                              ),
                            )
                          else if (_reviews.isEmpty)
                            _buildEmptyReviewsState()
                          else
                            _buildReviewsList(),

                          const SizedBox(height: 24),

                          // Travel Tips Card
                          if (travelTips.isNotEmpty) ...[
                            ttSectionH('Local Travel Tips'),
                            ttInfoCard(
                              context: context,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: travelTips.map((tip) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: kAccent)),
                                        Expanded(
                                          child: Text(
                                            tip,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: kInkSoft,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Sticky Bottom CTA Button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: appBgColor(context),
                    border: Border(top: BorderSide(color: appLineColor(context), width: 1)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: ttPrimaryBtn(
                      'See Available Local Agents',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AgentListingScreen(
                              destinationName: widget.destinationName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
