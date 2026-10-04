import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_network_image.dart';
import '../../../widgets/glass_app_bar.dart';

class TravellerChatScreen extends StatefulWidget {
  const TravellerChatScreen({super.key});

  @override
  State<TravellerChatScreen> createState() => _TravellerChatScreenState();
}

class _TravellerChatScreenState extends State<TravellerChatScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _msgController = TextEditingController();
  
  String? _bookingId;
  String? _myUserId;
  Map<String, dynamic>? _booking;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingId == null) {
      final args = ModalRoute.of(context)?.settings.arguments as String?;
      if (args != null) {
        _bookingId = args;
        _myUserId = _supabase.auth.currentUser?.id;
        _fetchInitialData();
        _setupRealtime();
      } else {
        setState(() => _loading = false);
      }
    }
  }

  void _setupRealtime() {
    if (_bookingId == null) return;
    _channel = _supabase.channel('public:messages:$_bookingId').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'booking_id',
        value: _bookingId!,
      ),
      callback: (payload) {
        final newMsg = payload.newRecord;
        if (newMsg['sender_id'] != _myUserId) {
          setState(() {
            _messages.add(newMsg);
          });
        }
      }
    ).subscribe();
  }

  Future<void> _fetchInitialData() async {
    try {
      final bookingRes = await _supabase.from('bookings').select('''
        *,
        agent:agent_id (
          full_name,
          photo_url
        )
      ''').eq('id', _bookingId!).maybeSingle();
      
      final messagesRes = await _supabase.from('messages')
        .select()
        .eq('booking_id', _bookingId!)
        .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _booking = bookingRes;
          _messages = List<Map<String, dynamic>>.from(messagesRes);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching chat data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _bookingId == null || _myUserId == null) return;
    
    _msgController.clear();
    
    final tempMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'booking_id': _bookingId,
      'sender_id': _myUserId,
      'content': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    
    setState(() {
      _messages.add(tempMsg);
    });

    try {
      await _supabase.from('messages').insert({
        'booking_id': _bookingId,
        'sender_id': _myUserId,
        'content': text,
      });
      // The local tempMsg could be replaced with real ID if needed, 
      // but for simplicity we rely on optimistic update + fetch or just keeping optimistic
    } catch (e) {
      debugPrint('Error sending message: $e');
      // If failed, remove optimistic message
      setState(() {
        _messages.remove(tempMsg);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Chat not found.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_id'] == _myUserId;
                      
                      String timeStr = '';
                      if (msg['created_at'] != null) {
                        try {
                          final dt = DateTime.parse(msg['created_at']).toLocal();
                          timeStr = DateFormat('hh:mm a').format(dt);
                        } catch (_) {}
                      }

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? AppTheme.coralGold : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isMe ? 20 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 20),
                            ),
                            boxShadow: AppTheme.softShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['content'] ?? '',
                                style: TextStyle(
                                  color: isMe ? Colors.white : AppTheme.charcoalText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (timeStr.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: isMe ? Colors.white70 : AppTheme.greyText,
                                    fontSize: 10,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final agentName = _booking?['agent']?['full_name'] ?? 'Agent';
    final agentPhoto = _booking?['agent']?['photo_url'] ?? 'https://ui-avatars.com/api/?name=$agentName';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.textDark.withValues(alpha: 0.9),
        border: Border(bottom: BorderSide(color: AppTheme.textDark.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          const GlassBackButton(),
          const SizedBox(width: 12),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AppNetworkImage(
                  imageUrl: agentPhoto,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.softGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.textDark, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agentName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.charcoalText, fontSize: 16)),
                const Text('Online • Tour Guide', style: TextStyle(color: AppTheme.softGreen, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        boxShadow: AppTheme.softShadow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(LucideIcons.paperclip, color: AppTheme.greyText), onPressed: () {}),
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: AppTheme.greyText),
                filled: true,
                fillColor: AppTheme.sandBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: AppTheme.coralGold,
            child: IconButton(
              icon: const Icon(LucideIcons.send, color: AppTheme.textDark, size: 18),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
