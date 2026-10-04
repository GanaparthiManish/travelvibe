import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/data_service.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _supportCtrl = TextEditingController();
  String _supportCategory = 'Booking Issue';
  bool _submittingTicket = false;
  List<Map<String, dynamic>> _myTickets = [];
  bool _loadingTickets = false;

  final List<String> _supportCategories = const [
    'Booking Issue',
    'Agent Problem',
    'Payment Query',
    'App Bug',
    'Safety Concern',
    'Refund Request',
    'Other',
  ];

  final List<Map<String, String>> _faqs = const [
    {
      'q': 'How do I book a verified guide on TravelTop?',
      'a': 'Search your destination on Home or Discover, pick a guide based on rating & price, select trip dates on their availability calendar, and complete checkout.'
    },
    {
      'q': 'Are all guides on TravelTop background-verified?',
      'a': 'Yes. Every guide undergoes document & ID verification by our admin team before their profile becomes active.'
    },
    {
      'q': 'What is the cancellation policy?',
      'a': 'Trips can be cancelled anytime before the start date directly from the Trip Details screen.'
    },
    {
      'q': 'How do I track my shopping order?',
      'a': 'Go to Shop → My Orders. Each order shows real-time status: Placed → Packed → Shipped → Delivered.'
    },
    {
      'q': 'How long does delivery take?',
      'a': 'Standard delivery is 4-7 business days. Express delivery (select items) is 2 days.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadMyTickets();
  }

  @override
  void dispose() {
    _supportCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyTickets() async {
    setState(() => _loadingTickets = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = SupabaseService.client.auth.currentUser?.id;
      final List<Map<String, dynamic>> tickets = [];

      final keys = [
        'user_tickets_all',
        if (userId != null) 'user_tickets_$userId',
        'user_tickets_guest',
      ];

      for (final key in keys) {
        final raw = prefs.getStringList(key) ?? [];
        for (final str in raw) {
          try {
            final parsed = Map<String, dynamic>.from(jsonDecode(str));
            if (!tickets.any((t) => t['id'] == parsed['id'])) {
              tickets.add(parsed);
            }
          } catch (_) {}
        }
      }

      if (userId != null) {
        try {
          final data = await SupabaseService.client
              .from('support_tickets')
              .select('*')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(10);
          final remote = List<Map<String, dynamic>>.from(data ?? []);
          for (final rt in remote) {
            if (!tickets.any((t) => t['id'] == rt['id'])) {
              tickets.add(rt);
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _myTickets = tickets;
          _loadingTickets = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  Future<void> _submitSupportTicket() async {
    final msg = _supportCtrl.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your issue first.')),
      );
      return;
    }
    final userId = await SupabaseService.resolveActiveUserId();

    final ticketId = 'ST-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    setState(() => _submittingTicket = true);

    final ticketData = {
      'id': ticketId,
      'user_id': userId,
      'subject': '[$_supportCategory] ${msg.substring(0, msg.length.clamp(0, 80))}',
      'category': _supportCategory,
      'type': _supportCategory,
      'message': msg,
      'description': msg,
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
    };

    // Save to local SharedPreferences so it shows immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        'user_tickets_all',
        if (userId != null) 'user_tickets_$userId',
        'user_tickets_guest',
      ];
      for (final key in keys) {
        final existing = prefs.getStringList(key) ?? [];
        existing.insert(0, jsonEncode(ticketData));
        await prefs.setStringList(key, existing);
      }
    } catch (_) {}

    // Upload to Supabase support_tickets table matching exact schema
    try {
      if (userId == null) {
        throw 'Please log in to submit a support ticket.';
      }

      await SupabaseService.client.from('support_tickets').insert({
        'user_id': userId,
        'type': _supportCategory,
        'description': msg,
        'status': 'open',
      });

      if (mounted) {
        _supportCtrl.clear();
        setState(() => _submittingTicket = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Support ticket submitted! Admin will review within 2-4 hours.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        _loadMyTickets();
      }
    } catch (e) {
      debugPrint('[SUPPORT] Error submitting ticket: $e');
      if (mounted) {
        setState(() => _submittingTicket = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket submission notice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _reportSafetyIssue() async {
    final issueCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Safety Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please describe the emergency or safety concern. Our support team responds immediately.'),
            const SizedBox(height: 12),
            TextField(
              controller: issueCtrl,
              maxLines: 3,
              decoration: ttFieldDeco('Describe issue...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit', style: TextStyle(color: Color(0xFFC0392B)))),
        ],
      ),
    );

    if (confirm == true && issueCtrl.text.trim().isNotEmpty) {
      final userId = await SupabaseService.resolveActiveUserId();

      final msg = issueCtrl.text.trim();
      try {
        if (userId == null) {
          throw 'Please log in to report safety concerns.';
        }
        await SupabaseService.client.from('support_tickets').insert({
          'user_id': userId,
          'type': 'Safety Issue',
          'description': msg,
          'status': 'urgent',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚨 Safety issue reported. Support team alerted immediately!'),
              backgroundColor: Color(0xFFC0392B),
            ),
          );
          _loadMyTickets();
        }
      } catch (e) {
        debugPrint('[SUPPORT] Safety report error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Safety report notice: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    issueCtrl.dispose();
  }

  Color _ticketStatusColor(String status) {
    switch (status) {
      case 'open': return const Color(0xFF3B82F6);
      case 'urgent': return const Color(0xFFC0392B);
      case 'resolved': return const Color(0xFF22C55E);
      case 'closed': return kInkSoft;
      default: return kInkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor(context),
      appBar: AppBar(
        backgroundColor: appBgColor(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: appPaperColor(context)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: kInk),
          ),
        ),
        title: Text(
          'Help & Support',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w800, color: kInk,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Emergency Safety Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8E8),
              border: Border.all(color: const Color(0xFFF8B4B4)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFFC0392B), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Safety Issue',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFC0392B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Immediate 24/7 emergency response during trips.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kInkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC0392B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _reportSafetyIssue,
                  child: const Text('Report', style: TextStyle(color: kWhite)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Submit Support Ticket Form
          ttSectionH('Submit a Ticket'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kWhite,
              border: Border.all(color: appLineColor(context)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How can we help you?', style: kLcTitle),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _supportCategory,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appLineColor(context))),
                    labelText: 'Category',
                  ),
                  items: _supportCategories
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: kLcMeta)))
                      .toList(),
                  onChanged: (v) => setState(() => _supportCategory = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _supportCtrl,
                  maxLines: 4,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Describe your issue or query...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInkSoft),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appLineColor(context))),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submittingTicket ? null : _submitSupportTicket,
                    icon: _submittingTicket
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    label: Text(
                      _submittingTicket ? 'Submitting...' : 'Submit Ticket',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // My Support Tickets Section
          if (_myTickets.isNotEmpty || _loadingTickets) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Support Tickets', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: kInk)),
                GestureDetector(
                  onTap: _loadMyTickets,
                  child: const Icon(Icons.refresh_rounded, size: 18, color: kAccent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingTickets)
              const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent)))
            else
              ..._myTickets.map((ticket) {
                final status = ticket['status'] as String? ?? 'open';
                final category = ticket['category'] as String? ?? '';
                final subject = ticket['subject'] as String? ?? '';
                final adminReply = ticket['admin_reply'] as String?;
                final created = ticket['created_at'] as String? ?? '';
                final dateStr = created.length >= 10 ? created.substring(0, 10) : created;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: appPaperColor(context),
                    border: Border.all(color: appLineColor(context)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(subject,
                                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _ticketStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9, fontWeight: FontWeight.w800,
                                color: _ticketStatusColor(status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('$category • $dateStr',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kInkSoft)),
                      if (adminReply != null && adminReply.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFF22C55E)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Support Reply: $adminReply',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kInk, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],

          const SizedBox(height: 24),

          // FAQs
          ttSectionH('Frequently Asked Questions'),
          Container(
            decoration: BoxDecoration(
              color: appPaperColor(context),
              border: Border.all(color: appLineColor(context)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: _faqs.asMap().entries.map((entry) {
                final i = entry.key;
                final faq = entry.value;
                return Column(
                  children: [
                    if (i > 0) Divider(height: 1, color: appLineColor(context)),
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      iconColor: kAccent,
                      collapsedIconColor: kInkSoft,
                      title: Text(
                        faq['q']!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Text(
                            faq['a']!,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: kInkSoft, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
