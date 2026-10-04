import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'agent_signup_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? targetUserId;

      final res = await SupabaseService.instance.signIn(email: email, password: password);
      targetUserId = res?.user?.id;

      if (targetUserId != null) {
        await _routeFromSession(targetUserId);
        return;
      }

      if (mounted) _showError('Invalid login credentials. Please check your email or password.');
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) _showError('Unable to sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _routeFromSession(String userId) async {
    // Fetch agent_details verification_status
    Map<String, dynamic>? agentDetails;
    try {
      agentDetails = await SupabaseService.instance.getAgentDetails(userId);
    } catch (_) {}

    if (!mounted) return;

    final bool isSuspended = agentDetails?['suspended'] == true;
    if (isSuspended) {
      _showError('Your account has been suspended by administration. Please contact support.');
      return;
    }

    final docUrl = agentDetails?['verification_doc_url'] ?? agentDetails?['id_proof_url'] ?? agentDetails?['selfie_url'];
    final bool hasSubmittedDocs = docUrl != null && docUrl.toString().trim().isNotEmpty;

    if (agentDetails == null || !hasSubmittedDocs) {
      // User signed in but has not submitted agent application / documents yet
      Navigator.pushReplacementNamed(context, '/signup');
      return;
    }

    final status = agentDetails['verification_status'] ?? 'pending';

    if (status == 'approved') {
      Navigator.pushReplacementNamed(context, '/agent_shell');
    } else {
      Navigator.pushReplacementNamed(context, '/verification_pending');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.kAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.kWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF7300), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x408B5CF6),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: -0.6,
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Travel',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFF7300),
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Vibe',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF8B5CF6),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome Back',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.kInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Log in to your TravelVibe Local Agent account',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.kInkSoft,
                ),
              ),
              const SizedBox(height: 36),

              // Email Field
              Text(
                'Email Address',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.kInk,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'e.g. priya.sharma@traveltop.com',
                ),
              ),
              const SizedBox(height: 20),

              // Password Field
              Text(
                'Password',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.kInk,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: AppTheme.kWhite, strokeWidth: 2),
                        )
                      : const Text('Log In'),
                ),
              ),
              const SizedBox(height: 24),

              // Signup Prompt
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an agent account? ",
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.kInkSoft, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AgentSignupScreen()),
                      );
                    },
                    child: Text(
                      'Apply Now',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.kAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
