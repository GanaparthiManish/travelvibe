import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: const Text('Help & Safety Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Safety emergency card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.kAccentLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.kAccent, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppTheme.kAccent, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Report a Safety Issue',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.kInk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '24/7 Agent SOS Emergency Line: +91 1800-TRAVEL-SAFE\nContact support immediately if you encounter weather hazards or traveller emergencies.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.kInkSoft, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Frequently Asked Questions', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.kInk)),
            const SizedBox(height: 12),
            _buildFaqTile('How do I receive tour payouts?', 'Payouts are transferred directly to your registered bank account or UPI ID within 24 hours of marking a tour as Completed.'),
            _buildFaqTile('How do I update my daily tour pricing?', 'Navigate to Agent Settings → Edit Profile to update your per-day rate and inclusions.'),
            _buildFaqTile('What happens if a traveller cancels?', 'If a traveller cancels within 24 hours of start date, full day compensation is paid automatically.'),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqTile(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.kLine, width: 1.5),
      ),
      child: ExpansionTile(
        title: Text(q, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.kInk)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(a, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.kInkSoft, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
