import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_network_image.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/nature_background.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Map<String, dynamic>> _wishlist = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    setState(() => _loading = true);
    final items = await SupabaseService.instance.fetchWishlist();
    if (mounted) {
      setState(() {
        _wishlist = items;
        _loading = false;
      });
    }
  }

  Future<void> _removeItem(String agentId) async {
    setState(() {
      _wishlist.removeWhere((item) => item['agent_id'] == agentId);
    });
    await SupabaseService.instance.toggleWishlist(agentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NatureBackground(
        child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
                  : _wishlist.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.78,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _wishlist.length,
                          itemBuilder: (context, index) {
                            final item = _wishlist[index];
                            final agentDetails = item['agent_details'] ?? {};
                            final profiles = agentDetails['profiles'] ?? {};
                            final name = profiles['full_name'] ?? 'Agent';
                            final photoUrl = profiles['photo_url'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300';
                            final price = (agentDetails['price_per_day'] ?? 2500).toString();
                            final agentId = item['agent_id'];

                            return GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/agent_profile', arguments: agentId),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.textDark.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppTheme.textDark.withValues(alpha: 0.3), width: 1.5),
                                    ),
                                    child: Stack(
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                              child: AppNetworkImage(
                                                imageUrl: photoUrl,
                                                height: 120,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textDark, fontSize: 14,
                                                      shadows: [Shadow(color: Color(0x44000000), blurRadius: 4)]),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Verified Tour Agent',
                                                    style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.75), fontSize: 12),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.coral.withValues(alpha: 0.85),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      '₹$price/day',
                                                      style: const TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w800, fontSize: 12),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => _removeItem(agentId),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AppTheme.textDark.withValues(alpha: 0.25),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: AppTheme.textDark.withValues(alpha: 0.3)),
                                              ),
                                              child: const Icon(LucideIcons.heart, size: 16, color: AppTheme.coral),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
                  child: const Icon(Icons.arrow_back, color: AppTheme.textDark, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Saved Destinations',
            style: TextStyle(
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.coral.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.heart, size: 48, color: AppTheme.coral),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your Wishlist is Empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textDark,
              shadows: [Shadow(color: Color(0x44000000), blurRadius: 6)]),
          ),
          const SizedBox(height: 8),
          Text(
            'Explore top rated agents and save them for your next trip.',
            style: TextStyle(fontSize: 14, color: AppTheme.textDark.withValues(alpha: 0.78)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/agent_listing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.sunshineYellow,
              foregroundColor: AppTheme.inkNavy,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.inkNavy, width: 2),
              ),
            ),
            child: const Text('Explore Agents', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
