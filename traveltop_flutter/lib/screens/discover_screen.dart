import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../main.dart';
import '../services/data_service.dart';
import 'destination_detail_screen.dart';


class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchCtrl = TextEditingController();
  int _selectedFilter = 0;
  List<DestinationData> _results = [];
  bool _loading = false;

  final List<String> _filters = const ['Top Rated', 'Featured', 'Trending'];

  @override
  void initState() {
    super.initState();
    _fetchDestinations();
  }

  Future<void> _fetchDestinations() async {
    setState(() => _loading = true);
    try {
      final query = _searchCtrl.text.trim();
      dynamic req = SupabaseService.client.from('destinations').select('*');

      if (query.isNotEmpty) {
        req = req.ilike('name', '%$query%');
      }

      if (_selectedFilter == 1) {
        req = req.eq('is_featured', true);
      } else if (_selectedFilter == 2) {
        req = req.eq('is_trending', true);
      }

      final res = await req.order('created_at', ascending: false);
      final items = (res as List).map((e) => DestinationData.fromJson(e)).toList();
      setState(() => _results = items);
    } catch (e) {
      debugPrint('Error fetching search destinations: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeNotifier, languageNotifier]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: appBgColor(context),

          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ttAppBar(context, 'Discover & Search'),
                // Search Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => _fetchDestinations(),
                    style: TextStyle(color: appInkColor(context)),
                    decoration: ttFieldDeco(tr('search_placeholder'), context: context).copyWith(
                      prefixIcon: Icon(Icons.search_rounded, color: appInkSoftColor(context)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: appInkSoftColor(context)),
                              onPressed: () {
                                _searchCtrl.clear();
                                _fetchDestinations();
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Wrap(
                    spacing: 8,
                    children: List.generate(_filters.length, (i) {
                      return ttChip(
                        _filters[i],
                        context: context,
                        active: _selectedFilter == i,
                        onTap: () {
                          setState(() => _selectedFilter = i);
                          _fetchDestinations();
                        },
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 10),

                // Results List
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: kAccent))
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                'No matching destinations found.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: appInkSoftColor(context),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _results.length,
                              itemBuilder: (_, i) {
                                final d = _results[i];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DestinationDetailScreen(
                                          destinationId: d.id,
                                          destinationName: d.name,
                                          country: d.country,
                                          coverImageUrl: d.coverImageUrl,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ttListCard(
                                    context: context,
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        d.coverImageUrl.isNotEmpty
                                            ? d.coverImageUrl
                                            : 'https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=400&q=80',
                                        width: 64,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(color: appPaperColor(context)),
                                      ),
                                    ),

                                    middle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(d.name, style: kLcTitle.copyWith(color: appInkColor(context))),
                                        const SizedBox(height: 2),
                                        Text('Explore places & guides',
                                            style: kLcMeta.copyWith(color: appInkSoftColor(context))),
                                      ],
                                    ),
                                    trailing: Icon(
                                        Icons.chevron_right_rounded,
                                        color: appInkSoftColor(context),
                                        size: 20),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}
