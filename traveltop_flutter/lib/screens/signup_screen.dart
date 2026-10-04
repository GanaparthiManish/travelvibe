import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/data_service.dart';
import '../app_shell.dart';
import '../utils/user_utils.dart';
import 'legal_page_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _agreedToTerms = false;
  bool _loading = false;
  String? _errorMsg;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _listenAuthChanges();
  }

  void _listenAuthChanges() {
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      final user = session?.user;
      if (user != null && mounted) {
        final email = user.email ?? '';
        // CRITICAL: Ignore anonymous auth sessions with empty email so real profiles are never wiped!
        if (email.isEmpty) return;

        final name = resolveDisplayName(user: user, email: email);
        final photo = (user.userMetadata?['avatar_url'] as String?) ??
            (user.userMetadata?['picture'] as String?) ??
            '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', user.id);
        await prefs.setString('user_email', email);
        await prefs.setString('user_name', name);
        if (photo.isNotEmpty) await prefs.setString('user_photo', photo);
        await prefs.setBool('is_logged_in', true);

        try {
          await SupabaseService.client.from('profiles').upsert({
            'id': user.id,
            'email': email,
            'full_name': name,
            'photo_url': photo,
            'role': 'traveller',
            'suspended': false,
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'id');
        } catch (e) {
          debugPrint('Auth change profile upsert notice: $e');
        }

        // Broadcast new user to admin panel via HTTP (no race condition)
        unawaited(_httpBroadcastUserEvent('user_logged_in', {
          'id': user.id,
          'email': email,
          'full_name': name,
          'photo_url': photo,
          'role': 'traveller',
          'suspended': false,
          'created_at': DateTime.now().toIso8601String(),
        }));

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
        );
      }
    });
  }


  @override
  void dispose() {
    _authSub?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = 'Please fill out all fields.');
      return;
    }

    if (pass.length < 6) {
      setState(() => _errorMsg = 'Password must be at least 6 characters.');
      return;
    }

    if (!_agreedToTerms) {
      setState(() => _errorMsg = 'Please agree to the Terms & Conditions and Privacy Policy.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      // 1. Check if profile already exists for this email
      final existing = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, email, role, suspended')
          .eq('email', email)
          .maybeSingle();

      if (existing != null && existing['suspended'] == true) {
        throw Exception('Your account has been suspended by administration. Please contact support.');
      }

      String effectiveId = '';

      if (existing != null && existing['id'] != null) {
        effectiveId = existing['id'] as String;
      } else {
        // Create genuine auth session to satisfy foreign key constraints
        try {
          final authRes = await SupabaseService.client.auth.signUp(
            email: email,
            password: pass,
            data: {'full_name': name, 'role': 'traveller'},
          );
          if (authRes.user != null) {
            effectiveId = authRes.user!.id;
          }
        } catch (aErr) {
          debugPrint('Auth signUp notice: $aErr');
        }

        if (effectiveId.isEmpty) {
          try {
            final anonRes = await SupabaseService.client.auth.signInAnonymously();
            if (anonRes.user != null) {
              effectiveId = anonRes.user!.id;
            }
          } catch (aErr) {
            debugPrint('Anon auth notice: $aErr');
          }
        }

        if (effectiveId.isEmpty && SupabaseService.client.auth.currentUser != null) {
          effectiveId = SupabaseService.client.auth.currentUser!.id;
        }

        // Upsert profile in Supabase
        await SupabaseService.client.from('profiles').upsert({
          'id': effectiveId,
          'email': email,
          'full_name': name,
          'role': 'traveller',
          'suspended': false,
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', effectiveId);
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setBool('is_logged_in', true);

      // Realtime broadcast to admin via HTTP (fire-and-forget, no race)
      unawaited(_httpBroadcastUserEvent('user_logged_in', {
        'id': effectiveId,
        'email': email,
        'full_name': name,
        'photo_url': '',
        'role': 'traveller',
        'suspended': false,
        'created_at': DateTime.now().toIso8601String(),
      }));

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Signup error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('AuthApiException: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      GoogleSignInAccount? googleUser;
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );
        try { await googleSignIn.signOut(); } catch (_) {}
        googleUser = await googleSignIn.signIn();
      } catch (e1) {
        debugPrint('GoogleSignIn native attempt notice: $e1');
      }

      if (googleUser != null) {
        final email = googleUser.email;
        final name = resolveDisplayName(prefName: googleUser.displayName, email: email);
        final photo = googleUser.photoUrl ?? '';

        // Check if existing
        final existing = await SupabaseService.client
            .from('profiles')
            .select('id, full_name, email, role, suspended')
            .eq('email', email)
            .maybeSingle();

        if (existing != null && existing['suspended'] == true) {
          throw Exception('Your account has been suspended by administration. Please contact support.');
        }

        String effectiveId = '';
        if (existing != null && existing['id'] != null) {
          effectiveId = existing['id'] as String;
        } else {
          try {
            final authRes = await SupabaseService.client.auth.signInAnonymously();
            if (authRes.user != null) effectiveId = authRes.user!.id;
          } catch (_) {}

          if (effectiveId.isEmpty && SupabaseService.client.auth.currentUser != null) {
            effectiveId = SupabaseService.client.auth.currentUser!.id;
          }

          await SupabaseService.client.from('profiles').upsert({
            'id': effectiveId,
            'email': email,
            'full_name': name,
            'photo_url': photo,
            'role': 'traveller',
            'suspended': false,
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'id');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', effectiveId);
        await prefs.setString('user_name', name);
        await prefs.setString('user_email', email);
        if (photo.isNotEmpty) await prefs.setString('user_photo', photo);
        await prefs.setBool('is_logged_in', true);

        // Broadcast to Admin Console via HTTP (fire-and-forget, no race)
        unawaited(_httpBroadcastUserEvent('user_logged_in', {
          'id': effectiveId,
          'email': email,
          'full_name': name,
          'photo_url': photo,
          'role': 'traveller',
          'suspended': false,
          'created_at': DateTime.now().toIso8601String(),
        }));

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
        );
        return;
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }




  /// Sends a Supabase Realtime broadcast via HTTP REST (no WebSocket race condition).
  Future<void> _httpBroadcastUserEvent(String event, Map<String, dynamic> payload) async {
    const supabaseUrl = 'https://imretkikrsdydreldosx.supabase.co';
    const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/realtime/v1/api/broadcast'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
        },
        body: jsonEncode({
          'messages': [
            {
              'topic': 'realtime:user_live_stream_channel',
              'event': event,
              'payload': payload,
            }
          ],
        }),
      );
      debugPrint('HTTP broadcast result: ${response.statusCode}');
    } catch (e) {
      debugPrint('HTTP broadcast error (non-critical): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kInk, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const TravelVibeBrandLogo(iconSize: 26, fontSize: 19),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Join TravelVibe',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: kInk,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create your account & unlock exclusive travel vibes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: kInkSoft,
              ),
            ),
            const SizedBox(height: 28),

            if (_errorMsg != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF2F2),
                  border: Border.all(color: kAccent.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: kAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            Text(
              'FULL NAME',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: kInkSoft,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kInk,
              ),
              decoration: InputDecoration(
                hintText: 'Alex Morgan',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: kInkSoft.withOpacity(0.6),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.person_outline_rounded, color: kAccent, size: 20),
                fillColor: kPaper,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kLine, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kLine, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kAccent, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'EMAIL ADDRESS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: kInkSoft,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kInk,
              ),
              decoration: InputDecoration(
                hintText: 'alex.morgan@travelvibe.com',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: kInkSoft.withOpacity(0.6),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.mail_outline_rounded, color: kAccent, size: 20),
                fillColor: kPaper,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kLine, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kLine, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kAccent, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'CREATE PASSWORD',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: kInkSoft,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kInk,
              ),
              decoration: InputDecoration(
                hintText: '••••••••',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: kInkSoft.withOpacity(0.6),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: kAccent, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: kInkSoft,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
                fillColor: kPaper,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kLine, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kLine, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kAccent, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),

            // ── Terms & Conditions Checkbox ─────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreedToTerms,
                    activeColor: kAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'I agree to the ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: kInkSoft,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LegalPageScreen(pageType: 'terms_conditions'),
                          ),
                        ),
                        child: Text(
                          'Terms & Conditions',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        ' and ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: kInkSoft,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LegalPageScreen(pageType: 'privacy_policy'),
                          ),
                        ),
                        child: Text(
                          'Privacy Policy',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _loading
                ? const Center(child: CircularProgressIndicator(color: kAccent))
                : SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: Container(
                      decoration: BoxDecoration(
                        color: kAccent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: kAccent.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

            const SizedBox(height: 26),

            Row(
              children: [
                const Expanded(child: Divider(color: kLine, height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OR SIGN UP WITH',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: kInkSoft,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: kLine, height: 1)),
              ],
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: _handleGoogleSignIn,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: kWhite,
                  border: Border.all(color: kLine, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFEA4335),
                      ),
                      child: const Center(
                        child: Text(
                          'G',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
