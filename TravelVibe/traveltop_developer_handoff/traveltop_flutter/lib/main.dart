import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_shell.dart';
import 'screens/splash_screen.dart';
import 'services/data_service.dart';
import 'services/location_ping_service.dart';
import 'services/wishlist_service.dart';
import 'theme.dart';

/// Dark mode removed — always light. Kept as stub so existing imports don't break.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.init();
  DataService.instance.start();
  LocationPingService.instance.start();
  WishlistService.instance.init();

  runApp(const TravelTopApp());
}

class TravelTopApp extends StatelessWidget {
  const TravelTopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelVibe',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        scaffoldBackgroundColor: kWhite,
        colorScheme: ColorScheme.fromSeed(seedColor: kAccent, brightness: Brightness.light),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: child!,
        );
      },
      home: const SplashScreen(),
      routes: {
        '/shell': (_) => const AppShell(),
      },
    );
  }
}
