import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_network_image.dart';

void showPlaceBottomSheet(BuildContext context, Map<String, dynamic> place) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PlaceBottomSheet(place: place),
  );
}

class _PlaceBottomSheet extends StatelessWidget {
  final Map<String, dynamic> place;

  const _PlaceBottomSheet({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.warmPaper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppTheme.inkNavy, width: 2.5),
          left: BorderSide(color: AppTheme.inkNavy, width: 2.5),
          right: BorderSide(color: AppTheme.inkNavy, width: 2.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (place['image_url'] != null && place['image_url'].toString().isNotEmpty)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: AppTheme.thickBorder,
                boxShadow: AppTheme.stickerShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AppNetworkImage(
                  imageUrl: place['image_url'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            place['name'] ?? 'Unknown Place',
            style: const TextStyle(
              color: AppTheme.inkNavy,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (place['category'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.sunshineYellow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.inkNavy, width: 1.5),
                  ),
                  child: Text(
                    place['category'].toString().toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.inkNavy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (place['ideal_duration'] != null && place['ideal_duration'].toString().isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.clock, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      place['ideal_duration'],
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              if (place['best_time_of_day'] != null && place['best_time_of_day'].toString().isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.sun, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      place['best_time_of_day'],
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (place['description'] != null && place['description'].toString().isNotEmpty)
            Text(
              place['description'],
              style: const TextStyle(
                color: AppTheme.inkNavy,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
