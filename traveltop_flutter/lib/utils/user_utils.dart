import 'package:supabase_flutter/supabase_flutter.dart';

/// Checks if a given display name is a dummy/placeholder string.
bool isDummyName(String? name) {
  if (name == null) return true;
  final trimmed = name.trim();
  if (trimmed.isEmpty) return true;
  final lower = trimmed.toLowerCase();
  return lower == 'traveler user' ||
      lower == 'traveller user' ||
      lower == 'google traveler' ||
      lower == 'google traveller' ||
      lower == 'traveler' ||
      lower == 'traveller' ||
      lower == 'customer' ||
      lower == 'user';
}

/// Resolves the real user display name from available sources.
/// Prioritizes real names over placeholders, and falls back to email handle.
String resolveDisplayName({
  String? profileName,
  String? prefName,
  User? user,
  String? email,
}) {
  // 1. Valid profile name from database
  if (!isDummyName(profileName)) return profileName!.trim();

  // 2. Valid user metadata name from auth provider
  final metaName = (user?.userMetadata?['full_name'] as String?) ??
      (user?.userMetadata?['name'] as String?);
  if (!isDummyName(metaName)) return metaName!.trim();

  // 3. Valid stored name in preferences
  if (!isDummyName(prefName)) return prefName!.trim();

  // 4. Extract name handle from email address
  final activeEmail = user?.email ?? email;
  if (activeEmail != null && activeEmail.contains('@')) {
    final handle = activeEmail.split('@')[0].trim();
    if (handle.isNotEmpty && !isDummyName(handle)) {
      // Capitalize first letter of email handle if it looks like a name
      if (handle.length > 1) {
        return handle[0].toUpperCase() + handle.substring(1);
      }
      return handle;
    }
  }

  return 'User';
}
