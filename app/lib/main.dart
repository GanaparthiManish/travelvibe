import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/app_state_provider.dart';
import 'services/supabase_service.dart';
import 'services/location_ping_service.dart';

// Auth Screens
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/agent_signup_screen.dart';
import 'screens/auth/verification_pending_screen.dart';

// Agent Console & Tabs
import 'screens/agent/agent_shell_screen.dart';
import 'screens/agent/home/agent_console_screen.dart';
import 'screens/agent/profile/agent_profile_edit_screen.dart';
import 'screens/agent/availability/agent_availability_screen.dart';
import 'screens/agent/earnings/earnings_screen.dart';
import 'screens/agent/reviews/agent_reviews_screen.dart';
import 'screens/agent/settings/agent_settings_screen.dart';
import 'screens/agent/notifications/agent_notifications_screen.dart';
import 'screens/settings/privacy_policy_screen.dart';
import 'screens/traveller/support/help_support_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.instance.initialize();
  LocationPingService.instance.start();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: const TravelVibeAgentApp(),
    ),
  );
}

class TravelVibeAgentApp extends StatelessWidget {
  const TravelVibeAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    return MaterialApp(
      title: 'TravelVibe Agent',
      debugShowCheckedModeBanner: false,
      themeMode: appState.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const AgentSignupScreen(),
        '/verification_pending': (context) => const VerificationPendingScreen(),
        '/agent_shell': (context) => const AgentShellScreen(),
        '/agent_dashboard': (context) => const AgentConsoleScreen(),
        '/agent_profile_edit': (context) => const AgentProfileEditScreen(),
        '/agent_availability': (context) => const AgentAvailabilityScreen(),
        '/agent_earnings': (context) => const EarningsScreen(),
        '/agent_reviews': (context) => const AgentReviewsScreen(),
        '/agent_settings': (context) => const AgentSettingsScreen(),
        '/notifications': (context) => const AgentNotificationsScreen(),
        '/privacy_policy': (context) => const PrivacyPolicyScreen(),
        '/help_support': (context) => const HelpSupportScreen(),
      },
    );
  }
}
