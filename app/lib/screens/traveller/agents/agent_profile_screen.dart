import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/app_network_image.dart';

class AgentProfileScreen extends StatefulWidget {
  const AgentProfileScreen({super.key});

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen> {
  final _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  
  String? _agentId;
  Map<String, dynamic>? _agentData;
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_agentId == null) {
      final args = ModalRoute.of(context)?.settings.arguments as String?;
      if (args != null) {
        _agentId = args;
        _fetchAgent();
        _setupRealtime();
      } else {
        setState(() => _loading = false);
      }
    }
  }

  void _setupRealtime() {
    if (_agentId == null) return;
    _channel = _supabase.channel('public:agent_details:$_agentId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'agent_details',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: _agentId!,
      ),
      callback: (payload) {
        _fetchAgent();
      }
    ).subscribe();
  }

  Future<void> _fetchAgent() async {
    try {
      final res = await _supabase.from('agent_details').select('''
        *,
        profiles(full_name, photo_url)
      ''').eq('id', _agentId!).maybeSingle();
      
      if (mounted) {
        setState(() {
          _agentData = res;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching agent: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.sandBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_agentData == null) {
      return Scaffold(
        backgroundColor: AppTheme.sandBg,
        appBar: AppBar(title: const Text('Agent Profile')),
        body: const Center(child: Text('Agent not found.')),
      );
    }

    final agent = _agentData!;
    final profile = agent['profiles'] ?? {};
    final avatar = profile['photo_url'] ?? 'https://ui-avatars.com/api/?name=${profile['full_name'] ?? 'Agent'}';
    final name = profile['full_name'] ?? 'Agent';
    final location = (agent['places_covered'] as List?)?.join(', ') ?? 'Global';
    final rating = agent['rating_avg'] ?? 5.0;
    final trips = agent['review_count'] ?? 0;
    final rate = '₹${agent['price_per_day'] ?? 0} / day';
    final bio = agent['bio'] ?? 'Experienced travel guide ready to show you the best spots.';
    final tags = List<String>.from(agent['tags'] ?? []);

    return Scaffold(
      backgroundColor: AppTheme.sandBg,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(context, avatar),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(context, name, location, rating, trips, avatar),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'About Guide'),
                  const SizedBox(height: 10),
                  GlassCard(
                    child: Text(
                      bio,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: AppTheme.charcoalText,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Places Covered'),
                  const SizedBox(height: 10),
                  _buildChips((agent['places_covered'] as List?)?.map((e) => e.toString()).toList() ?? []),
                  
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Tags / Specialities'),
                    const SizedBox(height: 10),
                    _buildChips(tags),
                  ],

                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Services Included'),
                  const SizedBox(height: 10),
                  _buildServiceIcons(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Traveler Reviews ($trips)'),
                  const SizedBox(height: 10),
                  _buildReviewList(context),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildStickyBottomBar(context, rate),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, String coverImageUrl) {
    return SliverAppBar(
      expandedHeight: 280.0,
      pinned: true,
      backgroundColor: AppTheme.oceanTeal,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                double offset = 0.0;
                if (_scrollController.hasClients && _scrollController.positions.isNotEmpty) {
                  offset = _scrollController.offset * 0.3;
                }
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: AppNetworkImage(
                    imageUrl: coverImageUrl,
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.oceanTeal.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
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
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, String name, String location, num rating, int trips, String avatar) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: AppNetworkImage(
                  imageUrl: avatar,
                  width: 72,
                  height: 72,
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin, color: AppTheme.oceanTeal, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: const TextStyle(color: AppTheme.greyText, fontSize: 14),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.charcoalText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _buildChips(List<String> tags) {
    if (tags.isEmpty) {
      return const Text('None available', style: TextStyle(color: AppTheme.greyText));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.oceanTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.oceanTeal.withValues(alpha: 0.2)),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              color: AppTheme.oceanTeal,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServiceIcons() {
    final services = [
      {'icon': LucideIcons.car, 'label': 'Private Car'},
      {'icon': LucideIcons.camera, 'label': 'Photography'},
      {'icon': LucideIcons.languages, 'label': 'English Speaking'},
      {'icon': LucideIcons.ticket, 'label': 'Passes Included'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        return GlassCard(
          padding: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Icon(services[index]['icon'] as IconData, color: AppTheme.oceanTeal, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  services[index]['label'] as String,
                  style: const TextStyle(
                    color: AppTheme.charcoalText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewList(BuildContext context) {
    return Column(
      children: List.generate(2, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      index == 0 ? 'Sarah Jenkins' : 'Michael Chang',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.charcoalText,
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.star_rounded, color: AppTheme.coralGold, size: 16),
                        SizedBox(width: 2),
                        Text('5.0', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  index == 0
                      ? 'Incredible guide! Took us to places before the crowd arrived.'
                      : 'Super knowledgeable and fluent in English. High quality private transport.',
                  style: const TextStyle(color: AppTheme.greyText, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStickyBottomBar(BuildContext context, String rateStr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        boxShadow: AppTheme.softShadow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Guide Fee', style: TextStyle(color: AppTheme.greyText, fontSize: 12)),
                Text(
                  rateStr,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.oceanTeal,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: GradientButton(
              text: 'Book Guide Now',
              style: GradientButtonStyle.primaryCoral,
              onPressed: () => Navigator.pushNamed(context, '/availability'),
            ),
          ),
        ],
      ),
    );
  }
}
