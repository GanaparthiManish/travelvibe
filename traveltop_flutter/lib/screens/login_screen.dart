import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';
import '../services/wishlist_service.dart';
import '../services/notification_service.dart';
import '../app_shell.dart';
import '../utils/user_utils.dart';

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

        // Broadcast live login event to admin panel via HTTP (no race condition)
        unawaited(_httpBroadcastUserEvent('user_logged_in', {
          'id': user.id,
          'email': email,
          'full_name': name,
          'photo_url': photo,
          'role': 'traveller',
          'suspended': false,
          'created_at': DateTime.now().toIso8601String(),
        }));

        try {
          await WishlistService.instance.reloadForUser();
          await NotificationService.instance.reloadForUser();
        } catch (_) {}


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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = 'Please enter both email and password.');
      return;
    }

    if (pass.length < 6) {
      setState(() => _errorMsg = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final name = email.split('@')[0];
      String effectiveId = '';

      try {
        final authRes = await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: pass,
        );
        if (authRes.user != null) {
          effectiveId = authRes.user!.id;
        }
      } catch (authE) {
        debugPrint('Email auth notice: $authE');
      }

      await _broadcastLiveUserLogin(
        id: effectiveId,
        email: email,
        name: name,
        photoUrl: '',
        phone: '',
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
      debugPrint('Login exception: $e');
      if (!mounted) return;
      if (e.toString().contains('SUSPENDED_ACCOUNT')) {
        setState(() => _errorMsg = 'Your account has been suspended by administration. Please contact support.');
      } else {
        setState(() => _errorMsg = 'Login failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Sends a Supabase Realtime broadcast via HTTP REST (no WebSocket race condition).
  /// The admin's subscribed channel receives it the moment the HTTP call completes.
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

  Future<void> _broadcastLiveUserLogin({
    required String id,
    required String email,
    required String name,
    required String photoUrl,
    required String phone,
  }) async {
    try {
      // 1. Check if user already exists in profiles table by email
      Map<String, dynamic>? existing;
      if (email.isNotEmpty) {
        existing = await SupabaseService.client
            .from('profiles')
            .select('id, role, phone, full_name, suspended, email')
            .eq('email', email)
            .maybeSingle();
      }

      // If not found by email, also check by full_name to link previous sessions created without email
      if (existing == null && name.isNotEmpty && name != 'User') {
        existing = await SupabaseService.client
            .from('profiles')
            .select('id, role, phone, full_name, suspended, email')
            .eq('full_name', name)
            .maybeSingle();
      }

      if (existing != null && existing['suspended'] == true) {
        throw Exception('SUSPENDED_ACCOUNT');
      }

      String effectiveId = id;

      if (existing != null && existing['id'] != null) {
        // User already has an established record in Supabase — reuse their ID so bookings, wishlists & orders stay linked!
        effectiveId = existing['id'] as String;
        final updates = <String, dynamic>{
          if (email.isNotEmpty) 'email': email,
          if (name.isNotEmpty && name != 'User') 'full_name': name,
          if (phone.isNotEmpty) 'phone': phone,
          if (photoUrl.isNotEmpty) 'photo_url': photoUrl,
        };
        if (updates.isNotEmpty) {
          try {
            await SupabaseService.client.from('profiles').update(updates).eq('id', effectiveId);
          } catch (_) {}
        }
      } else {
        // First-time new user: resolve valid auth ID
        if (effectiveId.isEmpty && SupabaseService.client.auth.currentUser != null) {
          effectiveId = SupabaseService.client.auth.currentUser!.id;
        }

        if (effectiveId.isEmpty) {
          try {
            final authRes = await SupabaseService.client.auth.signInAnonymously();
            if (authRes.user != null) {
              effectiveId = authRes.user!.id;
            }
          } catch (aErr) {
            debugPrint('Anonymous auth session notice: $aErr');
          }
        }

        if (effectiveId.isEmpty && SupabaseService.client.auth.currentUser != null) {
          effectiveId = SupabaseService.client.auth.currentUser!.id;
        }

        final payload = {
          'id': effectiveId,
          'email': email,
          'full_name': name,
          if (phone.isNotEmpty) 'phone': phone,
          if (photoUrl.isNotEmpty) 'photo_url': photoUrl,
          'role': 'traveller',
          'suspended': false,
          'created_at': DateTime.now().toIso8601String(),
        };

        try {
          await SupabaseService.client.from('profiles').upsert(payload, onConflict: 'id');
        } catch (pErr) {
          debugPrint('Profile upsert notice: $pErr');
        }
      }

      // Save locally so the session and profile persist across restarts and logouts
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', effectiveId);
      if (email.isNotEmpty) await prefs.setString('user_email', email);
      if (name.isNotEmpty) await prefs.setString('user_name', name);
      if (photoUrl.isNotEmpty) await prefs.setString('user_photo', photoUrl);
      await prefs.setBool('is_logged_in', true);

      // 2. Broadcast live login event to Admin Console via HTTP (fire-and-forget, no race)
      unawaited(_httpBroadcastUserEvent('user_logged_in', {
        'id': effectiveId,
        'email': email,
        'full_name': name,
        'photo_url': photoUrl,
        'role': existing?['role'] ?? 'traveller',
        'suspended': false,
        'created_at': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('Error in _broadcastLiveUserLogin: $e');
      if (e.toString().contains('SUSPENDED_ACCOUNT')) {
        rethrow;
      }
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

        String effectiveId = '';
        try {
          final googleAuth = await googleUser.authentication;
          if (googleAuth.idToken != null) {
            final authRes = await SupabaseService.client.auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: googleAuth.idToken!,
              accessToken: googleAuth.accessToken,
            );
            if (authRes.user != null) {
              effectiveId = authRes.user!.id;
            }
          }
        } catch (tokenErr) {
          debugPrint('Google signInWithIdToken notice: $tokenErr');
        }

        await _broadcastLiveUserLogin(
          id: effectiveId,
          email: email,
          name: name,
          photoUrl: photo,
          phone: '',
        );

        try {
          await WishlistService.instance.reloadForUser();
          await NotificationService.instance.reloadForUser();
        } catch (_) {}

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
        return;
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = 'Sign in failed: ${e.toString()}';
      });
    }
  }





  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: kWhite,
      body: Stack(
        children: [
          // ── 1. App-Matching Hero Backdrop ───────────────────────────────────
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
                  errorBuilder: (_, __, ___) => Container(color: kInk),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.30),
                        Colors.black.withOpacity(0.65),
                        kWhite,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Top Badge & Brand Header
                Positioned(
                  top: 54,
                  left: 24,
                  right: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const TravelVibeBrandLogo(iconSize: 26, fontSize: 18),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: kAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'VERIFIED VIBES',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Floating App-Design Form Sheet ─────────────────────────────
          Positioned.fill(
            top: screenHeight * 0.28,
            child: Container(
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to access your curated trips, local guides & wishlist.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: kInkSoft,
                        ),
                      ),
                      const SizedBox(height: 26),

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

                      // Email Field Header & Input
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

                      // Password Field Header & Input
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PASSWORD',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: kInkSoft,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Forgot?',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kAccent,
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
                      const SizedBox(height: 28),

                      // Primary Sign In Button (Coral Accent)
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
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                      const SizedBox(height: 26),

                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider(color: kLine, height: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'OR SIGN IN WITH',
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

                      // Google Sign In Button
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

                      const SizedBox(height: 30),

                      // Footer Link to Sign Up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: kInkSoft,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SignupScreen()),
                              );
                            },
                            child: Text(
                              'Create Account',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: kAccent,
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
