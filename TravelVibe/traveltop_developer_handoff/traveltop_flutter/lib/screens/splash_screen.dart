import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/data_service.dart';
import 'login_screen.dart';
import '../app_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<_SplashSlide> _slides = const [
    _SplashSlide(
      imageUrl:
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1200&q=80',
      badge: 'VERIFIED LOCAL GUIDES',
      title: 'Explore the world\nwith local experts',
      subtitle:
          'Connect directly with certified local guides for unique, authentic travel experiences.',
    ),
    _SplashSlide(
      imageUrl:
          'https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=1200&q=80',
      badge: 'UNFORGETTABLE DESTINATIONS',
      title: 'Discover hidden gems\n& scenic trails',
      subtitle:
          'From mist-covered tea hills to high mountain passes, explore curated places.',
    ),
    _SplashSlide(
      imageUrl:
          'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1200&q=80',
      badge: 'SEAMLESS BOOKING',
      title: 'Real-time trips\n& custom itineraries',
      subtitle:
          'Book verified guides, track gear orders, and message guides live.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkSessionAndInit();
  }

  Future<void> _checkSessionAndInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final session = SupabaseService.client.auth.currentSession;

      if (isLoggedIn || session != null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
        return;
      }
    } catch (e) {
      debugPrint('[SplashScreen] session check error: $e');
    }

    // Only start auto-slide onboarding if user is NOT logged in
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (_currentPage < _slides.length - 1) {
        _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      } else {
        _timer?.cancel();
      }
    });
  }

  void _finishSplash() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final session = SupabaseService.client.auth.currentSession;

    Widget target = (isLoggedIn || session != null) ? const AppShell() : const LoginScreen();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => target,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kInk,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 3-Slide PageView with Nature Imagery
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, i) {
              final slide = _slides[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  // High-res Nature Background Image
                  Image.network(
                    slide.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: kInk),
                  ),

                  // Multi-stage Gradient Scrim Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x66000000),
                          Color(0x33000000),
                          Color(0xEE111111),
                        ],
                        stops: [0.0, 0.35, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Slide Typography Content
                  SafeArea(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pill Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: Colors.white30, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: kAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  slide.badge,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Slide Title
                          Text(
                            slide.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.15,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Slide Subtitle
                          Text(
                            slide.subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.85),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 90), // Space for bottom bar
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Top Skip Button
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: _finishSplash,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'Skip',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Bar: 3 Segment Progress Line + CTA Button
          Positioned(
            bottom: 30,
            left: 28,
            right: 28,
            child: Row(
              children: [
                // 3 Segment Indicators
                Expanded(
                  child: Row(
                    children: List.generate(_slides.length, (idx) {
                      final isActive = _currentPage == idx;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        width: isActive ? 32 : 12,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: isActive ? kAccent : Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),

                // Action Button (Next or Get Started)
                GestureDetector(
                  onTap: () {
                    if (_currentPage < _slides.length - 1) {
                      _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _finishSplash();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: kAccent,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == _slides.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 16),
                      ],
                    ),
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

class _SplashSlide {
  final String imageUrl;
  final String badge;
  final String title;
  final String subtitle;

  const _SplashSlide({
    required this.imageUrl,
    required this.badge,
    required this.title,
    required this.subtitle,
  });
}
