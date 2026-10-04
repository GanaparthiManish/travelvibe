import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';

class ReviewScreen extends StatefulWidget {
  final String bookingId;
  final String agentId;
  final String agentName;
  final String destinationName;
  final String? destinationId;

  const ReviewScreen({
    super.key,
    required this.bookingId,
    required this.agentId,
    required this.agentName,
    this.destinationName = '',
    this.destinationId,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  // Guide rating
  double _guideRating = 5.0;
  final _guideCommentCtrl = TextEditingController();

  // Destination rating
  double _destRating = 5.0;
  final _destCommentCtrl = TextEditingController();
  final List<XFile> _pickedImages = [];
  final ImagePicker _picker = ImagePicker();

  bool _submitting = false;
  String? _resolvedDestId;

  @override
  void initState() {
    super.initState();
    _resolveDestinationId();
  }

  Future<void> _resolveDestinationId() async {
    if (widget.destinationId != null && widget.destinationId!.isNotEmpty) {
      _resolvedDestId = widget.destinationId;
      return;
    }
    final destName = widget.destinationName.trim();
    if (destName.isNotEmpty) {
      try {
        final client = SupabaseService.client;
        final res = await client
            .from('destinations')
            .select('id, name')
            .ilike('name', '%$destName%')
            .limit(1)
            .maybeSingle();
        if (res != null && mounted) {
          setState(() {
            _resolvedDestId = res['id'] as String?;
          });
        }
      } catch (e) {
        debugPrint('Could not resolve destinationId: $e');
      }
    }
  }

  Future<void> _pickImages() async {
    if (_pickedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 photos allowed per review.')),
      );
      return;
    }

    try {
      final remaining = 5 - _pickedImages.length;
      final List<XFile> selected = await _picker.pickMultiImage(limit: remaining);
      if (selected.isNotEmpty && mounted) {
        setState(() {
          _pickedImages.addAll(selected.take(remaining));
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pickedImages.removeAt(index);
    });
  }

  Future<void> _submitReview() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.')),
      );
      return;
    }

    final guideComment = _guideCommentCtrl.text.trim();
    final destComment = _destCommentCtrl.text.trim();

    if (guideComment.isEmpty && destComment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please share a few words about your experience.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final client = SupabaseService.client;

      // 1. Submit Guide Review
      if (widget.agentId.isNotEmpty) {
        try {
          await client.from('reviews').insert({
            'booking_id': widget.bookingId,
            'agent_id': widget.agentId,
            'traveller_id': userId,
            'overall_rating': _guideRating,
            'safety_rating': _guideRating,
            'punctuality_rating': _guideRating,
            'value_rating': _guideRating,
            'communication_rating': _guideRating,
            'review_text': guideComment.isNotEmpty ? guideComment : destComment,
          });

          // Recalculate agent rating
          final reviews = await client
              .from('reviews')
              .select('overall_rating')
              .eq('agent_id', widget.agentId);
          if (reviews != null && (reviews as List).isNotEmpty) {
            final list = reviews as List;
            final count = list.length;
            final avg = list
                    .map((r) => (r['overall_rating'] as num?)?.toDouble() ?? 5.0)
                    .reduce((a, b) => a + b) /
                count;
            await client.from('agent_details').update({
              'rating_avg': avg,
              'review_count': count,
            }).eq('id', widget.agentId);
          }
        } catch (guideErr) {
          debugPrint('Error inserting agent review: $guideErr');
        }
      }

      // 2. Submit Destination Review
      if (_resolvedDestId != null && _resolvedDestId!.isNotEmpty) {
        try {
          final destReviewRes = await client.from('destination_reviews').insert({
            'destination_id': _resolvedDestId,
            'traveller_id': userId,
            'booking_id': widget.bookingId,
            'rating': _destRating.round(),
            'review_text': destComment.isNotEmpty ? destComment : guideComment,
          }).select('id').single();

          final destReviewId = destReviewRes['id'] as String;

          // 3. Upload attached photos
          if (_pickedImages.isNotEmpty) {
            for (int i = 0; i < _pickedImages.length; i++) {
              try {
                final file = _pickedImages[i];
                final bytes = await file.readAsBytes();
                final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
                final path = 'reviews/${destReviewId}_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

                await client.storage.from('review-images').uploadBinary(
                  path,
                  bytes,
                  fileOptions: FileOptions(contentType: 'image/$ext'),
                );

                final publicUrl = client.storage.from('review-images').getPublicUrl(path);

                await client.from('destination_review_images').insert({
                  'review_id': destReviewId,
                  'image_url': publicUrl,
                  'display_order': i,
                });
              } catch (uploadErr) {
                debugPrint('Error uploading review photo $i: $uploadErr');
              }
            }
          }
        } catch (destErr) {
          debugPrint('Error inserting destination review: $destErr');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you! Your reviews and photos have been submitted.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('General review submit error: $e');
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _guideCommentCtrl.dispose();
    _destCommentCtrl.dispose();
    super.dispose();
  }

  Widget _buildStarPicker({required double rating, required ValueChanged<double> onRatingChanged}) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starVal = (index + 1).toDouble();
          return IconButton(
            iconSize: 34,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: Icon(
              rating >= starVal ? Icons.star_rounded : Icons.star_border_rounded,
              color: const Color(0xFFFFB800),
            ),
            onPressed: () => onRatingChanged(starVal),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destTitle = widget.destinationName.isNotEmpty ? widget.destinationName : 'the Destination';

    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: kInk),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Rate Your Experience', style: kAppBarTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Guide Rating Section ─────────────────────────────────────
              ttInfoCard(
                context: context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, color: kAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your Guide: ${widget.agentName}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'How was your experience with ${widget.agentName}?',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kInkSoft),
                    ),
                    const SizedBox(height: 10),
                    _buildStarPicker(
                      rating: _guideRating,
                      onRatingChanged: (r) => setState(() => _guideRating = r),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'FEEDBACK FOR GUIDE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: kInkSoft,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _guideCommentCtrl,
                      maxLines: 3,
                      decoration: ttFieldDeco('Comment on guide expertise, friendliness, punctuality...'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 2. Destination Rating Section ──────────────────────────────
              ttInfoCard(
                context: context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_rounded, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Destination: $destTitle',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'How was your trip to $destTitle? Was it worth visiting?',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kInkSoft),
                    ),
                    const SizedBox(height: 10),
                    _buildStarPicker(
                      rating: _destRating,
                      onRatingChanged: (r) => setState(() => _destRating = r),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'DESTINATION REVIEW',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: kInkSoft,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _destCommentCtrl,
                      maxLines: 4,
                      decoration: ttFieldDeco('Share what you loved, scenery, best spots, tips for others...'),
                    ),
                    const SizedBox(height: 16),

                    // Attached Photos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PHOTOS (${_pickedImages.length}/5)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: kInkSoft,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (_pickedImages.length < 5)
                          GestureDetector(
                            onTap: _pickImages,
                            child: Row(
                              children: [
                                const Icon(Icons.add_photo_alternate_rounded, size: 16, color: kAccent),
                                const SizedBox(width: 4),
                                Text(
                                  'Add Photos',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_pickedImages.isNotEmpty)
                      SizedBox(
                        height: 74,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _pickedImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final xf = _pickedImages[idx];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kIsWeb
                                      ? Image.network(xf.path, width: 70, height: 70, fit: BoxFit.cover)
                                      : Image.file(File(xf.path), width: 70, height: 70, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(idx),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: appLineColor(context).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: appLineColor(context)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 20, color: kInkSoft),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Add 1 to 5 real trip photos to help other travellers see the place.',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: kInkSoft),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _submitting
                  ? const Center(child: CircularProgressIndicator(color: kAccent))
                  : ttPrimaryBtn('Submit All Reviews', onTap: _submitReview),
            ],
          ),
        ),
      ),
    );
  }
}
