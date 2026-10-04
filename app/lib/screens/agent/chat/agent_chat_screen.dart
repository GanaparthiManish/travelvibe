import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../services/translation_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/agent_avatar.dart';

class AgentChatScreen extends StatefulWidget {
  final String bookingId;
  final String travellerName;
  final String travellerPhoto;

  const AgentChatScreen({
    super.key,
    required this.bookingId,
    required this.travellerName,
    required this.travellerPhoto,
  });

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSub;
  List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  // Language & Translation State
  String _myLangCode = 'en';
  String _recipientLangCode = 'hi';
  final Set<String> _showOriginalMsgIds = {};

  // Voice Recording State
  bool _isRecording = false;
  int _recordDurationSec = 0;
  Timer? _recordTimer;
  final Set<String> _playingAudioIds = {};

  // Quick reply suggestions
  final List<String> _quickReplies = [
    '👋 Hello! How can I help?',
    '✅ Booking confirmed!',
    'ℹ️ Please share your details',
    '📍 Meeting point is...',
    '🕐 Tour starts at 9:00 AM',
    '💰 Payment received. Thanks!',
  ];

  @override
  void initState() {
    super.initState();
    _loadParticipantLanguages();
    _subscribeMessages();
    _messageController.addListener(_onTypingChanged);
  }

  Future<void> _loadParticipantLanguages() async {
    final currentUserId = SupabaseService.instance.currentUser?.id ??
        SupabaseService.instance.activeAgentId;
    if (currentUserId == null) return;

    try {
      final myProfile = await SupabaseService.instance.client
          ?.from('profiles')
          .select('preferred_language')
          .eq('id', currentUserId)
          .maybeSingle();

      if (myProfile != null && myProfile['preferred_language'] != null) {
        _myLangCode = myProfile['preferred_language'] as String;
      }

      final bookingRow = await SupabaseService.instance.client
          ?.from('bookings')
          .select('agent_id, traveller_id')
          .eq('id', widget.bookingId)
          .maybeSingle();

      if (bookingRow != null) {
        final travellerId = bookingRow['traveller_id'] as String?;
        if (travellerId != null) {
          final travellerProfile = await SupabaseService.instance.client
              ?.from('profiles')
              .select('preferred_language')
              .eq('id', travellerId)
              .maybeSingle();
          if (travellerProfile != null && travellerProfile['preferred_language'] != null) {
            _recipientLangCode = travellerProfile['preferred_language'] as String;
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading participant languages in agent chat: $e');
    }
  }

  void _onTypingChanged() {
    if (!_isTyping && _messageController.text.isNotEmpty) {
      setState(() => _isTyping = true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isTyping = false);
    });
  }

  void _subscribeMessages() {
    SupabaseService.instance.markMessagesAsRead(widget.bookingId);
    _messagesSub =
        SupabaseService.instance.streamMessages(widget.bookingId).listen(
      (msgList) {
        if (!mounted) return;
        setState(() => _messages = msgList);
        _scrollToBottom();
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend([String? override]) async {
    final text = (override ?? _messageController.text).trim();
    if (text.isEmpty) return;

    String? currentUserId = SupabaseService.instance.currentUser?.id ??
        SupabaseService.instance.activeAgentId;

    if (currentUserId == null || currentUserId.length < 20) {
      try {
        final bRow = await SupabaseService.instance.client
            ?.from('bookings')
            .select('agent_id')
            .eq('id', widget.bookingId)
            .maybeSingle();
        if (bRow != null && bRow['agent_id'] != null) {
          currentUserId = bRow['agent_id'] as String;
        }
      } catch (_) {}
    }

    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not verify sender session. Please log in.')),
        );
      }
      return;
    }

    _messageController.clear();

    final translations = await TranslationService.instance.generateTranslationsMap(text);

    final newMsgObj = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'booking_id': widget.bookingId,
      'sender_id': currentUserId,
      'content': text,
      'original_language': _myLangCode,
      'translated_text': translations,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
    };

    setState(() {
      _isSending = true;
      _messages.add(newMsgObj);
    });
    _scrollToBottom();

    try {
      await SupabaseService.instance.client?.from('messages').insert({
        'booking_id': widget.bookingId,
        'sender_id': currentUserId,
        'content': text,
        'original_language': _myLangCode,
        'translated_text': translations,
        'is_read': false,
      });

      // Broadcast over live chat room channel
      try {
        final ch = SupabaseService.instance.client?.channel('chat_room_${widget.bookingId}');
        ch?.subscribe();
        await ch?.sendBroadcastMessage(event: 'new_message', payload: newMsgObj);
      } catch (_) {}
    } catch (e) {
      debugPrint('Supabase sendMessage notice: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startVoiceRecording() {
    setState(() {
      _isRecording = true;
      _recordDurationSec = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _recordDurationSec++);
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
    final duration = _recordDurationSec > 0 ? _recordDurationSec : 5;
    final currentUserId = SupabaseService.instance.currentUser?.id ??
        SupabaseService.instance.activeAgentId ??
        'agent';

    setState(() {
      _isRecording = false;
      _recordDurationSec = 0;
    });

    final voiceMsg = {
      'id': 'voice_${DateTime.now().millisecondsSinceEpoch}',
      'booking_id': widget.bookingId,
      'sender_id': currentUserId,
      'content': '🎙️ Voice note (${duration}s)',
      'audio_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      'audio_duration_seconds': duration,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': false,
    };

    setState(() {
      _messages.add(voiceMsg);
    });
    _scrollToBottom();

    try {
      await SupabaseService.instance.client?.from('messages').insert({
        'booking_id': widget.bookingId,
        'sender_id': currentUserId,
        'content': '🎙️ Voice note (${duration}s)',
        'audio_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        'audio_duration_seconds': duration,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error inserting voice message in Agent app: $e');
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

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = ts is String ? DateTime.parse(ts).toLocal() : ts as DateTime;
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = ts is String ? DateTime.parse(ts).toLocal() : ts as DateTime;
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today';
      } else if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day - 1) {
        return 'Yesterday';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.instance.currentUser?.id ??
        SupabaseService.instance.activeAgentId;

    final myLangName = TranslationService.languageNames[_myLangCode] ?? 'English';
    final recipientLangName = TranslationService.languageNames[_recipientLangCode] ?? 'Hindi';

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        backgroundColor: AppTheme.kWhite,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.kInk, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            AgentAvatar(
              name: widget.travellerName,
              photoUrl: widget.travellerPhoto,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.travellerName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.kInk,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.g_translate_rounded, size: 12, color: AppTheme.kAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'You: $myLangName · Traveller: $recipientLangName',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.kAccent,
                          ),
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
            icon: const Icon(Icons.phone_rounded,
                color: AppTheme.kInk, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Calling ${widget.travellerName}...'),
                    backgroundColor: AppTheme.kInk),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final m = _messages[i];
                      final msgId = m['id']?.toString() ?? '$i';
                      final senderId = m['sender_id'] as String? ?? '';
                      final isMe = (senderId == currentUserId) || (senderId == 'agent');
                      final originalContent = m['content'] as String? ?? '';
                      final audioUrl = m['audio_url'] as String?;
                      final audioDuration = (m['audio_duration_seconds'] as num?)?.toInt() ?? 5;
                      final ts = m['created_at'];
                      final showOriginal = _showOriginalMsgIds.contains(msgId);

                      final Map<String, dynamic> translations = (m['translated_text'] as Map<String, dynamic>?) ?? {};
                      final translatedContent = translations[_myLangCode] as String?;
                      final isTranslated = !isMe && translatedContent != null && translatedContent != originalContent;
                      final displayText = (isTranslated && !showOriginal) ? translatedContent : originalContent;

                      final isPlaying = _playingAudioIds.contains(msgId);

                      bool showDate = false;
                      if (i == 0) {
                        showDate = true;
                      } else {
                        final prevTs = _messages[i - 1]['created_at'];
                        if (_formatDate(ts) != _formatDate(prevTs)) {
                          showDate = true;
                        }
                      }

                      return Column(
                        children: [
                          if (showDate) _buildDateHeader(_formatDate(ts)),
                          _buildMessageBubble(
                            msgId: msgId,
                            originalContent: originalContent,
                            displayText: displayText,
                            isTranslated: isTranslated,
                            showOriginal: showOriginal,
                            audioUrl: audioUrl,
                            audioDuration: audioDuration,
                            isPlaying: isPlaying,
                            isMe: isMe,
                            time: _formatTime(ts),
                            context: context,
                          ),
                        ],
                      );
                    },
                  ),
          ),

          if (_messages.isEmpty || _messageController.text.isEmpty)
            _buildQuickReplies(),

          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.kAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 36, color: AppTheme.kAccent),
            ),
            const SizedBox(height: 20),
            Text(
              'Start conversation with ${widget.travellerName}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.kInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Auto-translation & voice messaging active.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.kInkSoft,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    if (date.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            date,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.kInkSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String msgId,
    required String originalContent,
    required String displayText,
    required bool isTranslated,
    required bool showOriginal,
    required String? audioUrl,
    required int audioDuration,
    required bool isPlaying,
    required bool isMe,
    required String time,
    required BuildContext context,
  }) {
    final maxW = MediaQuery.of(context).size.width * 0.80;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            AgentAvatar(
              name: widget.travellerName,
              photoUrl: widget.travellerPhoto,
              radius: 14,
            ),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: maxW),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? AppTheme.kAccent : AppTheme.kWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (audioUrl != null && audioUrl.isNotEmpty) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _toggleAudioPlayback(msgId),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.white24 : AppTheme.kAccent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: isMe ? Colors.white : AppTheme.kAccent,
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
                                          : (isPlaying ? AppTheme.kAccent : AppTheme.kInkSoft),
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
                                  color: isMe ? Colors.white70 : AppTheme.kInkSoft,
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
                          color: isMe ? Colors.white70 : AppTheme.kInkSoft,
                        ),
                      ),
                    ] else ...[
                      Text(
                        displayText,
                        style: GoogleFonts.plusJakartaSans(
                          color: isMe ? AppTheme.kWhite : AppTheme.kInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
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
                              Icon(Icons.g_translate_rounded, size: 12, color: isMe ? Colors.white70 : AppTheme.kAccent),
                              const SizedBox(width: 4),
                              Text(
                                showOriginal ? 'Show translation' : 'Auto-translated (See original)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isMe ? Colors.white70 : AppTheme.kAccent,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (time.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: AppTheme.kInkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.done_all_rounded,
                            size: 13, color: Color(0xFF22C55E)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      height: 38,
      color: AppTheme.kWhite,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: _quickReplies.length,
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () => _handleSend(_quickReplies[i]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.kAccent.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(20),
                color: AppTheme.kAccent.withValues(alpha: 0.06),
              ),
              child: Text(
                _quickReplies[i],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.kAccent,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: AppTheme.kWhite,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_isRecording) ...[
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
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recording voice note... 0:0$_recordDurationSec',
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
                  decoration: const BoxDecoration(color: AppTheme.kAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ] else ...[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.kInk,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Message ${widget.travellerName}...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: AppTheme.kInkMuted,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _handleSend(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.mic_rounded, color: AppTheme.kAccent, size: 22),
                        onPressed: _startVoiceRecording,
                        tooltip: 'Record Voice Note',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isSending ? AppTheme.kInkMuted : AppTheme.kAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.kAccent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _isSending ? null : () => _handleSend(),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
