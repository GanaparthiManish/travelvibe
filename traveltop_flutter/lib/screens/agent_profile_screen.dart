import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/data_service.dart';
import 'availability_screen.dart';
import 'chat_screen.dart';
import 'customize_trip_screen.dart';
import 'chat_inquiry_screen.dart';
import '../widgets/app_video_player_modal.dart';

class AgentProfileScreen extends StatefulWidget {
  final String agentId;
  final String name;
  final String photoUrl;
  final String bio;
  final double ratingAvg;
  final int pricePerDay;
  final bool verified;
  final List<String> placesCovered;

  const AgentProfileScreen({
    super.key,
    required this.agentId,
    required this.name,
    required this.photoUrl,
    required this.bio,
    required this.ratingAvg,
    required this.pricePerDay,
    required this.verified,
    required this.placesCovered,
  });

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen> {
  Map<String, dynamic>? _agentDetails;
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _gallery = [];
  bool _loading = true;



  @override
  void initState() {
    super.initState();
    _fetchAgentData();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final isUuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(widget.agentId);
    if (!isUuid) return;

    try {
      SupabaseService.client
          .channel('agent_profile_${widget.agentId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'agent_details',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: widget.agentId,
            ),
            callback: (_) => _fetchAgentData(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'agent_gallery',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'agent_id',
              value: widget.agentId,
            ),
            callback: (_) => _fetchAgentData(),
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _fetchAgentData() async {
    final isUuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(widget.agentId);

    if (!isUuid) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final client = SupabaseService.client;

      // 1. Fetch agent detail record & profile separately for guaranteed join
      Map<String, dynamic>? detailsRes;
      try {
        detailsRes = await client
            .from('agent_details')
            .select('*')
            .eq('id', widget.agentId)
            .maybeSingle();

        final profRes = await client
            .from('profiles')
            .select('full_name, email, phone, photo_url')
            .eq('id', widget.agentId)
            .maybeSingle();

        if (detailsRes != null && profRes != null) {
          detailsRes['profiles'] = profRes;
        }
      } catch (e) {
        debugPrint('Notice fetching agent details: $e');
      }

      // 2. Fetch reviews for this agent
      try {
        final reviewsRes = await client
            .from('reviews')
            .select('*')
            .eq('agent_id', widget.agentId)
            .order('created_at', ascending: false);
        _reviews = List<Map<String, dynamic>>.from(reviewsRes ?? []);
      } catch (e) {
        debugPrint('Reviews fetch notice: $e');
      }

      // 3. Fetch Trip Gallery portfolio (Public)
      try {
        final galleryRes = await client
            .from('agent_gallery')
            .select('*')
            .eq('agent_id', widget.agentId)
            .order('display_order', ascending: true);
        _gallery = List<Map<String, dynamic>>.from(galleryRes ?? []);
      } catch (_) {}

      if (_gallery.isEmpty) {
        if (detailsRes?['gallery_urls'] != null) {
          final urls = parseStringList(detailsRes!['gallery_urls']);
          _gallery = urls.map((url) => {'image_url': url}).toList();
        } else if (detailsRes?['gallery'] != null) {
          final urls = parseStringList(detailsRes!['gallery']);
          _gallery = urls.map((url) => {'image_url': url}).toList();
        }
      }

      if (_gallery.isEmpty && detailsRes?['bio'] != null) {
        final bioStr = detailsRes!['bio'].toString();
        final match = RegExp(r'\[\[GALLERY:(.*?)\]\]').firstMatch(bioStr);
        if (match != null && match.group(1) != null) {
          final rawUrls = match.group(1)!.split('||');
          _gallery = rawUrls.where((u) => u.trim().isNotEmpty).map((url) => {'image_url': url.trim()}).toList();
        }
      }

      if (mounted) {
        setState(() {
          _agentDetails = detailsRes;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching agent profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showImageLightbox(String imageUrl, String caption) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(imageUrl, fit: BoxFit.cover),
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                caption,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileName = (_agentDetails?['profiles']?['full_name'] as String?) ??
        (_agentDetails?['full_name'] as String?) ??
        widget.name;

    var rawPhoto = (_agentDetails?['profiles']?['photo_url'] as String?)?.trim();
    if (rawPhoto == null || rawPhoto.isEmpty) {
      rawPhoto = (_agentDetails?['photo_url'] as String?)?.trim();
    }
    if (rawPhoto == null || rawPhoto.isEmpty) {
      rawPhoto = (_agentDetails?['selfie_url'] as String?)?.trim();
    }
    if (rawPhoto == null || rawPhoto.isEmpty) {
      rawPhoto = (_agentDetails?['verification_doc_url'] as String?)?.trim();
    }
    if (rawPhoto == null || rawPhoto.isEmpty) {
      rawPhoto = widget.photoUrl.trim();
    }

    var resolvedPhotoUrl = rawPhoto ?? '';
    if (resolvedPhotoUrl.isNotEmpty &&
        !resolvedPhotoUrl.startsWith('http://') &&
        !resolvedPhotoUrl.startsWith('https://') &&
        !resolvedPhotoUrl.startsWith('data:') &&
        !resolvedPhotoUrl.startsWith('file://') &&
        !resolvedPhotoUrl.startsWith('/')) {
      resolvedPhotoUrl =
          'https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/$resolvedPhotoUrl';
    }

    final rawBio = (_agentDetails?['bio'] as String?)?.trim() ?? '';
    final fetchedBio = rawBio.replaceAll(RegExp(r'\[\[GALLERY:.*?\]\]'), '').trim();
    final widgetBio = widget.bio.replaceAll(RegExp(r'\[\[GALLERY:.*?\]\]'), '').trim();
    final bioText = fetchedBio.isNotEmpty
        ? fetchedBio
        : (widgetBio.isNotEmpty
            ? widgetBio
            : 'Local Tour Expertise');

    final expYears = (_agentDetails?['years_experience'] as num?)?.toInt() ??
        (_agentDetails?['experience_years'] as num?)?.toInt() ??
        4;
    final languages = parseStringList(_agentDetails?['languages']);
    final displayLanguages = languages;
    final safetyScore = (_agentDetails?['safety_score'] as num?)?.toInt() ?? 98;
    final includesStay = (_agentDetails?['accommodation_included'] as bool?) ?? true;
    final includesTransport = (_agentDetails?['transport_included'] as bool?) ?? true;
    final includesMeals = (_agentDetails?['meals_included'] as bool?) ?? true;

    final displayGallery = _gallery;
    final initials = (profileName.isNotEmpty ? profileName[0] : 'A').toUpperCase();

    final ratingVal = (_agentDetails?['rating_avg'] as num?)?.toDouble() ?? widget.ratingAvg;
    final displayRating = ratingVal > 0 ? ratingVal.toStringAsFixed(1) : '4.9';
    final reviewCnt = (_agentDetails?['review_count'] as num?)?.toInt() ?? 14;

    return Scaffold(
      backgroundColor: appBgColor(context),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Cover Scrim & Profile Header ────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage('https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.black.withValues(alpha: 0.2),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 48,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.9),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: kInk),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -36,
                      left: 20,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kWhite, width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(45),
                          child: resolvedPhotoUrl.startsWith('http')
                              ? Image.network(
                                  resolvedPhotoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: kAccent,
                                    child: Center(child: Text(initials, style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 32))),
                                  ),
                                )
                              : Container(
                                  color: kAccent,
                                  child: Center(child: Text(initials, style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold, fontSize: 32))),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      profileName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: kInk,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified_rounded, color: Color(0xFF1E8E5A), size: 20),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Local Mountain & Experience Specialist',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: kInkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Stat Cards Row ────────────────────────────────────
                      Row(
                        children: [
                          ttStatCard('Rating', '★ $displayRating ($reviewCnt)'),
                          const SizedBox(width: 10),
                          ttStatCard('Experience', '$expYears Yrs'),
                          const SizedBox(width: 10),
                          ttStatCard('Safety Score', '$safetyScore%'),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Get Directions Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: appPaperColor(context),
                          border: Border.all(color: appLineColor(context), width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.near_me_rounded, color: kAccent, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Route to ${widget.name.split(' ')[0]}\'s Meeting Point',
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
                              'Base coverage: ${widget.placesCovered.isNotEmpty ? widget.placesCovered.join(', ') : 'Khajjiar, Munnar'}. Open Google Maps for driving directions & ETA.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: kInkSoft, height: 1.35),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final place = widget.placesCovered.isNotEmpty ? widget.placesCovered.first : 'Munnar';
                                  double destLat = 10.0889; double destLng = 77.0595;
                                  if (place.toLowerCase().contains('khajjiar')) {
                                    destLat = 32.5558; destLng = 76.0656;
                                  } else if (place.toLowerCase().contains('ladakh')) {
                                    destLat = 34.1526; destLng = 77.5771;
                                  }
                                  const userLat = 9.9312; const userLng = 76.2673;
                                  final url = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$userLat,$userLng&destination=$destLat,$destLng&travelmode=driving');
                                  try {
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    } else {
                                      await launchUrl(url, mode: LaunchMode.platformDefault);
                                    }
                                  } catch (e) {
                                    debugPrint('Error launching Google Maps: $e');
                                  }
                                },
                                icon: const Icon(Icons.directions_rounded, color: kAccent, size: 18),
                                label: Text(
                                  'Get Directions in Google Maps',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: kAccent),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: kAccent, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── About Guide ───────────────────────────────────────
                      ttSectionH('About Guide'),
                      const SizedBox(height: 6),
                      Text(
                        bioText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: kInkSoft,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Trip Gallery Portfolio ─────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ttSectionH('Trip Gallery Portfolio'),
                          Text(
                            '${displayGallery.length} Photos',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: kAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: displayGallery.length,
                          itemBuilder: (context, index) {
                            final item = displayGallery[index];
                            final imgUrl = item['image_url'] as String? ?? '';
                            final caption = item['caption'] as String? ?? 'Trip Photo';
                            final lower = imgUrl.toLowerCase();
                            final isVideo = lower.contains('.mp4') || lower.contains('.mov') || lower.contains('.webm') || lower.contains('.avi') || lower.contains('.mkv') || lower.contains('video');

                            return GestureDetector(
                              onTap: () {
                                if (isVideo) {
                                  AppVideoPlayerModal.show(context, imgUrl, title: caption);
                                } else {
                                  _showImageLightbox(imgUrl, caption);
                                }
                              },
                              child: Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: appPaperColor(context),
                                  border: Border.all(color: appLineColor(context)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (isVideo) ...[
                                      Positioned.fill(child: Container(color: const Color(0xFF0F172A))),
                                      const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                                          child: Text('30s Video', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ] else ...[
                                      Positioned.fill(
                                        child: Image.network(
                                          imgUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: appPaperColor(context), child: const Icon(Icons.broken_image, color: kInkSoft)),
                                        ),
                                      ),
                                    ],
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        color: Colors.black.withValues(alpha: 0.5),
                                        child: Text(
                                          isVideo ? '30s Place Clip' : caption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Spoken Languages ──────────────────────────────────
                      ttSectionH('Spoken Languages'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: displayLanguages
                            .map(
                              (lang) => Chip(
                                backgroundColor: appBgColor(context),
                                side: BorderSide(color: appLineColor(context)),
                                avatar: const Icon(Icons.translate_rounded, size: 14, color: kAccent),
                                label: Text(
                                  lang,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: kInk,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),

                      // ── Services Included ────────────────────────────────
                      ttSectionH('Services Included'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _servicePill(Icons.bed_rounded, 'Stay', includesStay),
                          const SizedBox(width: 10),
                          _servicePill(Icons.directions_car_rounded, 'Transport', includesTransport),
                          const SizedBox(width: 10),
                          _servicePill(Icons.restaurant_rounded, 'Meals', includesMeals),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ── Customer Reviews Section ──────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ttSectionH('Traveler Reviews'),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$displayRating ($reviewCnt reviews)',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: kInk),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_reviews.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          child: Text(
                            'No reviews yet',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kInkSoft),
                          ),
                        )
                      else
                        ..._reviews.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildReviewCard(
                            (r['profiles'] as Map?)?['full_name'] ?? 'Traveler',
                            (r['overall_rating'] ?? 5.0).toString(),
                            'Recent',
                            r['review_text'] ?? '',
                          ),
                        )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Action Bar ──────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: appBgColor(context),
                border: Border(top: BorderSide(color: appLineColor(context), width: 1.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From ₹${widget.pricePerDay}/day',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kInk,
                            ),
                          ),
                          Text(
                            'Customizable — add stays, food & more',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: kAccent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Chat Direct Button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatInquiryScreen(
                              agentId: widget.agentId,
                              agentName: profileName,
                              agentPhoto: resolvedPhotoUrl,
                              destination: widget.placesCovered.isNotEmpty ? widget.placesCovered.first : 'Guided Tour',
                              proposedDates: 'Flexible',
                              calculatedTotal: (widget.pricePerDay * 3).toDouble(),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: appPaperColor(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: appLineColor(context), width: 1.5),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded, color: kAccent, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Customize & Book Button
                    Expanded(
                      child: ttPrimaryBtn(
                        'Customize & Book',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomizeTripScreen(
                                agentId: widget.agentId,
                                agentName: profileName,
                                agentPhoto: resolvedPhotoUrl,
                                basePricePerDay: widget.pricePerDay.toDouble(),
                                destination: widget.placesCovered.isNotEmpty ? widget.placesCovered.first : 'Guided Tour',
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
          ),
        ],
      ),
    );
  }

  Widget _servicePill(IconData icon, String label, bool active) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE7F7EF) : kPaper,
          border: Border.all(
            color: active ? kGreen.withValues(alpha: 0.6) : kLine,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? kGreen : kInkSoft, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? kGreen : kInkSoft,
              ),
            ),
            const SizedBox(height: 2),
            Icon(
              active ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: active ? kGreen : const Color(0xFFCBD5E1),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(String name, String rating, String date, String comment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appPaperColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: appLineColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: kAccent,
                child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: kInk)),
              const Spacer(),
              Row(
                children: List.generate(5, (i) => const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft, height: 1.4),
          ),
        ],
      ),
    );
  }
}
