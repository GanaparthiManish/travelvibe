import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  State<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  StreamSubscription<Map<String, dynamic>?>? _subscription;
  Timer? _pollTimer;
  Map<String, dynamic>? _agentData;
  bool _isLoading = true;
  String _debugInfo = 'Initializing...';
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _subscribeAgentStatus();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        _pollTimer?.cancel();
        _subscription?.cancel();
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }
    _pollCount++;
    try {
      final data = await SupabaseService.instance.getAgentDetails(user.id);
      if (!mounted) return;

      final docUrl = data?['verification_doc_url'] ?? data?['id_proof_url'] ?? data?['selfie_url'];
      final bool hasSubmittedDocs = docUrl != null && docUrl.toString().trim().isNotEmpty;

      if (data == null || !hasSubmittedDocs) {
        _pollTimer?.cancel();
        _subscription?.cancel();
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final status = data['verification_status'] ?? 'pending';
      setState(() {
        _agentData = data;
        _isLoading = false;
        _debugInfo = 'Poll #$_pollCount | UID: ${user.id.substring(0, 8)}... | status: $status';
      });

      if (status == 'approved') {
        _pollTimer?.cancel();
        _subscription?.cancel();
        Navigator.pushReplacementNamed(context, '/agent_shell');
      }
    } catch (e) {
      if (mounted) setState(() => _debugInfo = 'Poll #$_pollCount | ERROR: $e');
    }
  }

  void _subscribeAgentStatus() {
    final user = SupabaseService.instance.currentUser;
    if (user == null || user.isAnonymous) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pollTimer?.cancel();
        _subscription?.cancel();
        Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }

    _subscription = SupabaseService.instance.streamAgentDetails(user.id).listen((data) {
      if (!mounted) return;

      if (data != null) {
        final docUrl = data['verification_doc_url'] ?? data['id_proof_url'] ?? data['selfie_url'];
        final bool hasSubmittedDocs = docUrl != null && docUrl.toString().trim().isNotEmpty;

        if (!hasSubmittedDocs) {
          _pollTimer?.cancel();
          _subscription?.cancel();
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }

        setState(() {
          _agentData = data;
          _isLoading = false;
        });

        final status = data['verification_status'] ?? 'pending';
        if (status == 'approved') {
          _pollTimer?.cancel();
          _subscription?.cancel();
          Navigator.pushReplacementNamed(context, '/agent_shell');
        }
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _agentData?['verification_status'] ?? 'pending';
    final isRejected = status == 'rejected';
    final rejectionReason = _agentData?['rejection_reason'] ?? 'Submitted document was unreadable or incomplete.';

    return Scaffold(
      backgroundColor: AppTheme.kPaper,
      appBar: AppBar(
        title: const Text('Agent Verification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SupabaseService.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.kAccent))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isRejected ? AppTheme.kAccentLight : AppTheme.kPaper,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRejected ? AppTheme.kAccent : AppTheme.kLine,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isRejected ? Icons.gavel_rounded : Icons.access_time_filled_rounded,
                        color: isRejected ? AppTheme.kAccent : AppTheme.kInk,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isRejected ? 'Verification Needed' : 'Verification Under Review',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.kInk,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isRejected
                          ? 'Your agent application requires update before approval.\n\nReason: "$rejectionReason"'
                          : 'Our TravelVibe compliance team is currently reviewing your ID and tour guide credentials. This usually takes 2-6 hours.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppTheme.kInkSoft,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (isRejected) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/agent_profile_edit');
                          },
                          child: const Text('Edit & Resubmit Application'),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.kWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.kLine, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.kAccent),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Auto-navigates on admin approval',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.kInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // DEBUG PANEL — remove before production
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _debugInfo,
                        style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
