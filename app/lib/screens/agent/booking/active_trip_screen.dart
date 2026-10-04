import '../../../widgets/glass_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/app_network_image.dart';

class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final TextEditingController _itineraryController = TextEditingController(
      text:
          'Day 1: Pickup at 8:00 AM from hotel -> Tegenungan Waterfall -> Local Warung Lunch.\nDay 2: Temple Tour at Tirta Empul -> Rice Terrace Walk.\nDay 3: Sunset beach tour & drop off.');

  bool _isCompleted = false;

  void _openChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AgentChatSheet(),
    );
  }

  void _completeTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Trip as Completed?'),
        content: const Text('This will finalize the tour booking and credit ₹6,750 net payout to your account balance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.softGreen),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isCompleted = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip marked as completed! Payout credited to balance.'),
                  backgroundColor: AppTheme.softGreen,
                ),
              );
            },
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTripStatusHeader(),
                        const SizedBox(height: 20),
                        _buildContactCard(),
                        const SizedBox(height: 20),
                        _buildItineraryCard(),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),
                _buildStickyCompleteButton(context),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
                  child: Icon(LucideIcons.arrowLeft, color: AppTheme.textDark, size: 20),
                ),
              ),
            ),
          ),
              const SizedBox(width: 16),
              Text(
                'Active Tour Management',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.85),
            child: IconButton(
              icon: const Icon(LucideIcons.messageSquare, color: AppTheme.oceanTeal),
              onPressed: _openChatSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStatusHeader() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isCompleted
                      ? AppTheme.softGreen.withValues(alpha: 0.2)
                      : AppTheme.coralGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isCompleted ? LucideIcons.checkCircle2 : LucideIcons.playCircle,
                      color: _isCompleted ? AppTheme.softGreen : AppTheme.coralGold,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isCompleted ? 'COMPLETED' : 'ONGOING TOUR',
                      style: TextStyle(
                        color: _isCompleted ? AppTheme.softGreen : AppTheme.coralGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Text('Oct 15 - Oct 17', style: TextStyle(color: AppTheme.greyText, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Ubud Waterfall & Temple Explorer', style: TextStyle(color: AppTheme.charcoalText, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: const AppNetworkImage(
              imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alex Traveler', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.charcoalText, fontSize: 16)),
                SizedBox(height: 2),
                Text('+62 812-3456-7890', style: TextStyle(color: AppTheme.greyText, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.phone, color: AppTheme.softGreen),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling traveler...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.messageCircle, color: AppTheme.oceanTeal),
            onPressed: _openChatSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Guide Tour Plan & Notes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.charcoalText)),
              Icon(LucideIcons.edit3, size: 16, color: AppTheme.oceanTeal.withValues(alpha: 0.8)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _itineraryController,
            maxLines: 5,
            style: const TextStyle(color: AppTheme.charcoalText, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.sandBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyCompleteButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.textDark,
        boxShadow: AppTheme.softShadow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: GradientButton(
        text: _isCompleted ? 'TRIP COMPLETED' : 'MARK TOUR AS COMPLETED',
        style: _isCompleted ? GradientButtonStyle.secondaryTeal : GradientButtonStyle.primaryCoral,
        onPressed: _isCompleted ? () {} : _completeTrip,
      ),
    );
  }
}

class _AgentChatSheet extends StatefulWidget {
  const _AgentChatSheet();

  @override
  State<_AgentChatSheet> createState() => _AgentChatSheetState();
}

class _AgentChatSheetState extends State<_AgentChatSheet> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'sender': 'traveler', 'text': 'Hi Wayan! We arrived at the hotel.'},
    {'sender': 'me', 'text': 'Awesome! I will pick you up at 8:00 AM tomorrow near the lobby.'},
  ];

  void _sendMessage() {
    if (_msgController.text.trim().isNotEmpty) {
      setState(() {
        _messages.add({'sender': 'me', 'text': _msgController.text.trim()});
        _msgController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.textDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 12),
          const Text('Chat with Alex Traveler', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender'] == 'me';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.oceanTeal : AppTheme.sandBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(color: isMe ? Colors.white : AppTheme.charcoalText, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: AppTheme.sandBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          ),
        ],
      ),
    );
  }
}
