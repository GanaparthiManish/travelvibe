import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../services/supabase_service.dart';

class WriteReviewScreen extends StatefulWidget {
  const WriteReviewScreen({super.key});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _commentController = TextEditingController();
  int _overallRating = 5;
  int _safetyRating = 5;
  int _punctualityRating = 5;
  int _valueRating = 5;
  int _commRating = 5;
  bool _isSubmitting = false;

  String? _bookingId;
  String? _agentId;
  String _destination = 'Tour Trip';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _bookingId = args['booking_id'];
      _agentId = args['agent_id'];
      _destination = args['destination'] ?? 'Tour Trip';
    }
  }

  Future<void> _submitReview() async {
    if (_bookingId == null || _agentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing booking or agent info for review.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.instance.submitReview(
        bookingId: _bookingId!,
        agentId: _agentId!,
        overallRating: _overallRating,
        safetyRating: _safetyRating,
        punctualityRating: _punctualityRating,
        valueRating: _valueRating,
        communicationRating: _commRating,
        reviewText: _commentController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.checkCircle2, color: AppTheme.textDark),
                SizedBox(width: 10),
                Text('Review submitted successfully! Thank you.'),
              ],
            ),
            backgroundColor: AppTheme.softGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting review: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTripHeaderCard(),
                        const SizedBox(height: 20),
                        _buildRatingSection(),
                        const SizedBox(height: 20),
                        _buildCommentSection(),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),
                _buildSubmitButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.textDark.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.textDark.withValues(alpha: 0.3), width: 1.2),
                  ),
                  child: Icon(LucideIcons.arrowLeft, color: AppTheme.textDark, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Write a Review',
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Color(0x55000000), blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripHeaderCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.coralGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.award, color: AppTheme.coralGold, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _destination,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.charcoalText,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Share your honest feedback to help future travellers.',
                  style: TextStyle(color: AppTheme.greyText, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rate Your Experience',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.charcoalText),
          ),
          const SizedBox(height: 16),
          _buildStarRow('Overall Experience', _overallRating, (val) => setState(() => _overallRating = val)),
          const Divider(height: 24),
          _buildStarRow('Safety & Security', _safetyRating, (val) => setState(() => _safetyRating = val)),
          const SizedBox(height: 12),
          _buildStarRow('Punctuality & Timing', _punctualityRating, (val) => setState(() => _punctualityRating = val)),
          const SizedBox(height: 12),
          _buildStarRow('Value for Money', _valueRating, (val) => setState(() => _valueRating = val)),
          const SizedBox(height: 12),
          _buildStarRow('Communication', _commRating, (val) => setState(() => _commRating = val)),
        ],
      ),
    );
  }

  Widget _buildStarRow(String label, int currentRating, Function(int) onSelect) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: label.startsWith('Overall') ? FontWeight.w800 : FontWeight.w600,
              color: AppTheme.charcoalText,
            ),
          ),
        ),
        Row(
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return GestureDetector(
              onTap: () => onSelect(starValue),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  starValue <= currentRating ? LucideIcons.star : LucideIcons.star,
                  color: starValue <= currentRating ? AppTheme.coralGold : Colors.grey.shade300,
                  size: label.startsWith('Overall') ? 24 : 20,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Written Review',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.charcoalText),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'What did you enjoy most about this tour guide? Were there any areas for improvement?',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.oceanTeal, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GradientButton(
        text: _isSubmitting ? 'Submitting Review…' : 'Submit Review',
        style: GradientButtonStyle.primaryCoral,
        onPressed: _isSubmitting ? () {} : _submitReview,
      ),
    );
  }
}
