import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';
import 'agent_chat_screen.dart';

class AgentChatTabScreen extends StatefulWidget {
  const AgentChatTabScreen({super.key});

  @override
  State<AgentChatTabScreen> createState() => _AgentChatTabScreenState();
}

class _AgentChatTabScreenState extends State<AgentChatTabScreen> {
  final _searchController = TextEditingController();
  StreamSubscription<List<Map<String, dynamic>>>? _bookingsSub;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    final agentId = SupabaseService.instance.activeAgentId ?? SupabaseService.instance.currentUser?.id;
    if (agentId == null) {
      if (!mounted) return;
      setState(() {
        _conversations = [];
        _isLoading = false;
      });
      return;
    }

    _bookingsSub = SupabaseService.instance.streamAgentBookings(agentId).listen((bookings) async {
      if (!mounted) return;

      List<Map<String, dynamic>> convList = [];
      for (var b in bookings) {
        final bId = b['id'];
        final traveller = await SupabaseService.instance.fetchBookingWithTraveller(bId);
        if (traveller != null) {
          convList.add({
            'booking_id': bId,
            'destination': b['destination'] ?? 'Kerala Tour',
            'start_date': b['start_date'] ?? '',
            'end_date': b['end_date'] ?? '',
            'traveller_name': traveller['profiles']?['full_name'] ?? 'Alex Traveler',
            'traveller_photo': traveller['profiles']?['photo_url'] ??
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
            'last_message': 'Tap to chat with traveller...',
            'unread': false,
          });
        }
      }

      if (mounted) {
        setState(() {
          _conversations = convList;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _conversations.where((c) {
      final name = (c['traveller_name'] as String).toLowerCase();
      final dest = (c['destination'] as String).toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || dest.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: Text('Traveller Messages', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Search traveller by name or destination...',
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.kInkSoft),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppTheme.kInkMuted),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Conversations will appear here once you have active or pending tour bookings.',
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.kInkSoft),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final conv = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(conv['traveller_photo']),
                              ),
                              title: Text(
                                conv['traveller_name'],
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              subtitle: Text(
                                '${conv['destination']} · ${conv['last_message']}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.kInkMuted),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AgentChatScreen(
                                      bookingId: conv['booking_id'],
                                      travellerName: conv['traveller_name'],
                                      travellerPhoto: conv['traveller_photo'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
