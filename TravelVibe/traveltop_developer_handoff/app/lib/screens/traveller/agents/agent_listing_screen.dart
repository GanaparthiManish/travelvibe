import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/app_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';

class AgentListingScreen extends StatefulWidget {
  const AgentListingScreen({super.key});

  @override
  State<AgentListingScreen> createState() => _AgentListingScreenState();
}

class _AgentListingScreenState extends State<AgentListingScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> _agents = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchAgents();
    _setupRealtime();
  }

  void _setupRealtime() {
    _channel = _supabase.channel('public:agent_details_listing').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'agent_details',
      callback: (payload) {
        _fetchAgents();
      }
    ).subscribe();
  }

  Future<void> _fetchAgents() async {
    try {
      final res = await _supabase.from('agent_details').select('''
        *,
        profiles(full_name, photo_url)
      ''').eq('verified', true).eq('suspended', false).order('rating_avg', ascending: false);
      
      if (mounted) {
        setState(() {
          _agents = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching agents: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAgents = _agents.where((agent) {
      final profile = agent['profiles'] ?? {};
      final name = profile['full_name']?.toString().toLowerCase() ?? '';
      final location = (agent['places_covered'] as List?)?.join(', ').toLowerCase() ?? '';
      
      final matchesSearch = name.contains(_searchController.text.toLowerCase()) ||
                            location.contains(_searchController.text.toLowerCase());
      
      if (!matchesSearch) return false;

      if (_selectedFilter == 'Top Rated') {
        final rating = agent['rating_avg'] ?? 0.0;
        if (rating < 4.8) return false;
      }
      
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(context),
                _buildSearchAndFilters(),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredAgents.isEmpty
                      ? EmptyStateWidget(
                          title: 'No Agents Found',
                          description:
                              'Try searching for another location or clearing your filter.',
                          icon: Icons.person_off,
                          buttonText: 'Reset Search',
                          onButtonPressed: () {
                            setState(() {
                              _searchController.clear();
                              _selectedFilter = 'All';
                            });
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filteredAgents.length,
                          itemBuilder: (context, index) {
                            return _buildAgentCard(filteredAgents[index]);
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
                  child: const Icon(Icons.arrow_back, color: AppTheme.textDark, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Explore Local Guides',
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

  Widget _buildSearchAndFilters() {
    final filters = ['All', 'Top Rated', 'Budget', 'Adventure'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          // Search Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.textDark.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.softShadow,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppTheme.charcoalText),
              decoration: const InputDecoration(
                hintText: 'Search by city or guide name...',
                hintStyle: TextStyle(color: AppTheme.greyText),
                border: InputBorder.none,
                icon: Icon(Icons.search, color: AppTheme.oceanTeal),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedFilter = filter);
                    },
                    selectedColor: AppTheme.coralGold,
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.charcoalText,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.coralGold : Colors.transparent,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final profile = agent['profiles'] ?? {};
    final avatar = profile['photo_url'] ?? 'https://ui-avatars.com/api/?name=${profile['full_name'] ?? 'Agent'}';
    final name = profile['full_name'] ?? 'Agent';
    final location = (agent['places_covered'] as List?)?.join(', ') ?? 'Global';
    final rating = agent['rating_avg'] ?? 5.0;
    final trips = agent['review_count'] ?? 0;
    final rate = '₹${agent['price_per_day'] ?? 0}/day';
    final tags = List<String>.from(agent['tags'] ?? []);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/agent_profile', arguments: agent['id']),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AppNetworkImage(
                      imageUrl: avatar,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppTheme.charcoalText,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, color: AppTheme.oceanTeal, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: const TextStyle(color: AppTheme.greyText, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AppTheme.coralGold, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '$rating ($trips reviews)',
                              style: const TextStyle(
                                color: AppTheme.charcoalText,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    rate,
                    style: const TextStyle(
                      color: AppTheme.oceanTeal,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.oceanTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: AppTheme.oceanTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
