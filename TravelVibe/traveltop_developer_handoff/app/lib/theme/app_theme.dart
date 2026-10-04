import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pro / Airbnb-Inspired Color Tokens
  static const Color kInk = Color(0xFF222222);
  static const Color kInkSoft = Color(0xFF666666);
  static const Color kInkMuted = Color(0xFF888888);
  static const Color kAccent = Color(0xFFE8483A);
  static const Color kAccentHover = Color(0xFFD63B2D);
  static const Color kAccentLight = Color(0xFFFEECEB);
  static const Color kLine = Color(0xFFEBEBEB);
  static const Color kPaper = Color(0xFFFAFAFA);
  static const Color kWhite = Color(0xFFFFFFFF);
  static const Color kGreen = Color(0xFF1E8E5A);
  static const Color kGreenLight = Color(0xFFE7F7EF);

  // Backward compatibility mappings
  static const Color primaryBlue = kInk;
  static const Color accentGreen = kGreen;
  static const Color background = kWhite;
  static const Color surface = kWhite;
  static const Color textDark = kInk;
  static const Color textMuted = kInkSoft;
  static const Color borderLight = kLine;

  static const Color oceanTeal = kInk;
  static const Color coralGold = kAccent;
  static const Color coral = kAccent;
  static const Color sunshineYellow = Color(0xFFFFB800);
  static const Color teal = kGreen;
  static const Color skyBlue = kInk;
  static const Color grape = kInk;
  static const Color warmPaper = kPaper;
  static const Color inkNavy = kInk;
  static const Color softLilac = kPaper;
  static const Color mintGreen = kGreenLight;
  static const Color charcoalText = kInk;
  static const Color greyText = kInkSoft;
  static const Color softGreen = kGreen;
  static const Color mutedRed = kAccent;
  static const Color sandBg = kPaper;

  static const LinearGradient oceanGradient = LinearGradient(
    colors: [kInk, kInk],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient coralGradient = oceanGradient;
  static const LinearGradient skyGradient = oceanGradient;

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      offset: const Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> glowShadow = softShadow;
  static List<BoxShadow> tealGlowShadow = softShadow;
  static List<BoxShadow> stickerShadow = softShadow;
  static List<BoxShadow> stickerShadowSmall = softShadow;

  static Border thickBorder = Border.all(
    color: kLine,
    width: 1.5,
  );

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();
    return ThemeData(
      useMaterial3: true,
      primaryColor: kAccent,
      scaffoldBackgroundColor: kWhite,
      colorScheme: const ColorScheme.light(
        primary: kAccent,
        onPrimary: kWhite,
        secondary: kInk,
        onSecondary: kWhite,
        surface: kWhite,
        onSurface: kInk,
        error: kAccent,
        onError: kWhite,
        outline: kLine,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: kInk,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          color: kInk,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          color: kInk,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: kInk,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: kInkSoft,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: kInk),
        titleTextStyle: TextStyle(
          color: kInk,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccent,
          foregroundColor: kWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kInk,
          side: const BorderSide(color: kLine, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kPaper,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kLine, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kLine, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kInk, width: 2),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(color: kInkMuted, fontSize: 13, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: kWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: kLine, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {

    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);
    const darkBg = Color(0xFF121212);
    const darkPaper = Color(0xFF1E1E1E);
    const darkInk = Color(0xFFF3F4F6);
    const darkInkSoft = Color(0xFF9CA3AF);
    const darkLine = Color(0xFF2D2D2D);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: kAccent,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: kAccent,
        onPrimary: kWhite,
        secondary: darkInk,
        onSecondary: darkBg,
        surface: darkPaper,
        onSurface: darkInk,
        error: kAccent,
        onError: kWhite,
        outline: darkLine,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: darkInk,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          color: darkInk,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          color: darkInk,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: darkInk,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: darkInkSoft,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkInk),
        titleTextStyle: TextStyle(
          color: darkInk,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkPaper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkLine, width: 1.5),
        ),
      ),
    );
  }
}

