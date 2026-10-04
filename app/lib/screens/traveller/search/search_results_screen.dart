import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_network_image.dart';
import '../../../services/supabase_service.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  bool _initialized = false;

  final List<String> _filters = ['All', 'Rating', 'Price', 'Distance'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        _searchController.text = args;
      }
      _initialized = true;
      _performSearch();
    }
  }

  Future<void> _performSearch() async {
    setState(() => _loading = true);
    final query = _searchController.text.trim();
    final list = await SupabaseService.instance.searchDestinations(query, filter: _selectedFilter);
    if (mounted) {
      setState(() {
        _results = list;
        _loading = false;
      });
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
            _buildFilterChips(),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
                  : _results.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final item = _results[index];
                            final name = item['name'] ?? 'Destination';
                            final country = item['country'] ?? '';
                            final imageUrl = item['cover_image_url'] ?? item['image_url'] ?? 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=600';
                            final rating = (item['rating_avg'] ?? 4.8).toString();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, '/destination_detail', arguments: item);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.textDark,
                                    borderRadius: BorderRadius.circular(20),
                                    border: AppTheme.thickBorder,
                                    boxShadow: AppTheme.stickerShadow,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                        child: AppNetworkImage(
                                          imageUrl: imageUrl,
                                          height: 160,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppTheme.inkNavy,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.location_on_outlined, color: AppTheme.teal, size: 14),
                                                      const SizedBox(width: 4),
                                                      Text(country, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                                                      const SizedBox(width: 12),
                                                      const Icon(Icons.star, color: AppTheme.sunshineYellow, size: 14),
                                                      const SizedBox(width: 4),
                                                      Text(rating, style: const TextStyle(color: AppTheme.inkNavy, fontSize: 13, fontWeight: FontWeight.w700)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppTheme.teal.withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(LucideIcons.chevronRight, color: AppTheme.teal, size: 20),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
        ],
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
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.textDark.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.textDark.withValues(alpha: 0.3), width: 1.2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _performSearch(),
                    style: const TextStyle(color: AppTheme.textDark),
                    decoration: InputDecoration(
                      hintText: 'Search destination name or country…',
                      hintStyle: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.55)),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search, color: AppTheme.textDark, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedFilter = filter);
                _performSearch();
              },
              backgroundColor: Colors.white,
              selectedColor: AppTheme.sunshineYellow,
              labelStyle: TextStyle(
                color: AppTheme.inkNavy,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppTheme.inkNavy, width: 1.5),
              ),
              showCheckmark: false,
            ),
          );
        },
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
            child: const Icon(LucideIcons.compass, size: 48, color: AppTheme.coral),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Destinations Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.inkNavy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try searching for another keyword like "Bali" or "Ladakh"',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
