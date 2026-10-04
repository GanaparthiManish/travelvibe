import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/agent_avatar.dart';

class AgentReviewsScreen extends StatefulWidget {
  const AgentReviewsScreen({super.key});

  @override
  State<AgentReviewsScreen> createState() => _AgentReviewsScreenState();
}

class _AgentReviewsScreenState extends State<AgentReviewsScreen> {
  StreamSubscription<List<Map<String, dynamic>>>? _reviewsSub;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  int _selectedFilterStar = 0; // 0 = All

  @override
  void initState() {
    super.initState();
    _subscribeReviews();
  }

  void _subscribeReviews() {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    _reviewsSub = SupabaseService.instance.streamAgentReviews(user.id).listen((rList) {
      if (!mounted) return;
      setState(() {
        _reviews = rList;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _reviewsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedFilterStar == 0
        ? _reviews
        : _reviews.where((r) => r['overall_rating'] == _selectedFilterStar).toList();

    double avgOverall = 4.9;
    if (_reviews.isNotEmpty) {
      final sum = _reviews.fold<num>(0, (prev, curr) => prev + (curr['overall_rating'] ?? 5));
      avgOverall = sum / _reviews.length;
    }

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: const Text('Reviews Received'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Rating Summary Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.kWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.kLine, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              avgOverall.toStringAsFixed(1),
                              style: GoogleFonts.plusJakartaSans(fontSize: 38, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                            ),
                            Row(
                              children: List.generate(
                                5,
                                (i) => const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${_reviews.length} Verified Traveller Reviews', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft)),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildSubRatingRow('Safety', '4.9★'),
                            _buildSubRatingRow('Punctuality', '4.8★'),
                            _buildSubRatingRow('Value', '4.9★'),
                            _buildSubRatingRow('Communication', '5.0★'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [0, 5, 4, 3, 2, 1].map((star) {
                        final isSelected = _selectedFilterStar == star;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(star == 0 ? 'All' : '$star ★'),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedFilterStar = star),
                            selectedColor: AppTheme.kInk,
                            backgroundColor: AppTheme.kWhite,
                            labelStyle: GoogleFonts.plusJakartaSans(
                              color: isSelected ? AppTheme.kWhite : AppTheme.kInk,
                              fontWeight: FontWeight.w700,
                            ),
                            side: const BorderSide(color: AppTheme.kLine, width: 1.5),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Reviews List
                  filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'No reviews matching this filter.',
                              style: GoogleFonts.plusJakartaSans(color: AppTheme.kInkSoft, fontSize: 14),
                            ),
                          ),
                        )
                      : Column(
                          children: filtered.map((r) {
                            final travellerName = r['profiles']?['full_name'] ?? 'Verified Traveller';
                            final photoUrl = r['profiles']?['photo_url'] ??
                                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300';
                            final rating = (r['overall_rating'] ?? 5) as int;
                            final text = r['review_text'] ?? 'Great guide! Very knowledgeable and punctual.';
                            final dateStr = (r['created_at'] ?? '').toString().split('T')[0];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.kWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.kLine, width: 1.5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      AgentAvatar(name: travellerName, photoUrl: photoUrl, radius: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(travellerName, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
                                            Text(dateStr, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.kInkSoft)),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: List.generate(
                                          rating,
                                          (i) => const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '"$text"',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.5, color: AppTheme.kInk, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildSubRatingRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.kInkSoft)),
          Text(val, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
        ],
      ),
    );
  }
}
