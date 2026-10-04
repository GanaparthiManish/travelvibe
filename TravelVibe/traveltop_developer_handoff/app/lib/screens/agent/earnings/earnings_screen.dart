import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  StreamSubscription<List<Map<String, dynamic>>>? _payoutsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _bookingsSub;

  List<Map<String, dynamic>> _payouts = [];
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  String _payoutMethod = 'UPI ID: agent@okaxis';

  @override
  void initState() {
    super.initState();
    _subscribeData();
  }

  void _subscribeData() async {
    final agentId = SupabaseService.instance.activeAgentId ?? SupabaseService.instance.currentUser?.id;
    if (agentId == null) {
      if (!mounted) return;
      setState(() {
        _bookings = [];
        _payouts = [];
        _isLoading = false;
      });
      return;
    }

    // Fetch agent profile phone to construct UPI fallback
    try {
      final details = await SupabaseService.instance.getAgentDetails(agentId);
      final phone = details?['profiles']?['phone'] as String? ?? '';
      if (phone.isNotEmpty) {
        _payoutMethod = 'UPI ID: $phone@okaxis';
      }
    } catch (_) {}

    _payoutsSub = SupabaseService.instance.streamAgentPayouts(agentId).listen((pList) {
      if (!mounted) return;
      setState(() {
        _payouts = pList;
      });
    });

    _bookingsSub = SupabaseService.instance.streamAgentBookings(agentId).listen((bList) {
      if (!mounted) return;
      setState(() {
        _bookings = bList;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _payoutsSub?.cancel();
    _bookingsSub?.cancel();
    super.dispose();
  }

  void _showWithdrawSheet(double availableBalance) {
    final amountController = TextEditingController(text: availableBalance.toInt().toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Withdraw Earnings', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
            const SizedBox(height: 6),
            Text('Withdraw wallet balance directly to your bank account or UPI.', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.kInkSoft)),
            const SizedBox(height: 20),
            Text('Withdrawal Amount (₹)', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Enter amount in ₹'),
            ),
            const SizedBox(height: 16),
            Text('Payout Destination', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(_payoutMethod, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.kAccent)),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountController.text.trim()) ?? 0;
                  if (amt <= 0 || amt > availableBalance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid withdrawal amount.'), backgroundColor: AppTheme.kAccent),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  await SupabaseService.instance.requestPayout(amt, method: _payoutMethod);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Withdrawal request submitted! Status set to Processing.'), backgroundColor: AppTheme.kGreen),
                    );
                  }
                },
                child: const Text('Confirm Withdrawal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManagePayoutMethodDialog() {
    final methodController = TextEditingController(text: _payoutMethod);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Payout Method'),
        content: TextField(
          controller: methodController,
          decoration: const InputDecoration(
            hintText: 'Enter UPI ID or Bank Account Details',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _payoutMethod = methodController.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total & month earnings
    double totalAllTime = 0.0;
    double thisMonth = 0.0;
    final now = DateTime.now();

    for (var b in _bookings) {
      if (b['status'] == 'completed') {
        final amt = ((b['total_price'] ?? 0) as num).toDouble();
        totalAllTime += amt;

        final dateStr = b['created_at'] ?? b['start_date'];
        if (dateStr != null) {
          final d = DateTime.tryParse(dateStr.toString());
          if (d != null && d.month == now.month && d.year == now.year) {
            thisMonth += amt;
          }
        }
      }
    }

    double totalWithdrawn = 0.0;
    for (var p in _payouts) {
      totalWithdrawn += ((p['amount'] ?? 0) as num).toDouble();
    }

    final double availableBalance = (totalAllTime - totalWithdrawn).clamp(0.0, 9999999.0);

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: Text('Earnings & Wallet', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wallet Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.kInk,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Available Balance', style: GoogleFonts.plusJakartaSans(color: AppTheme.kInkMuted, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${availableBalance.toInt()}',
                          style: GoogleFonts.plusJakartaSans(color: AppTheme.kWhite, fontSize: 32, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: availableBalance > 0 ? () => _showWithdrawSheet(availableBalance) : null,
                                child: const Text('Withdraw Funds'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _showManagePayoutMethodDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.kWhite,
                                side: const BorderSide(color: AppTheme.kLine),
                              ),
                              child: const Text('Method'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Summary Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryBox('All-Time Earnings', '₹${totalAllTime.toInt()}', AppTheme.kGreen),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildSummaryBox('This Month', '₹${thisMonth.toInt()}', AppTheme.kAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Payout History Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payout History',
                        style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                      ),
                      Text(
                        'Live Subscribed',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.kGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _payouts.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.kWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.kLine, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              'No payout requests yet',
                              style: GoogleFonts.plusJakartaSans(color: AppTheme.kInkSoft, fontSize: 14),
                            ),
                          ),
                        )
                      : Column(
                          children: _payouts.map((p) {
                            final status = (p['status'] ?? 'processing').toString();
                            final amount = ((p['amount'] ?? 0) as num).toInt();
                            final dateStr = (p['created_at'] ?? '').toString().split('T')[0];

                            Color badgeColor = AppTheme.kAccent;
                            if (status == 'paid') badgeColor = AppTheme.kGreen;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.kWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.kLine, width: 1.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₹$amount',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Date: $dateStr · ${p['payout_method'] ?? 'UPI'}',
                                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: badgeColor),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.kLine, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
