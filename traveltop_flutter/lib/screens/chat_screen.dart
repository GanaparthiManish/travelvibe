import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';
import '../services/translation_service.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String recipientName;
  final String? recipientPhotoUrl;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.recipientName,
    this.recipientPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  RealtimeChannel? _subscription;

  // Language & Translation State
  String _myLangCode = 'en';
  String _recipientLangCode = 'ml';
  final Set<String> _showOriginalMsgIds = {};

  // Voice Recording State
  bool _isRecording = false;
  int _recordDurationSec = 0;
  Timer? _recordTimer;
  final Set<String> _playingAudioIds = {};

  final List<String> _quickReplies = [
    '👋 Hi! Are you available for a tour?',
    '📍 Where is the exact meeting point?',
    '🕐 What time does the tour start?',
    '💰 Please share the total estimated cost',
    '✅ Sounds great! I am interested.',
  ];

  @override
  void initState() {
    super.initState();
    _loadParticipantLanguages();
    _fetchMessages();
    _subscribeRealtime();
  }

  Future<void> _loadParticipantLanguages() async {
    final currentUserId = SupabaseService.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final myProfile = await SupabaseService.client
          .from('profiles')
          .select('preferred_language')
          .eq('id', currentUserId)
          .maybeSingle();

      if (myProfile != null && myProfile['preferred_language'] != null) {
        _myLangCode = myProfile['preferred_language'] as String;
      }

      // Fetch recipient preferred language
      final bookingRow = await SupabaseService.client
          .from('bookings')
          .select('agent_id, traveller_id')
          .eq('id', widget.bookingId)
          .maybeSingle();

      if (bookingRow != null) {
        final agentId = bookingRow['agent_id'] as String?;
        final travellerId = bookingRow['traveller_id'] as String?;
        final recipientId = (currentUserId == travellerId) ? agentId : travellerId;

        if (recipientId != null) {
          final recipientProfile = await SupabaseService.client
              .from('profiles')
              .select('preferred_language')
              .eq('id', recipientId)
              .maybeSingle();
          if (recipientProfile != null && recipientProfile['preferred_language'] != null) {
            _recipientLangCode = recipientProfile['preferred_language'] as String;
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading participant languages: $e');
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final res = await SupabaseService.client
          .from('messages')
          .select('*')
          .eq('booking_id', widget.bookingId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(res ?? []);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error fetching chat messages: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _subscription = SupabaseService.client
        .channel('chat_room_${widget.bookingId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'booking_id',
            value: widget.bookingId,
          ),
          callback: (payload) {
            final newMsg = payload.newRecord;
            if (newMsg.isNotEmpty && mounted) {
              final newId = newMsg['id']?.toString();
              if (!_messages.any((m) => m['id']?.toString() == newId)) {
                setState(() {
                  _messages.add(newMsg);
                });
                _scrollToBottom();
              }
            }
          },
        )
        .onBroadcast(
          event: 'new_message',
          callback: (payload) {
            if (payload.isNotEmpty && mounted) {
              final currentUserId = SupabaseService.client.auth.currentUser?.id;
              if (payload['sender_id'] != currentUserId) {
                final newId = payload['id']?.toString();
                if (!_messages.any((m) => m['id']?.toString() == newId)) {
                  setState(() {
                    _messages.add(Map<String, dynamic>.from(payload));
                  });
                  _scrollToBottom();
                }
              }
            }
          },
        )
        .subscribe();
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? textToSend]) async {
    final text = (textToSend ?? _msgCtrl.text).trim();
    if (text.isEmpty) return;

    final userId = await SupabaseService.resolveActiveUserId();

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send messages.')),
      );
      return;
    }
    _msgCtrl.clear();

    // Generate multi-language translations map
    final translations = await TranslationService.instance.generateTranslationsMap(text);

    final newMsg = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'booking_id': widget.bookingId,
      'sender_id': userId,
      'content': text,
      'original_language': _myLangCode,
      'translated_text': translations,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (mounted) {
      setState(() {
        _messages.add(newMsg);
      });
      _scrollToBottom();
    }

    try {
      await SupabaseService.client.from('messages').insert({
        'booking_id': widget.bookingId,
        'sender_id': userId,
        'content': text,
        'original_language': _myLangCode,
        'translated_text': translations,
        'is_read': false,
      });

      // Broadcast over live chat channel
      try {
        final ch = SupabaseService.client.channel('chat_room_${widget.bookingId}');
        ch.subscribe(); // subscribe() returns RealtimeChannel, not Future — no await
        await ch.sendBroadcastMessage(event: 'new_message', payload: newMsg);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error inserting translated message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message could not be saved: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  // Voice Recording Functions
  void _startVoiceRecording() {
    setState(() {
      _isRecording = true;
      _recordDurationSec = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _recordDurationSec++);
      }
    });
  }

  void _cancelVoiceRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordDurationSec = 0;
    });
  }

  Future<void> _sendVoiceMessage() async {
    _recordTimer?.cancel();
    final duration = _recordDurationSec > 0 ? _recordDurationSec : 4;
    final userId = SupabaseService.client.auth.currentUser?.id ?? 'traveller';

    setState(() {
      _isRecording = false;
      _recordDurationSec = 0;
    });

    final voiceMsg = {
      'id': 'voice_${DateTime.now().millisecondsSinceEpoch}',
      'booking_id': widget.bookingId,
      'sender_id': userId,
      'content': '🎙️ Voice note (${duration}s)',
      'audio_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      'audio_duration_seconds': duration,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (mounted) {
      setState(() {
        _messages.add(voiceMsg);
      });
      _scrollToBottom();
    }

    try {
      await SupabaseService.client.from('messages').insert({
        'booking_id': widget.bookingId,
        'sender_id': userId,
        'content': '🎙️ Voice note (${duration}s)',
        'audio_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        'audio_duration_seconds': duration,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error inserting voice message: $e');
    }
  }

  void _toggleAudioPlayback(String msgId) {
    setState(() {
      if (_playingAudioIds.contains(msgId)) {
        _playingAudioIds.remove(msgId);
      } else {
        _playingAudioIds.add(msgId);
      }
    });
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _recordTimer?.cancel();
    _subscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.client.auth.currentUser?.id;
    final initials = (widget.recipientName.isNotEmpty ? widget.recipientName[0] : 'A').toUpperCase();

    final myLangName = TranslationService.languageNames[_myLangCode] ?? 'English';
    final recipientLangName = TranslationService.languageNames[_recipientLangCode] ?? 'Malayalam';

    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kInk, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: kAccent,
              backgroundImage: (widget.recipientPhotoUrl != null && widget.recipientPhotoUrl!.startsWith('http'))
                  ? NetworkImage(widget.recipientPhotoUrl!)
                  : null,
              child: (widget.recipientPhotoUrl == null || !widget.recipientPhotoUrl!.startsWith('http'))
                  ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700, color: kInk),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Participant Language Header Indicator
                  Row(
                    children: [
                      const Icon(Icons.g_translate_rounded, size: 12, color: kAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'You: $myLangName · ${widget.recipientName.split(' ')[0]}: $recipientLangName',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: kAccent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: kInk, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling ${widget.recipientName}...'), backgroundColor: kInk),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: kAccent))
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: kInkSoft),
                              const SizedBox(height: 12),
                              Text(
                                'Start conversation with ${widget.recipientName}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: kInk),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Auto-translation is active in $myLangName.',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) {
                            final m = _messages[i];
                            final msgId = m['id']?.toString() ?? '$i';
                            final isMe = m['sender_id'] == currentUserId || m['sender_id'] == 'traveller';
                            final originalContent = m['content'] as String? ?? '';
                            final audioUrl = m['audio_url'] as String?;
                            final audioDuration = (m['audio_duration_seconds'] as num?)?.toInt() ?? 5;
                            final timeStr = _formatTime(m['created_at']?.toString());
                            final showOriginal = _showOriginalMsgIds.contains(msgId);

                            // Check translation
                            final Map<String, dynamic> translations = (m['translated_text'] as Map<String, dynamic>?) ?? {};
                            final translatedContent = translations[_myLangCode] as String?;
                            final isTranslated = !isMe && translatedContent != null && translatedContent != originalContent;
                            final displayText = (isTranslated && !showOriginal) ? translatedContent : originalContent;

                            final isPlaying = _playingAudioIds.contains(msgId);

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.82,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe ? kAccent : appPaperColor(context),
                                  border: Border.all(color: isMe ? kAccent : appLineColor(context)),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 2),
                                    bottomRight: Radius.circular(isMe ? 2 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    // 🎙️ Voice Message Bubble
                                    if (audioUrl != null && audioUrl.isNotEmpty) ...[
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _toggleAudioPlayback(msgId),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isMe ? Colors.white.withOpacity(0.25) : kAccent.withOpacity(0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                color: isMe ? Colors.white : kAccent,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: List.generate(12, (idx) {
                                                  final h = (idx % 3 == 0) ? 14.0 : (idx % 2 == 0 ? 8.0 : 18.0);
                                                  return Container(
                                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                                    width: 3,
                                                    height: h,
                                                    decoration: BoxDecoration(
                                                      color: isMe
                                                          ? (isPlaying ? Colors.white : Colors.white60)
                                                          : (isPlaying ? kAccent : kInkSoft),
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                  );
                                                }),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '0:0${isPlaying ? '3' : audioDuration}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isMe ? Colors.white70 : kInkSoft,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '🎙️ Voice note · Text auto-translation does not apply',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9.5,
                                          fontStyle: FontStyle.italic,
                                          color: isMe ? Colors.white70 : kInkSoft,
                                        ),
                                      ),
                                    ] else ...[
                                      // 💬 Text Message with Auto-Translation
                                      Text(
                                        displayText,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: isMe ? kWhite : kInk,
                                          height: 1.4,
                                        ),
                                      ),

                                      // "See original" / "Show translation" Toggle Link
                                      if (isTranslated) ...[
                                        const SizedBox(height: 4),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (showOriginal) {
                                                _showOriginalMsgIds.remove(msgId);
                                              } else {
                                                _showOriginalMsgIds.add(msgId);
                                              }
                                            });
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.g_translate_rounded, size: 12, color: isMe ? Colors.white70 : kAccent),
                                              const SizedBox(width: 4),
                                              Text(
                                                showOriginal ? 'Show translation' : 'Auto-translated (See original)',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: isMe ? Colors.white70 : kAccent,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],

                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          timeStr,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            color: isMe ? kWhite.withOpacity(0.75) : kInkSoft,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            m['is_read'] == true ? Icons.done_all_rounded : Icons.done_rounded,
                                            size: 13,
                                            color: kWhite.withOpacity(0.85),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Quick Replies Strip
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickReplies.length,
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onTap: () => _sendMessage(_quickReplies[i]),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: appPaperColor(context),
                        border: Border.all(color: appLineColor(context)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          _quickReplies[i],
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: appInkColor(context)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Recording or Input Box Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: appBgColor(context),
                border: Border(top: BorderSide(color: appLineColor(context), width: 1)),
              ),
              child: Row(
                children: [
                  if (_isRecording) ...[
                    // Audio Recording Bar
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: _cancelVoiceRecording,
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recording voice note... 0:0${_recordDurationSec}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red.shade900),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendVoiceMessage,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: kAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ] else ...[
                    // Standard Text & Voice Button Bar
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: appPaperColor(context),
                          border: Border.all(color: appLineColor(context)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _msgCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Type message...',
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  isDense: true,
                                ),
                                style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: kInk),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            // Microphone button
                            IconButton(
                              icon: const Icon(Icons.mic_rounded, color: kAccent, size: 22),
                              onPressed: _startVoiceRecording,
                              tooltip: 'Record Voice Note',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _sendMessage(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: kAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
