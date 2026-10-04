import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/data_service.dart';
import 'destination_detail_screen.dart';

class CategoryDestinationsScreen extends StatefulWidget {
  final String initialCategory; // e.g. 'beach', 'hills', etc.
  final String initialLabel;    // e.g. 'Beach'

  const CategoryDestinationsScreen({
    super.key,
    required this.initialCategory,
    required this.initialLabel,
  });

  @override
  State<CategoryDestinationsScreen> createState() => _CategoryDestinationsScreenState();
}

class _CategoryDestinationsScreenState extends State<CategoryDestinationsScreen> {
  late String _selectedCat;
  late String _selectedLabel;
  List<DestinationData> _results = [];
  bool _loading = true;

  final List<_CatItem> _categories = const [
    _CatItem(id: 'all',        label: 'All',        icon: Icons.explore_rounded),
    _CatItem(id: 'beach',      label: 'Beach',      icon: Icons.beach_access_rounded),
    _CatItem(id: 'hills',      label: 'Hills',      icon: Icons.terrain_rounded),
    _CatItem(id: 'honeymoon',  label: 'Honeymoon',  icon: Icons.favorite_rounded),
    _CatItem(id: 'adventure',  label: 'Adventure',  icon: Icons.surfing_rounded),
    _CatItem(id: 'culture',    label: 'Culture',    icon: Icons.account_balance_rounded),
    _CatItem(id: 'wildlife',   label: 'Wildlife',   icon: Icons.forest_rounded),
    _CatItem(id: 'pilgrimage', label: 'Pilgrimage', icon: Icons.temple_buddhist_rounded),
    _CatItem(id: 'heritage',   label: 'Heritage',   icon: Icons.castle_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCat = widget.initialCategory;
    _selectedLabel = widget.initialLabel;
    _filter(_selectedCat);
  }

  void _filter(String cat) {
    final all = DataService.instance.data.value.destinations;
    setState(() {
      _loading = true;
      _selectedCat = cat;
      _selectedLabel = _categories.firstWhere((c) => c.id == cat, orElse: () => _categories[0]).label;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      final filtered = cat == 'all'
          ? all
          : all.where((d) => _matchesCat(d, cat)).toList();

      if (mounted) {
        setState(() {
          _results = filtered;
          _loading = false;
        });
      }
    });
  }

  bool _matchesCat(DestinationData d, String cat) {
    final text = '${d.name} ${d.country}'.toLowerCase();
    switch (cat) {
      case 'beach':
        return text.contains('beach') || text.contains('goa') || text.contains('alleppey') ||
            text.contains('backwater') || text.contains('coastal') || text.contains('sea') ||
            text.contains('island') || text.contains('marina') || text.contains('shore');
      case 'hills':
        return text.contains('hill') || text.contains('munnar') || text.contains('ladakh') ||
            text.contains('tea') || text.contains('valley') || text.contains('mountain') ||
            text.contains('ooty') || text.contains('shimla') || text.contains('manali') ||
            text.contains('darjeeling') || text.contains('plateau') || text.contains('spiti') ||
            text.contains('dzükou') || text.contains('dzukou') || text.contains('kaas') ||
            text.contains('khajjiar');
      case 'honeymoon':
        return text.contains('honeymoon') || text.contains('munnar') || text.contains('alleppey') ||
            text.contains('maldives') || text.contains('bali') || text.contains('coorg') ||
            text.contains('romantic') || text.contains('andaman');
      case 'adventure':
        return text.contains('rafting') || text.contains('ladakh') || text.contains('rishikesh') ||
            text.contains('trek') || text.contains('adventure') || text.contains('camping') ||
            text.contains('skiing') || text.contains('surfing') || text.contains('scuba');
      case 'culture':
        return text.contains('monastery') || text.contains('culture') || text.contains('temple') ||
            text.contains('rishikesh') || text.contains('varanasi') || text.contains('jaipur') ||
            text.contains('old') || text.contains('historic') || text.contains('heritage');
      case 'wildlife':
        return text.contains('wildlife') || text.contains('safari') || text.contains('jungle') ||
            text.contains('tiger') || text.contains('national park') || text.contains('forest') ||
            text.contains('kaziranga') || text.contains('ranthambore') || text.contains('bandhavgarh');
      case 'pilgrimage':
        return text.contains('temple') || text.contains('shrine') || text.contains('pilgrimage') ||
            text.contains('mandir') || text.contains('holy') || text.contains('dham') ||
            text.contains('varanasi') || text.contains('tirupati');
      case 'heritage':
        return text.contains('fort') || text.contains('palace') || text.contains('heritage') ||
            text.contains('unesco') || text.contains('monument') || text.contains('hampi') ||
            text.contains('mahabalipuram') || text.contains('khajuraho');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kAccent = const Color(0xFFE84040);

    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: appInkColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedCat == 'all' ? 'All Destinations' : '$_selectedLabel Destinations',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: appInkColor(context),
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category Filter Chips ────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final selected = cat.id == _selectedCat;
                return GestureDetector(
                  onTap: () => _filter(cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? kAccent : appPaperColor(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? kAccent : appLineColor(context),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat.icon,
                          size: 14,
                          color: selected ? Colors.white : appInkSoftColor(context),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          cat.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : appInkColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // ── Results Count ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              _loading ? 'Loading...' : '${_results.length} place${_results.length == 1 ? '' : 's'} found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: appInkSoftColor(context),
              ),
            ),
          ),
          // ── Grid ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE84040)))
                : _results.isEmpty
                    ? _emptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.18,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (context, i) => _DestCard(d: _results[i], kAccent: kAccent),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_off_rounded, size: 64, color: appLineColor(context)),
          const SizedBox(height: 16),
          Text(
            'No destinations found\nfor "$_selectedLabel"',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: appInkSoftColor(context),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _filter('all'),
            child: Text(
              'View All Destinations',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE84040),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestCard extends StatelessWidget {
  final DestinationData d;
  final Color kAccent;
  const _DestCard({required this.d, required this.kAccent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DestinationDetailScreen(
            destinationId: d.id,
            destinationName: d.name,
            country: d.country,
            coverImageUrl: d.coverImageUrl,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: appPaperColor(context),
          border: Border.all(color: appLineColor(context), width: 1.2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(
                d.coverImageUrl.isNotEmpty
                    ? d.coverImageUrl
                    : 'https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=400&q=80',
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context2, error, stack) => Container(
                  height: 100,
                  color: const Color(0xFF6B8F71),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: appInkColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          d.country.isNotEmpty ? d.country : 'India',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: appInkSoftColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 26,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DestinationDetailScreen(
                            destinationId: d.id,
                            destinationName: d.name,
                            country: d.country,
                            coverImageUrl: d.coverImageUrl,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Book',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatItem {
  final String id;
  final String label;
  final IconData icon;
  const _CatItem({required this.id, required this.label, required this.icon});
}
