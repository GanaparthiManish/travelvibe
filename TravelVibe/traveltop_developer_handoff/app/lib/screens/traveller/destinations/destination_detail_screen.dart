import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_network_image.dart';
import '../../../../widgets/place_story_viewer.dart';
import '../../../../widgets/glass_app_bar.dart';

class DestinationDetailScreen extends StatefulWidget {
  const DestinationDetailScreen({super.key});

  @override
  State<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  late Map<String, dynamic> initialDestination;
  final _supabase = Supabase.instance.client;

  Future<List<PlaceStoryItem>> _buildStoryItems(List<Map<String, dynamic>> places) async {
    final List<PlaceStoryItem> items = [];
    for (final p in places) {
      final placeId = p['id'].toString();
      final coverImg = p['image_url'] ?? 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=500';
      
      List<String> images = [coverImg];
      try {
        final galleryRes = await _supabase
            .from('place_images')
            .select('image_url')
            .eq('place_id', placeId)
            .order('display_order');
        if (galleryRes != null && (galleryRes as List).isNotEmpty) {
          final galleryUrls = (galleryRes as List).map((g) => g['image_url'].toString()).toList();
          images = [coverImg, ...galleryUrls.where((u) => u != coverImg)];
        }
      } catch (e) {
        debugPrint('Error fetching gallery images for place $placeId: $e');
      }

      items.add(PlaceStoryItem(
        id: placeId,
        name: p['name'] ?? '',
        category: p['category'] ?? 'Sightseeing',
        description: p['description'],
        idealDuration: p['ideal_duration'],
        bestTimeOfDay: p['best_time_of_day'],
        images: images,
      ));
    }
    return items;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      initialDestination = args;
    } else {
      initialDestination = {
        'id': 'a41ac867-3345-403a-9d5b-7c84446220c5', // Real Munnar ID instead of 'fallback'
        'name': 'Munnar',
        'country': 'India',
        'cover_image_url': 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=500',
        'description': 'A serene hill station famous for rolling tea plantations and misty mountains.',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: initialDestination['id'] == 'fallback' 
          ? Future.value([initialDestination]) 
          : _supabase.from('destinations').select().eq('id', initialDestination['id']),
      builder: (context, snapshot) {
        final destination = (snapshot.hasData && snapshot.data!.isNotEmpty) ? snapshot.data!.first : initialDestination;
        
        final name = destination['name'] ?? 'Unknown';
        final country = destination['country'] ?? '';
        final imageUrl = destination['cover_image_url'] ?? destination['image_url'] ?? 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=500&q=80';
        final desc = destination['description'] ?? '';
        final bestSeason = destination['best_season'] as String?;
        final idealDuration = destination['ideal_trip_duration'] as String?;
        final travelTips = destination['travel_tips'] as String?;
        final bestMonths = List<String>.from(destination['best_months'] ?? []);
        final riskyMonths = List<String>.from(destination['risky_months'] ?? []);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Real Nature Background
              // 2. Main Scrollable Content
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Hero Header Image & Glass App Bar
                  SliverAppBar(
                    expandedHeight: 300,
                    pinned: true,
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    leading: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: GlassBackButton(),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.5),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.75),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Destination Details Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Destination Name & Location Header
                          Text(
                            name,
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Color(0x77000000), blurRadius: 10, offset: Offset(0, 3))],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(LucideIcons.mapPin, color: AppTheme.coral, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                country,
                                style: const TextStyle(
                                  color: AppTheme.textDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  shadows: [Shadow(color: Color(0x66000000), blurRadius: 8)],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Description Card (Frosted Glass)
                          if (desc.isNotEmpty) ...[
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                desc,
                                style: TextStyle(
                                  color: AppTheme.textDark.withValues(alpha: 0.95),
                                  fontSize: 15,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Travel Info Header
                          const Text(
                            'Travel Info',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              shadows: [Shadow(color: Color(0x55000000), blurRadius: 8)],
                            ),
                          ),
                          const SizedBox(height: 14),
                          
                          // Info Cards (Best Season & Ideal Trip)
                          Row(
                            children: [
                              if (bestSeason != null && bestSeason.isNotEmpty)
                                Expanded(
                                  child: _buildGlassInfoCard(
                                    LucideIcons.sun,
                                    'Best Season',
                                    bestSeason,
                                    AppTheme.sunshineYellow,
                                  ),
                                ),
                              if (bestSeason != null && bestSeason.isNotEmpty && idealDuration != null && idealDuration.isNotEmpty)
                                const SizedBox(width: 14),
                              if (idealDuration != null && idealDuration.isNotEmpty)
                                Expanded(
                                  child: _buildGlassInfoCard(
                                    LucideIcons.clock,
                                    'Ideal Trip',
                                    idealDuration,
                                    AppTheme.mintGreen,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Best Months & Risky Months Card
                          if (bestMonths.isNotEmpty || riskyMonths.isNotEmpty)
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (bestMonths.isNotEmpty) ...[
                                    const Row(
                                      children: [
                                        Icon(LucideIcons.calendarCheck, size: 18, color: AppTheme.mintGreen),
                                        SizedBox(width: 8),
                                        Text('Best Months', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textDark)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: bestMonths.map((m) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.mintGreen.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppTheme.mintGreen.withValues(alpha: 0.5)),
                                        ),
                                        child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                                      )).toList(),
                                    ),
                                    if (riskyMonths.isNotEmpty) const SizedBox(height: 18),
                                  ],
                                  if (riskyMonths.isNotEmpty) ...[
                                    const Row(
                                      children: [
                                        Icon(LucideIcons.alertTriangle, size: 18, color: AppTheme.coral),
                                        SizedBox(width: 8),
                                        Text('Risky / Avoid', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textDark)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: riskyMonths.map((m) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.coral.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppTheme.coral.withValues(alpha: 0.5)),
                                        ),
                                        child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                                      )).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                          // Travel Tips Card
                          if (travelTips != null && travelTips.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(LucideIcons.lightbulb, size: 20, color: Color(0xFFFFD54F)),
                                      SizedBox(width: 10),
                                      Text('Travel Tips', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textDark)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    travelTips,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.55, color: AppTheme.textDark.withValues(alpha: 0.95)),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Places to Visit Section Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Places to Visit',
                                style: TextStyle(
                                  color: AppTheme.textDark,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  shadows: [Shadow(color: Color(0x55000000), blurRadius: 8)],
                                ),
                              ),
                              Row(
                                children: const [
                                  Icon(LucideIcons.playCircle, size: 16, color: AppTheme.coral),
                                  SizedBox(width: 4),
                                  Text(
                                    'Watch stories',
                                    style: TextStyle(
                                      color: AppTheme.coral,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Places List
                          if (initialDestination['id'] == 'fallback')
                            const Center(child: Text('No places available.', style: TextStyle(color: AppTheme.textMuted)))
                          else
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _supabase.from('places').select().eq('destination_id', initialDestination['id']),
                              builder: (context, placesSnapshot) {
                                if (!placesSnapshot.hasData && placesSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator(color: AppTheme.textDark));
                                }
                                final places = placesSnapshot.data ?? [];
                                if (places.isEmpty) {
                                  return GlassCard(
                                    padding: const EdgeInsets.all(20),
                                    child: const Center(
                                      child: Text(
                                        'No places listed for this destination yet.',
                                        style: TextStyle(color: AppTheme.textDark, fontSize: 14),
                                      ),
                                    ),
                                  );
                                }

                                return FutureBuilder<List<PlaceStoryItem>>(
                                  future: _buildStoryItems(places),
                                  builder: (context, storySnapshot) {
                                    final storyItems = storySnapshot.data ?? places.map((p) => PlaceStoryItem(
                                      id: p['id'].toString(),
                                      name: p['name'] ?? '',
                                      category: p['category'] ?? 'Sightseeing',
                                      description: p['description'],
                                      idealDuration: p['ideal_duration'],
                                      bestTimeOfDay: p['best_time_of_day'],
                                      images: [p['image_url'] ?? 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=500'],
                                    )).toList();

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Story Rings Row
                                        SizedBox(
                                          height: 110,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: storyItems.length,
                                            separatorBuilder: (context, index) => const SizedBox(width: 14),
                                            itemBuilder: (context, index) {
                                              final item = storyItems[index];
                                              return GestureDetector(
                                                onTap: () => PlaceStoryViewer.show(
                                                  context,
                                                  places: storyItems,
                                                  initialIndex: index,
                                                ),
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(3),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        gradient: const LinearGradient(
                                                          colors: [AppTheme.coral, AppTheme.sunshineYellow],
                                                        ),
                                                      ),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(2),
                                                        decoration: const BoxDecoration(
                                                          color: Colors.black,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(30),
                                                          child: AppNetworkImage(
                                                            imageUrl: item.images.first,
                                                            width: 60,
                                                            height: 60,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    SizedBox(
                                                      width: 72,
                                                      child: Text(
                                                        item.name,
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(
                                                          color: AppTheme.textDark,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        // Detailed Place Cards List
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          padding: EdgeInsets.zero,
                                          itemCount: places.length,
                                          separatorBuilder: (context, index) => const SizedBox(width: 0, height: 12),
                                          itemBuilder: (context, index) {
                                            final place = places[index];
                                            return GestureDetector(
                                              onTap: () => PlaceStoryViewer.show(
                                                context,
                                                places: storyItems,
                                                initialIndex: index,
                                              ),
                                              child: GlassCard(
                                                padding: const EdgeInsets.all(12),
                                                child: Row(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: AppNetworkImage(
                                                        imageUrl: place['image_url'] ?? 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=500',
                                                        width: 75,
                                                        height: 75,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            place['name'] ?? '',
                                                            style: const TextStyle(
                                                              color: AppTheme.textDark,
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.w800,
                                                              shadows: [Shadow(color: Color(0x55000000), blurRadius: 8)],
                                                            ),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          if (place['category'] != null)
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                              decoration: BoxDecoration(
                                                                color: AppTheme.coral.withValues(alpha: 0.25),
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              child: Text(
                                                                place['category'].toString().toUpperCase(),
                                                                style: const TextStyle(
                                                                  color: AppTheme.textDark,
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w800,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    const Icon(LucideIcons.playCircle, color: AppTheme.coral, size: 28),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.borderLight, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/agent_listing', arguments: {'destination': name});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Find Expert Guides Here',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(LucideIcons.arrowRight, size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildGlassInfoCard(IconData icon, String title, String value, Color accentColor) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textDark.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
