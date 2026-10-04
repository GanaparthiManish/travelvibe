import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  RealtimeChannel? _channel;
  String _privacyContent =
      'TravelVibe collects agent registration details (full name, phone number, email address), government identification documents for background verification, location services for tour guidance, and bank/UPI payout details.';
  String _termsContent =
      'Your submitted identification and tourism licenses are stored securely in encrypted cloud storage accessible strictly by TravelVibe compliance officers for verification purposes.';
  String _lastUpdated = 'August 2026';

  @override
  void initState() {
    super.initState();
    _fetchRealtimePolicies();
  }

  void _fetchRealtimePolicies() {
    try {
      final client = Supabase.instance.client;
      _channel = client.channel('policy_updates_channel');
      _channel?.onBroadcast(
        event: 'policy_updated',
        callback: (payload) {
          if (mounted && payload != null) {
            setState(() {
              if (payload['key'] == 'privacy' && payload['content'] != null) {
                _privacyContent = payload['content'];
              } else if (payload['key'] == 'terms' && payload['content'] != null) {
                _termsContent = payload['content'];
              }
              _lastUpdated = 'Live Updated Just Now';
            });
          }
        },
      ).subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: const Text('Privacy Policy & Terms'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.kWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.kLine, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TravelVibe Terms & Privacy',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.kGreenLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '● Live Sync',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.kGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Last updated: $_lastUpdated',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.kInkSoft),
              ),
              const SizedBox(height: 20),
              _buildTitle('1. Privacy & Data Collection'),
              _buildText(_privacyContent),
              const SizedBox(height: 16),
              _buildTitle('2. Verification & Safety Terms'),
              _buildText(_termsContent),
              const SizedBox(height: 16),
              _buildTitle('3. Tour Bookings & Payouts'),
              _buildText(
                  'Tour earnings are credited directly to your agent wallet upon tour completion and processed via Razorpay/UPI payout channels.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String text) {
    return Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.kInk));
  }

  Widget _buildText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.kInkSoft, height: 1.5)),
    );
  }
}
