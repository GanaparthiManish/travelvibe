import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final user = SupabaseService.instance.currentUser;
    if (user == null || user.isAnonymous) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Fetch agent_details row to check verification status
    final details = await SupabaseService.instance.getAgentDetails(user.id);
    if (!mounted) return;

    final docUrl = details?['verification_doc_url'] ?? details?['id_proof_url'] ?? details?['selfie_url'];
    final bool hasSubmittedDocs = docUrl != null && docUrl.toString().trim().isNotEmpty;

    if (details != null && hasSubmittedDocs) {
      final status = details['verification_status'] ?? 'pending';
      if (status == 'approved') {
        Navigator.pushReplacementNamed(context, '/agent_shell');
      } else {
        Navigator.pushReplacementNamed(context, '/verification_pending');
      }
    } else {
      // Unapplied user or missing documents -> Go to login/signup
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kWhite,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.kAccent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
              ),
              child: const Icon(
                Icons.compass_calibration_rounded,
                color: AppTheme.kWhite,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Travel',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFF7300),
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: 'Vibe',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF8B5CF6),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Agent Console',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.kAccent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.kAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
