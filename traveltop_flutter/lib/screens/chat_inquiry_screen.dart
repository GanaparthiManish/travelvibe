import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';
import 'payment_screen.dart';

class ChatInquiryScreen extends StatefulWidget {
  final String agentId;
  final String agentName;
  final String agentPhoto;
  final String destination;
  final String proposedDates;
  final double calculatedTotal;

  const ChatInquiryScreen({
    super.key,
    required this.agentId,
    required this.agentName,
    required this.agentPhoto,
    required this.destination,
    required this.proposedDates,
    required this.calculatedTotal,
  });

  @override
  State<ChatInquiryScreen> createState() => _ChatInquiryScreenState();
}

class _ChatInquiryScreenState extends State<ChatInquiryScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String? _inquiryId;
  double? _agreedPrice;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _initInquiry();
  }

  Future<void> _initInquiry() async {
    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    try {
      final existing = await client
          .from('inquiries')
          .select('id, agreed_price')
          .eq('traveller_id', userId)
          .eq('agent_id', widget.agentId)
          .eq('status', 'open')
          .maybeSingle();

      if (existing != null) {
        _inquiryId = existing['id'] as String?;
        if (existing['agreed_price'] != null) {
          _agreedPrice = (existing['agreed_price'] as num).toDouble();
        }
      } else {
        final newInqId = 'inq_${DateTime.now().millisecondsSinceEpoch}';
        try {
          await client.from('inquiries').insert({
            'id': newInqId,
            'traveller_id': userId,
            'agent_id': widget.agentId,
            'destination': widget.destination,
            'proposed_dates': widget.proposedDates,
            'status': 'open',
          });
        } catch (_) {}
        _inquiryId = newInqId;
      }

      await _fetchMessages();
      _subscribeRealtime();
    } catch (e) {
      debugPrint('Inquiry init notice: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchMessages() async {
    if (_inquiryId == null) return;
    try {
      final res = await SupabaseService.client
          .from('messages')
          .select('*')
          .eq('inquiry_id', _inquiryId!)
          .order('created_at', ascending: true);

      if (res != null && mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(res);
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _subscribeRealtime() {
    if (_inquiryId == null) return;
    _channel = SupabaseService.client
        .channel('public:messages:inquiry_$_inquiryId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'inquiry_id',
            value: _inquiryId,
          ),
          callback: (_) => _fetchMessages(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _inquiryId == null) return;
    _msgCtrl.clear();

    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return;
    final senderId = user.id;

    try {
      await SupabaseService.client.from('messages').insert({
        'inquiry_id': _inquiryId,
        'sender_id': senderId,
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _fetchMessages();
    } catch (e) {
      debugPrint('Error sending inquiry message: $e');
    }
  }

  void _showSetAgreedPriceDialog() {
    final priceCtrl = TextEditingController(text: _agreedPrice != null ? _agreedPrice!.toInt().toString() : widget.calculatedTotal.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.handshake_rounded, color: kAccent),
            SizedBox(width: 8),
            Text('Confirm Agreed Price'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calculated Total: ₹${widget.calculatedTotal.toInt()}\n\nEnter the final discounted price agreed in chat with ${widget.agentName}:',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: kInk),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Agreed Price (₹)',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kAccent),
            onPressed: () async {
              final val = double.tryParse(priceCtrl.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                setState(() => _agreedPrice = val);

                if (_inquiryId != null) {
                  try {
                    await SupabaseService.client.from('inquiries').update({'agreed_price': val}).eq('id', _inquiryId!);
                  } catch (_) {}
                }

                try {
                  final user = SupabaseService.client.auth.currentUser;
                  await SupabaseService.client.from('messages').insert({
                    'inquiry_id': _inquiryId,
                    'sender_id': user?.id ?? 'system',
                    'content': '🤝 Agreed Price Confirmed: ₹${val.toInt()} (Discounted from ₹${widget.calculatedTotal.toInt()})',
                    'created_at': DateTime.now().toIso8601String(),
                  });
                  await _fetchMessages();
                } catch (_) {}
              }
            },
            child: const Text('Confirm Price ✓', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseService.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: appPaperColor(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pre-Booking Chat', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: kInk)),
            Text('${widget.agentName} • ${widget.destination}', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kInkSoft)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kInk),
        actions: [
          IconButton(
            icon: const Icon(Icons.handshake_outlined, color: kAccent),
            tooltip: 'Confirm Agreed Price',
            onPressed: _showSetAgreedPriceDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // PRE-BOOKING OFFER BANNER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.amber.shade100.withOpacity(0.5),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Discuss your trip plan & agree on a discount with ${widget.agentName} before booking!',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),

          // AGREED PRICE CARD (IF SET)
          if (_agreedPrice != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF22C55E)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Agreed Price: ₹${_agreedPrice!.toInt()}', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF15803D))),
                        Text('Original: ₹${widget.calculatedTotal.toInt()}', style: GoogleFonts.plusJakartaSans(fontSize: 11, decoration: TextDecoration.lineThrough, color: const Color(0xFF166534))),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentScreen(
                            agentId: widget.agentId,
                            agentName: widget.agentName,
                            agentPhoto: widget.agentPhoto,
                            startDate: DateTime.now().add(const Duration(days: 1)),
                            endDate: DateTime.now().add(const Duration(days: 3)),
                            totalAmount: _agreedPrice!.toInt(),
                            basePrice: widget.calculatedTotal,
                            selectedAddons: const [],
                            negotiatedPrice: _agreedPrice,
                          ),
                        ),
                      );
                    },
                    child: Text('Book Now ✓', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ),
            ),

          // CHAT MESSAGES LIST
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kAccent))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Ask ${widget.agentName} anything about your trip!',
                          style: GoogleFonts.plusJakartaSans(color: kInkSoft, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, idx) {
                          final msg = _messages[idx];
                          final isMe = msg['sender_id'] == currentUserId;
                          final text = msg['content'] ?? '';

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isMe ? kAccent : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isMe ? 14 : 2),
                                  bottomRight: Radius.circular(isMe ? 2 : 14),
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Text(
                                text,
                                style: GoogleFonts.plusJakartaSans(
                                  color: isMe ? Colors.white : kInk,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // BOTTOM MESSAGE INPUT BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: appPaperColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: kAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
