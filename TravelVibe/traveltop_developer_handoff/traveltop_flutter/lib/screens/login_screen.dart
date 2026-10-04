import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';
import '../services/wishlist_service.dart';
import '../services/notification_service.dart';
import '../app_shell.dart';

import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;
  String? _errorMsg;

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final name = email.split('@')[0];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setBool('is_logged_in', true);

      try {
        await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: pass,
        );
      } catch (_) {
        try {
          await SupabaseService.client.auth.signUp(
            email: email,
            password: pass,
            data: {'full_name': name},
          );
        } catch (_) {}
      }

      final user = SupabaseService.client.auth.currentUser;
      final userIdToUse = user?.id ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';

      await _broadcastLiveUserLogin(
        id: userIdToUse,
        email: email,
        name: name,
        photoUrl: '',
        phone: '+91 98765 43210',
      );

      try {
        await WishlistService.instance.reloadForUser();
        await NotificationService.instance.reloadForUser();
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }

  }

  Future<void> _broadcastLiveUserLogin({
    required String id,
    required String email,
    required String name,
    required String photoUrl,
    required String phone,
  }) async {
    try {
      // 1. Search profiles by email to find the authentic profile for THIS account
      final existing = await SupabaseService.client
          .from('profiles')
          .select('id, role, phone, full_name')
          .eq('email', email)
          .maybeSingle();

      String effectiveId = id;
      if (existing != null) {
        effectiveId = existing['id'] as String;
        final updates = <String, dynamic>{
          if (name.isNotEmpty && name != 'User') 'full_name': name,
          if (phone.isNotEmpty) 'phone': phone,
          if (photoUrl.isNotEmpty) 'photo_url': photoUrl,
        };
        await SupabaseService.client.from('profiles').update(updates).eq('id', effectiveId);
      } else {
        // Safety check: ensure id is not already used by another email
        final idCheck = await SupabaseService.client
            .from('profiles')
            .select('id, email')
            .eq('id', id)
            .maybeSingle();

        if (idCheck != null && idCheck['email'] != email) {
          debugPrint('Notice: auth ID $id belongs to ${idCheck['email']}, preserving profile.');
          return;
        }

        final payload = {
          'id': id,
          'email': email,
          'full_name': name,
          if (phone.isNotEmpty) 'phone': phone,
          if (photoUrl.isNotEmpty) 'photo_url': photoUrl,
          'role': 'traveller',
          'suspended': false,
          'created_at': DateTime.now().toIso8601String(),
        };
        await SupabaseService.client.from('profiles').insert(payload);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', effectiveId);
      await prefs.setString('user_email', email);
      await prefs.setString('user_name', name);
      if (photoUrl.isNotEmpty) await prefs.setString('user_photo', photoUrl);

      final ch = SupabaseService.client.channel('user_live_stream_channel');
      await ch.subscribe();
      await ch.sendBroadcastMessage(event: 'user_logged_in', payload: {
        'id': effectiveId,
        'email': email,
        'full_name': name,
        'photo_url': photoUrl,
        'role': existing?['role'] ?? 'traveller',
      });
    } catch (e) {
      debugPrint('Error broadcasting live user login: $e');
    }
  }



  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      // Pure Native Google Sign-In (In-App Bottom Sheet without launching Chrome)
      const webClientId = '633644129492-kbkalft70qsesenq03q3r3q46e4cbqlg.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );

      // Force account picker so user can test multiple emails in real-time
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _loading = false);
        return; // User cancelled
      }

      final realName = googleUser.displayName ?? 'Traveler User';
      final realEmail = googleUser.email;
      final realPhoto = googleUser.photoUrl ?? '';

      // 1. Instantly store to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', realName);
      await prefs.setString('user_email', realEmail);
      await prefs.setString('user_photo', realPhoto);
      await prefs.setBool('is_logged_in', true);

      // 2. Auth & Upsert with Supabase
      try {
        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        if (idToken != null) {
          final authRes = await SupabaseService.client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );

          final user = authRes.user ?? SupabaseService.client.auth.currentUser;
          if (user != null) {
            await _broadcastLiveUserLogin(
              id: user.id,
              email: realEmail,
              name: realName,
              photoUrl: realPhoto,
              phone: '+91 98765 43210',
            );
          }
        }
      } catch (authErr) {
        debugPrint('Supabase Auth Token notice: $authErr');
        try {
          final pRes = await SupabaseService.client
              .from('profiles')
              .select('id, role')
              .eq('email', realEmail)
              .maybeSingle();
          if (pRes != null) {
            await _broadcastLiveUserLogin(
              id: pRes['id'] as String,
              email: realEmail,
              name: realName,
              photoUrl: realPhoto,
              phone: '',
            );
          }
        } catch (_) {}
      }


      try {
        await WishlistService.instance.reloadForUser();
        await NotificationService.instance.reloadForUser();
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } catch (e) {
      debugPrint('Google Sign-In notice: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }

  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── 1. Pro High-Res Hero Header ────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.38,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1200&q=80',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF7300), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.black.withOpacity(0.75),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // TravelVibe Brand Header Logo
                Positioned(
                  top: 54,
                  left: 24,
                  right: 24,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const TravelVibeBrandLogo(iconSize: 28, fontSize: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Floating Modern Card ─────────────────────────────────────────
          Positioned.fill(
            top: screenHeight * 0.28,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Explore verified local guides & plan your next vibe',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (_errorMsg != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFDC2626), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Email Field
                      Text(
                        'EMAIL ADDRESS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
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
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'alex.morgan@travelvibe.com',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(Icons.mail_outline_rounded,
                              color: Color(0xFFFF7300), size: 20),
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFFF7300), width: 2.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password Field Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PASSWORD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Forgot?',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFF7300),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(Icons.lock_outline_rounded,
                              color: Color(0xFF8B5CF6), size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Sign In Primary Gradient CTA Button
                      _loading
                          ? const Center(
                              child: CircularProgressIndicator(color: Color(0xFFFF7300)))
                          : SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFF7300), Color(0xFF8B5CF6)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x40FF7300),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'Sign In to TravelVibe',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                      const SizedBox(height: 28),

                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OR SIGN IN WITH',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Native 1-Tap Google Sign In
                      GestureDetector(
                        onTap: _handleGoogleSignIn,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
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
                                      fontSize: 14,
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
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Footer Link to Sign Up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SignupScreen()),
                              );
                            },
                            child: Text(
                              'Create Account',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFF7300),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
