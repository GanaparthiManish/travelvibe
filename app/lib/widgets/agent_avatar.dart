import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

const _kStorageBase =
    'https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/';

/// A smart avatar widget that handles:
/// - Network URLs (http/https)
/// - Relative Supabase storage paths (auto-resolved to full URL)
/// - Base64 data: URLs (data:image/jpeg;base64,...)
/// - Empty/null/Error → shows initials inside an accent circle
class AgentAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const AgentAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 28,
  });

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _resolveUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('data:')) {
      return raw;
    }
    if (raw.isNotEmpty) {
      return '$_kStorageBase$raw';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = photoUrl ?? '';
    final url = _resolveUrl(rawUrl);
    final size = radius * 2;
    final fontSize = radius * 0.65;

    Widget fallback = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.kAccent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _initials,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.kWhite,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
          ),
        ),
      ),
    );

    if (url.startsWith('data:')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final base64Str = url.substring(commaIdx + 1);
          final bytes = base64Decode(base64Str);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _e, _s) => fallback,
            ),
          );
        }
      } catch (_) {}
      return fallback;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _e, _s) => fallback,
        ),
      );
    }

    return fallback;
  }
}
